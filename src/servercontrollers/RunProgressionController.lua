local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local MonetizationController = require(ServerStorage.Controllers.MonetizationController)
local RageController = require(ServerStorage.Controllers.RageController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)

type Choice = {
	abilityId: string,
	kind: string,
	currentLevel: number,
	nextLevel: number,
}

type PlayerRunState = {
	level: number,
	xp: number,
	totalXP: number,
	xpRequired: number,
	pendingChoices: number,
	choiceSetId: number,
	choices: { Choice }?,
}

local RunProgressionController = {}

local progressionNetwork
local random = Random.new()
local states: { [Player]: PlayerRunState } = {}
local endedPlayers: { [Player]: boolean } = {}
local takeAllReservations: { [Player]: { choiceSetId: number, expiresAt: number } } = {}

local function getAbilitySnapshot(player: Player)
	local snapshot = {}
	local runData = AbilityController.GetRunData(player)
	if not runData then
		return snapshot
	end
	for _, definition in AbilityDefinitions.List do
		local level = runData.Levels[definition.Id]
		if runData.Owned[definition.Id] and type(level) == "number" then
			table.insert(snapshot, {
				id = definition.Id,
				level = level,
				category = definition.Category,
			})
		end
	end
	return snapshot
end

local function makePacket(player: Player, state: PlayerRunState)
	return {
		active = ServerContext.IsGameServer(),
		level = state.level,
		xp = state.xp,
		xpRequired = state.xpRequired,
		pendingChoices = state.pendingChoices,
		choiceSetId = state.choiceSetId,
		choices = state.choices,
		abilities = getAbilitySnapshot(player),
	}
end

local function sendState(player: Player, state: PlayerRunState)
	if progressionNetwork and player.Parent == Players then
		progressionNetwork:fire(player, "RunStateChanged", makePacket(player, state))
	end
end

local function buildCandidates(player: Player)
	local runData = AbilityController.GetRunData(player)
	if not runData then
		return {}
	end
	local permanentData = AbilityController.GetPermanentData(player)
	local candidates = {}
	-- Choice kind is explicit so future Evolution candidates can share this roller and validation path
	-- without masquerading as duplicate abilities or weakening server authority.
	for _, definition in AbilityDefinitions.List do
		local currentLevel = runData.Levels[definition.Id]
		if runData.Owned[definition.Id] then
			if type(currentLevel) == "number" and currentLevel < definition.MaxLevel then
				table.insert(candidates, {
					abilityId = definition.Id,
					kind = "Upgrade",
					currentLevel = currentLevel,
					nextLevel = currentLevel + 1,
				})
			end
		elseif permanentData.Owned[definition.Id] == true
			or table.find(RunProgressionConfig.Abilities.AlwaysAvailable, definition.Id)
		then
			local equipped = runData.Equipped[definition.Category]
			if #equipped < AbilityController.GetEquipLimit(player, definition.Category) then
				table.insert(candidates, {
					abilityId = definition.Id,
					kind = "New",
					currentLevel = 0,
					nextLevel = 1,
				})
			end
		end
	end
	return candidates
end

local function takeCandidate(candidates, passiveWeight: number)
	if passiveWeight == 1 then
		return table.remove(candidates, random:NextInteger(1, #candidates))
	end
	local totalWeight = 0
	for _, candidate in candidates do
		local category = AbilityDefinitions.ById[candidate.abilityId].Category
		totalWeight += if category == AbilityDefinitions.Categories.Passive then passiveWeight else 1
	end
	local roll = random:NextNumber() * totalWeight
	for index, candidate in candidates do
		local category = AbilityDefinitions.ById[candidate.abilityId].Category
		roll -= if category == AbilityDefinitions.Categories.Passive then passiveWeight else 1
		if roll <= 0 then
			return table.remove(candidates, index)
		end
	end
	return table.remove(candidates, #candidates)
end

local function chooseWithoutReplacement(candidates, count: number, slotFillRatio: number, passiveWeight: number): { Choice }
	local choices = {}
	local upgrades = {}
	local newAbilities = {}
	for _, candidate in candidates do
		table.insert(if candidate.kind == "Upgrade" then upgrades else newAbilities, candidate)
	end
	local newOfferChance = RunProgressionConfig.Abilities.NewOfferChanceAtEmpty
		+ (RunProgressionConfig.Abilities.NewOfferChanceAtFull
			- RunProgressionConfig.Abilities.NewOfferChanceAtEmpty) * math.clamp(slotFillRatio, 0, 1)
	local offeredNew = false
	local guaranteedUpgradeCount = math.min(2, #upgrades)
	while #choices < count and (#upgrades > 0 or #newAbilities > 0) do
		-- Preserve the owned-ability preference; only the passive catch-up bonus changes weights
		-- inside each group. Rarity and current level never affect candidate selection.
		local selected
		if #upgrades > 0 and (#choices < guaranteedUpgradeCount or #newAbilities == 0) then
			selected = takeCandidate(upgrades, passiveWeight)
		elseif not offeredNew and #newAbilities > 0 and (#upgrades == 0 or random:NextNumber() < newOfferChance) then
			selected = takeCandidate(newAbilities, passiveWeight)
			offeredNew = true
		elseif #upgrades > 0 then
			selected = takeCandidate(upgrades, passiveWeight)
		else
			selected = takeCandidate(newAbilities, passiveWeight)
			offeredNew = true
		end
		table.insert(choices, {
			abilityId = selected.abilityId,
			kind = selected.kind,
			currentLevel = selected.currentLevel,
			nextLevel = selected.nextLevel,
		})
	end
	return choices
end

local function offerNextChoice(player: Player, state: PlayerRunState)
	if state.choices or state.pendingChoices <= 0 then
		return
	end
	if not AbilityController.GetRunData(player) then
		-- Studio destination listeners run asynchronously. Preserve the earned choice until the
		-- ability run state is ready instead of incorrectly treating the temporary empty pool as final.
		return
	end
	local runData = AbilityController.GetRunData(player)
	local equippedCount = #runData.Equipped.Weapon + #runData.Equipped.Passive
	local totalSlots = AbilityController.GetEquipLimit(player, "Weapon")
		+ AbilityController.GetEquipLimit(player, "Passive")
	-- Count distinct equipped abilities, not their levels. Passives get a catch-up bonus only
	-- while the player has fewer passives than active weapons in the authoritative run loadout.
	local passiveWeight = if #runData.Equipped.Passive < #runData.Equipped.Weapon
		then RunProgressionConfig.Abilities.PassiveCatchUpWeight
		else 1
	local choices = chooseWithoutReplacement(
		buildCandidates(player),
		RunProgressionConfig.Abilities.ChoiceCount,
		equippedCount / totalSlots,
		passiveWeight
	)
	if #choices == 0 then
		-- This only occurs after every legal run ability reaches its configured maximum.
		state.pendingChoices = 0
		return
	end
	state.choiceSetId += 1
	state.choices = choices
	AnalyticsController.StartRunChoice(player, state.choiceSetId, state.level, choices)
end

local function initializePlayer(player: Player)
	if states[player] or endedPlayers[player] or not ServerContext.IsGameServer() then
		return
	end
	-- XP state is independent of ability state. In Studio, both systems react to the same asynchronous
	-- destination signal, so requiring abilities here can permanently skip progression initialization.
	local state: PlayerRunState = {
		level = 1,
		xp = 0,
		totalXP = 0,
		xpRequired = RunProgressionConfig.GetXPRequirement(1),
		pendingChoices = 0,
		choiceSetId = 0,
		choices = nil,
	}
	states[player] = state
	sendState(player, state)
end

function RunProgressionController.AddXP(player: Player, amount: number): boolean
	if not states[player] then
		-- Collection is an authoritative fallback initialization point, ensuring a transient startup
		-- ordering race can never consume a shard without crediting its XP.
		initializePlayer(player)
	end
	local state = states[player]
	if not state or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end

	local manualLevel = RuntimeState.Get(player, "TrainingManualAbilityLevel", nil)
	local manualStats
	if type(manualLevel) == "number" then
		local definition = AbilityDefinitions.ById.TrainingManual
		manualStats = if RageController.IsActive(player) then definition.GetRageStats(manualLevel) else definition.GetStats(manualLevel)
	end
	-- Run Boost is multiplied with ability bonuses at the authoritative award point, so clients cannot
	-- fabricate boosted XP and every XP source automatically observes the same run-only entitlement.
	local xpMultiplier = MonetizationController.GetXPMultiplier(player)
		* (1 + (manualStats and manualStats.XPBonusPercent or 0) / 100)
	if manualStats and amount >= manualStats.LargeCrystalMinimum then
		xpMultiplier *= 1 + manualStats.LargeCrystalBonusPercent / 100
	end
	if manualStats and RuntimeState.Get(player, "TrainingManualBreakthroughReady", false) then
		xpMultiplier *= 1 + manualStats.BreakthroughBonusPercent / 100
		RuntimeState.Set(player, "TrainingManualBreakthroughReady", false)
	end
	local awardedXP = math.max(1, math.floor(amount * xpMultiplier + 0.5))
	state.xp += awardedXP
	state.totalXP += awardedXP
	local earnedLevels = 0
	while state.level < RunProgressionConfig.XP.MaximumLevel and state.xp >= state.xpRequired do
		state.xp -= state.xpRequired
		state.level += 1
		earnedLevels += 1
		state.xpRequired = RunProgressionConfig.GetXPRequirement(state.level)
	end
	if state.level >= RunProgressionConfig.XP.MaximumLevel then
		state.xp = 0
		state.xpRequired = 0
	end
	if earnedLevels > 0 then
		-- One pending token always corresponds to exactly one server-validated card selection.
		state.pendingChoices += earnedLevels
		if manualStats and manualStats.BreakthroughBonusPercent > 0 then
			RuntimeState.Set(player, "TrainingManualBreakthroughReady", true)
		end
		AnalyticsController.TrackGameplayStep(player, 4, { "Level - " .. tostring(state.level) })
	end
	if state.pendingChoices > 0 then
		-- Retry unresolved tokens on every XP update. This closes the brief startup window where progression
		-- can initialize before the run ability pool and guarantees every earned level eventually gets a roll.
		offerNextChoice(player, state)
	end
	sendState(player, state)
	return true
end

function RunProgressionController.SetLevelForAdmin(player: Player, targetLevel: number): (boolean, number?)
	if type(targetLevel) ~= "number"
		or targetLevel % 1 ~= 0
		or targetLevel < 1
		or targetLevel > RunProgressionConfig.XP.MaximumLevel
	then
		return false, nil
	end
	if not states[player] then
		initializePlayer(player)
	end
	local state = states[player]
	if not state then
		return false, nil
	end

	local previousLevel = state.level
	state.level = targetLevel
	state.xp = 0
	state.xpRequired = if targetLevel >= RunProgressionConfig.XP.MaximumLevel
		then 0
		else RunProgressionConfig.GetXPRequirement(targetLevel)
	if targetLevel > previousLevel then
		-- Admin-granted levels preserve the normal one-choice-per-level invariant so test runs exercise
		-- the same legal ability selection flow as XP-earned progression.
		state.pendingChoices += targetLevel - previousLevel
	elseif targetLevel < previousLevel then
		-- Lowering the displayed run level must not leave choices earned by the discarded levels queued.
		-- Already selected run abilities remain intact because silently undoing a loadout is more surprising.
		state.pendingChoices = 0
		state.choices = nil
	end
	if state.pendingChoices > 0 then
		offerNextChoice(player, state)
	end
	sendState(player, state)
	return true, previousLevel
end

function RunProgressionController.RefreshPlayer(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	sendState(player, state)
	return true
end

function RunProgressionController.GetRunSummary(player: Player)
	local state = states[player]
	return {
		level = state and state.level or 1,
		totalXP = state and state.totalXP or 0,
	}
end

function RunProgressionController.EndRun(player: Player)
	endedPlayers[player] = true
	states[player] = nil
	takeAllReservations[player] = nil
	if progressionNetwork and player.Parent == Players then
		-- Clear all run-only progression and queued choices without touching persistent ability data.
		progressionNetwork:fire(player, "RunStateChanged", {
			active = false,
			level = 1,
			xp = 0,
			xpRequired = RunProgressionConfig.GetXPRequirement(1),
			pendingChoices = 0,
			choiceSetId = 0,
			choices = nil,
			abilities = {},
		})
	end
end

function RunProgressionController.RestartRun(player: Player): boolean
	if player.Parent ~= Players or not ServerContext.IsGameServer() then
		return false
	end

	-- Replays start at level one with no queued choices while persistent ability ownership remains untouched.
	endedPlayers[player] = nil
	states[player] = nil
	takeAllReservations[player] = nil
	initializePlayer(player)
	return states[player] ~= nil
end

function RunProgressionController.GetSnapshot(_, player: Player)
	if not states[player] then
		initializePlayer(player)
	end
	local state = states[player]
	if state and state.pendingChoices > 0 then
		offerNextChoice(player, state)
	end
	return state and makePacket(player, state) or {
		active = false,
		level = 1,
		xp = 0,
		xpRequired = RunProgressionConfig.GetXPRequirement(1),
		pendingChoices = 0,
		choiceSetId = 0,
		choices = nil,
		abilities = {},
	}
end

function RunProgressionController.SelectChoice(_, player: Player, choiceSetId: any, choiceIndex: any)
	local state = states[player]
	local reservation = takeAllReservations[player]
	if reservation and reservation.expiresAt < workspace:GetServerTimeNow() then
		takeAllReservations[player] = nil
		reservation = nil
	end
	if not state
		or type(choiceSetId) ~= "number"
		or choiceSetId % 1 ~= 0
		or choiceSetId ~= state.choiceSetId
		or type(choiceIndex) ~= "number"
		or choiceIndex % 1 ~= 0
		or not state.choices
		or reservation ~= nil
	then
		return
	end

	local choice = state.choices[choiceIndex]
	if not choice then
		return
	end
	AnalyticsController.TrackRunChoiceSelected(player, choiceSetId, choice.abilityId, choice.kind)
	local applied = if choice.kind == "New"
		then AbilityController.AddRunAbility(player, choice.abilityId)
		else AbilityController.UpgradeRunAbility(player, choice.abilityId)
	if not applied then
		-- Keep the cards open if authoritative ability state changed unexpectedly.
		sendState(player, state)
		return
	end
	AnalyticsController.TrackRunChoiceApplied(player, choiceSetId, choice.abilityId, choice.kind)
	AnalyticsController.TrackGameplayStep(player, 5, { "Item - " .. choice.abilityId, "Choice - " .. choice.kind })
	AnalyticsController.TrackOnboardingStep(player, 6)

	state.pendingChoices = math.max(state.pendingChoices - 1, 0)
	state.choices = nil
	offerNextChoice(player, state)
	sendState(player, state)
end

function RunProgressionController.ReserveTakeAll(player: Player, lifetime: number): number?
	local state = states[player]
	if not state or not state.choices or #state.choices < 2 or state.pendingChoices <= 0 then
		return nil
	end
	takeAllReservations[player] = {
		choiceSetId = state.choiceSetId,
		expiresAt = workspace:GetServerTimeNow() + math.clamp(lifetime, 1, 120),
	}
	return state.choiceSetId
end

function RunProgressionController.CancelTakeAllReservation(player: Player)
	takeAllReservations[player] = nil
end

function RunProgressionController.GrantReservedTakeAll(player: Player, choiceSetId: number): boolean
	local state = states[player]
	local reservation = takeAllReservations[player]
	if not state
		or not reservation
		or reservation.expiresAt < workspace:GetServerTimeNow()
		or reservation.choiceSetId ~= choiceSetId
		or state.choiceSetId ~= choiceSetId
		or not state.choices
	then
		takeAllReservations[player] = nil
		return false
	end

	-- Consume the reservation before granting anything. A repeated receipt or client request therefore
	-- cannot apply the same completed choice set twice, even if another callback arrives synchronously.
	takeAllReservations[player] = nil
	local choices = state.choices
	state.choices = nil
	local grantedCount = 0
	for _, choice in choices do
		local applied = if choice.kind == "New"
			then AbilityController.AddRunAbility(player, choice.abilityId)
			else AbilityController.UpgradeRunAbility(player, choice.abilityId)
		if applied then
			grantedCount += 1
			AnalyticsController.TrackRunChoiceApplied(player, choiceSetId, choice.abilityId, choice.kind)
		end
	end
	if grantedCount <= 0 then
		state.choices = choices
		sendState(player, state)
		return false
	end

	state.pendingChoices = math.max(state.pendingChoices - 1, 0)
	offerNextChoice(player, state)
	sendState(player, state)
	return true
end

function RunProgressionController.Init()
	progressionNetwork = Networker.server.new("RunProgressionController", RunProgressionController, {
		RunProgressionController.GetSnapshot,
		RunProgressionController.SelectChoice,
	})
	if RunService:IsStudio() then
		ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				for _, player in Players:GetPlayers() do
					initializePlayer(player)
				end
			end
		end)
	end
end

function RunProgressionController.OnPlayerAdded(player: Player)
	endedPlayers[player] = nil
	initializePlayer(player)
end

function RunProgressionController.OnPlayerRemoving(player: Player)
	states[player] = nil
	endedPlayers[player] = nil
	takeAllReservations[player] = nil
end

return RunProgressionController
