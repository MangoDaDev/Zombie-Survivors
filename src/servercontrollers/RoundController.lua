local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local RoundController = {}

local roundNetwork
local currentRound = 0
local votes: { [number]: boolean } = {}
local lastSkipVoteAt: { [number]: number } = {}
local advancing = false
local spawningRound = false
local completionCheckPending = false
local runGeneration = 0

local function getPartyMemberLookup(): { [number]: boolean }?
	local runData = ServerContext.GetRunData()
	local memberIds = type(runData) == "table" and runData.partyMemberIds or nil
	if type(memberIds) ~= "table" then
		return nil
	end

	local lookup = {}
	for _, userId in memberIds do
		if type(userId) == "number" and userId % 1 == 0 and userId > 0 then
			lookup[userId] = true
		end
	end
	return if next(lookup) ~= nil then lookup else nil
end

local function isPartyMember(player: Player): boolean
	local lookup = getPartyMemberLookup()
	return player.Parent == Players and (not lookup or lookup[player.UserId] == true)
end

local function getPartyCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if isPartyMember(player) then
			count += 1
		end
	end
	return count
end

local function getVoteCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if isPartyMember(player) and votes[player.UserId] then
			count += 1
		end
	end
	return count
end

local function getRequiredVotes(): number
	local partyCount = getPartyCount()
	-- A strict majority is always more than half of the currently connected party.
	return if partyCount > 0 then math.floor(partyCount / 2) + 1 else 0
end

local function makePacket(player: Player)
	local cooldownEndsAt = (lastSkipVoteAt[player.UserId] or 0) + RunProgressionConfig.Rounds.SkipVoteCooldown
	return {
		active = currentRound > 0,
		round = currentRound,
		remaining = if currentRound > 0 then ZombieController.GetLivingZombieCountForRound(currentRound) else 0,
		voteCount = getVoteCount(),
		requiredVotes = getRequiredVotes(),
		hasVoted = votes[player.UserId] == true,
		canVote = currentRound > 0
			and votes[player.UserId] ~= true
			and workspace:GetServerTimeNow() >= cooldownEndsAt,
		cooldownEndsAt = cooldownEndsAt,
	}
end

local function sendState(player: Player)
	if roundNetwork and player.Parent == Players then
		roundNetwork:fire(player, "RoundStateChanged", makePacket(player))
	end
end

local function broadcastState()
	for _, player in Players:GetPlayers() do
		if isPartyMember(player) then
			sendState(player)
		end
	end
end

local advanceRound

local function scheduleCompletionCheck(roundNumber: number)
	if completionCheckPending then
		return
	end
	completionCheckPending = true
	local scheduledGeneration = runGeneration
	task.defer(function()
		completionCheckPending = false
		if runGeneration == scheduledGeneration
			and currentRound == roundNumber
			and not advancing
			and ZombieController.GetLivingZombieCountForRound(roundNumber) == 0
		then
			advanceRound()
		else
			broadcastState()
		end
	end)
end

advanceRound = function()
	if advancing or not ZombieController.IsSimulationStarted() then
		return
	end
	advancing = true
	currentRound += 1
	table.clear(votes)

	local assignedCount = RunProgressionConfig.GetRoundZombieCount(currentRound, getPartyCount())
	spawningRound = true
	local spawnedIds = ZombieController.SpawnRound(currentRound, assignedCount)
	spawningRound = false
	-- Progression is intentionally committed before spawning: a skipped round never removes old zombies,
	-- and every client immediately sees the shared new round even if placement produced fewer enemies.
	broadcastState()
	advancing = false

	if #spawnedIds == 0 then
		warn(string.format("Round %d could not place its assigned zombie group", currentRound))
	end
end

local function evaluateSkipMajority()
	local requiredVotes = getRequiredVotes()
	if currentRound > 0 and requiredVotes > 0 and getVoteCount() >= requiredVotes then
		advanceRound()
	else
		broadcastState()
	end
end

function RoundController.GetState(_, player: Player)
	return makePacket(player)
end

function RoundController.VoteToSkip(_, player: Player)
	local now = workspace:GetServerTimeNow()
	if currentRound <= 0
		or not isPartyMember(player)
		or votes[player.UserId]
		or now < (lastSkipVoteAt[player.UserId] or 0) + RunProgressionConfig.Rounds.SkipVoteCooldown
	then
		sendState(player)
		return
	end

	-- The client supplies no counts or round number; the server records only the authenticated sender's
	-- one vote for the active shared round and owns both the cooldown and strict-majority decision.
	lastSkipVoteAt[player.UserId] = now
	votes[player.UserId] = true
	task.delay(RunProgressionConfig.Rounds.SkipVoteCooldown, function()
		if player.Parent == Players and lastSkipVoteAt[player.UserId] == now then
			sendState(player)
		end
	end)
	evaluateSkipMajority()
end

function RoundController.RestartRun()
	-- A unanimous replay is a new shared run: old completion tasks, votes, and skip cooldowns cannot carry over.
	runGeneration += 1
	currentRound = 0
	table.clear(votes)
	table.clear(lastSkipVoteAt)
	advancing = false
	spawningRound = false
	completionCheckPending = false

	if ZombieController.IsSimulationStarted() then
		advanceRound()
	else
		broadcastState()
	end
end

function RoundController.Init()
	roundNetwork = Networker.server.new("RoundController", RoundController, {
		RoundController.GetState,
		RoundController.VoteToSkip,
	})

	ZombieController.GetZombieDiedSignal():Connect(function(death)
		local roundNumber = type(death) == "table" and death.roundNumber or nil
		if type(roundNumber) == "number" and roundNumber == currentRound then
			scheduleCompletionCheck(roundNumber)
		end
	end)
	ZombieController.GetZombieSpawnedSignal():Connect(function(_, roundNumber)
		if not spawningRound and roundNumber == currentRound then
			broadcastState()
		end
	end)
	ZombieController.GetSimulationStartedSignal():Connect(function()
		if currentRound == 0 then
			advanceRound()
		end
	end)
	if ZombieController.IsSimulationStarted() then
		advanceRound()
	end
end

function RoundController.OnPlayerAdded(player: Player)
	if isPartyMember(player) then
		-- Joining changes the majority threshold, so every party member receives the same updated count.
		broadcastState()
	end
end

function RoundController.OnPlayerRemoving(player: Player)
	if votes[player.UserId] then
		votes[player.UserId] = nil
	end
	lastSkipVoteAt[player.UserId] = nil
	task.defer(evaluateSkipMajority)
end

return RoundController
