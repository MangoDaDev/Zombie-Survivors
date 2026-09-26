local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local GameReadyController = {}

local readyNetwork: Networker.Client?
local state = {
	active = false,
	started = false,
	startedAt = nil,
	deadline = nil,
	readyCount = 0,
	requiredCount = 0,
	isReady = false,
}
local stateChanged = Signal.new()

local function isFiniteNumber(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isValidState(packet): boolean
	return type(packet) == "table"
		and type(packet.active) == "boolean"
		and type(packet.started) == "boolean"
		and (packet.startedAt == nil or isFiniteNumber(packet.startedAt))
		and (packet.deadline == nil or isFiniteNumber(packet.deadline))
		and type(packet.readyCount) == "number"
		and packet.readyCount % 1 == 0
		and packet.readyCount >= 0
		and type(packet.requiredCount) == "number"
		and packet.requiredCount % 1 == 0
		and packet.requiredCount >= packet.readyCount
		and type(packet.isReady) == "boolean"
end

local function setState(packet)
	if not isValidState(packet) then
		return
	end
	state = packet
	stateChanged:Fire(state)
end

function GameReadyController.ReadyStateChanged(_, packet)
	setState(packet)
end

function GameReadyController.Init()
	readyNetwork = Networker.client.new("GameReadyController", GameReadyController)
	setState((readyNetwork :: Networker.Client):fetch("GetState"))
end

function GameReadyController.GetState()
	return state
end

function GameReadyController.GetStateChangedSignal()
	return stateChanged
end

function GameReadyController.ReadyUp()
	if readyNetwork and state.active and not state.isReady then
		(readyNetwork :: Networker.Client):fire("ReadyUp")
	end
end

return GameReadyController
