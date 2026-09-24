local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local RageController = require(ServerStorage.Controllers.RageController)
local RunRewardsController = require(ServerStorage.Controllers.RunRewardsController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local ACTIVE_ABILITY_IDS = { "Fireball", "Lightning", "Boomerang" }
local SCHEDULER_INTERVAL = 0.08
local PROJECTILE_NETWORK_LEAD = 0.05
local BOOMERANG_RETURN_DISTANCE = 2.6
local BOOMERANG_HOMING_SPEED = 7

local ActiveWeapons = {}

local abilityNetwork
local getAbilityData
local simulationConnection: RBXScriptConnection?
local nextObjectId = 0
local nextScheduleAt = 0
local runtimes = {}
local projectiles = {}
local burns = {}
local burningGrounds = {}

local function nextId(): number
	nextObjectId += 1
	return nextObjectId
end

local function isEquipped(data, abilityId: string): boolean
	local equipped = type(data.Equipped) == "table" and data.Equipped.Weapon
	return type(equipped) == "table" and table.find(equipped, abilityId) ~= nil
end

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getHorizontalDistance(left: Vector3, right: Vector3): number
	local offset = left - right
	return Vector2.new(offset.X, offset.Z).Magnitude
end

local function getPointToSegmentDistance(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): number
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0.0001 then
		return (point - segmentStart).Magnitude
	end
	local alpha = math.clamp((point - segmentStart):Dot(segment) / lengthSquared, 0, 1)
	return (point - segmentStart:Lerp(segmentEnd, alpha)).Magnitude
end

local function damageZombie(player: Player, definition, stats, targetId: number, amount: number, origin: Vector3, knockback: number): boolean
	local rageMultiplier = if stats.IsRage then definition.Rage.KnockbackMultiplier or 1 else 1
	local damaged = ZombieController.DamageZombie(
		targetId,
		math.max(1, math.floor(amount + 0.5)),
		origin,
		knockback * rageMultiplier,
		{
			player = player,
			source = definition.Id,
			canApplyHitPassives = true,
		}
	)
	-- Damage remains authoritative even though projectile presentation is latency-compensated on clients.
	return damaged
end

local function removeBurn(targetId: number)
	if burns[targetId] then
		burns[targetId] = nil
		abilityNetwork:fireAll("FireballBurnEnded", targetId)
	end
end

local function applyBurn(player: Player, definition, stats, targetId: number, targetPosition: Vector3, now: number)
	if not stats.Burn then
		return
	end
	local existing = burns[targetId]
	if existing then
		-- Reapplication refreshes one authoritative burn instead of stacking unbounded tick loops.
		existing.expiresAt = now + stats.BurnDuration
		existing.damage = math.max(existing.damage, stats.BurnDamage)
		existing.player = player
		existing.stats = stats
		existing.lastPosition = targetPosition
	else
		burns[targetId] = {
			player = player,
			definition = definition,
			stats = stats,
			damage = stats.BurnDamage,
			nextTickAt = now + definition.Combat.Burn.TickInterval,
			expiresAt = now + stats.BurnDuration,
			lastPosition = targetPosition,
		}
	end
	abilityNetwork:fireAll("FireballBurnApplied", {
		targetId = targetId,
		duration = stats.BurnDuration,
		rage = stats.IsRage == true,
	})
end

local function removeGroundAt(index: number)
	local ground = burningGrounds[index]
	abilityNetwork:fireAll("FireballGroundRemoved", ground.id)
	table.remove(burningGrounds, index)
end

local function addBurningGround(player: Player, definition, stats, position: Vector3, now: number)
	if not stats.BurningGround then
		return
	end

	local ownedCount = 0
	local oldestIndex
	local oldestCreatedAt = math.huge
	for index, ground in burningGrounds do
		if ground.player == player then
			ownedCount += 1
			if ground.createdAt < oldestCreatedAt then
				oldestCreatedAt = ground.createdAt
				oldestIndex = index
			end
		end
	end
	if ownedCount >= definition.Combat.BurningGround.MaximumPerPlayer and oldestIndex then
		removeGroundAt(oldestIndex)
	end

	local ground = {
		id = nextId(),
		player = player,
		definition = definition,
		stats = stats,
		position = position,
		radius = stats.ExplosionRadius * definition.Combat.BurningGround.RadiusMultiplier,
		damage = stats.GroundDamage,
		createdAt = now,
		expiresAt = now + stats.GroundDuration,
		nextTickAt = now + definition.Combat.BurningGround.TickInterval,
	}
	table.insert(burningGrounds, ground)
	abilityNetwork:fireAll("FireballGroundCreated", {
		id = ground.id,
		ownerUserId = player.UserId,
		position = position,
		radius = ground.radius,
		duration = stats.GroundDuration,
		rage = stats.IsRage == true,
	})
end

local function explodeFireball(projectile, now: number)
	local definition = projectile.definition
	local stats = projectile.stats
	local position = projectile.position
	abilityNetwork:fireAll("FireballExploded", {
		id = projectile.id,
		position = position,
		radius = stats.ExplosionRadius,
		rage = stats.IsRage == true,
		empowered = stats.EmpoweredExplosion == true,
	})

	local targets = ZombieController.GetZombiesInRadius(
		position,
		stats.ExplosionRadius,
		definition.Combat.MaximumTargetsPerExplosion
	)
	for _, target in targets do
		local damage = stats.Damage
		if stats.CenterDamageMultiplier > 1
			and getHorizontalDistance(target.position, position)
				<= stats.ExplosionRadius * definition.Combat.EmpoweredExplosion.CenterRadiusRatio
		then
			damage *= stats.CenterDamageMultiplier
		end
		local knockback = definition.Combat.Knockback
		if stats.EmpoweredExplosion then
			knockback *= definition.Combat.EmpoweredExplosion.KnockbackMultiplier
		end
		if damageZombie(projectile.player, definition, stats, target.id, damage, position, knockback) then
			applyBurn(projectile.player, definition, stats, target.id, target.position, now)
		end
	end
	addBurningGround(projectile.player, definition, stats, position, now)
end

local function chooseFireballTargets(origin: Vector3, definition, stats)
	local candidates = ZombieController.GetNearestZombies(
		origin,
		definition.Combat.Range,
		definition.Combat.GroupSearchCandidates
	)
	if #candidates == 0 then
		return {}
	end

	for _, candidate in candidates do
		candidate.groupCount = 0
		for _, other in candidates do
			if getHorizontalDistance(candidate.position, other.position) <= stats.ExplosionRadius * 1.35 then
				candidate.groupCount += 1
			end
		end
	end
	table.sort(candidates, function(left, right)
		if left.groupCount == right.groupCount then
			return left.distance < right.distance
		end
		return left.groupCount > right.groupCount
	end)

	local targets = {}
	for _, candidate in candidates do
		local separated = true
		for _, selected in targets do
			if getHorizontalDistance(candidate.position, selected.position) < stats.ExplosionRadius * 1.25 then
				separated = false
				break
			end
		end
		if separated then
			table.insert(targets, candidate)
			if #targets >= stats.ProjectileCount then
				break
			end
		end
	end
	if #targets == 0 then
		table.insert(targets, candidates[1])
	end
	return targets
end

local function attackFireball(player: Player, _runtime, stats, root: BasePart): boolean
	local definition = AbilityDefinitions.ById.Fireball
	local origin = root.Position + Vector3.new(0, 1.8, 0)
	local targets = chooseFireballTargets(origin, definition, stats)
	if #targets == 0 then
		return false
	end

	local projectileSpeed = stats.ProjectileSpeed or definition.Combat.ProjectileSpeed
	for projectileIndex = 1, stats.ProjectileCount do
		local target = targets[(projectileIndex - 1) % #targets + 1]
		local centeredIndex = projectileIndex - (stats.ProjectileCount + 1) * 0.5
		local spreadRadians = math.rad(centeredIndex * definition.Combat.SpreadDegrees)
		local targetOffset = Vector3.new(math.sin(spreadRadians) * 1.6, 0, math.cos(spreadRadians) * 0.45)
		local targetPosition = target.position + targetOffset
		local startPosition = origin + root.CFrame.RightVector * centeredIndex * 0.7
		local meteor = stats.IsRage and projectileIndex % 2 == 0
		if meteor then
			startPosition = targetPosition
				+ Vector3.new(centeredIndex * 2.1, definition.Rage.MeteorHeight, -centeredIndex * 1.4)
		end
		local offset = targetPosition - startPosition
		local travelDistance = math.min(offset.Magnitude, definition.Combat.Range)
		local direction = if offset.Magnitude > 0.001 then offset.Unit else root.CFrame.LookVector
		local id = nextId()
		local projectile = {
			kind = "Fireball",
			id = id,
			player = player,
			definition = definition,
			stats = stats,
			position = startPosition,
			direction = direction,
			speed = projectileSpeed,
			travelled = 0,
			maximumDistance = travelDistance,
			hitRadius = math.max(0.9, stats.ProjectileScale * 1.2),
			launchAt = workspace:GetServerTimeNow() + PROJECTILE_NETWORK_LEAD,
		}
		table.insert(projectiles, projectile)
		abilityNetwork:fireAll("FireballSpawned", {
			id = id,
			ownerUserId = player.UserId,
			startPosition = startPosition,
			direction = direction,
			speed = projectileSpeed,
			maximumDistance = travelDistance,
			scale = stats.ProjectileScale,
			launchAt = projectile.launchAt,
			rage = stats.IsRage == true,
			meteor = meteor,
		})
	end
	return true
end

local function findNearestUnused(candidates, position: Vector3, maximumDistance: number, used, excluded)
	local nearest
	local nearestDistance = maximumDistance
	for _, candidate in candidates do
		if not used[candidate.id] and not excluded[candidate.id] then
			local distance = getHorizontalDistance(position, candidate.position)
			if distance <= nearestDistance then
				nearest = candidate
				nearestDistance = distance
			end
		end
	end
	return nearest
end

local function buildLightningChain(candidates, origin: Vector3, definition, stats, excluded)
	local used = {}
	local targets = {}
	local current = findNearestUnused(candidates, origin, definition.Combat.FirstTargetRange, used, excluded)
	while current and #targets < stats.MaximumTargets do
		table.insert(targets, current)
		used[current.id] = true
		current = findNearestUnused(candidates, current.position, stats.ChainRange, used, excluded)
	end
	return targets, used
end

local function attackLightning(player: Player, runtime, stats, root: BasePart): boolean
	local definition = AbilityDefinitions.ById.Lightning
	local origin = root.Position + Vector3.new(0, 2.2, 0)
	local poolRadius = definition.Combat.FirstTargetRange + stats.ChainRange * math.min(stats.MaximumTargets - 1, 4)
	local candidates = ZombieController.GetZombiesInRadius(origin, poolRadius, definition.Combat.MaximumCandidatePool)
	if #candidates == 0 then
		return false
	end

	runtime.castCounts.Lightning += 1
	local castNumber = runtime.castCounts.Lightning
	local chainCount = stats.ChainCount or 1
	if stats.TwinChains and castNumber % definition.Combat.TwinChainsEveryAttacks == 0 then
		chainCount = math.max(chainCount, 2)
	end
	local shouldFork = stats.Fork and castNumber % stats.ForkEveryAttacks == 0
	local excluded = {}
	local visualChains = {}
	local visualBranches = {}

	for chainIndex = 1, chainCount do
		local targets, used = buildLightningChain(candidates, origin, definition, stats, excluded)
		if #targets == 0 then
			break
		end
		local points = { origin }
		for targetIndex, target in targets do
			table.insert(points, target.position)
			excluded[target.id] = true
			local multiplier = if stats.Finisher and targetIndex == #targets
				then definition.Combat.FinisherDamageMultiplier
				else 1
			damageZombie(
				player,
				definition,
				stats,
				target.id,
				stats.Damage * multiplier,
				target.position + Vector3.new(0, 8, 0),
				definition.Combat.Knockback
			)
		end
		table.insert(visualChains, {
			points = points,
			fromAbove = stats.IsRage == true and chainIndex % 2 == 1,
		})

		if shouldFork and #targets >= 2 then
			local branchOrigin = targets[math.max(1, math.floor(#targets * 0.5))]
			local branchTarget = findNearestUnused(
				candidates,
				branchOrigin.position,
				stats.ChainRange * 0.9,
				used,
				excluded
			)
			if branchTarget then
				excluded[branchTarget.id] = true
				damageZombie(
					player,
					definition,
					stats,
					branchTarget.id,
					stats.Damage * definition.Combat.ForkDamageMultiplier,
					branchOrigin.position,
					definition.Combat.Knockback
				)
				table.insert(visualBranches, { branchOrigin.position, branchTarget.position })
			end
		end
	end

	if #visualChains == 0 then
		return false
	end
	abilityNetwork:fireAll("LightningCast", {
		ownerUserId = player.UserId,
		chains = visualChains,
		branches = visualBranches,
		rage = stats.IsRage == true,
		powerful = #visualChains > 1,
	})
	return true
end

local function attackBoomerang(player: Player, _runtime, stats, root: BasePart): boolean
	local definition = AbilityDefinitions.ById.Boomerang
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local target = ZombieController.GetNearestZombies(origin, stats.Range, 1)[1]
	if not target then
		return false
	end
	local baseDirection = target.position - origin
	baseDirection = Vector3.new(baseDirection.X, 0, baseDirection.Z)
	if baseDirection.Magnitude <= 0.001 then
		baseDirection = root.CFrame.LookVector
	else
		baseDirection = baseDirection.Unit
	end

	local fanWidth = definition.Combat.SpreadDegrees * (if stats.IsRage then 2 else 1)
	for projectileIndex = 1, stats.ProjectileCount do
		local alpha = if stats.ProjectileCount == 1 then 0.5 else (projectileIndex - 1) / (stats.ProjectileCount - 1)
		local angle = math.rad((alpha - 0.5) * fanWidth)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(baseDirection).Unit
		local id = nextId()
		local spawnedAt = workspace:GetServerTimeNow()
		local startPosition = origin
			+ root.CFrame.RightVector * (projectileIndex - (stats.ProjectileCount + 1) * 0.5) * 0.45
		table.insert(projectiles, {
			kind = "Boomerang",
			id = id,
			player = player,
			definition = definition,
			stats = stats,
			position = startPosition,
			direction = direction,
			phase = "Outward",
			phaseDistance = 0,
			outwardRange = stats.Range,
			turnElapsed = 0,
			turnSide = if projectileIndex % 2 == 0 then -1 else 1,
			outwardHits = {},
			returnHits = {},
			uniqueHits = {},
			didBonusLoop = false,
		})
		abilityNetwork:fireAll("BoomerangSpawned", {
			id = id,
			ownerUserId = player.UserId,
			startPosition = startPosition,
			direction = direction,
			range = stats.Range,
			outwardSpeed = definition.Combat.OutboundSpeed,
			returnSpeed = definition.Combat.OutboundSpeed * stats.ReturnSpeedMultiplier,
			turnDuration = definition.Combat.TurnDuration,
			turnRadius = math.max(1.2, stats.HitRadius),
			turnSide = if projectileIndex % 2 == 0 then -1 else 1,
			scale = stats.ProjectileScale,
			rage = stats.IsRage == true,
			serverTime = spawnedAt,
		})
	end
	return true
end

local ATTACKERS = {
	Fireball = attackFireball,
	Lightning = attackLightning,
	Boomerang = attackBoomerang,
}

local function updateFireball(projectile, deltaTime: number, now: number): boolean
	if projectile.player.Parent ~= Players then
		return false
	end
	if now < projectile.launchAt then
		return true
	end
	local remaining = projectile.maximumDistance - projectile.travelled
	local stepDistance = math.min(projectile.speed * deltaTime, remaining)
	local previousPosition = projectile.position
	local nextPosition = previousPosition + projectile.direction * stepDistance
	projectile.position = nextPosition
	projectile.travelled += stepDistance

	local midpoint = previousPosition:Lerp(nextPosition, 0.5)
	local candidates = ZombieController.GetZombiesInRadius(
		midpoint,
		stepDistance * 0.5 + projectile.hitRadius,
		6
	)
	for _, target in candidates do
		if getPointToSegmentDistance(target.position, previousPosition, nextPosition) <= projectile.hitRadius then
			explodeFireball(projectile, now)
			return false
		end
	end
	if remaining <= stepDistance + 0.001 then
		explodeFireball(projectile, now)
		return false
	end
	return true
end

local function hitBoomerangSegment(projectile, segmentStart: Vector3, segmentEnd: Vector3)
	local stats = projectile.stats
	local definition = projectile.definition
	local midpoint = segmentStart:Lerp(segmentEnd, 0.5)
	local segmentLength = (segmentEnd - segmentStart).Magnitude
	local candidates = ZombieController.GetZombiesInRadius(
		midpoint,
		segmentLength * 0.5 + stats.HitRadius,
		definition.Combat.MaximumHitsPerStep
	)
	local hitSet = if projectile.phase == "Return" then projectile.returnHits else projectile.outwardHits
	for _, target in candidates do
		if not hitSet[target.id]
			and getPointToSegmentDistance(target.position, segmentStart, segmentEnd) <= stats.HitRadius
		then
			hitSet[target.id] = true
			projectile.uniqueHits[target.id] = true
			local damageMultiplier = if projectile.phase == "Return" then stats.ReturnDamageMultiplier else 1
			local damaged = damageZombie(
				projectile.player,
				definition,
				stats,
				target.id,
				stats.Damage * damageMultiplier,
				segmentStart,
				definition.Combat.Knockback
			)
			if damaged then
				abilityNetwork:fireAll("BoomerangHit", {
					position = target.position,
					rage = stats.IsRage == true,
				})
			end
		end
	end
end

local function countKeys(values): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

local function sendBoomerangPhase(projectile, phase: string)
	abilityNetwork:fireAll("BoomerangPhaseChanged", {
		id = projectile.id,
		phase = phase,
		position = projectile.position,
		direction = projectile.direction,
		range = projectile.outwardRange,
		turnRadius = math.max(1.2, projectile.stats.HitRadius),
		serverTime = workspace:GetServerTimeNow(),
	})
end

local function updateBoomerang(projectile, deltaTime: number): boolean
	local root = getAliveRoot(projectile.player)
	if not root then
		abilityNetwork:fireAll("BoomerangEnded", projectile.id)
		return false
	end

	local definition = projectile.definition
	local previousPosition = projectile.position
	if projectile.phase == "Outward" then
		local remaining = projectile.outwardRange - projectile.phaseDistance
		local stepDistance = math.min(definition.Combat.OutboundSpeed * deltaTime, remaining)
		projectile.position += projectile.direction * stepDistance
		projectile.phaseDistance += stepDistance
		if remaining <= stepDistance + 0.001 then
			projectile.phase = "Turning"
			projectile.turnElapsed = 0
			projectile.turnStartPosition = projectile.position
			projectile.turnStartDirection = projectile.direction
			sendBoomerangPhase(projectile, "Turning")
		end
	elseif projectile.phase == "Turning" then
		projectile.turnElapsed = math.min(projectile.turnElapsed + deltaTime, definition.Combat.TurnDuration)
		local alpha = projectile.turnElapsed / definition.Combat.TurnDuration
		local angle = alpha * math.pi
		local radius = math.max(1.2, projectile.stats.HitRadius)
		local side = Vector3.new(-projectile.turnStartDirection.Z, 0, projectile.turnStartDirection.X)
			* projectile.turnSide
		projectile.position = projectile.turnStartPosition
			+ projectile.turnStartDirection * math.sin(angle) * radius
			+ side * (1 - math.cos(angle)) * radius
		if alpha >= 1 then
			projectile.phase = "Return"
			projectile.direction = -projectile.turnStartDirection
			sendBoomerangPhase(projectile, "Return")
		end
	else
		local targetPosition = root.Position + Vector3.new(0, 1.3, 0)
		local offset = targetPosition - projectile.position
		if offset.Magnitude <= BOOMERANG_RETURN_DISTANCE then
			local qualifiesForLoop = projectile.stats.BonusLoop
				and not projectile.didBonusLoop
				and countKeys(projectile.uniqueHits) >= projectile.stats.BonusLoopHits
			if qualifiesForLoop then
				projectile.didBonusLoop = true
				projectile.phase = "Outward"
				projectile.phaseDistance = 0
				projectile.outwardRange = projectile.stats.Range * definition.Combat.BonusLoopRangeMultiplier
				projectile.outwardHits = {}
				projectile.returnHits = {}
				projectile.direction = if projectile.direction.Magnitude > 0.001
					then projectile.direction.Unit
					else root.CFrame.LookVector
				sendBoomerangPhase(projectile, "BonusLoop")
				return true
			end
			abilityNetwork:fireAll("BoomerangEnded", projectile.id)
			return false
		end
		local desiredDirection = offset.Unit
		local turnAlpha = math.clamp(deltaTime * BOOMERANG_HOMING_SPEED, 0, 1)
		local blendedDirection = projectile.direction:Lerp(desiredDirection, turnAlpha)
		projectile.direction = if blendedDirection.Magnitude > 0.001 then blendedDirection.Unit else desiredDirection
		projectile.position += projectile.direction
			* definition.Combat.OutboundSpeed
			* projectile.stats.ReturnSpeedMultiplier
			* deltaTime
	end

	hitBoomerangSegment(projectile, previousPosition, projectile.position)
	return true
end

local function updateProjectiles(deltaTime: number, now: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local keep = if projectile.kind == "Fireball"
			then updateFireball(projectile, deltaTime, now)
			else updateBoomerang(projectile, deltaTime)
		if not keep then
			table.remove(projectiles, index)
		end
	end
end

local function updateBurns(now: number)
	for targetId, burn in burns do
		if now >= burn.expiresAt or burn.player.Parent ~= Players then
			removeBurn(targetId)
		elseif now >= burn.nextTickAt then
			burn.nextTickAt = now + burn.definition.Combat.Burn.TickInterval
			local position = ZombieController.GetZombiePosition(targetId)
			if not position then
				removeBurn(targetId)
			else
				burn.lastPosition = position
				if not damageZombie(burn.player, burn.definition, burn.stats, targetId, burn.damage, position, 0) then
					removeBurn(targetId)
				end
			end
		end
	end
end

local function updateBurningGrounds(now: number)
	for index = #burningGrounds, 1, -1 do
		local ground = burningGrounds[index]
		if now >= ground.expiresAt or ground.player.Parent ~= Players then
			removeGroundAt(index)
		elseif now >= ground.nextTickAt then
			ground.nextTickAt = now + ground.definition.Combat.BurningGround.TickInterval
			local targets = ZombieController.GetZombiesInRadius(
				ground.position,
				ground.radius,
				ground.definition.Combat.MaximumTargetsPerExplosion
			)
			for _, target in targets do
				damageZombie(
					ground.player,
					ground.definition,
					ground.stats,
					target.id,
					ground.damage,
					ground.position,
					0
				)
			end
		end
	end
end

local function cleanupAbility(player: Player, abilityId: string)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		if projectile.player == player and projectile.kind == abilityId then
			if projectile.kind == "Boomerang" then
				abilityNetwork:fireAll("BoomerangEnded", projectile.id)
			end
			table.remove(projectiles, index)
		end
	end
	if abilityId == "Fireball" then
		for targetId, burn in burns do
			if burn.player == player then
				removeBurn(targetId)
			end
		end
		for index = #burningGrounds, 1, -1 do
			if burningGrounds[index].player == player then
				removeGroundAt(index)
			end
		end
	end
	abilityNetwork:fireAll("AbilityEffectsCleared", player.UserId, abilityId)
end

local function updateSafeAreaBlocks(now: number)
	for player, runtime in runtimes do
		local blocked = RunRewardsController.IsInSafeArea(player)
		if blocked == runtime.safeAreaBlocked then
			continue
		end

		runtime.safeAreaBlocked = blocked
		if blocked then
			-- Entering the safe area cancels every owned projectile and lingering damage field before
			-- simulation can acquire another target. Loadout and normal cooldown state remain intact.
			for _, abilityId in ACTIVE_ABILITY_IDS do
				cleanupAbility(player, abilityId)
			end
		else
			for _, abilityId in ACTIVE_ABILITY_IDS do
				if runtime.equipped[abilityId] then
					runtime.nextAttackAt[abilityId] = math.min(runtime.nextAttackAt[abilityId], now + 0.05)
				end
			end
		end
	end
end

local function scheduleAttacks(now: number)
	for player, runtime in runtimes do
		if player.Parent ~= Players or runtime.safeAreaBlocked then
			continue
		end
		local data = getAbilityData(player)
		for _, abilityId in ACTIVE_ABILITY_IDS do
			local equipped = isEquipped(data, abilityId)
			if equipped and now >= runtime.nextAttackAt[abilityId] then
				local root = getAliveRoot(player)
				local definition = AbilityDefinitions.ById[abilityId]
				local level = data.Levels[abilityId] or 1
				local rageActive = RageController.IsActive(player)
				local stats = if rageActive then definition.GetRageStats(level) else definition.GetStats(level)
				local attacked = root ~= nil and ATTACKERS[abilityId](player, runtime, stats, root)
				runtime.nextAttackAt[abilityId] = now + (if attacked then stats.Cooldown else math.min(stats.Cooldown, 0.3))
			end
		end
	end
end

local function stepSimulation(deltaTime: number)
	local now = workspace:GetServerTimeNow()
	updateSafeAreaBlocks(now)
	updateProjectiles(math.min(deltaTime, 0.1), now)
	updateBurns(now)
	updateBurningGrounds(now)
	if now >= nextScheduleAt then
		nextScheduleAt = now + SCHEDULER_INTERVAL
		scheduleAttacks(now)
	end
end

function ActiveWeapons.Init(network, dataGetter)
	abilityNetwork = network
	getAbilityData = dataGetter
	nextScheduleAt = workspace:GetServerTimeNow()
	simulationConnection = RunService.Heartbeat:Connect(stepSimulation)
end

function ActiveWeapons.OnPlayerAdded(player: Player)
	local now = workspace:GetServerTimeNow()
	runtimes[player] = {
		nextAttackAt = {
			Fireball = now + 0.25,
			Lightning = now + 0.3,
			Boomerang = now + 0.35,
		},
		castCounts = {
			Lightning = 0,
		},
		equipped = {},
		safeAreaBlocked = RunRewardsController.IsInSafeArea(player),
	}
	ActiveWeapons.Refresh(player)
end

function ActiveWeapons.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local data = getAbilityData(player)
	for _, abilityId in ACTIVE_ABILITY_IDS do
		local equipped = isEquipped(data, abilityId)
		if runtime.equipped[abilityId] and not equipped then
			cleanupAbility(player, abilityId)
		end
		runtime.equipped[abilityId] = equipped
	end
end

function ActiveWeapons.ForceImmediate(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local now = workspace:GetServerTimeNow() + 0.05
	for _, abilityId in ACTIVE_ABILITY_IDS do
		if runtime.equipped[abilityId] then
			runtime.nextAttackAt[abilityId] = now
		end
	end
end

function ActiveWeapons.Restart(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	for _, abilityId in ACTIVE_ABILITY_IDS do
		cleanupAbility(player, abilityId)
		runtime.nextAttackAt[abilityId] = workspace:GetServerTimeNow() + 0.25
	end
	ActiveWeapons.Refresh(player)
end

function ActiveWeapons.OnPlayerRemoving(player: Player)
	if runtimes[player] then
		for _, abilityId in ACTIVE_ABILITY_IDS do
			cleanupAbility(player, abilityId)
		end
	end
	runtimes[player] = nil
end

return ActiveWeapons
