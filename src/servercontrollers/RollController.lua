local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
	.GetRandomFromWeightedTable
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)
local RollServerConfig = require(script.Parent.Roll.RollServerConfig)

local MAX_PERSISTED_COUNT = 9_007_199_254_740_991

type PlayerRollState = {
	active: boolean,
	autoRollEnabled: boolean,
	autoScheduleId: number,
	lastAutoToggleAt: number,
	lastPresentationToggleAt: number,
	lastRollRequestAt: number,
	luck: number,
	nextRollAt: number,
	pendingDiscoveries: { [string]: number },
	presentationHidden: boolean,
	rollId: number,
	settingsRequested: boolean,
	token: number,
}

local RollController = {}

local dataService
local rollNetwork
local random = Random.new()
local states: { [Player]: PlayerRollState } = {}
local settingsRequestedPlayers: { [Player]: boolean } = {}
local startSequence: (Player, PlayerRollState) -> boolean

local function getBooleanPreference(player: Player, dataKey: string): boolean
	local value = dataService:get(player, dataKey)
	if type(value) == "boolean" then
		return value
	end

	dataService:set(player, dataKey, false)
	return false
end

local function isCurrentState(player: Player, state: PlayerRollState, token: number): boolean
	return player.Parent == Players and states[player] == state and state.token == token
end

local function selectItem(state: PlayerRollState, luckMultiplier: number)
	-- Owned abilities deliberately remain in the authoritative pool at their normal weight; ownership
	-- only decides whether the result discovers something new, never whether it can be rolled.
	return GetRandomFromWeightedTable(RollDefinitions.Items, "Weight", random, state.luck * luckMultiplier)
end

local function incrementTotalRolls(player: Player)
	dataService:update(player, RollDefinitions.TotalRollsDataKey, function(currentTotal)
		local validTotal = if type(currentTotal) == "number" and currentTotal >= 0 and currentTotal % 1 == 0
			then currentTotal
			else 0
		return math.min(validTotal + 1, MAX_PERSISTED_COUNT)
	end)
end

local function awardItem(player: Player, state: PlayerRollState, item, amount: number): (boolean, string?)
	if item.AbilityId then
		if AbilityController.IsOwned(player, item.AbilityId) then
			-- Owned abilities remain valid duplicate results at every progression point without
			-- duplicating persistent ownership or replaying discovery rewards.
			incrementTotalRolls(player)
			return true, nil
		end
		local discovered = AbilityController.TryDiscover(player, item.AbilityId, state.autoRollEnabled)
		if discovered then
			incrementTotalRolls(player)
		end
		return discovered, if discovered then item.AbilityId else nil
	end

	local inventory = dataService:get(player, RollDefinitions.InventoryDataKey)
	local currentAmount = type(inventory) == "table" and inventory[item.Id] or 0
	if type(currentAmount) ~= "number" or currentAmount < 0 or currentAmount % 1 ~= 0 then
		currentAmount = 0
	end
	if amount > MAX_PERSISTED_COUNT - currentAmount then
		return false
	end

	dataService:update(player, RollDefinitions.InventoryDataKey, function(currentInventory)
		local updatedInventory = if type(currentInventory) == "table" then table.clone(currentInventory) else {}
		updatedInventory[item.Id] = currentAmount + amount
		return updatedInventory
	end)
	incrementTotalRolls(player)
	return true, nil
end

local function scheduleAutoRoll(player: Player, state: PlayerRollState)
	state.autoScheduleId += 1
	local scheduleId = state.autoScheduleId
	if not state.autoRollEnabled or state.active or next(state.pendingDiscoveries) ~= nil then
		return
	end

	local delayDuration = math.max(
		RollDefinitions.Timing.AutoRollDelay,
		state.nextRollAt - workspace:GetServerTimeNow()
	)
	task.delay(delayDuration, function()
		if states[player] == state
			and state.autoScheduleId == scheduleId
			and state.autoRollEnabled
			and not state.active
			and player.Parent == Players
		then
			startSequence(player, state)
		end
	end)
end

local function pauseAutoRollForDiscovery(player: Player, state: PlayerRollState, abilityId: string)
	if not state.autoRollEnabled then
		return
	end

	state.autoScheduleId += 1
	local pauseId = state.autoScheduleId
	state.pendingDiscoveries[abilityId] = pauseId
	-- Auto Roll remains logically enabled; only its scheduler pauses until acknowledgement or this safety timeout.
	task.delay(RollDefinitions.Timing.ReelDuration + RollDefinitions.Timing.DiscoveryAutoResumeDelay, function()
		if states[player] ~= state or state.pendingDiscoveries[abilityId] ~= pauseId then
			return
		end
		state.pendingDiscoveries[abilityId] = nil
		scheduleAutoRoll(player, state)
	end)
end

local function acknowledgeDiscovery(player: Player, abilityId: string)
	local state = states[player]
	if not state or not state.pendingDiscoveries[abilityId] then
		return
	end
	state.pendingDiscoveries[abilityId] = nil
	scheduleAutoRoll(player, state)
end

startSequence = function(player: Player, state: PlayerRollState): boolean
	local now = workspace:GetServerTimeNow()
	if states[player] ~= state or player.Parent ~= Players or state.active or now < state.nextRollAt then
		return false
	end

	state.active = true
	state.autoScheduleId += 1
	state.nextRollAt = now + RollServerConfig.RollCooldown
	state.rollId += 1
	state.token += 1
	local rollId = state.rollId
	local token = state.token

	task.spawn(function()
		local luckMultiplier = 1
		local reelIndex = 1
		local sequenceId = 1

		while isCurrentState(player, state, token) do
			local nextCloverLuck = if luckMultiplier == 1
				then RollServerConfig.StartingCloverLuck
				else luckMultiplier * RollServerConfig.CloverLuckGrowth
			local cloverChance = if luckMultiplier == 1
				then RollServerConfig.FirstCloverChance
				else RollServerConfig.ChainedCloverChance
			local rolledClover = nextCloverLuck <= RollServerConfig.MaximumCloverLuck
				and random:NextNumber() < cloverChance

			if rolledClover then
				luckMultiplier = nextCloverLuck
				rollNetwork:fire(player, "RollStarted", {
					rollId = rollId,
					sequenceId = sequenceId,
					reelIndex = reelIndex,
					kind = "Clover",
					luckMultiplier = luckMultiplier,
				})

				task.wait(RollDefinitions.Timing.ReelDuration + RollDefinitions.Timing.ResultHoldDuration)
				if not isCurrentState(player, state, token) then
					return
				end
				reelIndex += 1
				sequenceId += 1
				continue
			end

			local item = selectItem(state, luckMultiplier)
			local awarded = false
			local discoveredAbilityId
			if item then
				awarded, discoveredAbilityId = awardItem(player, state, item, 1)
			end
			if not item or not awarded then
				break
			end
			if discoveredAbilityId then
				pauseAutoRollForDiscovery(player, state, discoveredAbilityId)
			end

			-- Reward first, then notify the owning client; animation events can never duplicate the grant.
			rollNetwork:fire(player, "RollStarted", {
				rollId = rollId,
				sequenceId = sequenceId,
				reelIndex = reelIndex,
				kind = "Item",
				itemId = item.Id,
				isNewAbility = discoveredAbilityId ~= nil,
				luckMultiplier = luckMultiplier,
			})

			task.wait(RollDefinitions.Timing.ReelDuration + RollDefinitions.Timing.ResultHoldDuration)
			if not isCurrentState(player, state, token) then
				return
			end

			break
		end

		if not isCurrentState(player, state, token) then
			return
		end

		state.active = false
		rollNetwork:fire(player, "RollFinished", rollId, state.autoRollEnabled)
		scheduleAutoRoll(player, state)
	end)

	return true
end

function RollController.RequestRoll(_, player: Player)
	local state = states[player]
	if not state then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - state.lastRollRequestAt < RollServerConfig.RollRequestCooldown then
		return
	end
	state.lastRollRequestAt = now
	-- The request carries no result, luck, reward, clover, or multiplier data by design.
	startSequence(player, state)
end

function RollController.GetSettings(_, player: Player)
	local state = states[player]
	if not state then
		-- DataService can release the client just before lifecycle dispatch reaches this controller.
		-- Remember that the listener is ready so OnPlayerAdded can publish and resume the real saved state.
		settingsRequestedPlayers[player] = true
		return {
			autoRollEnabled = false,
			presentationHidden = false,
		}
	end

	if not state.settingsRequested then
		state.settingsRequested = true
		-- Resume saved Auto Roll only after the client controller is listening for the resulting roll events.
		if state.autoRollEnabled then
			scheduleAutoRoll(player, state)
		end
	end

	return {
		autoRollEnabled = state.autoRollEnabled,
		presentationHidden = state.presentationHidden,
	}
end

function RollController.SetAutoRoll(_, player: Player, enabled: any)
	local state = states[player]
	if not state or type(enabled) ~= "boolean" then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - state.lastAutoToggleAt < RollServerConfig.AutoToggleCooldown then
		return
	end
	state.lastAutoToggleAt = now
	if state.autoRollEnabled == enabled then
		return
	end
	state.autoRollEnabled = enabled
	state.autoScheduleId += 1
	-- Accepted roll preferences are persisted immediately so leaving between rolls cannot revert them.
	dataService:set(player, RollDefinitions.AutoRollEnabledDataKey, enabled)
	rollNetwork:fire(player, "AutoRollChanged", enabled)

	if enabled and state.settingsRequested then
		scheduleAutoRoll(player, state)
	end
end

function RollController.SetPresentationHidden(_, player: Player, hidden: any)
	local state = states[player]
	if not state or type(hidden) ~= "boolean" then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - state.lastPresentationToggleAt < RollServerConfig.PresentationToggleCooldown then
		return
	end
	state.lastPresentationToggleAt = now
	if state.presentationHidden == hidden then
		return
	end

	state.presentationHidden = hidden
	-- The server owns the saved display preference even though hiding the reel is presentation-only.
	dataService:set(player, RollDefinitions.PresentationHiddenDataKey, hidden)
	rollNetwork:fire(player, "PresentationHiddenChanged", hidden)
end

function RollController.GetLuck(player: Player): number?
	local state = states[player]
	return state and state.luck or nil
end

function RollController.SetLuck(player: Player, luck: number): boolean
	local state = states[player]
	if not state or type(luck) ~= "number" or luck ~= luck then
		return false
	end

	-- This API is server-only; clients have no Networker access to submit luck values.
	state.luck = math.clamp(luck, RollServerConfig.MinimumLuck, RollServerConfig.MaximumLuck)
	return true
end

function RollController.SetDataService(service)
	dataService = service
end

function RollController.Init()
	AbilityController.SetDiscoveryAcknowledgedCallback(acknowledgeDiscovery)
	rollNetwork = Networker.server.new("RollController", RollController, {
		RollController.GetSettings,
		RollController.RequestRoll,
		RollController.SetAutoRoll,
		RollController.SetPresentationHidden,
	})
end

function RollController.OnPlayerAdded(player: Player)
	local autoRollEnabled = getBooleanPreference(player, RollDefinitions.AutoRollEnabledDataKey)
	local presentationHidden = getBooleanPreference(player, RollDefinitions.PresentationHiddenDataKey)
	local settingsRequested = settingsRequestedPlayers[player] == true
	settingsRequestedPlayers[player] = nil

	local state: PlayerRollState = {
		active = false,
		autoRollEnabled = autoRollEnabled,
		autoScheduleId = 0,
		lastAutoToggleAt = -math.huge,
		lastPresentationToggleAt = -math.huge,
		lastRollRequestAt = -math.huge,
		luck = RollServerConfig.DefaultLuck,
		nextRollAt = 0,
		pendingDiscoveries = {},
		presentationHidden = presentationHidden,
		rollId = 0,
		settingsRequested = settingsRequested,
		token = 0,
	}
	states[player] = state
	if settingsRequested then
		rollNetwork:fire(player, "AutoRollChanged", autoRollEnabled)
		rollNetwork:fire(player, "PresentationHiddenChanged", presentationHidden)
		if autoRollEnabled then
			scheduleAutoRoll(player, state)
		end
	end

	local inventory = dataService:get(player, RollDefinitions.InventoryDataKey)
	if type(inventory) ~= "table" then
		dataService:set(player, RollDefinitions.InventoryDataKey, {})
	end
	local totalRolls = dataService:get(player, RollDefinitions.TotalRollsDataKey)
	if type(totalRolls) ~= "number" or totalRolls < 0 or totalRolls % 1 ~= 0 then
		dataService:set(player, RollDefinitions.TotalRollsDataKey, 0)
	end
end

function RollController.OnPlayerRemoving(player: Player)
	local state = states[player]
	if state then
		state.token += 1
		state.autoScheduleId += 1
	end
	states[player] = nil
	settingsRequestedPlayers[player] = nil
end

return RollController
