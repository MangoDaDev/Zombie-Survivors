local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ClassesAbilitiesTutorialConfig = require(ReplicatedStorage.Modules.Game.ClassesAbilitiesTutorialConfig)

local ClassesAbilitiesTutorialController = {}

local tutorialNetwork
local state = {
	active = false,
	targetClassId = ClassesAbilitiesTutorialConfig.TargetClassId,
}
local stateChanged = Signal.new()

local function setState(newState)
	state = {
		active = type(newState) == "table" and newState.active == true,
		targetClassId = if type(newState) == "table" and newState.targetClassId == ClassesAbilitiesTutorialConfig.TargetClassId
			then newState.targetClassId
			else ClassesAbilitiesTutorialConfig.TargetClassId,
	}
	stateChanged:Fire(state)
end

function ClassesAbilitiesTutorialController.StateChanged(_, newState)
	setState(newState)
end

function ClassesAbilitiesTutorialController.Init()
	tutorialNetwork = Networker.client.new("ClassesAbilitiesTutorialController", ClassesAbilitiesTutorialController)
	setState(tutorialNetwork:fetch("GetState"))
end

function ClassesAbilitiesTutorialController.GetState()
	return state
end

function ClassesAbilitiesTutorialController.IsActive(): boolean
	return state.active
end

function ClassesAbilitiesTutorialController.GetStateChangedSignal()
	return stateChanged
end

return ClassesAbilitiesTutorialController
