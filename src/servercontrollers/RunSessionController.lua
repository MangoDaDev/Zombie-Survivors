local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local BackpackController = require(ServerStorage.Controllers.BackpackController)
local CharacterController = require(ServerStorage.Controllers.CharacterController)
local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local PartyTeleportService = require(ServerStorage.Controllers.PartyTeleportService)
local RageController = require(ServerStorage.Controllers.RageController)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local RoundController = require(ServerStorage.Controllers.RoundController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local RETURN_DELAY = 15

type RunRuntime = {
	startedAt: number?,
	zombiesKilled: number,
	coinsCollected: number,
	ended: boolean,
	resultPacket: any?,
	deathConnection: RBXScriptConnection?,
	returnToken: number,
	restarting: boolean,
}

local RunSessionController = {}

local sessionNetwork
local runtimes: { [Player]: RunRuntime } = {}
local replayVotes: { [Player]: boolean } = {}
local restartingParty = false

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

local function getPartyPlayers(): { Player }
	local partyPlayers = {}
	for _, player in Players:GetPlayers() do
		if isPartyMember(player) and runtimes[player] then
			table.insert(partyPlayers, player)
		end
	end
	return partyPlayers
end

local function getReplayVoteCount(): number
	local count = 0
	for _, player in getPartyPlayers() do
		if replayVotes[player] then
			count += 1
		end
	end
	return count
end

local function makeSnapshot(player: Player, runtime: RunRuntime)
	if not runtime.resultPacket then
		return { active = false, startedAt = runtime.startedAt }
	end

	local result = table.clone(runtime.resultPacket)
	result.replayVoteCount = getReplayVoteCount()
	result.replayRequiredVotes = #getPartyPlayers()
	result.hasReplayVoted = replayVotes[player] == true
	return result
end

local function broadcastReplayState()
	if not sessionNetwork then
		return
	end
	for _, player in getPartyPlayers() do
		local runtime = runtimes[player]
		if runtime and runtime.ended and runtime.resultPacket then
			sessionNetwork:fire(player, "GameOver", makeSnapshot(player, runtime))
		end
	end
end

local function disconnectDeath(runtime: RunRuntime)
	if runtime.deathConnection then
		runtime.deathConnection:Disconnect()
		runtime.deathConnection = nil
	end
end

local function initializePlayer(player: Player)
	if runtimes[player] or not ServerContext.IsGameServer() then
		return
	end
	runtimes[player] = {
		startedAt = ZombieController.GetFirstZombieSpawnedAt(),
		zombiesKilled = 0,
		coinsCollected = 0,
		ended = false,
		resultPacket = nil,
		deathConnection = nil,
		returnToken = 0,
		restarting = false,
	}
end

local function returnPlayerToLobby(player: Player, runtime: RunRuntime, token: number)
	if runtimes[player] ~= runtime or runtime.returnToken ~= token or player.Parent ~= Players then
		return
	end
	local success, errorMessage = PartyTeleportService.ReturnToLobby(player)
	if not success then
		warn(string.format("Could not return %s to lobby: %s", player.Name, errorMessage or "Unknown error"))
		if sessionNetwork and player.Parent == Players then
			sessionNetwork:fire(player, "LobbyReturnFailed", errorMessage or "Could not return to the lobby.")
		end
	end
end

local function endRun(player: Player)
	local runtime = runtimes[player]
	if not runtime or runtime.ended then
		return
	end
	runtime.ended = true
	runtime.returnToken += 1
	disconnectDeath(runtime)

	local now = workspace:GetServerTimeNow()
	local progression = RunProgressionController.GetRunSummary(player)
	runtime.resultPacket = {
		active = true,
		startedAt = runtime.startedAt,
		endedAt = now,
		returnAt = now + RETURN_DELAY,
		stats = {
			survivalTime = if runtime.startedAt then math.max(now - runtime.startedAt, 0) else 0,
			zombiesKilled = runtime.zombiesKilled,
			levelReached = progression.level,
			coinsCollected = runtime.coinsCollected,
			xpCollected = progression.totalXP,
		},
	}

	-- Snapshot first so the result screen always receives final values before run-only systems are cleared.
	if sessionNetwork and player.Parent == Players then
		sessionNetwork:fire(player, "GameOver", makeSnapshot(player, runtime))
	end
	RunProgressionController.EndRun(player)
	AbilityController.EndRun(player)
	RageController.EndRun(player)
	BackpackController.SetCarriedCoins(player, 0)

	local token = runtime.returnToken
	task.delay(RETURN_DELAY, returnPlayerToLobby, player, runtime, token)
	broadcastReplayState()
end

function RunSessionController.GetSnapshot(_, player: Player)
	initializePlayer(player)
	local runtime = runtimes[player]
	return runtime and makeSnapshot(player, runtime) or { active = false }
end

local function restartParty()
	if restartingParty then
		return
	end
	local partyPlayers = getPartyPlayers()
	if #partyPlayers == 0 or getReplayVoteCount() < #partyPlayers then
		broadcastReplayState()
		return
	end

	restartingParty = true
	for _, player in partyPlayers do
		local runtime = runtimes[player]
		runtime.restarting = true
		runtime.returnToken += 1
		disconnectDeath(runtime)
	end

	local failedPlayers = {}
	for _, player in partyPlayers do
		if not CharacterController.ReloadCharacter(player) then
			table.insert(failedPlayers, player)
		end
	end

	if #failedPlayers > 0 then
		for _, player in partyPlayers do
			local runtime = runtimes[player]
			runtime.restarting = false
			if runtime.resultPacket then
				local token = runtime.returnToken
				task.delay(
					math.max(runtime.resultPacket.returnAt - workspace:GetServerTimeNow(), 0),
					returnPlayerToLobby,
					player,
					runtime,
					token
				)
			end
			if sessionNetwork and player.Parent == Players then
				sessionNetwork:fire(player, "ReplayFailed", "Could not restart every player. Please try again.")
			end
		end
		restartingParty = false
		return
	end

	-- Play Again is a shared run boundary: every player and every horde system resets before round one spawns.
	ZombieController.RestartRun()
	table.clear(replayVotes)
	for _, player in partyPlayers do
		local runtime = runtimes[player]
		runtime.startedAt = nil
		runtime.zombiesKilled = 0
		runtime.coinsCollected = 0
		runtime.ended = false
		runtime.resultPacket = nil
		runtime.restarting = false

		AbilityController.RestartRun(player)
		RunProgressionController.RestartRun(player)
		RageController.EndRun(player)
		BackpackController.SetCarriedCoins(player, 0)
		RunSessionController.OnCharacterAdded(player, player.Character)
	end
	-- CharacterController places freshly loaded characters on a deferred task. Start round one after those
	-- placements so its spawn groups are measured from the authored arena spawn rather than a transient position.
	task.defer(function()
		RoundController.RestartRun()
		restartingParty = false
	end)
end

function RunSessionController.RequestReplay(_, player: Player)
	local runtime = runtimes[player]
	if
		not runtime
		or not runtime.ended
		or runtime.restarting
		or replayVotes[player]
		or player.Parent ~= Players
		or not isPartyMember(player)
		or not ServerContext.IsGameServer()
	then
		return
	end

	-- A replay vote opts this player out of the automatic lobby return so they can wait for every teammate.
	replayVotes[player] = true
	runtime.returnToken += 1
	restartParty()
end

function RunSessionController.Init()
	sessionNetwork = Networker.server.new("RunSessionController", RunSessionController, {
		RunSessionController.GetSnapshot,
		RunSessionController.RequestReplay,
	})
	local function beginSurvivalClock(startedAt: number)
		for player, runtime in runtimes do
			if not runtime.ended and not runtime.startedAt then
				runtime.startedAt = startedAt
				if player.Parent == Players then
					sessionNetwork:fire(player, "RunStarted", startedAt)
				end
			end
		end
	end
	ZombieController.GetFirstZombieSpawnedSignal():Connect(beginSurvivalClock)
	local existingStart = ZombieController.GetFirstZombieSpawnedAt()
	if existingStart then
		beginSurvivalClock(existingStart)
	end

	ZombieController.GetZombieDiedSignal():Connect(function(death)
		local killer = type(death) == "table" and death.killer or nil
		local runtime = killer and runtimes[killer]
		if runtime and not runtime.ended then
			runtime.zombiesKilled += 1
		end
	end)
	CoinDropController.GetCoinCollectedSignal():Connect(function(player: Player, value: number)
		local runtime = runtimes[player]
		if runtime and not runtime.ended then
			runtime.coinsCollected += value
		end
	end)

	if RunService:IsStudio() then
		ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				for _, player in Players:GetPlayers() do
					initializePlayer(player)
				end
			end
		end)
	end
end

function RunSessionController.OnPlayerAdded(player: Player)
	initializePlayer(player)
	broadcastReplayState()
end

function RunSessionController.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime or runtime.ended then
		return
	end
	disconnectDeath(runtime)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		runtime.deathConnection = humanoid.Died:Connect(function()
			endRun(player)
		end)
	end
end

function RunSessionController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.returnToken += 1
		disconnectDeath(runtime)
	end
	replayVotes[player] = nil
	runtimes[player] = nil
	task.defer(restartParty)
end

return RunSessionController
