local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ClientActionState = require(ReplicatedStorage.Modules.Core.ClientActionState)
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
local presentation = ClientActionState.new(state, function(packet)
	state = packet
	stateChanged:Fire(packet)
end)

local function isValidPacket(packet): boolean
	return type(packet) == "table"
		and type(packet.revision) == "number" and packet.revision % 1 == 0 and packet.revision >= 0
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
		presentation:Apply(packet, not packet.active or packet.choiceSetId ~= state.choiceSetId)
	end
end

function RunProgressionController.ChoiceResolved(_, requestId, packet)
	if isValidPacket(packet) then
		presentation:Resolve(requestId, packet)
	end
end

function RunProgressionController.Init()
	progressionNetwork = Networker.client.new("RunProgressionController", RunProgressionController)
	task.spawn(function()
		RunProgressionController.RunStateChanged(nil, progressionNetwork:fetch("GetSnapshot"))
	end)
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
		and state.active and state.choiceSetId == choiceSetId
		and type(state.choices) == "table" and state.choices[choiceIndex] ~= nil
	then
		local requestId = presentation:Begin(function(authoritative)
			local predicted = table.clone(authoritative)
			if predicted.choiceSetId == choiceSetId then
				-- Consume only the visible offer. Levels, XP, abilities and rewards await server confirmation.
				predicted.choices = nil
			end
			return predicted
		end)
		if requestId then
			progressionNetwork:fire("RequestChoice", requestId, choiceSetId, choiceIndex)
		end
	end
end

function RunProgressionController.GetStateChangedSignal()
	return stateChanged
end

return RunProgressionController
