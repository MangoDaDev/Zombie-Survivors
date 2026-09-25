local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local PartyTeleporterController = {}

local partyNetwork: Networker.Client?
local currentState
local stateChanged = Signal.new()

local function isValidState(state): boolean
	return type(state) == "table"
		and type(state.teleporterId) == "string"
		and type(state.memberCount) == "number"
		and state.memberCount % 1 == 0
		and type(state.maxSize) == "number"
		and state.maxSize % 1 == 0
		and type(state.leaderUserId) == "number"
		and type(state.leaderName) == "string"
		and type(state.friendsOnly) == "boolean"
		and (state.countdown == nil or type(state.countdown) == "number")
		and type(state.isLeader) == "boolean"
		and type(state.locked) == "boolean"
end

local function setState(state)
	if state ~= nil and not isValidState(state) then
		return
	end
	currentState = state
	stateChanged:Fire(state)
end

function PartyTeleporterController.PartyStateChanged(_, state)
	setState(state)
end

function PartyTeleporterController.PartyMessage(_, message, kind)
	if type(message) ~= "string" or message == "" or type(kind) ~= "string" then
		return
	end
	local color = if kind == "Success"
		then UIStyle.Colors.Green
		elseif kind == "Error" then UIStyle.Colors.Red
		else UIStyle.Colors.Blue
	NotificationManager.Notify(message, 3, color)
end

function PartyTeleporterController.Init()
	partyNetwork = Networker.client.new("PartyTeleporterController", PartyTeleporterController)
	setState((partyNetwork :: Networker.Client):fetch("GetState"))
end

function PartyTeleporterController.GetState()
	return currentState
end

function PartyTeleporterController.GetStateChangedSignal()
	return stateChanged
end

function PartyTeleporterController.SetMaxPartySize(maximumSize: number)
	if partyNetwork and type(maximumSize) == "number" then
		(partyNetwork :: Networker.Client):fire("SetMaxPartySize", maximumSize)
	end
end

function PartyTeleporterController.SetFriendsOnly(enabled: boolean)
	if partyNetwork and type(enabled) == "boolean" then
		(partyNetwork :: Networker.Client):fire("SetFriendsOnly", enabled)
	end
end

function PartyTeleporterController.LeaveParty()
	if partyNetwork then
		(partyNetwork :: Networker.Client):fire("LeaveParty")
	end
end

function PartyTeleporterController.CancelParty()
	if partyNetwork then
		(partyNetwork :: Networker.Client):fire("CancelParty")
	end
end

return PartyTeleporterController
