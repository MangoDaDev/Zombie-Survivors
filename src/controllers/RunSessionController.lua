local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local RunSessionController = {}

local state = { active = false }
local stateChanged = Signal.new()
local returnFailed = Signal.new()

local function isValidPacket(packet): boolean
	if type(packet) ~= "table" or type(packet.active) ~= "boolean" then
		return false
	end
	if not packet.active then
		return true
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
end

local function setState(packet)
	if isValidPacket(packet) then
		state = packet
		stateChanged:Fire(state)
	end
end

function RunSessionController.GameOver(_, packet)
	setState(packet)
end

function RunSessionController.LobbyReturnFailed(_, message)
	if type(message) == "string" and message ~= "" then
		returnFailed:Fire(message)
	end
end

function RunSessionController.Init()
	local network = Networker.client.new("RunSessionController", RunSessionController)
	setState(network:fetch("GetSnapshot"))
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

return RunSessionController
