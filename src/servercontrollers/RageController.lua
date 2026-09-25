local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local ServerContext = require(script.Parent.ServerContext)

type PlayerRuntime = {
	active: boolean,
	endsAt: number,
	chargeStartedAt: number,
	revision: number,
	activationToken: number,
	lastActivationRequestAt: number,
	deathConnection: RBXScriptConnection?,
}

local RageController = {}

local rageNetwork
local runtimes: { [Player]: PlayerRuntime } = {}
local activated = Signal.new()

local function getCurrentRage(runtime: PlayerRuntime, now: number): number
	if runtime.active then
		return RageConfig.Maximum
	end
	return math.clamp((now - runtime.chargeStartedAt) / RageConfig.ChargeDuration, 0, 1) * RageConfig.Maximum
end

local function sendState(player: Player, runtime: PlayerRuntime)
	local now = workspace:GetServerTimeNow()
	runtime.revision += 1
	rageNetwork:fire(player, "RageStateChanged", {
		rage = getCurrentRage(runtime, now),
		active = runtime.active,
		endsAt = runtime.endsAt,
		chargeStartedAt = runtime.chargeStartedAt,
		revision = runtime.revision,
	})
end

local function clearRage(player: Player, runtime: PlayerRuntime, chargeStartedAt: number?)
	runtime.activationToken += 1
	runtime.active = false
	runtime.endsAt = 0
	runtime.chargeStartedAt = chargeStartedAt or workspace:GetServerTimeNow()
	sendState(player, runtime)
end

function RageController.IsActive(player: Player): boolean
	local runtime = runtimes[player]
	return runtime ~= nil and runtime.active and workspace:GetServerTimeNow() < runtime.endsAt
end

function RageController.ActivateRage(_, player: Player)
	local runtime = runtimes[player]
	if not runtime or ServerContext.IsLobbyServer() then
		-- Rage is a run mechanic and must never activate from a Lobby request.
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - runtime.lastActivationRequestAt < RageConfig.ActivationRequestCooldown then
		return
	end
	runtime.lastActivationRequestAt = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- The request contains no meter or duration values; only the server-owned timer can fill and activate Rage.
	-- The client predicts only presentation; this server-time check remains authoritative for activation and duration.
	if runtime.active or getCurrentRage(runtime, now) < RageConfig.Maximum or not humanoid or humanoid.Health <= 0 then
		sendState(player, runtime)
		return
	end

	runtime.activationToken += 1
	local token = runtime.activationToken
	runtime.active = true
	runtime.endsAt = now + RageConfig.Duration
	sendState(player, runtime)
	activated:Fire(player)

	task.delay(RageConfig.Duration, function()
		if runtimes[player] ~= runtime or runtime.activationToken ~= token or not runtime.active then
			return
		end
		-- Charge resumes from the authoritative end timestamp even if this delayed task runs a frame late.
		clearRage(player, runtime, runtime.endsAt)
	end)
end

function RageController.GetActivatedSignal()
	return activated
end

function RageController.Init()
	rageNetwork = Networker.server.new("RageController", RageController, {
		RageController.ActivateRage,
	})
end

function RageController.OnPlayerAdded(player: Player)
	local now = workspace:GetServerTimeNow()
	runtimes[player] = {
		active = false,
		endsAt = 0,
		chargeStartedAt = now,
		revision = 0,
		activationToken = 0,
		lastActivationRequestAt = -math.huge,
		deathConnection = nil,
	}
	sendState(player, runtimes[player])
end

function RageController.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	if runtime.deathConnection then
		runtime.deathConnection:Disconnect()
	end
	clearRage(player, runtime)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		runtime.deathConnection = humanoid.Died:Connect(function()
			if runtimes[player] == runtime then
				clearRage(player, runtime)
			end
		end)
	end
end

function RageController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.activationToken += 1
		if runtime.deathConnection then
			runtime.deathConnection:Disconnect()
		end
	end
	runtimes[player] = nil
end

return RageController
