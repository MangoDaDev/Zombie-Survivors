local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local ServerContext = require(script.Parent.ServerContext)
local ClassController = require(script.Parent.ClassController)
local GameReadyController = require(script.Parent.GameReadyController)

type PlayerRuntime = {
	active: boolean,
	endsAt: number,
	chargeStartedAt: number,
	revision: number,
	activationToken: number,
	lastActivationRequestAt: number,
	bonusRestoreChargeStartedAt: number?,
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
	runtime.bonusRestoreChargeStartedAt = nil
	ClassController.ClearRageKillSpeed(player)
	sendState(player, runtime)
end

local function scheduleRageEnd(player: Player, runtime: PlayerRuntime)
	local token = runtime.activationToken
	local endsAt = runtime.endsAt
	task.delay(math.max(endsAt - workspace:GetServerTimeNow(), 0), function()
		if runtimes[player] ~= runtime or runtime.activationToken ~= token or not runtime.active then
			return
		end
		-- Bonus Rage preserves the meter's original timeline; normal Rage begins recharging when it ends.
		local nextChargeStartedAt = runtime.bonusRestoreChargeStartedAt or endsAt
		clearRage(player, runtime, nextChargeStartedAt)
	end)
end

function RageController.IsActive(player: Player): boolean
	local runtime = runtimes[player]
	return runtime ~= nil and runtime.active and workspace:GetServerTimeNow() < runtime.endsAt
end

function RageController.ActivateRage(_, player: Player)
	local runtime = runtimes[player]
	if not runtime or ServerContext.IsLobbyServer() or not GameReadyController.IsStarted() then
		-- Rage is a combat mechanic and must never activate from the Lobby or the in-game ready phase.
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
	runtime.active = true
	runtime.endsAt = now + RageConfig.Duration + ClassController.GetRageDurationBonus(player)
	runtime.bonusRestoreChargeStartedAt = nil
	sendState(player, runtime)
	activated:Fire(player)
	scheduleRageEnd(player, runtime)
end

function RageController.ActivateBonusRage(player: Player, duration: number?): (boolean, number?)
	local runtime = runtimes[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not runtime
		or ServerContext.IsLobbyServer()
		or not GameReadyController.IsStarted()
		or not humanoid
		or humanoid.Health <= 0
	then
		return false, nil
	end

	local now = workspace:GetServerTimeNow()
	local bonusDuration = if type(duration) == "number" and duration > 0
		then duration else RageConfig.Duration + ClassController.GetRageDurationBonus(player)
	local wasActive = runtime.active and now < runtime.endsAt
	if runtime.active and not wasActive then
		-- Reconcile a just-expired timer before preserving charge for the canister.
		runtime.active = false
		runtime.chargeStartedAt = runtime.bonusRestoreChargeStartedAt or runtime.endsAt
		runtime.bonusRestoreChargeStartedAt = nil
	end
	if wasActive then
		-- Extending a naturally activated Rage lets its meter recharge from the original end time.
		runtime.bonusRestoreChargeStartedAt = runtime.bonusRestoreChargeStartedAt or runtime.endsAt
	else
		-- The canister is a true bonus: partial or fully ready natural charge is never consumed.
		runtime.bonusRestoreChargeStartedAt = runtime.chargeStartedAt
	end

	runtime.activationToken += 1
	runtime.active = true
	runtime.endsAt = math.min(math.max(now, runtime.endsAt) + bonusDuration,
		now + (RageConfig.Duration + ClassController.GetRageDurationBonus(player)) * 2)
	sendState(player, runtime)
	if not wasActive then
		activated:Fire(player)
	end
	scheduleRageEnd(player, runtime)
	return true, runtime.endsAt
end

function RageController.GetActivatedSignal()
	return activated
end

function RageController.EndRun(player: Player)
	local runtime = runtimes[player]
	if runtime then
		clearRage(player, runtime)
	end
end

function RageController.Init()
	rageNetwork = Networker.server.new("RageController", RageController, {
		RageController.ActivateRage,
	})
	GameReadyController.GetStartedSignal():Connect(function(startedAt)
		for player, runtime in runtimes do
			-- The Rage clock begins with combat, not while players are deciding whether to ready up.
			clearRage(player, runtime, startedAt)
		end
	end)
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
		bonusRestoreChargeStartedAt = nil,
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
