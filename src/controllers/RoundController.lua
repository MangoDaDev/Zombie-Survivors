local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

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
	bossAnnouncement = {
		active = false,
		stage = "",
		bossName = "",
		message = "",
		color = Color3.fromRGB(195, 48, 61),
		endsAt = 0,
		sequence = 0,
	},
}
local stateChanged = Signal.new()
local lastBossAnnouncementSequence = 0

local function isNonNegativeInteger(value): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0
end

local function isValidState(packet): boolean
	local announcement = type(packet) == "table" and packet.bossAnnouncement or nil
	return type(packet) == "table"
		and type(packet.active) == "boolean"
		and isNonNegativeInteger(packet.round)
		and isNonNegativeInteger(packet.remaining)
		and isNonNegativeInteger(packet.voteCount)
		and isNonNegativeInteger(packet.requiredVotes)
		and type(packet.hasVoted) == "boolean"
		and type(packet.canVote) == "boolean"
		and type(packet.cooldownEndsAt) == "number"
		and type(announcement) == "table"
		and type(announcement.active) == "boolean"
		and type(announcement.stage) == "string"
		and type(announcement.bossName) == "string"
		and type(announcement.message) == "string"
		and typeof(announcement.color) == "Color3"
		and type(announcement.endsAt) == "number"
		and isNonNegativeInteger(announcement.sequence)
end

local function setState(packet)
	if not isValidState(packet) then
		return
	end
	local announcement = packet.bossAnnouncement
	if announcement.active and announcement.sequence > lastBossAnnouncementSequence then
		local soundName = if announcement.stage == "Entrance"
			then "FlameBurst"
			elseif announcement.stage == "Buildup" then "CountdownBeep"
			else "Alert"
		-- Stage changes are replicated once and drive one local cue; state rebroadcasts never stack audio.
		Sounds.Play(soundName, Players.LocalPlayer.PlayerGui)
	end
	lastBossAnnouncementSequence = math.max(lastBossAnnouncementSequence, announcement.sequence)
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
