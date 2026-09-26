local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local ClassController = require(ServerStorage.Controllers.ClassController)
local RageController = require(ServerStorage.Controllers.RageController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local ZombieController = require(ServerStorage.Controllers.ZombieController)
local CombatTargets = require(script.Parent.CombatTargets)
local PassiveEffects = require(script.Parent.PassiveEffects)

local ACTIVE_ABILITY_IDS = { "Aura", "Ball", "Drill", "Mine", "Poison" }
local SCHEDULER_INTERVAL = 0.08
local PROJECTILE_NETWORK_LEAD = 0.05

local CrowdWeapons = {}

local abilityNetwork
local getAbilityData
local simulationConnection: RBXScriptConnection?
local nextObjectId = 0
local nextScheduleAt = 0
local random = Random.new()
local runtimes = {}
local projectiles = {}
local mines = {}
local puddles = {}

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

local function horizontalDirection(vector: Vector3): Vector3?
	local flattened = Vector3.new(vector.X, 0, vector.Z)
	return if flattened.Magnitude > 0.001 then flattened.Unit else nil
end

local function horizontalDistance(left: Vector3, right: Vector3): number
	local offset = left - right
	return Vector2.new(offset.X, offset.Z).Magnitude
end

local function pointToSegmentDistance(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): number
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0.0001 then
		return (point - segmentStart).Magnitude
	end
	local alpha = math.clamp((point - segmentStart):Dot(segment) / lengthSquared, 0, 1)
	return (point - segmentStart:Lerp(segmentEnd, alpha)).Magnitude
end

local function damageTarget(player: Player, definition, stats, target, amount: number, origin: Vector3, knockback: number)
	local rageMultiplier = if stats.IsRage then definition.Rage.KnockbackMultiplier or 1 else 1
	return CombatTargets.DamageTarget(target, math.max(1, math.floor(amount + 0.5)), origin, knockback * rageMultiplier, {
		player = player,
		source = definition.Id,
		canApplyHitPassives = true,
	})
end

local function getGroundPosition(player: Player, proposedPosition: Vector3, height: number, depth: number): Vector3?
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local origin = proposedPosition + Vector3.yAxis * height
	local result = Workspace:Raycast(origin, Vector3.new(0, -(height + depth), 0), raycastParams)
	return result and result.Position or nil
end

local function countOwned(list, player: Player): (number, number?)
	local count = 0
	local oldestIndex
	local oldestCreatedAt = math.huge
	for index, object in list do
		if object.player == player then
			count += 1
			if object.createdAt < oldestCreatedAt then
				oldestCreatedAt = object.createdAt
				oldestIndex = index
			end
		end
	end
	return count, oldestIndex
end

local function countOwnedProjectiles(player: Player, kind: string): number
	local count = 0
	for _, projectile in projectiles do
		if projectile.player == player and projectile.kind == kind then
			count += 1
		end
	end
	return count
end

local function sendAuraState(player: Player, runtime, stats, root: BasePart?, force: boolean?)
	local visible = root ~= nil and runtime.equipped.Aura == true
	local signature = if visible
		then string.format("%.3f:%s", stats.Radius, tostring(stats.IsRage == true))
		else "hidden"
	if not force and runtime.auraSignature == signature then
		return
	end
	runtime.auraSignature = signature
	abilityNetwork:fireAll("AuraState", {
		ownerUserId = player.UserId,
		enabled = visible,
		radius = if visible then stats.Radius else 0,
		rage = visible and stats.IsRage == true,
	})
end

local function attackAura(player: Player, runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Aura
	local targets = CombatTargets.GetDamageablesInRadius(
		root.Position,
		stats.Radius,
		definition.Combat.MaximumTargetsPerTick
	)
	local hitPositions = {}
	for _, target in targets do
		if damageTarget(player, definition, stats, target, stats.Damage, root.Position, definition.Combat.Knockback) then
			table.insert(hitPositions, target.position)
		end
	end
	if #hitPositions > 0 then
		abilityNetwork:fireAll("AuraHit", {
			ownerUserId = player.UserId,
			positions = hitPositions,
			rage = stats.IsRage == true,
		})
	end

	if stats.PulseInterval and now >= runtime.nextAuraPulseAt then
		local pulseRadius = stats.Radius * stats.PulseRadiusMultiplier
		local pulseTargets = CombatTargets.GetDamageablesInRadius(
			root.Position,
			pulseRadius,
			definition.Combat.MaximumTargetsPerTick
		)
		for _, target in pulseTargets do
			damageTarget(
				player,
				definition,
				stats,
				target,
				stats.Damage * stats.PulseDamageMultiplier,
				root.Position,
				definition.Combat.Knockback
			)
		end
		abilityNetwork:fireAll("AuraPulse", {
			ownerUserId = player.UserId,
			position = root.Position,
			radius = pulseRadius,
			rage = stats.IsRage == true,
		})
		runtime.nextAuraPulseAt = now + stats.PulseInterval
	end
	return true
end

local function selectBallTarget(position: Vector3, range: number, hitTargets, previousTargetId: number?)
	local candidates = CombatTargets.GetNearestHostiles(position, range, 35)
	for _, candidate in candidates do
		if not hitTargets[candidate.id] then
			return candidate
		end
	end
	for _, candidate in candidates do
		if candidate.id ~= previousTargetId then
			return candidate
		end
	end
	return candidates[1]
end

local function endProjectile(projectile)
	abilityNetwork:fireAll(projectile.kind .. "Ended", projectile.id)
end

local function spawnBall(player: Player, stats, origin: Vector3, target, ballIndex: number, now: number)
	local id = nextId()
	local startPosition = origin + Vector3.new(0, 1.35 + (ballIndex - 1) * 0.18, 0)
	local direction = horizontalDirection(target.position - startPosition) or Vector3.zAxis
	local projectile = {
		kind = "Ball",
		id = id,
		player = player,
		definition = AbilityDefinitions.ById.Ball,
		stats = stats,
		bounceRange = AbilityDefinitions.ById.Ball.Combat.BounceRange * ClassController.GetProjectileRangeMultiplier(player),
		position = startPosition,
		targetPosition = target.position,
		targetId = target.id,
		direction = direction,
		hitTargets = {},
		hitCount = 0,
		uniqueHitStreak = 0,
		createdAt = now,
		missExpiresAt = nil,
	}
	table.insert(projectiles, projectile)
	abilityNetwork:fireAll("BallSpawned", {
		id = id,
		ownerUserId = player.UserId,
		startPosition = startPosition,
		targetPosition = target.position,
		speed = stats.Speed,
		scale = stats.Scale,
		launchAt = now + PROJECTILE_NETWORK_LEAD,
		rage = stats.IsRage == true,
	})
end

local function attackBall(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Ball
	if countOwnedProjectiles(player, "Ball") >= stats.MaximumActive then
		return false
	end
	local origin = root.Position
	local candidates = CombatTargets.GetNearestHostiles(
		origin,
		definition.Combat.TargetRange * ClassController.GetProjectileRangeMultiplier(player),
		math.max(stats.BallCount * 3, 8)
	)
	if #candidates == 0 then
		return false
	end
	for ballIndex = 1, stats.BallCount do
		if countOwnedProjectiles(player, "Ball") >= stats.MaximumActive then
			break
		end
		local target = candidates[(ballIndex - 1) % #candidates + 1]
		spawnBall(player, stats, origin, target, ballIndex, now)
	end
	return true
end

local function spawnDrill(player: Player, stats, root: BasePart, direction: Vector3, lateralOffset: number, now: number)
	local definition = AbilityDefinitions.ById.Drill
	local id = nextId()
	local startPosition = root.Position + Vector3.new(0, 1.35, 0) + direction * 2.5 + root.CFrame.RightVector * lateralOffset
	local projectile = {
		kind = "Drill",
		id = id,
		player = player,
		definition = definition,
		stats = stats,
		position = startPosition,
		direction = direction,
		travelled = 0,
		hitTargets = {},
	}
	table.insert(projectiles, projectile)
	abilityNetwork:fireAll("DrillSpawned", {
		id = id,
		ownerUserId = player.UserId,
		startPosition = startPosition,
		direction = direction,
		speed = stats.Speed,
		range = stats.Range,
		width = stats.Width,
		launchAt = now + PROJECTILE_NETWORK_LEAD,
		rage = stats.IsRage == true,
	})
end

local function attackDrill(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	-- Direction is captured exactly once so turning or network lag can never redirect an existing Drill.
	local facing = horizontalDirection(root.CFrame.LookVector)
	if not facing then
		return false
	end
	local right = Vector3.new(-facing.Z, 0, facing.X)
	for drillIndex = 1, stats.DrillCount do
		local centeredIndex = drillIndex - (stats.DrillCount + 1) * 0.5
		local angle = math.rad(centeredIndex * stats.SpreadDegrees)
		local direction = (facing * math.cos(angle) + right * math.sin(angle)).Unit
		local lateralOffset = if stats.DrillCount == 2 then centeredIndex * stats.Width * 0.85 else centeredIndex * stats.Width * 0.45
		spawnDrill(player, stats, root, direction, lateralOffset, now)
	end
	return true
end

local function removeMineAt(index: number)
	local mine = mines[index]
	abilityNetwork:fireAll("MineRemoved", mine.id)
	table.remove(mines, index)
end

local function makeRoomForMine(player: Player, maximumActive: number)
	local count, oldestIndex = countOwned(mines, player)
	if count >= maximumActive and oldestIndex then
		removeMineAt(oldestIndex)
	end
end

local function placeMine(player: Player, stats, position: Vector3, now: number)
	makeRoomForMine(player, stats.MaximumActive)
	local mine = {
		id = nextId(),
		player = player,
		definition = AbilityDefinitions.ById.Mine,
		stats = stats,
		position = position,
		createdAt = now,
		expiresAt = now + (stats.Lifetime or AbilityDefinitions.ById.Mine.Combat.Lifetime),
		triggerAt = nil,
	}
	table.insert(mines, mine)
	abilityNetwork:fireAll("MinePlaced", {
		id = mine.id,
		ownerUserId = player.UserId,
		position = position,
		radius = stats.Radius,
		triggerRadius = stats.TriggerRadius,
		rage = stats.IsRage == true,
	})
end

local function attackMine(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Mine
	local back = horizontalDirection(-root.CFrame.LookVector) or Vector3.zAxis
	local right = Vector3.new(-back.Z, 0, back.X)
	local placed = false
	for mineIndex = 1, stats.MineCount do
		local centeredIndex = mineIndex - (stats.MineCount + 1) * 0.5
		local proposed = root.Position
			+ back * (definition.Combat.PlacementBackDistance + math.abs(centeredIndex) * 0.4)
			+ right * centeredIndex * 2.4
		local groundPosition = getGroundPosition(
			player,
			proposed,
			definition.Combat.GroundRayHeight,
			definition.Combat.GroundRayDepth
		)
		if groundPosition then
			placeMine(player, stats, groundPosition + Vector3.yAxis * 0.28, now)
			placed = true
		end
	end
	return placed
end

local function removePuddleAt(index: number)
	local puddle = puddles[index]
	abilityNetwork:fireAll("PoisonRemoved", puddle.id)
	table.remove(puddles, index)
end

local function makeRoomForPuddle(player: Player, maximumActive: number)
	local count, oldestIndex = countOwned(puddles, player)
	if count >= maximumActive and oldestIndex then
		removePuddleAt(oldestIndex)
	end
end

local function createPuddle(player: Player, stats, position: Vector3, now: number, secondary: boolean)
	local definition = AbilityDefinitions.ById.Poison
	makeRoomForPuddle(player, stats.MaximumActive)
	local spread = definition.Combat.Spread
	local radius = stats.Radius * (if secondary then spread.RadiusMultiplier else 1)
	local duration = stats.Duration * (if secondary then spread.DurationMultiplier else 1)
	local damage = stats.Damage * (if secondary then spread.DamageMultiplier else 1)
	local puddle = {
		id = nextId(),
		player = player,
		definition = definition,
		stats = stats,
		position = position,
		radius = radius,
		damage = damage,
		secondary = secondary,
		createdAt = now,
		expiresAt = now + duration,
		nextTickAt = now + stats.TickInterval,
	}
	table.insert(puddles, puddle)
	abilityNetwork:fireAll("PoisonCreated", {
		id = puddle.id,
		ownerUserId = player.UserId,
		position = position,
		radius = radius,
		duration = duration,
		secondary = secondary,
		rage = stats.IsRage == true,
	})
end

local function choosePoisonTargets(origin: Vector3, stats, range: number)
	local candidates = CombatTargets.GetNearestHostiles(origin, range, 30)
	local selected = {}
	for _, candidate in candidates do
		local separated = true
		for _, existing in selected do
			if horizontalDistance(candidate.position, existing.position) < stats.Radius * 1.35 then
				separated = false
				break
			end
		end
		if separated then
			table.insert(selected, candidate)
			if #selected >= stats.PuddleCount then
				break
			end
		end
	end
	return selected
end

local function attackPoison(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Poison
	local targets = choosePoisonTargets(root.Position, stats, definition.Combat.TargetRange)
	if #targets == 0 then
		return false
	end
	local created = false
	for _, target in targets do
		local groundPosition = getGroundPosition(
			player,
			target.position,
			definition.Combat.GroundRayHeight,
			definition.Combat.GroundRayDepth
		)
		if groundPosition then
			createPuddle(player, stats, groundPosition + Vector3.yAxis * 0.08, now, false)
			created = true
		end
	end
	return created
end

local ATTACKERS = {
	Aura = attackAura,
	Ball = attackBall,
	Drill = attackDrill,
	Mine = attackMine,
	Poison = attackPoison,
}

local function updateBall(projectile, deltaTime: number, now: number): boolean
	if projectile.player.Parent ~= Players or not getAliveRoot(projectile.player) then
		endProjectile(projectile)
		return false
	end
	if projectile.missExpiresAt then
		projectile.position += projectile.direction * projectile.stats.Speed * deltaTime
		if now >= projectile.missExpiresAt then
			endProjectile(projectile)
			return false
		end
		return true
	end

	local offset = projectile.targetPosition - projectile.position
	local stepDistance = projectile.stats.Speed * deltaTime
	if offset.Magnitude > stepDistance + projectile.stats.HitRadius then
		projectile.direction = offset.Unit
		projectile.position += projectile.direction * stepDistance
		return true
	end

	projectile.position = projectile.targetPosition
	projectile.hitCount += 1
	local wasNewTarget = not projectile.hitTargets[projectile.targetId]
	projectile.hitTargets[projectile.targetId] = true
	-- A repeat target breaks Trickshot's consecutive-unique ricochet streak.
	projectile.uniqueHitStreak = if wasNewTarget then projectile.uniqueHitStreak + 1 else 0
	local targetPosition = ZombieController.GetZombiePosition(projectile.targetId)
	if targetPosition then
		local multiplier = 1
		if wasNewTarget then
			multiplier += math.min((projectile.hitCount - 1) * projectile.stats.PowerBouncePerHit,
				projectile.stats.PowerBounceCap)
			multiplier += math.min((projectile.uniqueHitStreak - 1) * (projectile.stats.ClassUniqueRicochetDamage or 0),
				projectile.stats.ClassUniqueRicochetCap or 0)
		end
		damageTarget(
			projectile.player,
			projectile.definition,
			projectile.stats,
			{ id = projectile.targetId, kind = "Zombie", key = projectile.targetId },
			projectile.stats.Damage * multiplier,
			projectile.position,
			projectile.definition.Combat.Knockback
		)
	end
	abilityNetwork:fireAll("BallHit", {
		id = projectile.id,
		position = projectile.position,
		rage = projectile.stats.IsRage == true,
	})

	if projectile.hitCount >= projectile.stats.BounceCount then
		endProjectile(projectile)
		return false
	end
	local nextTarget = selectBallTarget(
		projectile.position,
		projectile.bounceRange,
		projectile.hitTargets,
		projectile.targetId
	)
	if not nextTarget then
		projectile.missExpiresAt = now + projectile.definition.Combat.MissLifetime
		projectile.targetPosition = projectile.position
			+ projectile.direction * projectile.stats.Speed * projectile.definition.Combat.MissLifetime
		abilityNetwork:fireAll("BallRedirected", {
			id = projectile.id,
			position = projectile.position,
			targetPosition = projectile.targetPosition,
			serverTime = now,
		})
		return true
	end
	projectile.targetId = nextTarget.id
	projectile.targetPosition = nextTarget.position
	projectile.direction = horizontalDirection(nextTarget.position - projectile.position) or projectile.direction
	abilityNetwork:fireAll("BallRedirected", {
		id = projectile.id,
		position = projectile.position,
		targetPosition = projectile.targetPosition,
		serverTime = now,
	})
	return true
end

local function updateDrill(projectile, deltaTime: number): boolean
	if projectile.player.Parent ~= Players or not getAliveRoot(projectile.player) then
		endProjectile(projectile)
		return false
	end
	local previousPosition = projectile.position
	local stepDistance = math.min(projectile.stats.Speed * deltaTime, projectile.stats.Range - projectile.travelled)
	projectile.position += projectile.direction * stepDistance
	projectile.travelled += stepDistance
	local center = previousPosition:Lerp(projectile.position, 0.5)
	local queryRadius = stepDistance * 0.5 + projectile.stats.Width
	local candidates = CombatTargets.GetDamageablesInRadius(
		center,
		queryRadius,
		projectile.definition.Combat.MaximumTargets
	)
	for _, target in candidates do
		if not projectile.hitTargets[target.key]
			and pointToSegmentDistance(target.position, previousPosition, projectile.position) <= projectile.stats.Width
		then
			projectile.hitTargets[target.key] = true
			damageTarget(
				projectile.player,
				projectile.definition,
				projectile.stats,
				target,
				projectile.stats.Damage,
				previousPosition,
				projectile.definition.Combat.Knockback
			)
			abilityNetwork:fireAll("DrillHit", {
				position = target.position,
				rage = projectile.stats.IsRage == true,
			})
		end
	end
	if projectile.travelled >= projectile.stats.Range then
		endProjectile(projectile)
		return false
	end
	return true
end

local function updateProjectiles(deltaTime: number, now: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local keep = if projectile.kind == "Ball"
			then updateBall(projectile, deltaTime, now)
			else updateDrill(projectile, deltaTime)
		if not keep then
			table.remove(projectiles, index)
		end
	end
end

local function explodeMine(index: number, now: number)
	local mine = mines[index]
	local definition = mine.definition
	local stats = mine.stats
	abilityNetwork:fireAll("MineExploded", {
		id = mine.id,
		position = mine.position,
		radius = stats.Radius,
		rage = stats.IsRage == true,
	})
	local targets = CombatTargets.GetDamageablesInRadius(
		mine.position,
		stats.Radius,
		definition.Combat.MaximumTargetsPerExplosion
	)
	for _, target in targets do
		damageTarget(mine.player, definition, stats, target, stats.Damage, mine.position, definition.Combat.Knockback)
	end

	if stats.ChainUnlocked then
		local chainIndex = 0
		for _, other in mines do
			if other ~= mine
				and other.player == mine.player
				and not other.triggerAt
				and horizontalDistance(other.position, mine.position) <= definition.Combat.Chain.Radius
			then
				chainIndex += 1
				other.triggerAt = now + definition.Combat.Chain.Stagger * chainIndex
				abilityNetwork:fireAll("MineTriggered", {
					id = other.id,
					fuseDuration = definition.Combat.Chain.Stagger * chainIndex,
				})
			end
		end
	end
	table.remove(mines, index)
end

local function updateMines(now: number)
	for index = #mines, 1, -1 do
		local mine = mines[index]
		if mine.player.Parent ~= Players or not getAliveRoot(mine.player) or now >= mine.expiresAt then
			removeMineAt(index)
		elseif mine.triggerAt and now >= mine.triggerAt then
			explodeMine(index, now)
		elseif not mine.triggerAt then
			local target = CombatTargets.GetHostilesInRadius(mine.position, mine.stats.TriggerRadius, 1)[1]
			if target then
				mine.triggerAt = now + mine.stats.FuseDuration
				abilityNetwork:fireAll("MineTriggered", {
					id = mine.id,
					fuseDuration = mine.stats.FuseDuration,
				})
			end
		end
	end
end

local function updatePuddles(now: number)
	for index = #puddles, 1, -1 do
		local puddle = puddles[index]
		if puddle.player.Parent ~= Players or not getAliveRoot(puddle.player) or now >= puddle.expiresAt then
			removePuddleAt(index)
		elseif now >= puddle.nextTickAt then
			puddle.nextTickAt = now + puddle.stats.TickInterval
			local targets = CombatTargets.GetDamageablesInRadius(
				puddle.position,
				puddle.radius,
				puddle.definition.Combat.MaximumTargetsPerTick
			)
			local spreadCreated = false
			for _, target in targets do
				local _, killed = damageTarget(
					puddle.player,
					puddle.definition,
					puddle.stats,
					target,
					puddle.damage,
					puddle.position,
					puddle.definition.Combat.Knockback
				)
				if target.kind == "Zombie" then
					local slowMultiplier, slowDuration = ClassController.GetAfflictionSlow(puddle.player)
					if slowMultiplier then ZombieController.SlowZombie(target.id, slowMultiplier, slowDuration) end
				end
				if killed
					and target.kind == "Zombie"
					and not puddle.secondary
					and not spreadCreated
					and puddle.stats.SpreadUnlocked
					and random:NextNumber(0, 100) <= puddle.stats.SpreadChancePercent
				then
					local groundPosition = getGroundPosition(
						puddle.player,
						target.position,
						puddle.definition.Combat.GroundRayHeight,
						puddle.definition.Combat.GroundRayDepth
					)
					if groundPosition then
						-- Secondary fields are explicitly marked so their kills cannot recurse into more Poison.
						createPuddle(puddle.player, puddle.stats, groundPosition + Vector3.yAxis * 0.08, now, true)
						spreadCreated = true
					end
				end
			end
		end
	end
end

local function cleanupAbility(player: Player, abilityId: string)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		if projectile.player == player and projectile.kind == abilityId then
			endProjectile(projectile)
			table.remove(projectiles, index)
		end
	end
	if abilityId == "Mine" then
		for index = #mines, 1, -1 do
			if mines[index].player == player then
				removeMineAt(index)
			end
		end
	elseif abilityId == "Poison" then
		for index = #puddles, 1, -1 do
			if puddles[index].player == player then
				removePuddleAt(index)
			end
		end
	elseif abilityId == "Aura" then
		local runtime = runtimes[player]
		if runtime then
			runtime.auraSignature = nil
		end
	end
	abilityNetwork:fireAll("AbilityEffectsCleared", player.UserId, abilityId)
end

local function scheduleAttacks(now: number)
	if ServerContext.IsLobbyServer() then
		return
	end
	for player, runtime in runtimes do
		if player.Parent ~= Players then
			continue
		end
		local data = getAbilityData(player)
		local root = getAliveRoot(player)
		for _, abilityId in ACTIVE_ABILITY_IDS do
			if not runtime.equipped[abilityId] then
				continue
			end
			local definition = AbilityDefinitions.ById[abilityId]
			local level = data.Levels[abilityId] or 1
			local rageActive = RageController.IsActive(player)
			local stats = if rageActive then definition.GetRageStats(level) else definition.GetStats(level)
			ClassController.ApplyWeaponStats(player, abilityId, stats)
			stats = PassiveEffects.ModifyWeaponStats(player, abilityId, stats)
			if abilityId == "Aura" then
				sendAuraState(player, runtime, stats, root)
			end
			if root and now >= runtime.nextAttackAt[abilityId] then
				local attacked = ATTACKERS[abilityId](player, runtime, stats, root, now)
				runtime.nextAttackAt[abilityId] = now + (if attacked
					then stats.Cooldown * PassiveEffects.GetCooldownMultiplier(player)
					else math.min(stats.Cooldown, 0.3))
			end
		end
	end
end

local function stepSimulation(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	updateProjectiles(math.min(deltaTime, 0.1), now)
	if now >= nextScheduleAt then
		nextScheduleAt = now + SCHEDULER_INTERVAL
		updateMines(now)
		updatePuddles(now)
		scheduleAttacks(now)
	end
end

function CrowdWeapons.Init(network, dataGetter)
	abilityNetwork = network
	getAbilityData = dataGetter
	nextScheduleAt = Workspace:GetServerTimeNow()
	simulationConnection = RunService.Heartbeat:Connect(stepSimulation)
end

function CrowdWeapons.OnPlayerAdded(player: Player)
	local now = Workspace:GetServerTimeNow()
	runtimes[player] = {
		nextAttackAt = {
			Aura = now + 0.15,
			Ball = now + 0.25,
			Drill = now + 0.3,
			Mine = now + 0.35,
			Poison = now + 0.4,
		},
		nextAuraPulseAt = now + AbilityDefinitions.ById.Aura.Combat.Pulse.Interval,
		equipped = {},
		auraSignature = nil,
	}
	CrowdWeapons.Refresh(player)
end

function CrowdWeapons.Refresh(player: Player)
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
	if runtime.equipped.Aura then
		local definition = AbilityDefinitions.ById.Aura
		local stats = if RageController.IsActive(player)
			then definition.GetRageStats(data.Levels.Aura or 1)
			else definition.GetStats(data.Levels.Aura or 1)
		stats = PassiveEffects.ModifyWeaponStats(player, "Aura", stats)
		sendAuraState(player, runtime, stats, getAliveRoot(player), true)
	end
end

function CrowdWeapons.ForceImmediate(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local now = Workspace:GetServerTimeNow() + 0.05
	for _, abilityId in ACTIVE_ABILITY_IDS do
		if runtime.equipped[abilityId] then
			runtime.nextAttackAt[abilityId] = now
		end
	end
	runtime.nextAuraPulseAt = now
	runtime.auraSignature = nil
end

function CrowdWeapons.Restart(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, abilityId in ACTIVE_ABILITY_IDS do
		cleanupAbility(player, abilityId)
		runtime.nextAttackAt[abilityId] = now + 0.25
	end
	runtime.nextAuraPulseAt = now + AbilityDefinitions.ById.Aura.Combat.Pulse.Interval
	CrowdWeapons.Refresh(player)
end

function CrowdWeapons.OnPlayerRemoving(player: Player)
	if runtimes[player] then
		for _, abilityId in ACTIVE_ABILITY_IDS do
			cleanupAbility(player, abilityId)
		end
	end
	runtimes[player] = nil
end

return CrowdWeapons
