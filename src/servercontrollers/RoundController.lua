local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local Signal = require(ReplicatedStorage.Packages.signal)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local RoundController = {}

local roundNetwork
local currentRound = 0
local votes: { [number]: boolean } = {}
local lastSkipVoteAt: { [number]: number } = {}
local advancing = false
local spawningRound = false
local roundSpawnPending = false
local completionCheckPending = false
local runGeneration = 0
local roundCompleted = Signal.new()
local bossAnnouncement = {
	active = false,
	stage = "",
	bossName = "",
	message = "",
	color = Color3.fromRGB(195, 48, 61),
	endsAt = 0,
	sequence = 0,
}

local function setBossAnnouncement(active: boolean, stage: string?, definition, message: string?, duration: number?)
	bossAnnouncement = {
		active = active,
		stage = stage or "",
		bossName = if definition then definition.DisplayName or "Boss" else "",
		message = message or "",
		color = if definition and typeof(definition.EffectColor) == "Color3"
			then definition.EffectColor
			else Color3.fromRGB(195, 48, 61),
		endsAt = if active then workspace:GetServerTimeNow() + math.max(duration or 0, 0) else 0,
		sequence = bossAnnouncement.sequence + 1,
	}
end

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
		bossAnnouncement = bossAnnouncement,
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
			and not roundSpawnPending
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
	if currentRound > 0 then
		local playersWhoSurvived = {}
		for _, player in Players:GetPlayers() do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if isPartyMember(player) and humanoid and humanoid.Health > 0 then
				table.insert(playersWhoSurvived, player)
			end
		end
		-- Completing or majority-skipping the active round credits only party members alive at this boundary.
		roundCompleted:Fire(currentRound, playersWhoSurvived)
	end
	currentRound += 1
	table.clear(votes)

	local roundNumber = currentRound
	local scheduledGeneration = runGeneration
	local assignedCount = RunProgressionConfig.GetRoundZombieCount(currentRound, getPartyCount())
	local bossEncounter = RunProgressionConfig.GetBossEncounter(roundNumber)
	local bossDefinition = bossEncounter and ZombieDefinitions[bossEncounter.BossType] or nil
	if bossEncounter and bossDefinition then
		setBossAnnouncement(
			true,
			"Warning",
			bossDefinition,
			"A POWERFUL UNDEAD IS APPROACHING",
			if roundNumber == 1 then RunProgressionConfig.Rounds.FirstRoundDelay else RunProgressionConfig.Rounds.IntermissionDuration
		)
	else
		setBossAnnouncement(false)
	end
	roundSpawnPending = true
	-- Commit the round before its breathing window. A skip never removes older zombies, while the
	-- generation/round guards below prevent delayed reinforcements from leaking across run boundaries.
	broadcastState()
	advancing = false

	task.spawn(function()
		local rounds = RunProgressionConfig.Rounds
		task.wait(if roundNumber == 1 then rounds.FirstRoundDelay else rounds.IntermissionDuration)
		local remaining = assignedCount
		local totalSpawned = 0
		local firstBatch = true
		if bossEncounter and runGeneration == scheduledGeneration and currentRound == roundNumber then
			spawningRound = true
			local spawnedIds = ZombieController.SpawnBossBuildup(roundNumber)
			spawningRound = false
			totalSpawned += #spawnedIds
			setBossAnnouncement(
				true,
				"Buildup",
				bossDefinition,
				"SURVIVE THE GUARD — THE BOSS IS STILL BELOW",
				bossEncounter.BuildupDuration
			)
			broadcastState()
			task.wait(bossEncounter.BuildupDuration)
			if runGeneration ~= scheduledGeneration or currentRound ~= roundNumber then
				return
			end
			setBossAnnouncement(
				true,
				"Entrance",
				bossDefinition,
				"GROUND BREACH — STAY CLEAR OF THE MARKER",
				bossEncounter.EntranceDuration
			)
			ZombieController.BeginBossEntrance(roundNumber)
			broadcastState()
			task.wait(bossEncounter.EntranceDuration)
			if runGeneration ~= scheduledGeneration or currentRound ~= roundNumber then
				return
			end
			spawningRound = true
			local bossIds = ZombieController.SpawnBossEncounter(roundNumber)
			spawningRound = false
			totalSpawned += #bossIds
			remaining = 0
			setBossAnnouncement(false)
			broadcastState()
		else
			while remaining > 0 and runGeneration == scheduledGeneration and currentRound == roundNumber do
<<<<<<< HEAD
				-- Later rounds deploy larger reinforcements with shorter gaps so their increased population
				-- becomes simultaneous combat pressure instead of merely extending the round's duration.
				local batchLimit = RunProgressionConfig.GetRoundSpawnBatchSize(roundNumber, firstBatch)
=======
				local batchLimit = if firstBatch then rounds.InitialBatchSize else rounds.ReinforcementBatchSize
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
				local batchCount = math.min(remaining, batchLimit)
				spawningRound = true
				local spawnedIds = ZombieController.SpawnRound(roundNumber, batchCount)
				spawningRound = false
				totalSpawned += #spawnedIds
				remaining -= batchCount
				firstBatch = false
				broadcastState()
				if remaining > 0 then
<<<<<<< HEAD
					task.wait(RunProgressionConfig.GetRoundReinforcementInterval(roundNumber))
=======
					task.wait(rounds.ReinforcementInterval)
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
				end
			end
		end

		if runGeneration ~= scheduledGeneration or currentRound ~= roundNumber then
			return
		end
		roundSpawnPending = false
		if totalSpawned == 0 then
			warn(string.format("Round %d could not place its assigned zombie group", roundNumber))
			broadcastState()
		elseif ZombieController.GetLivingZombieCountForRound(roundNumber) == 0 then
			scheduleCompletionCheck(roundNumber)
		else
			broadcastState()
		end
	end)
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

function RoundController.GetRoundCompletedSignal()
	return roundCompleted
end

<<<<<<< HEAD
function RoundController.GetCurrentRound(): number
	return currentRound
end

function RoundController.AdvanceForAdmin(): (boolean, number)
	if not ZombieController.IsSimulationStarted() or advancing then
		return false, currentRound
	end
	advanceRound()
	return currentRound > 0, currentRound
end

function RoundController.SetRoundForAdmin(roundNumber: number): (boolean, number)
	if type(roundNumber) ~= "number"
		or roundNumber % 1 ~= 0
		or roundNumber < 1
		or not ZombieController.IsSimulationStarted()
	then
		return false, currentRound
	end

	-- Setting a round is an exact testing jump: invalidate delayed batches, clear the current horde,
	-- and start the requested round without crediting completion for the abandoned round.
	runGeneration += 1
	currentRound = roundNumber - 1
	table.clear(votes)
	table.clear(lastSkipVoteAt)
	advancing = false
	spawningRound = false
	roundSpawnPending = false
	completionCheckPending = false
	setBossAnnouncement(false)
	ZombieController.ClearAll()
	advanceRound()
	return currentRound == roundNumber, currentRound
end

=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
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
	roundSpawnPending = false
	completionCheckPending = false
	setBossAnnouncement(false)

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
