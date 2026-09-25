local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local BackpackController = require(ServerStorage.Controllers.BackpackController)
local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local PartyTeleportService = require(ServerStorage.Controllers.PartyTeleportService)
local RageController = require(ServerStorage.Controllers.RageController)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local RETURN_DELAY = 15

type RunRuntime = {
	startedAt: number,
	zombiesKilled: number,
	coinsCollected: number,
	ended: boolean,
	resultPacket: any?,
	deathConnection: RBXScriptConnection?,
	returnToken: number,
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
		startedAt = workspace:GetServerTimeNow(),
		zombiesKilled = 0,
		coinsCollected = 0,
		ended = false,
		resultPacket = nil,
		deathConnection = nil,
		returnToken = 0,
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
		endedAt = now,
		returnAt = now + RETURN_DELAY,
		stats = {
			survivalTime = math.max(now - runtime.startedAt, 0),
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
	return runtime and runtime.resultPacket or { active = false }
end

function RunSessionController.Init()
	sessionNetwork = Networker.server.new("RunSessionController", RunSessionController, {
		RunSessionController.GetSnapshot,
	})

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
