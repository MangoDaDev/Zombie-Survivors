local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local GetRandomFromWeightedTable =
	require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable).GetRandomFromWeightedTable
local ServerContext = require(script.Parent.ServerContext)
local ZombieAreas = require(ReplicatedStorage.Modules.Game.Zombies.ZombieAreas)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)
local Zombie = require(script.Parent.Zombie.Zombie)
local ZombieSeparation = require(script.Parent.Zombie.ZombieSeparation)

local MAX_SPAWN_ATTEMPTS = 12
local SEPARATION_INTERVAL = 0.05
local VARIATION_MINIMUM = 0.95
local VARIATION_MAXIMUM = 1.05

local ZombieController = {}
local zombieNetwork
local simulationConnection
local nextZombieId = 0
local nextSnapshotAt = 0
local separationAccumulator = 0
local random = Random.new()
local zombies = {}
local areaRuntime = {}
local groundOffsets = {}
local boundaryRadii = {}
local maximumBoundaryRadius = 0
local zombieDamaged = Signal.new()
local playerDamagedByZombie = Signal.new()

type DamageContext = {
	player: Player?,
	source: string?,
	canApplyHitPassives: boolean?,
	chainDepth: number?,
	chainState: any?,
}

local function onZombieDamagedPlayer(zombie, player: Player, actualDamage: number)
	-- This server-only signal carries the exact attacker and post-mitigation health loss to defensive passives.
	playerDamagedByZombie:Fire(player, zombie.id, zombie.cframe.Position, actualDamage)
end

local function createVariation()
	-- Independent subtle rolls prevent whole groups from sharing the same silhouette and cadence.
	return {
		Scale = random:NextNumber(VARIATION_MINIMUM, VARIATION_MAXIMUM),
		MoveSpeed = random:NextNumber(VARIATION_MINIMUM, VARIATION_MAXIMUM),
		TurnSpeed = random:NextNumber(VARIATION_MINIMUM, VARIATION_MAXIMUM),
		AnimationSpeed = random:NextNumber(VARIATION_MINIMUM, VARIATION_MAXIMUM),
	}
end

local function getLivePlayerCandidates()
	local candidates = {}
	local candidateLookup = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass "Humanoid"
		local root = character and character:FindFirstChild "HumanoidRootPart"
		if humanoid and humanoid.Health > 0 and root and root:IsA "BasePart" then
			local candidate = {
				player = player,
				humanoid = humanoid,
				position = root.Position,
			}
			table.insert(candidates, candidate)
			candidateLookup[player] = candidate
		end
	end

	return candidates, candidateLookup
end

local function isAwayFromPlayers(position, candidates, minimumDistance)
	for _, candidate in candidates do
		local offset = Vector3.new(position.X - candidate.position.X, 0, position.Z - candidate.position.Z)
		if offset.Magnitude < minimumDistance then
			return false
		end
	end

	return true
end

local function chooseGroupCenter(area, candidates)
	-- The largest scaled model footprint keeps every randomly yawed zombie wholly inside the area,
	-- including its very first replicated frame before the simulation has stepped.
	local halfSize = area.Size * 0.5 - Vector2.one * maximumBoundaryRadius * VARIATION_MAXIMUM
	for _ = 1, MAX_SPAWN_ATTEMPTS do
		local localPosition =
			Vector3.new(random:NextNumber(-halfSize.X, halfSize.X), 0, random:NextNumber(-halfSize.Y, halfSize.Y))
		local worldPosition = area.CFrame:PointToWorldSpace(localPosition)
		if isAwayFromPlayers(worldPosition, candidates, area.MinPlayerDistance) then
			return localPosition
		end
	end

	return nil
end

local function getGroupedSpawnPosition(area, groupCenter, candidates)
	local halfSize = area.Size * 0.5 - Vector2.one * maximumBoundaryRadius * VARIATION_MAXIMUM
	for _ = 1, MAX_SPAWN_ATTEMPTS do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(random:NextNumber()) * area.GroupRadius
		local localPosition = Vector3.new(
			math.clamp(groupCenter.X + math.cos(angle) * radius, -halfSize.X, halfSize.X),
			0,
			math.clamp(groupCenter.Z + math.sin(angle) * radius, -halfSize.Y, halfSize.Y)
		)
		local worldPosition = area.CFrame:PointToWorldSpace(localPosition)
		if isAwayFromPlayers(worldPosition, candidates, area.MinPlayerDistance) then
			return worldPosition
		end
	end

	return nil
end

local function createZombie(area, typeName, surfacePosition)
	local definition = ZombieDefinitions[typeName]
	local groundOffset = groundOffsets[typeName]
	local boundaryRadius = boundaryRadii[typeName]
	if not definition or not groundOffset or not boundaryRadius then
		return nil
	end

	nextZombieId += 1
	local variation = createVariation()
	local spawnPosition = surfacePosition + Vector3.yAxis * groundOffset * variation.Scale
	local spawnYaw = random:NextNumber(-math.pi, math.pi)
	local spawnCFrame = CFrame.new(spawnPosition) * CFrame.Angles(0, spawnYaw, 0)
	local zombie = Zombie.new(
		nextZombieId,
		typeName,
		definition,
		spawnCFrame,
		area,
		variation,
		boundaryRadius,
		onZombieDamagedPlayer
	)
	zombies[zombie.id] = zombie
	areaRuntime[area.Id].count += 1

	return zombie:GetSpawnPacket()
end

local function spawnGroup(area, candidates, serverTime)
	local runtime = areaRuntime[area.Id]
	local availableSlots = area.MaxZombies - runtime.count
	if availableSlots <= 0 then
		return
	end

	local groupCenter = chooseGroupCenter(area, candidates)
	if not groupCenter then
		return
	end

	local requestedSize = random:NextInteger(area.GroupSize.Min, area.GroupSize.Max)
	local groupSize = math.min(requestedSize, availableSlots)
	local spawnPackets = {}

	for _ = 1, groupSize do
		local surfacePosition = getGroupedSpawnPosition(area, groupCenter, candidates)
		if surfacePosition then
			local weightedType = GetRandomFromWeightedTable(area.ZombieWeights, "Weight", random)
			local packet = weightedType and createZombie(area, weightedType.Name, surfacePosition)
			if packet then
				table.insert(spawnPackets, packet)
			end
		end
	end

	if #spawnPackets > 0 then
		-- One timestamp per batch avoids repeating derivable interpolation metadata per zombie.
		zombieNetwork:fireAll("SpawnZombies", spawnPackets, serverTime)
	end
end

local function removeZombies(ids)
	local removedIds = {}
	for _, id in ids do
		local zombie = zombies[id]
		if zombie then
			zombies[id] = nil
			local runtime = areaRuntime[zombie.areaId]
			if runtime then
				runtime.count = math.max(runtime.count - 1, 0)
			end
			table.insert(removedIds, id)
		end
	end

	if #removedIds > 0 then
		zombieNetwork:fireAll("RemoveZombies", removedIds)
	end
end

local function buildGroundOffsets()
	local templates = ReplicatedStorage.Assets.Models.Zombies
	for typeName, definition in ZombieDefinitions do
		local template = templates:FindFirstChild(definition.AssetName)
		if template and template:IsA "Model" then
			local pivot = template:GetPivot()
			local boundingCFrame, boundingSize = template:GetBoundingBox()
			local localBoundingCFrame = pivot:ToObjectSpace(boundingCFrame)
			local authoredScale = template:GetScale()
			-- ZombieView uses ScaleTo with the variation as an absolute scale. Normalize Studio-authored
			-- template scale first so every type rests on the floor at its actual rendered size.
			groundOffsets[typeName] = -(localBoundingCFrame.Position.Y - boundingSize.Y * 0.5) / authoredScale
			-- A normalized horizontal bounding circle stays valid for every randomized spawn yaw and
			-- keeps the complete rendered model inside its assigned combat floor.
			local boundaryRadius = Vector2.new(boundingSize.X, boundingSize.Z).Magnitude * 0.5 / authoredScale
			boundaryRadii[typeName] = boundaryRadius
			maximumBoundaryRadius = math.max(maximumBoundaryRadius, boundaryRadius)
		else
			warn(string.format("Missing zombie model ReplicatedStorage.Assets.Models.Zombies.%s", definition.AssetName))
		end
	end
end

local function stepSimulation(deltaTime)
	local now = workspace:GetServerTimeNow()
	local candidates, candidateLookup = getLivePlayerCandidates()

	for _, area in ZombieAreas do
		local runtime = areaRuntime[area.Id]
		if now >= runtime.nextSpawnAt then
			runtime.nextSpawnAt = now + area.SpawnInterval
			-- Every configured floor stays populated while the run has a living player; player proximity
			-- must not silently disable distant spawn areas.
			if #candidates > 0 and runtime.count < area.MaxZombies then
				spawnGroup(area, candidates, now)
			end
		end
	end

	local deadIds = {}
	for id, zombie in zombies do
		zombie:Step(deltaTime, candidates, candidateLookup, now)
		if zombie:IsDead() then
			-- Simulator coin drops are archived; run rewards will be awarded by the future session flow.
			table.insert(deadIds, id)
		end
	end

	separationAccumulator += deltaTime
	if separationAccumulator >= SEPARATION_INTERVAL then
		ZombieSeparation.Apply(zombies, math.min(separationAccumulator, 0.1))
		separationAccumulator = 0
	end

	removeZombies(deadIds)

	if now >= nextSnapshotAt then
		nextSnapshotAt = now + ZombieProtocol.SnapshotInterval
		local updates = {}
		for _, zombie in zombies do
			table.insert(updates, zombie:GetUpdatePacket())
		end
		if #updates > 0 then
			zombieNetwork:fireAll("UpdateZombies", updates, now)
		end
	end
end

function ZombieController.GetSnapshot(_, _player)
	local now = workspace:GetServerTimeNow()
	local packets = {}
	for _, zombie in zombies do
		table.insert(packets, zombie:GetSpawnPacket())
	end

	return { now, packets }
end

function ZombieController.DamageZombie(
	id,
	amount,
	hitOrigin: Vector3?,
	knockbackImpulse: number?,
	damageContext: DamageContext?
)
	local zombie = zombies[id]
	local healthBefore = if zombie then zombie.health else 0
	local damaged = zombie ~= nil and zombie:TakeDamage(amount, hitOrigin, knockbackImpulse)
	if damaged then
		local actualDamage = math.max(healthBefore - zombie.health, 0)
		local killed = zombie:IsDead()
		local position = zombie.cframe.Position
		local direction = Vector3.zero
		if typeof(hitOrigin) == "Vector3" then
			local offset = zombie.cframe.Position - hitOrigin
			local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
			if horizontalOffset.Magnitude > 0.001 then
				direction = horizontalOffset.Unit
			end
		end
		-- Damage feedback is replicated immediately instead of waiting for the next movement snapshot.
		zombieNetwork:fireAll(
			"ZombieDamaged",
			id,
			zombie.health,
			zombie.definition.MaxHealth,
			direction,
			knockbackImpulse or 0
		)
		-- Every authored damage source reports through this one server pipeline so kill credit and hit
		-- passives cannot be forged by clients or accidentally applied twice by individual abilities.
		zombieDamaged:Fire(id, position, actualDamage, killed, damageContext)
		return true, killed
	end
	return false, false
end

function ZombieController.GetZombieDamagedSignal()
	return zombieDamaged
end

function ZombieController.GetPlayerDamagedByZombieSignal()
	return playerDamagedByZombie
end

function ZombieController.GetZombiesInRadius(position: Vector3, maximumDistance: number, maximumCount: number?)
	local candidates = {}
	local countLimit = maximumCount or math.huge
	for id, zombie in zombies do
		if not zombie:IsDead() then
			local zombiePosition = zombie.cframe.Position
			local offset = zombiePosition - position
			-- Orbiting weapons operate around the player's ground plane; a generous vertical check avoids
			-- missing visually intersecting zombies on small slopes without turning this into global damage.
			if math.abs(offset.Y) <= 7 and Vector2.new(offset.X, offset.Z).Magnitude <= maximumDistance then
				table.insert(candidates, {
					id = id,
					position = zombiePosition,
				})
				if #candidates >= countLimit then
					break
				end
			end
		end
	end
	return candidates
end

function ZombieController.GetZombiePosition(id: number): Vector3?
	local zombie = zombies[id]
	return if zombie and not zombie:IsDead() then zombie.cframe.Position else nil
end

function ZombieController.GetNearestZombies(position: Vector3, maximumDistance: number, maximumCount: number)
	local candidates = {}
	for id, zombie in zombies do
		if not zombie:IsDead() then
			local distance = (zombie.cframe.Position - position).Magnitude
			if distance <= maximumDistance then
				table.insert(candidates, {
					id = id,
					position = zombie.cframe.Position,
					distance = distance,
				})
			end
		end
	end
	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)
	for index = #candidates, maximumCount + 1, -1 do
		table.remove(candidates, index)
	end
	return candidates
end

function ZombieController.Init()
	zombieNetwork = Networker.server.new("ZombieController", ZombieController, {
		ZombieController.GetSnapshot,
	})
	if ServerContext.IsLobbyServer() then
		-- Keep the read-only network endpoint available to the shared client bootstrap, but do not
		-- build spawn state or connect simulation in a lobby server. No zombie can be created here.
		return
	end

	buildGroundOffsets()
	for _, area in ZombieAreas do
		areaRuntime[area.Id] = {
			count = 0,
			nextSpawnAt = workspace:GetServerTimeNow() + random:NextNumber(0.5, area.SpawnInterval),
		}
	end

	nextSnapshotAt = workspace:GetServerTimeNow() + ZombieProtocol.SnapshotInterval
	simulationConnection = RunService.Heartbeat:Connect(stepSimulation)
end

return ZombieController
