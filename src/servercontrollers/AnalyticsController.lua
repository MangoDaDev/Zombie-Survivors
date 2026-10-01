local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local AnalyticsConfig = require(ReplicatedStorage.Modules.Game.AnalyticsConfig)
local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local SurvivalStatsConfig = require(ReplicatedStorage.Modules.Game.SurvivalStatsConfig)
local ServerContext = require(script.Parent.ServerContext)

type FunnelRuntime = {
	id: string,
	highestStep: number,
}

type ShopRuntime = FunnelRuntime & {
	selectedItemId: string?,
}

local AnalyticsController = {}

local SHOP_OPEN_COOLDOWN = 1
local SHOP_SELECTION_COOLDOWN = 0.08

local dataService
local analyticsNetwork
local gameplayFunnels: { [Player]: FunnelRuntime } = {}
local shopFunnels: { [Player]: { [string]: ShopRuntime } } = {}
local choiceFunnels: { [Player]: { [number]: FunnelRuntime } } = {}
local replayFunnels: { [Player]: FunnelRuntime } = {}
local monetizationFunnels: { [Player]: { [string]: FunnelRuntime } } = {}
local lastShopOpenAt: { [Player]: number } = {}
local lastShopSelectionAt: { [Player]: number } = {}

local CUSTOM_FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function makeCustomFields(values: { any }?): { [string]: string }?
	if not values then
		return nil
	end
	local fields = {}
	for index = 1, math.min(#values, #CUSTOM_FIELD_KEYS) do
		local value = values[index]
		if value ~= nil then
			fields[CUSTOM_FIELD_KEYS[index]] = tostring(value)
		end
	end
	return if next(fields) then fields else nil
end

local function logStep(player: Player, funnel, sessionId: string, stepNumber: number, fieldValues: { any }?): boolean
	local stepName = funnel.Steps[stepNumber]
	if player.Parent ~= Players or not stepName then
		return false
	end

	-- Analytics is observational and must never interrupt authoritative gameplay if the platform rejects
	-- an event (for example, from an unpublished Studio session). Surface the error without propagating it.
	local success, errorMessage = pcall(
		AnalyticsService.LogFunnelStepEvent,
		AnalyticsService,
		player,
		funnel.Name,
		sessionId,
		stepNumber,
		stepName,
		makeCustomFields(fieldValues)
	)
	if not success then
		warn(string.format("Analytics funnel %s step %d failed: %s", funnel.Name, stepNumber, tostring(errorMessage)))
	end
	return success
end

local function logOnboardingStep(player: Player, stepNumber: number, fieldValues: { any }?): boolean
	local funnel = AnalyticsConfig.Funnels.Onboarding
	local stepName = funnel.Steps[stepNumber]
	if player.Parent ~= Players or not stepName then
		return false
	end

	-- Roblox owns the one-time onboarding session, so this uses the dedicated onboarding funnel API
	-- instead of inventing a repeatable funnel session ID for a flow each player should complete once.
	local success, errorMessage = pcall(
		AnalyticsService.LogOnboardingFunnelStepEvent,
		AnalyticsService,
		player,
		stepNumber,
		stepName,
		makeCustomFields(fieldValues)
	)
	if not success then
		warn(string.format("Analytics onboarding step %d failed: %s", stepNumber, tostring(errorMessage)))
	end
	return success
end

local function advanceFunnel(
	player: Player,
	runtime: FunnelRuntime?,
	funnel,
	stepNumber: number,
	fieldValues: { any }?
): boolean
	-- Requiring the next exact step keeps duplicate callbacks and out-of-order lifecycle events from
	-- inflating conversion counts or making a player appear to complete steps they skipped.
	if not runtime or stepNumber ~= runtime.highestStep + 1 then
		return false
	end
	if not logStep(player, funnel, runtime.id, stepNumber, fieldValues) then
		return false
	end
	runtime.highestStep = stepNumber
	return true
end

local function getAnalyticsData(player: Player)
	local saved = dataService:get(player, AnalyticsConfig.DataKey)
	return {
		OnboardingVersion = if type(saved) == "table" and type(saved.OnboardingVersion) == "number"
			then math.max(0, math.floor(saved.OnboardingVersion))
			else 0,
		OnboardingStep = if type(saved) == "table" and type(saved.OnboardingStep) == "number"
			then math.clamp(math.floor(saved.OnboardingStep), 0, #AnalyticsConfig.Funnels.Onboarding.Steps)
			else 0,
	}
end

local function getClassId(player: Player): string
	local classData = dataService:get(player, ClassDefinitions.DataKey)
	local classId = type(classData) == "table" and classData.Equipped or nil
	return if type(classId) == "string" and ClassDefinitions.ById[classId] then classId else ClassDefinitions.DefaultId
end

local function getLifetimeRounds(player: Player): number
	local value = dataService:get(player, SurvivalStatsConfig.DataKey)
	return if type(value) == "number" and value >= 0 then math.floor(value) else 0
end

local function getProgressBucket(rounds: number): string
	if rounds <= 0 then
		return "Progress - New"
	elseif rounds < 15 then
		return "Progress - Early"
	elseif rounds < 60 then
		return "Progress - Established"
	end
	return "Progress - Veteran"
end

local function getLevelBucket(level: number): string
	if level <= 5 then
		return "Level - 1-5"
	elseif level <= 10 then
		return "Level - 6-10"
	elseif level <= 20 then
		return "Level - 11-20"
	elseif level <= 35 then
		return "Level - 21-35"
	end
	return "Level - 36+"
end

local function getRoundBucket(roundNumber: number): string
	if roundNumber <= 4 then
		return "Round - 1-4"
	elseif roundNumber <= 14 then
		return "Round - 5-14"
	elseif roundNumber <= 29 then
		return "Round - 15-29"
	elseif roundNumber <= 44 then
		return "Round - 30-44"
	elseif roundNumber <= 59 then
		return "Round - 45-59"
	end
	return "Round - 60+"
end

local function getPartySize(): number
	local runData = ServerContext.GetRunData()
	local partySize = type(runData) == "table" and runData.partySize or nil
	return if type(partySize) == "number" and partySize >= 1 then math.floor(partySize) else #Players:GetPlayers()
end

local function getPlayerFields(player: Player): { string }
	local rounds = getLifetimeRounds(player)
	return {
		"Class - " .. getClassId(player),
		getProgressBucket(rounds),
		"Party Size - " .. tostring(math.max(getPartySize(), 1)),
	}
end

local function isValidShopItem(shopKind: string, itemId: string): boolean
	return (shopKind == "Ability" and AbilityDefinitions.ById[itemId] ~= nil)
		or (shopKind == "Class" and ClassDefinitions.ById[itemId] ~= nil)
end

local function getShopDefinition(shopKind: string)
	if shopKind == "Ability" then
		return AnalyticsConfig.Funnels.AbilityShop
	elseif shopKind == "Class" then
		return AnalyticsConfig.Funnels.ClassShop
	end
	return nil
end

function AnalyticsController.ShopOpened(_, player: Player, shopKind: any)
	local funnel = type(shopKind) == "string" and getShopDefinition(shopKind) or nil
	local now = workspace:GetServerTimeNow()
	if not funnel
		or not ServerContext.IsLobbyServer()
		or now - (lastShopOpenAt[player] or -math.huge) < SHOP_OPEN_COOLDOWN
	then
		return
	end
	lastShopOpenAt[player] = now

	local runtime: ShopRuntime = {
		id = HttpService:GenerateGUID(false),
		highestStep = 0,
		selectedItemId = nil,
	}
	shopFunnels[player] = shopFunnels[player] or {}
	shopFunnels[player][shopKind] = runtime
	advanceFunnel(player, runtime, funnel, 1, getPlayerFields(player))
end

function AnalyticsController.ShopItemSelected(_, player: Player, shopKind: any, itemId: any)
	local now = workspace:GetServerTimeNow()
	if type(shopKind) ~= "string"
		or type(itemId) ~= "string"
		or not ServerContext.IsLobbyServer()
		or not isValidShopItem(shopKind, itemId)
		or now - (lastShopSelectionAt[player] or -math.huge) < SHOP_SELECTION_COOLDOWN
	then
		return
	end
	lastShopSelectionAt[player] = now
	local runtime = shopFunnels[player] and shopFunnels[player][shopKind]
	local funnel = getShopDefinition(shopKind)
	if not runtime or not funnel then
		return
	end
	if runtime.highestStep >= 3 and runtime.selectedItemId ~= itemId then
		-- A different item after an attempted checkout is a new repeatable checkout session within
		-- the same visible shop visit, so its later purchase cannot complete the previous item's funnel.
		runtime = {
			id = HttpService:GenerateGUID(false),
			highestStep = 0,
			selectedItemId = itemId,
		}
		shopFunnels[player][shopKind] = runtime
		advanceFunnel(player, runtime, funnel, 1, {
			"Item - " .. itemId,
			"Class - " .. getClassId(player),
			getProgressBucket(getLifetimeRounds(player)),
		})
	end
	runtime.selectedItemId = itemId
	advanceFunnel(player, runtime, funnel, 2, { "Item - " .. itemId })
end

function AnalyticsController.TrackShopPurchaseAttempt(player: Player, shopKind: string, itemId: string)
	local runtime = shopFunnels[player] and shopFunnels[player][shopKind]
	local funnel = getShopDefinition(shopKind)
	if not runtime or not funnel or not isValidShopItem(shopKind, itemId) then
		return
	end
	if runtime.highestStep == 1 then
		runtime.selectedItemId = itemId
		advanceFunnel(player, runtime, funnel, 2, { "Item - " .. itemId })
	end
	-- The server request is the authoritative selected item even if the player browsed several cards
	-- after the one-time selection step was recorded.
	runtime.selectedItemId = itemId
	advanceFunnel(player, runtime, funnel, 3, { "Item - " .. itemId })
end

function AnalyticsController.TrackShopPurchaseCompleted(player: Player, shopKind: string, itemId: string)
	local runtime = shopFunnels[player] and shopFunnels[player][shopKind]
	local funnel = getShopDefinition(shopKind)
	if runtime and funnel and runtime.selectedItemId == itemId then
		advanceFunnel(player, runtime, funnel, 4, { "Item - " .. itemId })
	end
end

function AnalyticsController.StartMonetizationCheckout(player: Player, productKey: string, productKind: string)
	local runtime: FunnelRuntime = { id = HttpService:GenerateGUID(false), highestStep = 0 }
	monetizationFunnels[player] = monetizationFunnels[player] or {}
	monetizationFunnels[player][productKey] = runtime
	advanceFunnel(player, runtime, AnalyticsConfig.Funnels.MonetizationCheckout, 1, {
		"Product - " .. productKey,
		"Kind - " .. productKind,
		getProgressBucket(getLifetimeRounds(player)),
	})
end

function AnalyticsController.CompleteMonetizationCheckout(player: Player, productKey: string)
	local runtime = monetizationFunnels[player] and monetizationFunnels[player][productKey]
	if advanceFunnel(player, runtime, AnalyticsConfig.Funnels.MonetizationCheckout, 2, {
		"Product - " .. productKey,
	}) then
		monetizationFunnels[player][productKey] = nil
	end
end

function AnalyticsController.TrackOnboardingStep(player: Player, stepNumber: number)
	local funnel = AnalyticsConfig.Funnels.Onboarding
	local data = getAnalyticsData(player)
	if data.OnboardingVersion >= AnalyticsConfig.OnboardingVersion or stepNumber ~= data.OnboardingStep + 1 then
		return
	end
	local fields = if stepNumber == 1 then getPlayerFields(player) else nil
	if not logOnboardingStep(player, stepNumber, fields) then
		return
	end

	data.OnboardingStep = stepNumber
	if stepNumber == #funnel.Steps then
		data.OnboardingVersion = AnalyticsConfig.OnboardingVersion
	end
	-- Persisting each boundary lets this first-run funnel continue across the lobby-to-game teleport.
	dataService:set(player, AnalyticsConfig.DataKey, data)
end

function AnalyticsController.TrackLifetimeProgression(player: Player, roundsSurvived: number)
	local stepNumber = table.find(AnalyticsConfig.LifetimeRoundMilestones, roundsSurvived)
	if not stepNumber then
		return
	end
	local sessionId = string.format("lifetime-rounds-v1-%d", player.UserId)
	logStep(
		player,
		AnalyticsConfig.Funnels.LifetimeProgression,
		sessionId,
		stepNumber,
		if stepNumber == 1 then getPlayerFields(player) else nil
	)
end

function AnalyticsController.StartGameplayRun(player: Player)
	local runtime: FunnelRuntime = {
		id = HttpService:GenerateGUID(false),
		highestStep = 0,
	}
	gameplayFunnels[player] = runtime
	advanceFunnel(player, runtime, AnalyticsConfig.Funnels.GameplayLoop, 1, getPlayerFields(player))
end

function AnalyticsController.TrackGameplayStep(player: Player, stepNumber: number, fieldValues: { any }?)
	advanceFunnel(player, gameplayFunnels[player], AnalyticsConfig.Funnels.GameplayLoop, stepNumber, fieldValues)
end

function AnalyticsController.StartRunChoice(player: Player, choiceSetId: number, level: number, choices)
	local hasNew = false
	local hasUpgrade = false
	for _, choice in choices do
		hasNew = hasNew or choice.kind == "New"
		hasUpgrade = hasUpgrade or choice.kind == "Upgrade"
	end
	local offerKind = if hasNew and hasUpgrade then "Mixed" elseif hasNew then "New" else "Upgrade"
	local runtime: FunnelRuntime = {
		id = HttpService:GenerateGUID(false),
		highestStep = 0,
	}
	choiceFunnels[player] = choiceFunnels[player] or {}
	choiceFunnels[player][choiceSetId] = runtime
	advanceFunnel(player, runtime, AnalyticsConfig.Funnels.RunAbilityChoice, 1, {
		getLevelBucket(level),
		"Offer - " .. offerKind,
		"Class - " .. getClassId(player),
	})
end

function AnalyticsController.TrackRunChoiceSelected(player: Player, choiceSetId: number, abilityId: string, choiceKind: string)
	local runtime = choiceFunnels[player] and choiceFunnels[player][choiceSetId]
	advanceFunnel(player, runtime, AnalyticsConfig.Funnels.RunAbilityChoice, 2, {
		"Item - " .. abilityId,
		"Choice - " .. choiceKind,
	})
end

function AnalyticsController.TrackRunChoiceApplied(player: Player, choiceSetId: number, abilityId: string, choiceKind: string)
	local runtime = choiceFunnels[player] and choiceFunnels[player][choiceSetId]
	if advanceFunnel(player, runtime, AnalyticsConfig.Funnels.RunAbilityChoice, 3, {
		"Item - " .. abilityId,
		"Choice - " .. choiceKind,
	}) then
		choiceFunnels[player][choiceSetId] = nil
	end
end

function AnalyticsController.StartReplayFunnel(player: Player, levelReached: number, roundReached: number)
	local runtime: FunnelRuntime = {
		id = HttpService:GenerateGUID(false),
		highestStep = 0,
	}
	replayFunnels[player] = runtime
	advanceFunnel(player, runtime, AnalyticsConfig.Funnels.Replay, 1, {
		getLevelBucket(levelReached),
		getRoundBucket(roundReached),
		"Party Size - " .. tostring(math.max(getPartySize(), 1)),
	})
end

function AnalyticsController.TrackReplayStep(player: Player, stepNumber: number)
	advanceFunnel(player, replayFunnels[player], AnalyticsConfig.Funnels.Replay, stepNumber, nil)
end

function AnalyticsController.SetDataService(service)
	dataService = service
end

function AnalyticsController.Init()
	analyticsNetwork = Networker.server.new("AnalyticsController", AnalyticsController, {
		AnalyticsController.ShopOpened,
		AnalyticsController.ShopItemSelected,
	})
end

function AnalyticsController.OnPlayerAdded(player: Player)
	shopFunnels[player] = {}
	choiceFunnels[player] = {}
	monetizationFunnels[player] = {}
	local data = getAnalyticsData(player)
	if ServerContext.IsLobbyServer()
		and data.OnboardingVersion < AnalyticsConfig.OnboardingVersion
		and (data.OnboardingStep > 0 or getLifetimeRounds(player) == 0)
	then
		AnalyticsController.TrackOnboardingStep(player, 1)
	end
end

function AnalyticsController.OnCharacterAdded(player: Player, _character: Model)
	if ServerContext.IsLobbyServer() then
		AnalyticsController.TrackOnboardingStep(player, 2)
	end
end

function AnalyticsController.OnPlayerRemoving(player: Player)
	gameplayFunnels[player] = nil
	shopFunnels[player] = nil
	choiceFunnels[player] = nil
	replayFunnels[player] = nil
	monetizationFunnels[player] = nil
	lastShopOpenAt[player] = nil
	lastShopSelectionAt[player] = nil
end

return AnalyticsController
