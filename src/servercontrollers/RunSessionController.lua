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
		sessionNetwork:fire(player, "GameOver", runtime.resultPacket)
	end
	RunProgressionController.EndRun(player)
	AbilityController.EndRun(player)
	RageController.EndRun(player)
	BackpackController.SetCarriedCoins(player, 0)

	local token = runtime.returnToken
	task.delay(RETURN_DELAY, returnPlayerToLobby, player, runtime, token)
end

function RunSessionController.GetSnapshot(_, player: Player)
	initializePlayer(player)
	local runtime = runtimes[player]
	return runtime and (runtime.resultPacket or { active = false, startedAt = runtime.startedAt }) or { active = false }
end

function RunSessionController.RequestReplay(_, player: Player)
	local runtime = runtimes[player]
	if
		not runtime
		or not runtime.ended
		or runtime.restarting
		or player.Parent ~= Players
		or not ServerContext.IsGameServer()
	then
		return
	end

	runtime.restarting = true
	-- Replaying is an in-server character reload. Invalidating the token guarantees the old delayed lobby
	-- teleport cannot race the reload and move the player into a different server after they press Play Again.
	runtime.returnToken += 1
	disconnectDeath(runtime)

	if not CharacterController.ReloadCharacter(player) then
		runtime.restarting = false
		local resultPacket = runtime.resultPacket
		if resultPacket then
			local token = runtime.returnToken
			task.delay(math.max(resultPacket.returnAt - workspace:GetServerTimeNow(), 0), returnPlayerToLobby, player, runtime, token)
		end
		if sessionNetwork and player.Parent == Players then
			sessionNetwork:fire(player, "ReplayFailed", "Could not restart the run. Please try again.")
		end
		return
	end

	local startedAt = workspace:GetServerTimeNow()
	runtime.startedAt = startedAt
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

	if sessionNetwork and player.Parent == Players then
		sessionNetwork:fire(player, "RunStarted", startedAt)
	end
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
	runtimes[player] = nil
end

return RunSessionController
