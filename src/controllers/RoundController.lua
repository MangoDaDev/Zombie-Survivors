local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local RoundController = {}

local roundNetwork: Networker.Client?
local state = {
	active = false,
	round = 0,
	remaining = 0,
	voteCount = 0,
	requiredVotes = 0,
	hasVoted = false,
	canVote = false,
	cooldownEndsAt = 0,
}
local stateChanged = Signal.new()

local function isNonNegativeInteger(value): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0
end

local function isValidState(packet): boolean
	return type(packet) == "table"
		and type(packet.active) == "boolean"
		and isNonNegativeInteger(packet.round)
		and isNonNegativeInteger(packet.remaining)
		and isNonNegativeInteger(packet.voteCount)
		and isNonNegativeInteger(packet.requiredVotes)
		and type(packet.hasVoted) == "boolean"
		and type(packet.canVote) == "boolean"
		and type(packet.cooldownEndsAt) == "number"
end

local function setState(packet)
	if not isValidState(packet) then
		return
	end
	state = packet
	stateChanged:Fire(state)
end

function RoundController.RoundStateChanged(_, packet)
	setState(packet)
end

function RoundController.Init()
	roundNetwork = Networker.client.new("RoundController", RoundController)
	setState((roundNetwork :: Networker.Client):fetch("GetState"))
end

function RoundController.GetState()
	return state
end

function RoundController.GetStateChangedSignal()
	return stateChanged
end

function RoundController.VoteToSkip()
	if roundNetwork and state.active and state.canVote then
		(roundNetwork :: Networker.Client):fire("VoteToSkip")
	end
end

return RoundController
