local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local ClassController = require(ServerStorage.Controllers.ClassController)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)

local UPDATE_INTERVAL = 0.05

type XPCollection = {
	position: Vector3,
	magnetSpeed: number,
	forcedCollection: boolean,
}

type XPDropState = {
	id: number,
	value: number,
	position: Vector3,
	despawnAt: number,
	collectibleAt: number,
	ownerUserId: number?,
	eligibleUserIds: { [number]: boolean },
	collectedUserIds: { [number]: boolean },
	collections: { [Player]: XPCollection },
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
	return drop.eligibleUserIds[player.UserId] == true
		and drop.collectedUserIds[player.UserId] ~= true
		and drop.collections[player] == nil
end

local function isUntouched(drop: XPDropState): boolean
	return next(drop.collections) == nil and next(drop.collectedUserIds) == nil
end

local function hasRemainingCollectors(drop: XPDropState): boolean
	for userId in drop.eligibleUserIds do
		if not drop.collectedUserIds[userId] then
			return true
		end
	end
	return false
end

local function getEligibleUserIds(ownerUserId: number?): { [number]: boolean }
	local eligibleUserIds = {}
	for _, player in Players:GetPlayers() do
		if ownerUserId == nil or player.UserId == ownerUserId then
			eligibleUserIds[player.UserId] = true
		end
	end
	return eligibleUserIds
end

local function matchesEligibility(drop: XPDropState, eligibleUserIds: { [number]: boolean }): boolean
	for userId in drop.eligibleUserIds do
		if not eligibleUserIds[userId] then
			return false
		end
	end
	for userId in eligibleUserIds do
		if not drop.eligibleUserIds[userId] then
			return false
		end
	end
	return true
end

local function fireEligible(drop: XPDropState, eventName: string, ...)
	for userId in drop.eligibleUserIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			xpNetwork:fire(player, eventName, ...)
		end
	end
end

local function getVisualScale(value: number): number
	local config = RunProgressionConfig.Pickups.XP
	local tier = RunProgressionConfig.GetXPVisualTier(value)
	local valueGrowth = math.min(math.log(math.max(value, 1)) / math.log(2) * 0.08, 0.45)
	return (config.BaseVisualScale + valueGrowth) * tier.ScaleMultiplier
end

local function addOverflowValue(
	position: Vector3,
	value: number,
	ownerUserId: number?,
	eligibleUserIds: { [number]: boolean }
): boolean
	local nearest
	local nearestDistance = math.huge
	for _, drop in drops do
		local distance = (drop.position - position).Magnitude
		if drop.ownerUserId == ownerUserId
			and isUntouched(drop)
			and matchesEligibility(drop, eligibleUserIds)
			and distance < nearestDistance
		then
			nearest = drop
			nearestDistance = distance
		end
	end
	if nearest then
		nearest.value += value
		nearest.despawnAt = workspace:GetServerTimeNow() + RunProgressionConfig.Pickups.XP.Lifetime
		fireEligible(nearest, "XPValueChanged", nearest.id, nearest.value, getVisualScale(nearest.value))
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
	local eligibleUserIds = getEligibleUserIds(ownerUserId)
	if next(eligibleUserIds) == nil then
		return
	end
	if activeCount >= config.MaximumActive and addOverflowValue(position, value, ownerUserId, eligibleUserIds) then
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
		eligibleUserIds = eligibleUserIds,
		collectedUserIds = {},
		collections = {},
	}
	drops[drop.id] = drop
	activeCount += 1
	fireEligible(drop, "SpawnXP", {
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

local function releaseDrop(drop: XPDropState, player: Player)
	drop.collections[player] = nil
	if player.Parent == Players then
		xpNetwork:fire(player, "ReleaseXP", drop.id, drop.position)
	end
end

local function collectDrop(id: number, drop: XPDropState, player: Player)
	-- A shard must only disappear after the authoritative progression state accepts its value.
	-- If startup ordering temporarily blocks the grant, release it for a later collection attempt.
	if not RunProgressionController.AddXP(player, drop.value) then
		drop.collectibleAt = workspace:GetServerTimeNow() + 0.25
		releaseDrop(drop, player)
		return
	end
	-- Resolve only this player's claim so every other eligible player keeps their own XP copy.
	drop.collections[player] = nil
	drop.collectedUserIds[player.UserId] = true
	xpNetwork:fire(player, "XPCollected", id, player.UserId, drop.value)
	if not hasRemainingCollectors(drop) then
		drops[id] = nil
		activeCount -= 1
	end
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
		for collector, collection in drop.collections do
			local root = getLiveRoot(collector)
			if not root or not drop.eligibleUserIds[collector.UserId] or drop.collectedUserIds[collector.UserId] then
				releaseDrop(drop, collector)
			else
				local destination = root.Position + Vector3.new(0, 1.25, 0)
				local offset = destination - collection.position
				if offset.Magnitude <= config.PickupRadius then
					collectDrop(id, drop, collector)
				elseif not collection.forcedCollection
					and offset.Magnitude > config.MagnetRadius * ClassController.GetPickupMagnetMultiplier(collector) * 3
				then
					releaseDrop(drop, collector)
				else
					collection.magnetSpeed += config.MagnetAcceleration * deltaTime
					collection.position += offset.Unit * math.min(collection.magnetSpeed * deltaTime, offset.Magnitude)
				end
			end
		end
		if not drops[id] then
			continue
		elseif next(drop.collections) == nil and now >= drop.despawnAt then
			drops[id] = nil
			activeCount -= 1
			table.insert(expiredIds, id)
		elseif now >= drop.collectibleAt then
			for _, candidate in candidates do
				if not canCollect(drop, candidate.player) then
					continue
				end
				local distance = (candidate.root.Position - drop.position).Magnitude
				local magnetRadius = config.MagnetRadius * ClassController.GetPickupMagnetMultiplier(candidate.player)
				if distance <= magnetRadius then
					drop.collections[candidate.player] = {
						position = drop.position,
						magnetSpeed = config.MagnetInitialSpeed,
						forcedCollection = false,
					}
					xpNetwork:fire(candidate.player, "MagnetXP", id, candidate.player.UserId, drop.position, now)
				end
			end
		end
	end
	if #expiredIds > 0 then
		xpNetwork:fireAll("DespawnXP", expiredIds)
	end
end

function XPDropController.StealNearest(position: Vector3, radius: number, maximumCount: number): number
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" or type(maximumCount) ~= "number" then
		return 0
	end
	local candidates = {}
	for id, drop in drops do
		if next(drop.collections) == nil then
			local distance = (drop.position - position).Magnitude
			if distance <= radius then
				table.insert(candidates, { id = id, distance = distance })
			end
		end
	end
	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)
	local stolenValue = 0
	local removedIds = {}
	for index = 1, math.min(#candidates, math.max(math.floor(maximumCount), 0)) do
		local id = candidates[index].id
		local drop = drops[id]
		if drop then
			stolenValue += drop.value
			drops[id] = nil
			activeCount = math.max(activeCount - 1, 0)
			table.insert(removedIds, id)
		end
	end
	if #removedIds > 0 then
		xpNetwork:fireAll("DespawnXP", removedIds)
	end
	return stolenValue
end

function XPDropController.CollectAll(player: Player): number
	if player.Parent ~= Players or not getLiveRoot(player) then
		return 0
	end
	local collectedCount = 0
	local now = workspace:GetServerTimeNow()
	for _, drop in drops do
		if canCollect(drop, player) then
			drop.collections[player] = {
				position = drop.position,
				magnetSpeed = math.max(RunProgressionConfig.Pickups.XP.MagnetInitialSpeed * 5, 80),
				forcedCollection = true,
			}
			xpNetwork:fire(player, "MagnetXP", drop.id, player.UserId, drop.position, now)
			collectedCount += 1
		end
	end
	return collectedCount
end

function XPDropController.ClearAll()
	local ids = {}
	for id in drops do
		table.insert(ids, id)
	end
	table.clear(drops)
	activeCount = 0
	accumulator = 0
	if xpNetwork and #ids > 0 then
		xpNetwork:fireAll("DespawnXP", ids)
	end
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

function XPDropController.GetSnapshot(_, player: Player)
	local snapshot = {}
	for _, drop in drops do
		local collection = drop.collections[player]
		if canCollect(drop, player) or collection then
			table.insert(snapshot, {
				id = drop.id,
				value = drop.value,
				position = if collection then collection.position else drop.position,
				scale = getVisualScale(drop.value),
				ownerUserId = drop.ownerUserId,
				collectorUserId = if collection then player.UserId else nil,
			})
		end
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

function XPDropController.OnPlayerRemoving(player: Player)
	for id, drop in drops do
		drop.collections[player] = nil
		drop.eligibleUserIds[player.UserId] = nil
		drop.collectedUserIds[player.UserId] = nil
		if not hasRemainingCollectors(drop) then
			drops[id] = nil
			activeCount = math.max(activeCount - 1, 0)
		end
	end
end

return XPDropController
