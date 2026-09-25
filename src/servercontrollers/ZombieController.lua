local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local GetRandomFromWeightedTable =
	require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable).GetRandomFromWeightedTable
local ServerContext = require(script.Parent.ServerContext)
local MapController = require(script.Parent.MapController)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local ZombieAreas = require(ReplicatedStorage.Modules.Game.Zombies.ZombieAreas)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)
local Zombie = require(script.Parent.Zombie.Zombie)
local ZombieSeparation = require(script.Parent.Zombie.ZombieSeparation)

local SEPARATION_INTERVAL = 0.05
local VARIATION_MINIMUM = 0.95
local VARIATION_MAXIMUM = 1.05
local TAU = math.pi * 2

local ZombieController = {}
local zombieNetwork
local simulationConnection
local contextChangedConnection
local nextZombieId = 0
local nextSnapshotAt = 0
local separationAccumulator = 0
local random = Random.new()
local zombies = {}
local areaRuntime = {}
local groundOffsets = {}
local boundaryRadii = {}
local maximumBoundaryRadius = 0
local pendingSpawnRequests = {}
local pendingProjectiles = {}
local runStartedAt = 0
local firstZombieSpawnedAt: number? = nil
local zombieDamaged = Signal.new()
local zombieDied = Signal.new()
local playerDamagedByZombie = Signal.new()
local firstZombieSpawned = Signal.new()

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

local function createVariation(definition)
	-- Independent subtle rolls prevent whole groups from sharing the same silhouette and cadence.
	return {
		Scale = definition.ModelScale * random:NextNumber(VARIATION_MINIMUM, VARIATION_MAXIMUM),
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
				root = root,
				position = root.Position,
				velocity = root.AssemblyLinearVelocity,
				lookVector = root.CFrame.LookVector,
			}
			table.insert(candidates, candidate)
			candidateLookup[player] = candidate
		end
	end

	return candidates, candidateLookup
end

local function broadcastAbility(packet)
	zombieNetwork:fireAll("ZombieAbility", packet)
end

local function damagePlayersInRadius(attacker, position, radius, damage)
	local candidates = getLivePlayerCandidates()
	for _, candidate in candidates do
		local offset = candidate.position - position
		if math.abs(offset.Y) <= 8 and Vector2.new(offset.X, offset.Z).Magnitude <= radius then
			attacker:DamagePlayer(candidate, damage)
		end
	end
end

local damageZombieInternal

local function damageZombiesInRadius(excludedId, position, radius, damage)
	for id, target in zombies do
		if id ~= excludedId and not target:IsDead() then
			local offset = target.cframe.Position - position
			if math.abs(offset.Y) <= 8 and Vector2.new(offset.X, offset.Z).Magnitude <= radius then
				damageZombieInternal(id, damage, position, 0, { source = "Bomber" })
			end
		end
	end
end

local function healZombiesInRadius(excludedId, position, radius, amount)
	for id, target in zombies do
		if id ~= excludedId and not target:IsDead() and (target.cframe.Position - position).Magnitude <= radius then
			target.health = math.min(target.health + amount, target.maximumHealth)
		end
	end
end

local function queueSpawn(typeName, position, area)
	if ZombieDefinitions[typeName] then
		table.insert(pendingSpawnRequests, {
			typeName = typeName,
			position = Vector3.new(position.X, area.CFrame.Position.Y, position.Z),
			area = area,
		})
	end
end

local function launchProjectile(attacker, targetPosition, speed, impactRadius, damage)
	local origin = attacker.cframe.Position + Vector3.yAxis * 2
	local distance = (targetPosition - origin).Magnitude
	local duration = math.clamp(distance / speed, 0.2, 1.5)
	table.insert(pendingProjectiles, {
		attacker = attacker,
		targetPosition = targetPosition,
		impactRadius = impactRadius,
		damage = damage,
		impactAt = workspace:GetServerTimeNow() + duration,
	})
	broadcastAbility({
		Kind = "Projectile",
		Origin = origin,
		Target = targetPosition,
		Duration = duration,
		Color = attacker.definition.TintColor,
	})
end

local zombieServices = {
	Random = random,
	OnPlayerDamaged = onZombieDamagedPlayer,
	BroadcastAbility = broadcastAbility,
	DamagePlayersInRadius = damagePlayersInRadius,
	DamageZombiesInRadius = damageZombiesInRadius,
	HealZombiesInRadius = healZombiesInRadius,
	QueueSpawn = queueSpawn,
	LaunchProjectile = launchProjectile,
}

local function isAwayFromPlayers(position, candidates, minimumDistance)
	for _, candidate in candidates do
		local offset = Vector3.new(position.X - candidate.position.X, 0, position.Z - candidate.position.Z)
		if offset.Magnitude < minimumDistance then
			return false
		end
	end

	return true
end

local function isInsideArea(area, position: Vector3): boolean
	local localPosition = area.CFrame:PointToObjectSpace(position)
	local halfSize = area.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Y
		and math.abs(localPosition.Y) <= 20
end

local function findGroundPosition(area, worldPosition: Vector3, candidates)
	local activeMap = MapController.GetActiveMap()
	if not activeMap then
		return nil
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { activeMap }
	local result = workspace:Raycast(
		Vector3.new(worldPosition.X, area.CFrame.Position.Y + 45, worldPosition.Z),
		Vector3.new(0, -90, 0),
		raycastParams
	)
	if not result or result.Normal.Y < 0.65 then
		return nil
	end
	local surfacePosition = result.Position
	if not isInsideArea(area, surfacePosition)
		or not isAwayFromPlayers(surfacePosition, candidates, math.max(area.MinPlayerDistance, RunProgressionConfig.Spawning.MinimumDistance))
	then
		return nil
	end
	return surfacePosition
end

local function getTravelDirection(candidate): Vector3
	local horizontalVelocity = Vector3.new(candidate.velocity.X, 0, candidate.velocity.Z)
	if horizontalVelocity.Magnitude >= RunProgressionConfig.Spawning.MovementHeadingSpeedThreshold then
		return horizontalVelocity.Unit
	end
	local horizontalFacing = Vector3.new(candidate.lookVector.X, 0, candidate.lookVector.Z)
	return if horizontalFacing.Magnitude > 0.001 then horizontalFacing.Unit else Vector3.zAxis
end

local function chooseGroupCenter(area, candidates, areaCandidates)
	local halfSize = area.Size * 0.5 - Vector2.one * maximumBoundaryRadius * VARIATION_MAXIMUM
	local spawnConfig = RunProgressionConfig.Spawning
	local distanceRange = spawnConfig.PreferredDistance
	local runtime = areaRuntime[area.Id]
	local sectorCount = spawnConfig.SurroundSectorCount
	local sector = runtime and runtime.nextSurroundSector or random:NextInteger(0, sectorCount - 1)
	if runtime then
		-- The advance is coprime with eight sectors, so every direction is visited before repeating.
		runtime.nextSurroundSector = (sector + spawnConfig.SurroundSectorAdvance) % sectorCount
	end
	local surroundAngle = TAU * sector / sectorCount
	-- Decide once per group so each horde has a coherent approach: some intercept movement while
	-- the rest rotate around the player through every surrounding sector.
	local preferForward = random:NextNumber() < spawnConfig.ForwardSpawnChance
	local directedAttempts = math.floor(spawnConfig.AttemptsPerGroup * spawnConfig.DirectedSpawnAttemptFraction)
	for attempt = 1, RunProgressionConfig.Spawning.AttemptsPerGroup do
		local anchor = areaCandidates[random:NextInteger(1, #areaCandidates)]
		local direction
		if attempt <= directedAttempts then
			if preferForward then
				local heading = getTravelDirection(anchor)
				local coneRadians = math.rad(spawnConfig.ForwardSpawnConeDegrees)
				local yawOffset = random:NextNumber(-coneRadians, coneRadians)
				direction = CFrame.fromAxisAngle(Vector3.yAxis, yawOffset):VectorToWorldSpace(heading)
			else
				local jitter = math.rad(spawnConfig.SurroundSpawnJitterDegrees)
				local angle = surroundAngle + random:NextNumber(-jitter, jitter)
				direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			end
		else
			-- Relax the requested direction after repeated failures near floor edges so spawning never stalls.
			local angle = random:NextNumber(0, TAU)
			direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		local distance = random:NextNumber(distanceRange.Min, distanceRange.Max)
		local desired = anchor.position + direction * distance
		local localPosition = area.CFrame:PointToObjectSpace(desired)
		local clampedLocal = Vector3.new(
			math.clamp(localPosition.X, -halfSize.X, halfSize.X),
			0,
			math.clamp(localPosition.Z, -halfSize.Y, halfSize.Y)
		)
		local groundPosition = findGroundPosition(area, area.CFrame:PointToWorldSpace(clampedLocal), candidates)
		if groundPosition then
			return groundPosition
		end
	end
	return nil
end

local function getGroupedSpawnPosition(area, groupCenter, candidates)
	local halfSize = area.Size * 0.5 - Vector2.one * maximumBoundaryRadius * VARIATION_MAXIMUM
	for _ = 1, RunProgressionConfig.Spawning.AttemptsPerGroup do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(random:NextNumber()) * area.GroupRadius
		local centerLocal = area.CFrame:PointToObjectSpace(groupCenter)
		local localPosition = Vector3.new(
			math.clamp(centerLocal.X + math.cos(angle) * radius, -halfSize.X, halfSize.X),
			0,
			math.clamp(centerLocal.Z + math.sin(angle) * radius, -halfSize.Y, halfSize.Y)
		)
		local worldPosition = area.CFrame:PointToWorldSpace(localPosition)
		local groundPosition = findGroundPosition(area, worldPosition, candidates)
		if groundPosition then
			return groundPosition
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
	local variation = createVariation(definition)
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
		zombieServices
	)
	-- Summons and split offspring can originate beside a boundary; constrain before their first packet.
	zombie:_constrainToArea()
	zombies[zombie.id] = zombie
	areaRuntime[area.Id].count += 1
	if not firstZombieSpawnedAt then
		-- Start survival timing on the first successful authoritative spawn, after map/character loading.
		firstZombieSpawnedAt = workspace:GetServerTimeNow()
		firstZombieSpawned:Fire(firstZombieSpawnedAt)
	end

	return zombie:GetSpawnPacket()
end

local function getPressure(areaPlayerCount: number, now: number)
	local config = RunProgressionConfig.Spawning
	-- Match the visible survival timer: pressure begins rising only after the first zombie actually spawns.
	local pressureStartedAt = firstZombieSpawnedAt or runStartedAt
	local difficultySteps = math.max((now - pressureStartedAt) / config.DifficultyStepSeconds, 0)
	local elapsedMultiplier = 1 + difficultySteps * config.SpawnRateIncreasePerStep
	local playerMultiplier = math.max(areaPlayerCount, 1) ^ config.PlayerCountExponent
	-- The interval eventually reaches its safe floor, but unbounded group growth and threat weighting
	-- continue increasing total difficulty forever while retaining players ^ 0.8 party scaling.
	local rateMultiplier = elapsedMultiplier * playerMultiplier
	return rateMultiplier, difficultySteps
end

local function chooseZombieType(area, difficultySteps: number)
	local highestThreatLevel = 1
	for _, weightedType in area.ZombieWeights do
		local definition = ZombieDefinitions[weightedType.Name]
		if definition then
			highestThreatLevel = math.max(highestThreatLevel, definition.ThreatLevel or 1)
		end
	end

	local biasBase = 1 + difficultySteps * RunProgressionConfig.Spawning.StrongZombieBiasPerStep
	local adjustedWeights = {}
	for _, weightedType in area.ZombieWeights do
		local definition = ZombieDefinitions[weightedType.Name]
		if definition then
			local threatLevel = definition.ThreatLevel or 1
			-- Divide weaker entries instead of exponentiating stronger entries upward. This keeps weights
			-- numerically stable during extremely long runs while continually favoring higher threats.
			local threatGap = highestThreatLevel - threatLevel
			table.insert(adjustedWeights, {
				Name = weightedType.Name,
				Weight = weightedType.Weight / biasBase ^ threatGap,
			})
		end
	end

	return GetRandomFromWeightedTable(adjustedWeights, "Weight", random)
end

local function spawnGroup(area, candidates, areaCandidates, serverTime, difficultySteps)
	local groupCenter = chooseGroupCenter(area, candidates, areaCandidates)
	if not groupCenter then
		return
	end

	-- Additive growth is intentionally unbounded: every completed difficulty step permanently raises
	-- the possible horde size, including in the opening area that starts with single-zombie hordes.
	local groupSizeBonus = math.floor(difficultySteps * RunProgressionConfig.Spawning.GroupSizeBonusPerStep + 0.001)
	local maximumGroupSize = math.max(area.GroupSize.Min, area.GroupSize.Max + groupSizeBonus)
	local requestedSize = random:NextInteger(area.GroupSize.Min, maximumGroupSize)
	local groupSize = requestedSize
	local spawnPackets = {}
	-- Roll once per natural horde so its silhouette and behavior stay coherent; special summons remain separate.
	local weightedType = chooseZombieType(area, difficultySteps)
	if not weightedType then
		return
	end

	for _ = 1, groupSize do
		local surfacePosition = getGroupedSpawnPosition(area, groupCenter, candidates)
		if surfacePosition then
			local packet = createZombie(area, weightedType.Name, surfacePosition)
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
			maximumBoundaryRadius = math.max(maximumBoundaryRadius, boundaryRadius * definition.ModelScale)
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
		local areaCandidates = {}
		for _, candidate in candidates do
			if isInsideArea(area, candidate.position) then
				table.insert(areaCandidates, candidate)
			end
		end
		local rateMultiplier, difficultySteps = getPressure(#areaCandidates, now)
		if now >= runtime.nextSpawnAt then
			runtime.nextSpawnAt = now
				+ math.max(area.SpawnInterval / math.max(rateMultiplier, 1), RunProgressionConfig.Spawning.MinimumSpawnInterval)
			-- Only occupied combat floors spawn enemies; each group is placed around one of that floor's
			-- living players instead of silently filling remote areas they cannot currently interact with.
			if #areaCandidates > 0 then
				spawnGroup(area, candidates, areaCandidates, now, difficultySteps)
			end
		end
	end

	local deadIds = {}
	for id, zombie in zombies do
		zombie:Step(deltaTime, candidates, candidateLookup, now)
		if zombie:IsDead() then
			zombie:OnDeath()
			-- One central death event feeds pickups now and leaves a stable extension point for challenges later.
			zombieDied:Fire({
				id = zombie.id,
				typeName = zombie.typeName,
				definition = zombie.definition,
				position = zombie.cframe.Position,
				groundY = zombie.area.CFrame.Position.Y,
				killer = zombie.lastDamager,
				damageSource = zombie.lastDamageSource,
			})
			table.insert(deadIds, id)
		end
	end

	for index = #pendingProjectiles, 1, -1 do
		local projectile = pendingProjectiles[index]
		if now >= projectile.impactAt then
			damagePlayersInRadius(
				projectile.attacker,
				projectile.targetPosition,
				projectile.impactRadius,
				projectile.damage
			)
			broadcastAbility({
				Kind = "Impact",
				Position = projectile.targetPosition,
				Radius = projectile.impactRadius,
				Color = projectile.attacker.definition.TintColor,
			})
			table.remove(pendingProjectiles, index)
		end
	end

	separationAccumulator += deltaTime
	if separationAccumulator >= SEPARATION_INTERVAL then
		ZombieSeparation.Apply(zombies, math.min(separationAccumulator, 0.1))
		separationAccumulator = 0
	end

	removeZombies(deadIds)

	if #pendingSpawnRequests > 0 then
		local spawnPackets = {}
		for _, request in pendingSpawnRequests do
			local runtime = areaRuntime[request.area.Id]
			if runtime then
				local packet = createZombie(request.area, request.typeName, request.position)
				if packet then
					table.insert(spawnPackets, packet)
				end
			end
		end
		table.clear(pendingSpawnRequests)
		if #spawnPackets > 0 then
			zombieNetwork:fireAll("SpawnZombies", spawnPackets, now)
		end
	end

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

damageZombieInternal = function(
	id,
	amount,
	hitOrigin: Vector3?,
	knockbackImpulse: number?,
	damageContext: DamageContext?
)
	local zombie = zombies[id]
	local healthBefore = if zombie then zombie.health else 0
	local damaged = zombie ~= nil
		and zombie:TakeDamage(amount, hitOrigin, knockbackImpulse, damageContext, workspace:GetServerTimeNow())
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
			zombie.maximumHealth,
			direction,
			knockbackImpulse or 0
		)
		-- Armor, shields, and dodges consume the authoritative hit but must not trigger on-damage passives.
		if actualDamage > 0 then
			zombieDamaged:Fire(id, position, actualDamage, killed, damageContext)
		end
		return true, killed
	end
	return false, false
end

function ZombieController.DamageZombie(
	id,
	amount,
	hitOrigin: Vector3?,
	knockbackImpulse: number?,
	damageContext: DamageContext?
)
	return damageZombieInternal(id, amount, hitOrigin, knockbackImpulse, damageContext)
end

function ZombieController.GetZombieDamagedSignal()
	return zombieDamaged
end

function ZombieController.GetZombieDiedSignal()
	return zombieDied
end

function ZombieController.GetPlayerDamagedByZombieSignal()
	return playerDamagedByZombie
end

function ZombieController.GetFirstZombieSpawnedSignal()
	return firstZombieSpawned
end

function ZombieController.GetFirstZombieSpawnedAt(): number?
	return firstZombieSpawnedAt
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

local function startSimulation()
	if simulationConnection then
		return
	end
	buildGroundOffsets()
	runStartedAt = workspace:GetServerTimeNow()
	for _, area in ZombieAreas do
		areaRuntime[area.Id] = {
			count = 0,
			-- Start each combat floor in a random sector, then deterministically cover all eight directions.
			nextSurroundSector = random:NextInteger(0, RunProgressionConfig.Spawning.SurroundSectorCount - 1),
			-- The first group arrives promptly; later groups use the normal area cadence and pressure scaling.
			nextSpawnAt = workspace:GetServerTimeNow() + random:NextNumber(0.25, math.min(area.SpawnInterval, 0.8)),
		}
	end

	nextSnapshotAt = workspace:GetServerTimeNow() + ZombieProtocol.SnapshotInterval
	simulationConnection = RunService.Heartbeat:Connect(stepSimulation)
end

function ZombieController.Init()
	zombieNetwork = Networker.server.new("ZombieController", ZombieController, {
		ZombieController.GetSnapshot,
	})
	if ServerContext.IsGameServer() then
		startSimulation()
	elseif RunService:IsStudio() then
		-- Studio can promote the one local server into the fake destination after this controller initializes.
		contextChangedConnection = ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				startSimulation()
				contextChangedConnection:Disconnect()
				contextChangedConnection = nil
			end
		end)
	end
end

return ZombieController
