local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)

local UPDATE_INTERVAL = 0.05

type XPDropState = {
	id: number,
	value: number,
	position: Vector3,
	despawnAt: number,
	collectibleAt: number,
	ownerUserId: number?,
	collectingPlayer: Player?,
	magnetSpeed: number,
	forcedCollection: boolean,
}

local XPDropController = {}

local xpNetwork
local heartbeatConnection
local random = Random.new()
local nextDropId = 0
local activeCount = 0
local accumulator = 0
local drops: { [number]: XPDropState } = {}

local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function canCollect(drop: XPDropState, player: Player): boolean
	return drop.ownerUserId == nil or drop.ownerUserId == player.UserId
end

local function getVisualScale(value: number): number
	local config = RunProgressionConfig.Pickups.XP
	local tier = RunProgressionConfig.GetXPVisualTier(value)
	local valueGrowth = math.min(math.log(math.max(value, 1)) / math.log(2) * 0.08, 0.45)
	return (config.BaseVisualScale + valueGrowth) * tier.ScaleMultiplier
end

local function addOverflowValue(position: Vector3, value: number, ownerUserId: number?): boolean
	local nearest
	local nearestDistance = math.huge
	for _, drop in drops do
		local distance = (drop.position - position).Magnitude
		if drop.ownerUserId == ownerUserId and distance < nearestDistance then
			nearest = drop
			nearestDistance = distance
		end
	end
	if nearest then
		nearest.value += value
		nearest.despawnAt = workspace:GetServerTimeNow() + RunProgressionConfig.Pickups.XP.Lifetime
		xpNetwork:fireAll("XPValueChanged", nearest.id, nearest.value, getVisualScale(nearest.value))
		return true
	end
	return false
end

function XPDropController.Spawn(position: Vector3, value: number, owner: Player?, groundY: number?)
	if not ServerContext.IsGameServer()
		or typeof(position) ~= "Vector3"
		or type(value) ~= "number"
		or value <= 0
	then
		return
	end
	value = math.max(1, math.floor(value))
	local config = RunProgressionConfig.Pickups.XP
	local ownerUserId = if RunProgressionConfig.Pickups.Ownership == "Killer" and owner then owner.UserId else nil
	if activeCount >= config.MaximumActive and addOverflowValue(position, value, ownerUserId) then
		return
	end

	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(config.ScatterRadius.Min, config.ScatterRadius.Max)
	local floorY = if type(groundY) == "number" then groundY else position.Y
	local visualScale = getVisualScale(value)
	local target = Vector3.new(
		position.X + math.cos(angle) * distance,
		floorY + config.VisualHeight * visualScale,
		position.Z + math.sin(angle) * distance
	)
	local duration = random:NextNumber(config.ScatterDuration.Min, config.ScatterDuration.Max)
	local now = workspace:GetServerTimeNow()
	nextDropId += 1
	local drop: XPDropState = {
		id = nextDropId,
		value = value,
		position = target,
		despawnAt = now + config.Lifetime,
		collectibleAt = now + duration * 0.72,
		ownerUserId = ownerUserId,
		collectingPlayer = nil,
		magnetSpeed = config.MagnetInitialSpeed,
		forcedCollection = false,
	}
	drops[drop.id] = drop
	activeCount += 1
	xpNetwork:fireAll("SpawnXP", {
		id = drop.id,
		value = drop.value,
		origin = position + Vector3.new(0, 0.8, 0),
		position = target,
		launchAt = now,
		duration = duration,
		arcHeight = random:NextNumber(2.2, 4.2),
		scale = visualScale,
		ownerUserId = drop.ownerUserId,
	})
end

local function releaseDrop(drop: XPDropState)
	drop.collectingPlayer = nil
	drop.magnetSpeed = RunProgressionConfig.Pickups.XP.MagnetInitialSpeed
	drop.forcedCollection = false
	xpNetwork:fireAll("ReleaseXP", drop.id, drop.position)
end

local function collectDrop(id: number, drop: XPDropState, player: Player)
	-- A shard must only disappear after the authoritative progression state accepts its value.
	-- If startup ordering temporarily blocks the grant, release it for a later collection attempt.
	if not RunProgressionController.AddXP(player, drop.value) then
		drop.collectibleAt = workspace:GetServerTimeNow() + 0.25
		releaseDrop(drop)
		return
	end
	drops[id] = nil
	activeCount -= 1
	xpNetwork:fireAll("XPCollected", id, player.UserId, drop.value)
end

local function stepDrops(deltaTime: number, now: number)
	local config = RunProgressionConfig.Pickups.XP
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local root = getLiveRoot(player)
		if root then
			table.insert(candidates, { player = player, root = root })
		end
	end

	local expiredIds = {}
	for id, drop in drops do
		local collector = drop.collectingPlayer
		if collector then
			local root = getLiveRoot(collector)
			if not root or not canCollect(drop, collector) then
				releaseDrop(drop)
			else
				local destination = root.Position + Vector3.new(0, 1.25, 0)
				local offset = destination - drop.position
				if offset.Magnitude <= config.PickupRadius then
					collectDrop(id, drop, collector)
					continue
				end
				if not drop.forcedCollection and offset.Magnitude > config.MagnetRadius * 3 then
					releaseDrop(drop)
				else
					drop.magnetSpeed += config.MagnetAcceleration * deltaTime
					drop.position += offset.Unit * math.min(drop.magnetSpeed * deltaTime, offset.Magnitude)
				end
			end
		elseif now >= drop.despawnAt then
			drops[id] = nil
			activeCount -= 1
			table.insert(expiredIds, id)
		elseif now >= drop.collectibleAt then
			local nearest
			local nearestDistance = config.MagnetRadius
			for _, candidate in candidates do
				if canCollect(drop, candidate.player) then
					local distance = (candidate.root.Position - drop.position).Magnitude
					if distance <= nearestDistance then
						nearest = candidate.player
						nearestDistance = distance
					end
				end
			end
			if nearest then
				drop.collectingPlayer = nearest
				drop.magnetSpeed = config.MagnetInitialSpeed
				drop.forcedCollection = false
				xpNetwork:fireAll("MagnetXP", id, nearest.UserId, drop.position, now)
			end
		end
	end
	if #expiredIds > 0 then
		xpNetwork:fireAll("DespawnXP", expiredIds)
	end
end

function XPDropController.CollectAll(player: Player): number
	if player.Parent ~= Players or not getLiveRoot(player) then
		return 0
	end
	local collectedCount = 0
	local now = workspace:GetServerTimeNow()
	for _, drop in drops do
		if not drop.collectingPlayer and canCollect(drop, player) then
			drop.collectingPlayer = player
			drop.forcedCollection = true
			drop.magnetSpeed = math.max(RunProgressionConfig.Pickups.XP.MagnetInitialSpeed * 5, 80)
			xpNetwork:fireAll("MagnetXP", drop.id, player.UserId, drop.position, now)
			collectedCount += 1
		end
	end
	return collectedCount
end

local function onHeartbeat(deltaTime: number)
	accumulator += deltaTime
	if accumulator < UPDATE_INTERVAL then
		return
	end
	local elapsed = accumulator
	accumulator = 0
	stepDrops(math.min(elapsed, 0.15), workspace:GetServerTimeNow())
end

local function start()
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

function XPDropController.GetSnapshot(_, _player)
	local snapshot = {}
	for _, drop in drops do
		table.insert(snapshot, {
			id = drop.id,
			value = drop.value,
			position = drop.position,
			scale = getVisualScale(drop.value),
			ownerUserId = drop.ownerUserId,
			collectorUserId = drop.collectingPlayer and drop.collectingPlayer.UserId or nil,
		})
	end
	return snapshot
end

function XPDropController.Init()
	xpNetwork = Networker.server.new("XPDropController", XPDropController, {
		XPDropController.GetSnapshot,
	})
	if ServerContext.IsGameServer() then
		start()
	elseif RunService:IsStudio() then
		ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				start()
			end
		end)
	end
end

return XPDropController
