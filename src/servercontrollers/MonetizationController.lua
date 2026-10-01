local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)

local CONTEXT_LIFETIME = 90

type PendingContext = {
	expiresAt: number,
	choiceSetId: number?,
}

local MonetizationController = {}

local dataService
local monetizationNetwork
local ownershipByPlayer: { [Player]: { [string]: boolean } } = {}
local runBoostByPlayer: { [Player]: boolean } = {}
local pendingContexts: { [Player]: { [string]: PendingContext } } = {}
local processingReceipts: { [string]: boolean } = {}
local processingByUserId: { [number]: boolean } = {}
local developerProductById = {}
local lastPrepareAt: { [Player]: number } = {}
local lastGamepassRefreshAt: { [Player]: { [string]: number } } = {}

local function copyDictionary(source)
	local copy = {}
	if type(source) == "table" then
		for key, value in source do
			copy[key] = value
		end
	end
	return copy
end

local function normalizeData(raw)
	local normalized = {
		ProcessedReceipts = {},
		Credits = {},
	}
	if type(raw) ~= "table" then
		return normalized
	end
	if type(raw.ProcessedReceipts) == "table" then
		for purchaseId, timestamp in raw.ProcessedReceipts do
			if type(purchaseId) == "string" and type(timestamp) == "number" then
				normalized.ProcessedReceipts[purchaseId] = timestamp
			end
		end
	end
	if type(raw.Credits) == "table" then
		for productKey, amount in raw.Credits do
			if MonetizationConfig.DeveloperProducts[productKey]
				and type(amount) == "number"
				and amount >= 0
				and amount % 1 == 0
			then
				normalized.Credits[productKey] = math.min(amount, 100)
			end
		end
	end
	return normalized
end

local function pruneReceipts(receipts)
	local entries = {}
	for purchaseId, timestamp in receipts do
		table.insert(entries, { purchaseId = purchaseId, timestamp = timestamp })
	end
	table.sort(entries, function(left, right)
		return left.timestamp > right.timestamp
	end)
	for index = MonetizationConfig.Shop.MaximumReceiptHistory + 1, #entries do
		receipts[entries[index].purchaseId] = nil
	end
end

local function getData(player: Player)
	if not dataService or player.Parent ~= Players then
		return nil
	end
	return normalizeData(dataService:get(player, MonetizationConfig.DataKey))
end

local function setData(player: Player, value)
	if dataService and player.Parent == Players then
		dataService:set(player, MonetizationConfig.DataKey, value)
	end
end

local function sendState(player: Player)
	if monetizationNetwork and player.Parent == Players then
		monetizationNetwork:fire(player, "StateChanged", MonetizationController.GetSnapshot(nil, player))
	end
end

local function getPendingContext(player: Player, productKey: string): PendingContext?
	local playerContexts = pendingContexts[player]
	local context = playerContexts and playerContexts[productKey]
	if context and context.expiresAt >= workspace:GetServerTimeNow() then
		return context
	end
	if playerContexts then
		playerContexts[productKey] = nil
	end
	return nil
end

local function clearPendingContext(player: Player, productKey: string)
	local playerContexts = pendingContexts[player]
	if playerContexts then
		playerContexts[productKey] = nil
	end
	if productKey == "TakeAll" then
		local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
		RunProgressionController.CancelTakeAllReservation(player)
	end
end

local function grantPremiumBenefits(player: Player, gamepassKey: string)
	local definition = MonetizationConfig.Gamepasses[gamepassKey]
	if not definition or not definition.ClassId then
		return
	end
	-- Premium ownership unlocks the existing class and its required starting ability through their
	-- authoritative persistence APIs; it never creates a parallel premium-only class inventory.
	local AbilityController = require(ServerStorage.Controllers.AbilityController)
	local ClassController = require(ServerStorage.Controllers.ClassController)
	AbilityController.GrantPermanentAbility(player, definition.AbilityId)
	ClassController.GrantPremiumClass(player, definition.ClassId)
end

local function refreshOwnership(player: Player, gamepassKey: string): boolean
	local definition = MonetizationConfig.Gamepasses[gamepassKey]
	if not definition or not MonetizationConfig.IsConfiguredId(definition.GamepassId) or player.Parent ~= Players then
		return false
	end
	local success, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, definition.GamepassId)
	if not success then
		warn(string.format("Could not verify %s for %s: %s", gamepassKey, player.Name, tostring(owns)))
		return false
	end
	local previouslyOwned = ownershipByPlayer[player] and ownershipByPlayer[player][gamepassKey] == true
	ownershipByPlayer[player] = ownershipByPlayer[player] or {}
	ownershipByPlayer[player][gamepassKey] = owns == true
	if owns then
		grantPremiumBenefits(player, gamepassKey)
		if not previouslyOwned then AnalyticsController.CompleteMonetizationCheckout(player, gamepassKey) end
	end
	sendState(player)
	return owns == true
end

local function addReceiptCredit(player: Player, purchaseId: string, productKey: string): (boolean, boolean)
	local data = getData(player)
	if not data then
		return false, false
	end
	if data.ProcessedReceipts[purchaseId] then
		return true, true
	end
	data.ProcessedReceipts[purchaseId] = os.time()
	data.Credits[productKey] = math.min((data.Credits[productKey] or 0) + 1, 100)
	pruneReceipts(data.ProcessedReceipts)
	-- Recording a durable product credit before applying its effect ensures a delayed receipt can never
	-- be acknowledged without leaving recoverable value on the player's profile.
	setData(player, data)
	return true, false
end

local function removeCredit(player: Player, productKey: string)
	local data = getData(player)
	if not data or (data.Credits[productKey] or 0) <= 0 then
		return
	end
	data.Credits[productKey] -= 1
	setData(player, data)
end

local function applyCredit(player: Player, productKey: string): boolean
	local definition = MonetizationConfig.DeveloperProducts[productKey]
	if not definition then
		return false
	end
	if definition.Coins then
		local CoinsController = require(ServerStorage.Controllers.CoinsController)
		return CoinsController.Add(player, definition.Coins)
	elseif productKey == "Revive" then
		if not getPendingContext(player, productKey) then return false end
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		local applied = RunSessionController.RevivePlayer(player, "Purchase")
		if applied then clearPendingContext(player, productKey) end
		return applied
	elseif productKey == "ReviveTeam" then
		if not getPendingContext(player, productKey) then return false end
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		local applied = RunSessionController.ReviveTeam(player, "Purchase") > 0
		if applied then clearPendingContext(player, productKey) end
		return applied
	elseif productKey == "RunBoost" then
		if not getPendingContext(player, productKey) or not ServerContext.IsGameServer() or runBoostByPlayer[player] then
			return false
		end
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		if not RunSessionController.CanUseRunProduct(player) then
			return false
		end
		runBoostByPlayer[player] = true
		clearPendingContext(player, productKey)
		sendState(player)
		return true
	elseif productKey == "TakeAll" then
		local context = getPendingContext(player, productKey)
		if not context or not context.choiceSetId then
			return false
		end
		local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
		local granted = RunProgressionController.GrantReservedTakeAll(player, context.choiceSetId)
		if granted then
			clearPendingContext(player, productKey)
		end
		return granted
	end
	return false
end

local function consumeOneCredit(player: Player, productKey: string): boolean
	local data = getData(player)
	if not data or (data.Credits[productKey] or 0) <= 0 then
		return false
	end
	if not applyCredit(player, productKey) then
		return false
	end
	removeCredit(player, productKey)
	if monetizationNetwork and player.Parent == Players then
		monetizationNetwork:fire(player, "PurchaseApplied", productKey)
	end
	AnalyticsController.CompleteMonetizationCheckout(player, productKey)
	return true
end

local function processReceipt(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if processingReceipts[purchaseId] or processingByUserId[receiptInfo.PlayerId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local productKey = developerProductById[receiptInfo.ProductId]
	if not productKey then
		warn(string.format("Unconfigured developer product receipt: %s", tostring(receiptInfo.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not dataService then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processingReceipts[purchaseId] = true
	processingByUserId[receiptInfo.PlayerId] = true
	local recorded, duplicate = addReceiptCredit(player, purchaseId, productKey)
	if recorded and not duplicate then
		consumeOneCredit(player, productKey)
	end
	processingReceipts[purchaseId] = nil
	processingByUserId[receiptInfo.PlayerId] = nil
	return if recorded then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationController.GetSnapshot(_, player: Player)
	local ownership = {}
	for gamepassKey in MonetizationConfig.Gamepasses do
		ownership[gamepassKey] = ownershipByPlayer[player] and ownershipByPlayer[player][gamepassKey] == true
	end
	return {
		ownership = ownership,
		runBoostActive = runBoostByPlayer[player] == true,
	}
end

function MonetizationController.PrepareProductPurchase(_, player: Player, productKey: any)
	local now = workspace:GetServerTimeNow()
	if now - (lastPrepareAt[player] or 0) < 0.2 then
		return { allowed = false, reason = "Please wait a moment." }
	end
	lastPrepareAt[player] = now
	if type(productKey) ~= "string" then
		return { allowed = false, reason = "Invalid product." }
	end
	local definition = MonetizationConfig.DeveloperProducts[productKey]
	if not definition or not MonetizationConfig.IsConfiguredId(definition.ProductId) then
		return { allowed = false, reason = "This product has not been configured yet." }
	end
	local context: PendingContext = { expiresAt = workspace:GetServerTimeNow() + CONTEXT_LIFETIME }
	local contextualCount
	if productKey == "Revive" then
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		if not RunSessionController.CanRevivePlayer(player) then
			return { allowed = false, reason = "Revive is only available while you are down." }
		end
	elseif productKey == "ReviveTeam" then
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		contextualCount = RunSessionController.GetEligibleTeamReviveCount(player)
		if contextualCount <= 0 then
			return { allowed = false, reason = "No teammates can be revived right now." }
		end
	elseif productKey == "RunBoost" then
		local RunSessionController = require(ServerStorage.Controllers.RunSessionController)
		if runBoostByPlayer[player] or not RunSessionController.CanUseRunProduct(player) then
			return { allowed = false, reason = "Run Boost is only available once during an active run." }
		end
	elseif productKey == "TakeAll" then
		local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
		context.choiceSetId = RunProgressionController.ReserveTakeAll(player, CONTEXT_LIFETIME)
		if not context.choiceSetId then
			return { allowed = false, reason = "This ability choice is no longer available." }
		end
	end
	pendingContexts[player] = pendingContexts[player] or {}
	pendingContexts[player][productKey] = context
	local data = getData(player)
	if data and (data.Credits[productKey] or 0) > 0 and consumeOneCredit(player, productKey) then
		-- A previously paid contextual credit is always used before offering another charge. This covers
		-- teleport/disconnect timing without ever granting a stale roll or reviving an arbitrary player.
		return {
			allowed = false,
			applied = true,
			reason = "Your saved purchase was applied. No additional charge was made.",
		}
	end
	AnalyticsController.StartMonetizationCheckout(player, productKey, "Developer Product")
	return { allowed = true, productId = definition.ProductId, contextualCount = contextualCount }
end

function MonetizationController.PrepareGamepassPurchase(_, player: Player, gamepassKey: any)
	local now = workspace:GetServerTimeNow()
	if now - (lastPrepareAt[player] or 0) < 0.2 then
		return { allowed = false, reason = "Please wait a moment." }
	end
	lastPrepareAt[player] = now
	local definition = type(gamepassKey) == "string" and MonetizationConfig.Gamepasses[gamepassKey]
	if not definition or not MonetizationConfig.IsConfiguredId(definition.GamepassId) then
		return { allowed = false, reason = "This Gamepass has not been configured yet." }
	end
	if MonetizationController.OwnsGamepass(player, gamepassKey) then
		return { allowed = false, reason = "Already owned." }
	end
	AnalyticsController.StartMonetizationCheckout(player, gamepassKey, "Gamepass")
	return { allowed = true, gamepassId = definition.GamepassId }
end

function MonetizationController.CancelProductPurchase(_, player: Player, productKey: any)
	if type(productKey) == "string" then
		clearPendingContext(player, productKey)
	end
end

function MonetizationController.RefreshGamepass(_, player: Player, gamepassKey: any)
	if type(gamepassKey) == "string" and MonetizationConfig.Gamepasses[gamepassKey] then
		lastGamepassRefreshAt[player] = lastGamepassRefreshAt[player] or {}
		local now = workspace:GetServerTimeNow()
		if now - (lastGamepassRefreshAt[player][gamepassKey] or 0) < 2 then return end
		lastGamepassRefreshAt[player][gamepassKey] = now
		refreshOwnership(player, gamepassKey)
	end
end

function MonetizationController.OwnsGamepass(player: Player, gamepassKey: string): boolean
	return ownershipByPlayer[player] and ownershipByPlayer[player][gamepassKey] == true or false
end

function MonetizationController.GetCoinMultiplier(player: Player): number
	local multiplier = if MonetizationController.OwnsGamepass(player, "DoubleCoins")
		then MonetizationConfig.Run.PermanentCoinMultiplier
		else 1
	if runBoostByPlayer[player] then
		multiplier *= MonetizationConfig.Run.BoostCoinMultiplier
	end
	return multiplier
end

function MonetizationController.GetXPMultiplier(player: Player): number
	return if runBoostByPlayer[player] then MonetizationConfig.Run.BoostXPMultiplier else 1
end

function MonetizationController.GetAbilitySlotLimit(player: Player, category: string): number
	local ownsExtraSlots = MonetizationController.OwnsGamepass(player, "ExtraAbilitySlots")
	if category == "Weapon" then
		return MonetizationConfig.AbilitySlots.BaseWeapon
			+ (if ownsExtraSlots then MonetizationConfig.AbilitySlots.GamepassWeaponBonus else 0)
	end
	return MonetizationConfig.AbilitySlots.BasePassive
		+ (if ownsExtraSlots then MonetizationConfig.AbilitySlots.GamepassPassiveBonus else 0)
end

function MonetizationController.ResetRun(player: Player)
	runBoostByPlayer[player] = false
	clearPendingContext(player, "TakeAll")
	sendState(player)
end

function MonetizationController.SetDataService(service)
	dataService = service
end

function MonetizationController.Init()
	table.clear(developerProductById)
	for productKey, definition in MonetizationConfig.DeveloperProducts do
		if MonetizationConfig.IsConfiguredId(definition.ProductId) then
			developerProductById[definition.ProductId] = productKey
		end
	end
	monetizationNetwork = Networker.server.new("MonetizationController", MonetizationController, {
		MonetizationController.GetSnapshot,
		MonetizationController.PrepareProductPurchase,
		MonetizationController.PrepareGamepassPurchase,
		MonetizationController.CancelProductPurchase,
		MonetizationController.RefreshGamepass,
	})
	-- This controller is the single receipt owner. No other controller may assign ProcessReceipt.
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationController.OnPlayerAdded(player: Player)
	ownershipByPlayer[player] = {}
	runBoostByPlayer[player] = false
	pendingContexts[player] = {}
	lastPrepareAt[player] = -math.huge
	lastGamepassRefreshAt[player] = {}
	local normalized = normalizeData(dataService:get(player, MonetizationConfig.DataKey))
	setData(player, normalized)
	for productKey, amount in normalized.Credits do
		local definition = MonetizationConfig.DeveloperProducts[productKey]
		if amount > 0 and definition and (definition.Coins or productKey == "RunBoost") then
			while consumeOneCredit(player, productKey) do end
		end
	end
	for gamepassKey, definition in MonetizationConfig.Gamepasses do
		if MonetizationConfig.IsConfiguredId(definition.GamepassId) then
			-- Ownership requests are independent Marketplace calls; never hold up the rest of the player's
			-- controller initialization while Roblox resolves a catalog request.
			task.spawn(refreshOwnership, player, gamepassKey)
		end
	end
	sendState(player)
end

function MonetizationController.OnPlayerRemoving(player: Player)
	ownershipByPlayer[player] = nil
	runBoostByPlayer[player] = nil
	pendingContexts[player] = nil
	lastPrepareAt[player] = nil
	lastGamepassRefreshAt[player] = nil
end

return MonetizationController
