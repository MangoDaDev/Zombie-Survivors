local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ClientActionState = require(ReplicatedStorage.Modules.Core.ClientActionState)

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
local presentation = ClientActionState.new(state, function(packet)
	state = packet
	stateChanged:Fire(packet)
end)

local function isFiniteNumber(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isValidState(packet): boolean
	return type(packet) == "table"
		and isFiniteNumber(packet.revision) and packet.revision % 1 == 0 and packet.revision >= 0
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
	presentation:Apply(packet, not packet.active or packet.isReady)
end

function GameReadyController.ReadyResolved(_, requestId, packet)
	if isValidState(packet) then
		presentation:Resolve(requestId, packet)
	end
end

function GameReadyController.ReadyStateChanged(_, packet)
	setState(packet)
end

function GameReadyController.Init()
	readyNetwork = Networker.client.new("GameReadyController", GameReadyController)
	task.spawn(function()
		setState((readyNetwork :: Networker.Client):fetch("GetState"))
	end)
end

function GameReadyController.GetState()
	return state
end

function GameReadyController.GetStateChangedSignal()
	return stateChanged
end

function GameReadyController.ReadyUp()
	if readyNetwork and state.active and not state.isReady then
		local requestId = presentation:Begin(function(authoritative)
			local predicted = table.clone(authoritative)
			if predicted.active and not predicted.isReady then
				predicted.isReady = true
				predicted.readyCount = math.min(predicted.readyCount + 1, predicted.requiredCount)
			end
			-- Combat never starts from this prediction, even when the local ready count reaches its target.
			return predicted
		end)
		if requestId then
			(readyNetwork :: Networker.Client):fire("RequestReady", requestId)
		end
	end
end

return GameReadyController
