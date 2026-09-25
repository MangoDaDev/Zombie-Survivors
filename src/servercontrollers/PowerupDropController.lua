local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local PowerupConfig = require(ReplicatedStorage.Modules.Game.PowerupConfig)
local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local RageController = require(ServerStorage.Controllers.RageController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

type PowerupDrop = {
	id: number,
	powerupId: string,
	position: Vector3,
	collectibleAt: number,
	despawnAt: number,
}

local PowerupDropController = {}

local powerupNetwork
local xpDropController
local heartbeatConnection: RBXScriptConnection?
local contextChangedConnection: RBXScriptConnection?
local random = Random.new()
local nextDropId = 0
local accumulator = 0
local drops: { [number]: PowerupDrop } = {}

local function getLiveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function choosePowerupId(): string
	local totalWeight = 0
	for _, powerupId in PowerupConfig.Order do
		totalWeight += PowerupConfig.Definitions[powerupId].Weight
	end

	local roll = random:NextNumber(0, totalWeight)
	local runningWeight = 0
	for _, powerupId in PowerupConfig.Order do
		runningWeight += PowerupConfig.Definitions[powerupId].Weight
		if roll <= runningWeight then
			return powerupId
		end
	end
	return PowerupConfig.Order[#PowerupConfig.Order]
end

local function removeDrop(id: number)
	if drops[id] then
		drops[id] = nil
		powerupNetwork:fireAll("DespawnPowerups", { id })
	end
end

local function setTimedState(player: Player, key: string, duration: number, maximumDuration: number): number
	local now = workspace:GetServerTimeNow()
	local currentEndsAt = PlayerStateController.Get(player, key, 0)
	if type(currentEndsAt) ~= "number" then
		currentEndsAt = 0
	end
	-- Repeated pickups extend the buff, but the cap prevents a lucky cluster from trivializing a whole run.
	local endsAt = math.min(math.max(now, currentEndsAt) + duration, now + maximumDuration)
	PlayerStateController.Set(player, key, endsAt)
	return endsAt
end

local function canActivate(powerupId: string, humanoid: Humanoid): boolean
	-- A full-health player cannot accidentally waste the only pickup whose effect would do nothing.
	return powerupId ~= "CookedChicken" or humanoid.Health < humanoid.MaxHealth
end

local function activatePowerup(player: Player, powerupId: string, position: Vector3, humanoid: Humanoid): number
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local effectPosition = if root and root:IsA("BasePart") then root.Position else position
	if powerupId == "CookedChicken" then
		humanoid.Health = humanoid.MaxHealth
		return 0
	elseif powerupId == "RageCanister" then
		local _, endsAt = RageController.ActivateBonusRage(player)
		return endsAt or 0
	elseif powerupId == "Bomb" then
		local config = PowerupConfig.Bomb
		for _, target in ZombieController.GetZombiesInRadius(effectPosition, config.Radius, config.MaximumTargets) do
			ZombieController.DamageZombie(target.id, config.Damage, effectPosition, config.Knockback, {
				player = player,
				source = "PowerupBomb",
				canApplyHitPassives = false,
			})
		end
		return 0
	elseif powerupId == "ScrapMagnet" then
		CoinDropController.CollectAll(player)
		xpDropController.CollectAll(player)
		return 0
	elseif powerupId == "Stopwatch" then
		local config = PowerupConfig.Stopwatch
		ZombieController.SlowZombiesInRadius(
			effectPosition,
			config.Radius,
			config.MoveSpeedMultiplier,
			config.Duration,
			config.MaximumTargets
		)
		return now + config.Duration
	elseif powerupId == "GuardianHalo" then
		local config = PowerupConfig.GuardianHalo
		return setTimedState(player, "GuardianHaloEndsAt", config.Duration, config.MaximumStackedDuration)
	elseif powerupId == "LuckySkull" then
		local config = PowerupConfig.LuckySkull
		return setTimedState(player, "LuckySkullEndsAt", config.Duration, config.MaximumStackedDuration)
	end
	return 0
end

local function collectDrop(id: number, drop: PowerupDrop, player: Player, humanoid: Humanoid)
	-- Remove authority before applying the effect so overlapping player checks can never collect twice.
	drops[id] = nil
	local endsAt = activatePowerup(player, drop.powerupId, drop.position, humanoid)
	powerupNetwork:fireAll(
		"PowerupCollected",
		id,
		player.UserId,
		drop.powerupId,
		drop.position,
		endsAt
	)
end

local function stepDrops(now: number)
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local _, humanoid, root = getLiveCharacter(player)
		if humanoid and root then
			table.insert(candidates, {
				player = player,
				humanoid = humanoid,
				position = root.Position,
			})
		end
	end

	local expiredIds = {}
	for id, drop in drops do
		if now >= drop.despawnAt then
			drops[id] = nil
			table.insert(expiredIds, id)
		elseif now >= drop.collectibleAt then
			local nearest
			local nearestDistance = PowerupConfig.PickupRadius
			for _, candidate in candidates do
				local distance = (candidate.position - drop.position).Magnitude
				if distance <= nearestDistance and canActivate(drop.powerupId, candidate.humanoid) then
					nearest = candidate
					nearestDistance = distance
				end
			end
			if nearest then
				collectDrop(id, drop, nearest.player, nearest.humanoid)
			end
		end
	end
	if #expiredIds > 0 then
		powerupNetwork:fireAll("DespawnPowerups", expiredIds)
	end
end

local function onHeartbeat(deltaTime: number)
	accumulator += deltaTime
	if accumulator < PowerupConfig.UpdateInterval then
		return
	end
	accumulator = 0
	stepDrops(workspace:GetServerTimeNow())
end

local function start()
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

function PowerupDropController.Spawn(position: Vector3, landingY: number?)
	if not ServerContext.IsGameServer() or typeof(position) ~= "Vector3" then
		return
	end

	local activeCount = 0
	local oldestId
	local oldestDespawnAt = math.huge
	for id, drop in drops do
		activeCount += 1
		if drop.despawnAt < oldestDespawnAt then
			oldestDespawnAt = drop.despawnAt
			oldestId = id
		end
	end
	if activeCount >= PowerupConfig.MaximumActive and oldestId then
		-- Keep breakable rewards guaranteed without allowing abandoned drops to grow without bound.
		removeDrop(oldestId)
	end

	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(PowerupConfig.ScatterRadius.Min, PowerupConfig.ScatterRadius.Max)
	local floorY = if type(landingY) == "number" then landingY else position.Y
	local targetPosition = Vector3.new(
		position.X + math.cos(angle) * distance,
		floorY + PowerupConfig.VisualHeight,
		position.Z + math.sin(angle) * distance
	)
	local duration = random:NextNumber(PowerupConfig.ScatterDuration.Min, PowerupConfig.ScatterDuration.Max)
	local now = workspace:GetServerTimeNow()
	nextDropId += 1
	local drop = {
		id = nextDropId,
		powerupId = choosePowerupId(),
		position = targetPosition,
		collectibleAt = now + duration * 0.72,
		despawnAt = now + PowerupConfig.Lifetime,
	}
	drops[drop.id] = drop
	powerupNetwork:fireAll("SpawnPowerup", {
		id = drop.id,
		powerupId = drop.powerupId,
		origin = position + Vector3.new(0, 0.8, 0),
		position = drop.position,
		launchAt = now,
		duration = duration,
		arcHeight = random:NextNumber(PowerupConfig.ArcHeight.Min, PowerupConfig.ArcHeight.Max),
		despawnAt = drop.despawnAt,
	})
end

function PowerupDropController.GetSnapshot(_, _player)
	local snapshot = {}
	for _, drop in drops do
		table.insert(snapshot, {
			id = drop.id,
			powerupId = drop.powerupId,
			position = drop.position,
			despawnAt = drop.despawnAt,
		})
	end
	return snapshot
end

function PowerupDropController.Init()
	-- Resolve XP after this module has finished loading; XP progression reaches Ability -> Breakable,
	-- which intentionally depends back on this controller to create rewards.
	xpDropController = require(ServerStorage.Controllers.XPDropController)
	powerupNetwork = Networker.server.new("PowerupDropController", PowerupDropController, {
		PowerupDropController.GetSnapshot,
	})
	if ServerContext.IsGameServer() then
		start()
	elseif RunService:IsStudio() then
		contextChangedConnection = ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				start()
				contextChangedConnection:Disconnect()
				contextChangedConnection = nil
			end
		end)
	end
end

function PowerupDropController.OnCharacterAdded(player: Player, _character: Model)
	-- Temporary protection and reward buffs are run-life effects and never survive a respawn.
	PlayerStateController.Set(player, "GuardianHaloEndsAt", 0)
	PlayerStateController.Set(player, "LuckySkullEndsAt", 0)
	powerupNetwork:fireAll("ClearPlayerPowerups", player.UserId)
end

return PowerupDropController
