local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
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

local function getRollWeight(definition): number
	local reciprocalOdds = definition.Roll and definition.Roll.BaseOdds
	return if type(reciprocalOdds) == "number" and reciprocalOdds > 0 then 1 / reciprocalOdds else 1
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
					weight = getRollWeight(definition),
				})
			end
		elseif permanentData.Owned[definition.Id] == true
			or table.find(RunProgressionConfig.Abilities.AlwaysAvailable, definition.Id)
		then
			local equipped = runData.Equipped[definition.Category]
			if #equipped < AbilityDefinitions.EquipLimits[definition.Category] then
				table.insert(candidates, {
					abilityId = definition.Id,
					kind = "New",
					currentLevel = 0,
					nextLevel = 1,
					weight = getRollWeight(definition),
				})
			end
		end
	end
	return candidates
end

local function takeWeighted(candidates)
	local totalWeight = 0
	for _, candidate in candidates do
		totalWeight += candidate.weight
	end
	local roll = random:NextNumber() * totalWeight
	local selectedIndex = #candidates
	for index, candidate in candidates do
		roll -= candidate.weight
		if roll <= 0 then
			selectedIndex = index
			break
		end
	end
	return table.remove(candidates, selectedIndex)
end

local function chooseWithoutReplacement(candidates, count: number, slotFillRatio: number): { Choice }
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
		-- Lead with up to two distinct usable upgrades. With three or more owned abilities, the final
		-- card only expands the build occasionally, and never more than once in the same choice set.
		local selected
		if #upgrades > 0 and (#choices < guaranteedUpgradeCount or #newAbilities == 0) then
			selected = takeWeighted(upgrades)
		elseif not offeredNew and #newAbilities > 0 and (#upgrades == 0 or random:NextNumber() < newOfferChance) then
			selected = takeWeighted(newAbilities)
			offeredNew = true
		elseif #upgrades > 0 then
			selected = takeWeighted(upgrades)
		else
			selected = takeWeighted(newAbilities)
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
	local totalSlots = AbilityDefinitions.EquipLimits.Weapon + AbilityDefinitions.EquipLimits.Passive
	local choices = chooseWithoutReplacement(
		buildCandidates(player),
		RunProgressionConfig.Abilities.ChoiceCount,
		equippedCount / totalSlots
	)
	if #choices == 0 then
		-- This only occurs after every legal run ability reaches its configured maximum.
		state.pendingChoices = 0
		return
	end
	state.choiceSetId += 1
	state.choices = choices
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
	local xpMultiplier = 1 + (manualStats and manualStats.XPBonusPercent or 0) / 100
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
	end
	if state.pendingChoices > 0 then
		-- Retry unresolved tokens on every XP update. This closes the brief startup window where progression
		-- can initialize before the run ability pool and guarantees every earned level eventually gets a roll.
		offerNextChoice(player, state)
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
	if not state
		or type(choiceSetId) ~= "number"
		or choiceSetId % 1 ~= 0
		or choiceSetId ~= state.choiceSetId
		or type(choiceIndex) ~= "number"
		or choiceIndex % 1 ~= 0
		or not state.choices
	then
		return
	end

	local choice = state.choices[choiceIndex]
	if not choice then
		return
	end
	local applied = if choice.kind == "New"
		then AbilityController.AddRunAbility(player, choice.abilityId)
		else AbilityController.UpgradeRunAbility(player, choice.abilityId)
	if not applied then
		-- Keep the cards open if authoritative ability state changed unexpectedly.
		sendState(player, state)
		return
	end

	state.pendingChoices = math.max(state.pendingChoices - 1, 0)
	state.choices = nil
	offerNextChoice(player, state)
	sendState(player, state)
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
end

return RunProgressionController
