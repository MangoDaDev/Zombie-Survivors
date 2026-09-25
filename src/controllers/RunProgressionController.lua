local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)

local RunProgressionController = {}

local progressionNetwork
local stateChanged = Signal.new()
local state = {
	active = false,
	level = 1,
	xp = 0,
	xpRequired = RunProgressionConfig.GetXPRequirement(1),
	pendingChoices = 0,
	choiceSetId = 0,
	choices = nil,
	abilities = {},
}

local function isValidPacket(packet): boolean
	return type(packet) == "table"
		and type(packet.active) == "boolean"
		and type(packet.level) == "number"
		and type(packet.xp) == "number"
		and type(packet.xpRequired) == "number"
		and type(packet.pendingChoices) == "number"
		and type(packet.choiceSetId) == "number"
		and type(packet.abilities) == "table"
		and (packet.choices == nil or type(packet.choices) == "table")
end

function RunProgressionController.RunStateChanged(_, packet)
	if isValidPacket(packet) then
		state = packet
		stateChanged:Fire(state)
	end
end

function RunProgressionController.Init()
	progressionNetwork = Networker.client.new("RunProgressionController", RunProgressionController)
	local snapshot = progressionNetwork:fetch("GetSnapshot")
	if isValidPacket(snapshot) then
		state = snapshot
	end
end

function RunProgressionController.GetState()
	return state
end

function RunProgressionController.SelectChoice(choiceSetId: number, choiceIndex: number)
	if progressionNetwork
		and type(choiceSetId) == "number"
		and choiceSetId % 1 == 0
		and type(choiceIndex) == "number"
		and choiceIndex % 1 == 0
	then
		progressionNetwork:fire("SelectChoice", choiceSetId, choiceIndex)
	end
end

function RunProgressionController.GetStateChangedSignal()
	return stateChanged
end

return RunProgressionController
