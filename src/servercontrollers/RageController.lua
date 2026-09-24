local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)

type PlayerRuntime = {
	rage: number,
	active: boolean,
	endsAt: number,
	revision: number,
	activationToken: number,
	lastActivationRequestAt: number,
	deathConnection: RBXScriptConnection?,
}

local RageController = {}

local rageNetwork
local runtimes: { [Player]: PlayerRuntime } = {}
local activated = Signal.new()

local function sendState(player: Player, runtime: PlayerRuntime)
	runtime.revision += 1
	rageNetwork:fire(player, "RageStateChanged", {
		rage = runtime.rage,
		active = runtime.active,
		endsAt = runtime.endsAt,
		revision = runtime.revision,
	})
end

local function clearRage(player: Player, runtime: PlayerRuntime)
	runtime.activationToken += 1
	runtime.rage = 0
	runtime.active = false
	runtime.endsAt = 0
	sendState(player, runtime)
end

function RageController.AddCombatRage(player: Player, amount: number): boolean
	local runtime = runtimes[player]
	if not runtime or runtime.active or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return false
	end

	local updated = math.clamp(runtime.rage + amount, 0, RageConfig.Maximum)
	if updated == runtime.rage then
		return false
	end
	runtime.rage = updated
	sendState(player, runtime)
	return true
end

function RageController.IsActive(player: Player): boolean
	local runtime = runtimes[player]
	return runtime ~= nil and runtime.active and workspace:GetServerTimeNow() < runtime.endsAt
end

function RageController.ActivateRage(_, player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - runtime.lastActivationRequestAt < RageConfig.ActivationRequestCooldown then
		return
	end
	runtime.lastActivationRequestAt = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- The request contains no meter or duration values; only server-owned combat can fill and activate Rage.
	if runtime.active or runtime.rage < RageConfig.Maximum or not humanoid or humanoid.Health <= 0 then
		return
	end

	runtime.activationToken += 1
	local token = runtime.activationToken
	runtime.active = true
	runtime.rage = RageConfig.Maximum
	runtime.endsAt = now + RageConfig.Duration
	sendState(player, runtime)
	activated:Fire(player)

	task.delay(RageConfig.Duration, function()
		if runtimes[player] ~= runtime or runtime.activationToken ~= token or not runtime.active then
			return
		end
		clearRage(player, runtime)
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
	runtimes[player] = {
		rage = 0,
		active = false,
		endsAt = 0,
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
