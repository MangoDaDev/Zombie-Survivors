local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local RunSessionController = {}

local sessionNetwork: Networker.Client?
local state = { active = false }
local stateChanged = Signal.new()
local returnFailed = Signal.new()
local replayFailed = Signal.new()
local spectateChanged = Signal.new()
local spectateUserId: number? = nil

local function isValidPacket(packet): boolean
	if type(packet) ~= "table" or type(packet.active) ~= "boolean" then
		return false
	end
	if not packet.active then
		return (packet.startedAt == nil or type(packet.startedAt) == "number")
			and (packet.dead == nil or type(packet.dead) == "boolean")
			and (packet.livingUserIds == nil or type(packet.livingUserIds) == "table")
	end
	local stats = packet.stats
	return type(packet.endedAt) == "number"
		and type(packet.returnAt) == "number"
		and type(stats) == "table"
		and type(stats.survivalTime) == "number"
		and type(stats.zombiesKilled) == "number"
		and type(stats.levelReached) == "number"
		and type(stats.coinsCollected) == "number"
		and type(stats.xpCollected) == "number"
		and type(packet.replayVoteCount) == "number"
		and type(packet.replayRequiredVotes) == "number"
		and type(packet.hasReplayVoted) == "boolean"
end

local function setState(packet)
	if isValidPacket(packet) then
		state = packet
		if state.dead then
			local stillAvailable = false
			for _, userId in state.livingUserIds or {} do
				if userId == spectateUserId then stillAvailable = true; break end
			end
			if not stillAvailable then spectateUserId = (state.livingUserIds or {})[1] end
		else
			spectateUserId = nil
		end
		stateChanged:Fire(state)
		spectateChanged:Fire(RunSessionController.GetSpectatePlayer())
	end
end

function RunSessionController.RunStarted(_, startedAt)
	if type(startedAt) == "number" then
		setState({ active = false, startedAt = startedAt })
	end
end

function RunSessionController.GameOver(_, packet)
	setState(packet)
end

function RunSessionController.StateChanged(_, packet)
	setState(packet)
end

function RunSessionController.LobbyReturnFailed(_, message)
	if type(message) == "string" and message ~= "" then
		returnFailed:Fire(message)
	end
end

function RunSessionController.ReplayFailed(_, message)
	if type(message) == "string" and message ~= "" then
		replayFailed:Fire(message)
	end
end

function RunSessionController.Init()
	sessionNetwork = Networker.client.new("RunSessionController", RunSessionController)
	setState((sessionNetwork :: Networker.Client):fetch("GetSnapshot"))
end

function RunSessionController.GetState()
	return state
end

function RunSessionController.GetStateChangedSignal()
	return stateChanged
end

function RunSessionController.GetReturnFailedSignal()
	return returnFailed
end

function RunSessionController.GetReplayFailedSignal()
	return replayFailed
end

function RunSessionController.IsDown(): boolean
	return state.dead == true and not state.active
end

function RunSessionController.GetSpectatePlayer(): Player?
	return if spectateUserId then Players:GetPlayerByUserId(spectateUserId) else nil
end

function RunSessionController.GetSpectateChangedSignal()
	return spectateChanged
end

function RunSessionController.CycleSpectate(direction: number?): Player?
	local living = state.livingUserIds or {}
	if not state.dead or #living == 0 then return nil end
	local currentIndex = table.find(living, spectateUserId) or 1
	local step = if direction and direction < 0 then -1 else 1
	currentIndex = ((currentIndex - 1 + step) % #living) + 1
	spectateUserId = living[currentIndex]
	local player = RunSessionController.GetSpectatePlayer()
	spectateChanged:Fire(player)
	return player
end

function RunSessionController.RequestReplay()
	if sessionNetwork and state.active and not state.hasReplayVoted then
		(sessionNetwork :: Networker.Client):fire("RequestReplay")
	end
end

return RunSessionController
