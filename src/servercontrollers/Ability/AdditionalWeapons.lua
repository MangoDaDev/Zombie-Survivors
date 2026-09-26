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

local ABILITY_IDS = { "Shotgun", "FrostNova", "Meteor", "Turret", "Vortex" }
local SCHEDULER_INTERVAL = 0.08
local FROST_GROUND_INTERVAL = 0.16

local AdditionalWeapons = {}

local abilityNetwork
local getAbilityData
local simulationConnection: RBXScriptConnection?
local runtimes = {}
local novaWaves = {}
local meteors = {}
local turrets = {}
local vortexes = {}
local frozenGrounds = {}
local chilled = {}
local nextObjectId = 0
local nextScheduleAt = 0

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
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function horizontalDistance(left: Vector3, right: Vector3): number
	local offset = left - right
	return Vector2.new(offset.X, offset.Z).Magnitude
end

local function pointToSegmentDistanceXZ(point: Vector3, startPosition: Vector3, endPosition: Vector3): (number, number)
	local a = Vector2.new(startPosition.X, startPosition.Z)
	local b = Vector2.new(endPosition.X, endPosition.Z)
	local p = Vector2.new(point.X, point.Z)
	local segment = b - a
	local lengthSquared = segment:Dot(segment)
	local alpha = if lengthSquared > 0.0001 then math.clamp((p - a):Dot(segment) / lengthSquared, 0, 1) else 0
	return (p - a:Lerp(b, alpha)).Magnitude, alpha
end

local function getGroundPosition(player: Player, position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = Workspace:Raycast(position + Vector3.yAxis * 8, Vector3.new(0, -26, 0), params)
	return result and result.Position or nil
end

local function damageTarget(player: Player, abilityId: string, stats, target, amount: number, origin: Vector3, knockback: number)
	local definition = AbilityDefinitions.ById[abilityId]
	return CombatTargets.DamageTarget(target, amount, origin,
		knockback * (if stats.IsRage and definition.Rage then definition.Rage.KnockbackMultiplier or 1 else 1), {
			player = player,
			source = abilityId,
			canApplyHitPassives = true,
		})
end

local function chooseGroupTargets(origin: Vector3, range: number, radius: number, count: number)
	local candidates = CombatTargets.GetNearestHostiles(origin, range, 40)
	for _, candidate in candidates do
		local score = 0
		for _, other in candidates do
			if horizontalDistance(candidate.position, other.position) <= radius then
				score += 1
			end
		end
		candidate.groupScore = score
	end
	table.sort(candidates, function(left, right)
		return if left.groupScore == right.groupScore then left.distance < right.distance else left.groupScore > right.groupScore
	end)
	local selected = {}
	for _, candidate in candidates do
		local separated = true
		for _, previous in selected do
			if horizontalDistance(candidate.position, previous.position) < radius * 1.25 then
				separated = false
				break
			end
		end
		if separated then
			table.insert(selected, candidate)
			if #selected >= count then
				break
			end
		end
	end
	return selected
end

local function fireShotgunBlast(player: Player, runtime, stats, root: BasePart, damageMultiplier: number): boolean
	local definition = AbilityDefinitions.ById.Shotgun
	local origin = root.Position + Vector3.yAxis * 1.45
	local target = chooseGroupTargets(origin, stats.Range, 8, 1)[1]
	if not target then
		return false
	end
	local aim = target.position - origin
	local horizontal = Vector3.new(aim.X, 0, aim.Z)
	local direction = if horizontal.Magnitude > 0.001 then horizontal.Unit else root.CFrame.LookVector
	local candidates = CombatTargets.GetDamageablesInRadius(origin, stats.Range, definition.Combat.MaximumCandidates)
	local endpoints = {}
	local hitCounts = {}
	for pelletIndex = 1, stats.Pellets do
		local fraction = if stats.Pellets == 1 then 0 else (pelletIndex - 1) / (stats.Pellets - 1) - 0.5
		local angle = math.rad(fraction * stats.SpreadDegrees)
		local pelletDirection = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(direction).Unit
		local endPosition = origin + pelletDirection * stats.Range
		local hits = {}
		for _, candidate in candidates do
			local distance, alpha = pointToSegmentDistanceXZ(candidate.position, origin, endPosition)
			if distance <= stats.PelletRadius + (candidate.radius or 0) then
				table.insert(hits, { target = candidate, alpha = alpha })
			end
		end
		table.sort(hits, function(left, right) return left.alpha < right.alpha end)
		local maximumHits = if stats.Pierce then 2 else 1
		for index = 1, math.min(#hits, maximumHits) do
			local hit = hits[index]
			if damageTarget(player, "Shotgun", stats, hit.target,
				stats.Damage * damageMultiplier * (if index == 2 then 0.7 else 1), origin,
				definition.Combat.Knockback) then
				endPosition = if index == maximumHits or index == #hits then hit.target.position else endPosition
				if hit.target.kind == "Zombie" then
					hitCounts[hit.target.id] = (hitCounts[hit.target.id] or 0) + 1
				end
			end
		end
		table.insert(endpoints, endPosition)
	end
	if stats.Stagger then
		for zombieId, hits in hitCounts do
			if hits >= 3 then
				ZombieController.SlowZombie(zombieId, 0, 0.22)
			end
		end
	end
	abilityNetwork:fireAll("ShotgunFired", {
		ownerUserId = player.UserId, origin = origin, endpoints = endpoints,
		pelletRadius = stats.PelletRadius,
		rage = stats.IsRage == true, second = damageMultiplier < 1,
	})
	return true
end

local function attackShotgun(player: Player, runtime, stats, root: BasePart): boolean
	if not fireShotgunBlast(player, runtime, stats, root, 1) then
		return false
	end
	if stats.SecondBlast then
		local token = runtime.token
		task.delay(AbilityDefinitions.ById.Shotgun.Combat.SecondBlastDelay, function()
			if runtimes[player] ~= runtime or runtime.token ~= token or not runtime.equipped.Shotgun then
				return
			end
			local currentRoot = getAliveRoot(player)
			if currentRoot then
				fireShotgunBlast(player, runtime, stats, currentRoot, stats.SecondDamageMultiplier)
			end
		end)
	end
	return true
end

local function addNovaWave(player: Player, stats, center: Vector3, radiusMultiplier: number, damageMultiplier: number, now: number)
	local wave = {
		id = nextId(), player = player, stats = stats, center = center,
		radius = stats.Radius * radiusMultiplier, damage = stats.Damage * damageMultiplier,
		startedAt = now, previousRadius = 0, hit = {},
	}
	table.insert(novaWaves, wave)
	abilityNetwork:fireAll("FrostNovaStarted", {
		id = wave.id, ownerUserId = player.UserId, position = center,
		radius = wave.radius, duration = AbilityDefinitions.ById.FrostNova.Combat.WaveDuration,
		startedAt = now, rage = stats.IsRage == true,
	})
end

local function attackFrostNova(player: Player, runtime, stats, root: BasePart, now: number): boolean
	local center = root.Position
	addNovaWave(player, stats, center, 1, 1, now)
	if stats.Aftershock or stats.DoubleWave then
		local token = runtime.token
		task.delay(0.26, function()
			if runtimes[player] == runtime and runtime.token == token and runtime.equipped.FrostNova and getAliveRoot(player) then
				addNovaWave(player, stats, center,
					if stats.DoubleWave then 1 else 0.72,
					if stats.DoubleWave then 0.8 else 0.55,
					Workspace:GetServerTimeNow())
			end
		end)
	end
	return true
end

local function updateNovaWaves(now: number)
	local definition = AbilityDefinitions.ById.FrostNova
	for index = #novaWaves, 1, -1 do
		local wave = novaWaves[index]
		local alpha = math.clamp((now - wave.startedAt) / definition.Combat.WaveDuration, 0, 1)
		local currentRadius = wave.radius * alpha
		local targets = CombatTargets.GetDamageablesInRadius(wave.center, currentRadius + 2, definition.Combat.MaximumTargets)
		for _, target in targets do
			local distance = horizontalDistance(target.position, wave.center)
			if not wave.hit[target.key] and distance >= wave.previousRadius - 2 and distance <= currentRadius + 2 then
				wave.hit[target.key] = true
				local damaged = damageTarget(wave.player, "FrostNova", wave.stats, target,
					wave.damage, wave.center, definition.Combat.Knockback)
				if damaged and target.kind == "Zombie" then
					local prior = chilled[target.id]
					local repeatHit = prior and prior.player == wave.player and prior.expiresAt > now
					local resistant = (target.threatLevel or 0) >= 4
					if repeatHit and (wave.stats.FreezeOnRepeat or wave.stats.DoubleWave) and not resistant then
						ZombieController.SlowZombie(target.id, 0, 0.55)
					else
						ZombieController.SlowZombie(target.id,
							if resistant then math.max(0.35, wave.stats.ChillMultiplier - 0.1) else wave.stats.ChillMultiplier,
							wave.stats.ChillDuration)
					end
					chilled[target.id] = {
						player = wave.player, expiresAt = now + wave.stats.ChillDuration,
						shatter = wave.stats.Shatter,
					}
				end
			end
		end
		wave.previousRadius = currentRadius
		if alpha >= 1 then
			if wave.stats.FrozenGround then
				table.insert(frozenGrounds, {
					player = wave.player, center = wave.center, radius = wave.radius,
					expiresAt = now + 2.5, nextTickAt = now,
				})
				abilityNetwork:fireAll("FrostGroundCreated", {
					ownerUserId = wave.player.UserId, position = wave.center,
					radius = wave.radius, duration = 2.5,
				})
			end
			table.remove(novaWaves, index)
		end
	end
end

local function updateFrozenGround(now: number)
	for index = #frozenGrounds, 1, -1 do
		local ground = frozenGrounds[index]
		if now >= ground.expiresAt or ground.player.Parent ~= Players then
			table.remove(frozenGrounds, index)
		elseif now >= ground.nextTickAt then
			ground.nextTickAt = now + FROST_GROUND_INTERVAL
			for _, target in CombatTargets.GetHostilesInRadius(ground.center, ground.radius + 0.8, 45) do
				if math.abs(horizontalDistance(target.position, ground.center) - ground.radius) <= 1.5 then
					ZombieController.SlowZombie(target.id, 0.7, 0.35)
				end
			end
		end
	end
end

local function onZombieDamaged(id, position, _damage, killed, context)
	local chill = chilled[id]
	if not chill then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if killed or now >= chill.expiresAt then
		chilled[id] = nil
		return
	end
	if chill.shatter and type(context) == "table" and context.player == chill.player
		and context.source ~= "FrostNova" and context.source ~= "FrostShatter"
	then
		chilled[id] = nil
		ZombieController.DamageZombie(id, math.max(1, math.floor(_damage * 0.35 + 0.5)), position, 0, {
			player = chill.player, source = "FrostShatter", canApplyHitPassives = false,
		})
		abilityNetwork:fireAll("FrostShattered", { position = position })
	end
end

local function scheduleMeteor(player: Player, stats, position: Vector3, impactAt: number, damageMultiplier: number, radiusMultiplier: number, castHits)
	local strike = {
		id = nextId(), player = player, stats = stats, position = position,
		impactAt = impactAt, damageMultiplier = damageMultiplier,
		radius = stats.Radius * radiusMultiplier, castHits = castHits,
	}
	table.insert(meteors, strike)
	abilityNetwork:fireAll("MeteorWarned", {
		id = strike.id, ownerUserId = player.UserId, position = position,
		radius = strike.radius, impactAt = impactAt, rage = stats.IsRage == true,
	})
end

local function attackMeteor(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Meteor
	local targets = chooseGroupTargets(root.Position, stats.Range, stats.Radius * 1.2, stats.Count)
	if #targets == 0 then
		return false
	end
	local castHits = {}
	for index, target in targets do
		local ground = getGroundPosition(player, target.position)
		if ground then
			scheduleMeteor(player, stats, ground, now + stats.FallDelay + (index - 1) * 0.13,
				if stats.Shower then 0.7 else 1, if stats.Shower then 0.78 else 1, castHits)
		end
	end
	if stats.Shower then
		local ground = getGroundPosition(player, targets[1].position)
		if ground then
			scheduleMeteor(player, stats, ground, now + stats.FallDelay + 0.5, 1, 1.05, castHits)
		end
	end
	return true
end

local function impactMeteor(strike)
	local definition = AbilityDefinitions.ById.Meteor
	local stats = strike.stats
	local position = strike.position
	local kills = 0
	local targets = CombatTargets.GetDamageablesInRadius(position,
		strike.radius * (if stats.Shockwave then 1.38 else 1), definition.Combat.MaximumTargets)
	for _, target in targets do
		local distance = horizontalDistance(target.position, position)
		local inCenter = distance <= strike.radius
		local damage = stats.Damage * strike.damageMultiplier * (if inCenter then 1 else 0.35)
		if strike.castHits[target.key] and stats.Count >= 3 then
			damage *= 1.2
		end
		if inCenter or stats.Shockwave then
			local damaged, killed = damageTarget(strike.player, "Meteor", stats, target, damage, position,
				if inCenter then definition.Combat.Knockback else definition.Combat.Knockback * 0.5)
			if damaged then
				strike.castHits[target.key] = true
			end
			if killed and target.kind == "Zombie" then
				kills += 1
			end
		end
	end
	if stats.Fragments then
		for fragmentIndex = 1, definition.Combat.FragmentCount do
			local angle = fragmentIndex / definition.Combat.FragmentCount * math.pi * 2
			local point = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * strike.radius * 0.85
			for _, target in CombatTargets.GetDamageablesInRadius(point,
				definition.Combat.FragmentRadius, 8) do
				local _, killed = damageTarget(strike.player, "Meteor", stats, target, stats.Damage * 0.18,
					point, 3)
				if killed and target.kind == "Zombie" then
					kills += 1
				end
			end
		end
	end
	local runtime = runtimes[strike.player]
	if runtime and stats.Extinction and kills > 0 then
		-- Cap one impact's refund so dense waves cannot make Meteor cast without a pause.
		runtime.nextAttackAt.Meteor = math.max(Workspace:GetServerTimeNow() + 0.45,
			runtime.nextAttackAt.Meteor - math.min(kills * 0.07, 0.55))
	end
	abilityNetwork:fireAll("MeteorImpacted", {
		id = strike.id, position = position, radius = strike.radius,
		shockwave = stats.Shockwave, fragments = stats.Fragments, rage = stats.IsRage == true,
	})
end

local function updateMeteors(now: number)
	for index = #meteors, 1, -1 do
		local strike = meteors[index]
		if strike.player.Parent ~= Players or not getAliveRoot(strike.player) then
			abilityNetwork:fireAll("MeteorCancelled", strike.id)
			table.remove(meteors, index)
		elseif now >= strike.impactAt then
			impactMeteor(strike)
			table.remove(meteors, index)
		end
	end
end

local function removeTurretAt(index: number)
	local turret = turrets[index]
	abilityNetwork:fireAll("TurretRemoved", turret.id)
	table.remove(turrets, index)
end

local function deployTurret(player: Player, stats, position: Vector3, now: number)
	local owned = {}
	for index, turret in turrets do
		if turret.player == player then
			table.insert(owned, { index = index, createdAt = turret.createdAt })
		end
	end
	if #owned >= stats.MaximumActive then
		table.sort(owned, function(left, right) return left.createdAt < right.createdAt end)
		removeTurretAt(owned[1].index)
	end
	local turret = {
		id = nextId(), player = player, position = position, stats = stats,
		createdAt = now, expiresAt = now + stats.Duration, nextFireAt = now + 0.25,
		shots = 0, lastTargetId = nil, lockHits = 0,
	}
	table.insert(turrets, turret)
	abilityNetwork:fireAll("TurretDeployed", {
		id = turret.id, ownerUserId = player.UserId, position = position,
		duration = stats.Duration, rage = stats.IsRage == true,
	})
end

local function attackTurret(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local ground = getGroundPosition(player, root.Position - root.CFrame.LookVector * 2)
	if not ground then
		return false
	end
	deployTurret(player, stats, ground + Vector3.yAxis * 0.65, now)
	return true
end

local function updateTurrets(now: number)
	local definition = AbilityDefinitions.ById.Turret
	for index = #turrets, 1, -1 do
		local turret = turrets[index]
		local root = getAliveRoot(turret.player)
		if not root or now >= turret.expiresAt then
			removeTurretAt(index)
		elseif now >= turret.nextFireAt then
			local data = getAbilityData(turret.player)
			if not isEquipped(data, "Turret") then
				removeTurretAt(index)
				continue
			end
			local level = data.Levels.Turret or 1
			local rage = RageController.IsActive(turret.player)
			local stats = PassiveEffects.ModifyWeaponStats(turret.player, "Turret",
				if rage then definition.GetRageStats(level) else definition.GetStats(level))
			local targets = CombatTargets.GetNearestHostiles(turret.position, stats.Range,
				if stats.TargetLock then 12 else stats.Barrels)
			local target = targets[1]
			if not target then
				turret.nextFireAt = now + 0.2
				continue
			end
			if stats.TargetLock and turret.lastTargetId then
				-- A locked turret keeps a valid target instead of jittering toward whichever zombie
				-- happens to be fractionally closer on this tick; the second barrel still covers another.
				for candidateIndex, candidate in targets do
					if candidate.id == turret.lastTargetId then
						targets[candidateIndex] = target
						targets[1] = candidate
						target = candidate
						break
					end
				end
			end
			turret.shots += 1
			if turret.lastTargetId == target.id then
				turret.lockHits = math.min(turret.lockHits + 1, 5)
			else
				turret.lastTargetId = target.id
				turret.lockHits = 0
			end
			local damageMultiplier = if stats.TargetLock then 1 + turret.lockHits * 0.06 else 1
			local origin = turret.position + Vector3.yAxis * 1.4
			local endpoints = {}
			for barrelIndex = 1, stats.Barrels do
				-- Twin Barrel spreads fire to a second nearby zombie when available.
				local barrelTarget = targets[barrelIndex] or target
				local barrelMultiplier = if barrelTarget == target then damageMultiplier else 1
				damageTarget(turret.player, "Turret", stats, barrelTarget,
					stats.Damage * barrelMultiplier, origin, definition.Combat.Knockback)
				table.insert(endpoints, barrelTarget.position)
			end
			local rail = stats.RailEvery > 0 and turret.shots % stats.RailEvery == 0
			if rail then
				local direction = target.position - origin
				local horizontal = Vector3.new(direction.X, 0, direction.Z)
				if horizontal.Magnitude > 0.001 then
					local endPosition = origin + horizontal.Unit * definition.Combat.RailRange
					for _, candidate in CombatTargets.GetDamageablesInRadius(origin,
						definition.Combat.RailRange, definition.Combat.MaximumTargets) do
						if candidate.key ~= target.key and pointToSegmentDistanceXZ(candidate.position, origin, endPosition) <= 1.1 then
							damageTarget(turret.player, "Turret", stats, candidate, stats.Damage * 0.8, origin, 5)
						end
					end
				end
			end
			abilityNetwork:fireAll("TurretFired", {
				id = turret.id, origin = origin, targetPosition = target.position,
				endpoints = endpoints, bulletRadius = stats.BulletRadius,
				rage = rage, rail = rail, fast = level >= 5,
			})
			turret.nextFireAt = now + stats.FireInterval * PassiveEffects.GetCooldownMultiplier(turret.player)
		end
	end
end

local function removeVortexAt(index: number, collapse: boolean)
	local vortex = vortexes[index]
	if collapse and vortex.stats.Collapse and not vortex.mobile then
		local definition = AbilityDefinitions.ById.Vortex
		for _, target in CombatTargets.GetDamageablesInRadius(vortex.position,
			vortex.stats.Radius * 1.15, definition.Combat.MaximumTargets) do
			damageTarget(vortex.player, "Vortex", vortex.stats, target, vortex.stats.Damage * 2.2,
				vortex.position, 8)
		end
		abilityNetwork:fireAll("VortexCollapsed", {
			position = vortex.position, radius = vortex.stats.Radius * 1.15,
		})
	end
	abilityNetwork:fireAll("VortexRemoved", vortex.id)
	table.remove(vortexes, index)
end

local function createVortex(player: Player, stats, position: Vector3, now: number, mobile: boolean)
	local definition = AbilityDefinitions.ById.Vortex
	local owned = 0
	local oldestIndex
	local oldestAt = math.huge
	for index, vortex in vortexes do
		if vortex.player == player and not vortex.mobile then
			owned += 1
			if vortex.createdAt < oldestAt then
				oldestAt = vortex.createdAt
				oldestIndex = index
			end
		end
	end
	if not mobile and owned >= (stats.MaximumActive or definition.Combat.MaximumActive) and oldestIndex then
		removeVortexAt(oldestIndex, false)
	end
	local vortex = {
		id = nextId(), player = player, stats = stats, position = position,
		createdAt = now, expiresAt = now + stats.Duration, nextTickAt = now + 0.2,
		mobile = mobile,
	}
	table.insert(vortexes, vortex)
	abilityNetwork:fireAll("VortexCreated", {
		id = vortex.id, ownerUserId = player.UserId, position = position,
		radius = stats.Radius, duration = stats.Duration, mobile = mobile,
		rage = stats.IsRage == true,
	})
end

local function attackVortex(player: Player, _runtime, stats, root: BasePart, now: number): boolean
	local definition = AbilityDefinitions.ById.Vortex
	local targets = chooseGroupTargets(root.Position, definition.Combat.Range, stats.Radius, stats.Count)
	local created = false
	for _, target in targets do
		local ground = getGroundPosition(player, target.position)
		if ground then
			createVortex(player, stats, ground, now, false)
			created = true
		end
	end
	return created
end

local function updateVortexes(now: number)
	local definition = AbilityDefinitions.ById.Vortex
	for index = #vortexes, 1, -1 do
		local vortex = vortexes[index]
		local root = getAliveRoot(vortex.player)
		if not root or (vortex.mobile and not RageController.IsActive(vortex.player))
			or (not vortex.mobile and now >= vortex.expiresAt)
		then
			removeVortexAt(index, root ~= nil)
		elseif now >= vortex.nextTickAt then
			vortex.nextTickAt = now + definition.Combat.TickInterval
			if vortex.mobile then
				vortex.position = root.Position
			end
			local targets = CombatTargets.GetDamageablesInRadius(vortex.position,
				vortex.stats.Radius, definition.Combat.MaximumTargets)
			local zombieCount = 0
			for _, target in targets do
				if target.kind == "Zombie" then
					zombieCount += 1
				end
			end
			local multiplier = if vortex.stats.Compression then math.min(1.5, 1 + zombieCount * 0.025) else 1
			for _, target in targets do
				damageTarget(vortex.player, "Vortex", vortex.stats, target,
					vortex.stats.Damage * multiplier, vortex.position, 0)
				if target.kind == "Zombie" then
					if (target.threatLevel or 0) >= 4 then
						ZombieController.SlowZombie(target.id, 0.72, 0.6)
					else
						ZombieController.PullZombie(target.id, vortex.position,
							vortex.stats.PullSpeed * definition.Combat.TickInterval
								* PassiveEffects.GetImpactPullMultiplier(vortex.player))
					end
				end
			end
		end
	end
end

local ATTACKERS = {
	Shotgun = attackShotgun,
	FrostNova = attackFrostNova,
	Meteor = attackMeteor,
	Turret = attackTurret,
	Vortex = attackVortex,
}

local function cleanupAbility(player: Player, abilityId: string)
	if abilityId == "FrostNova" then
		for index = #novaWaves, 1, -1 do
			if novaWaves[index].player == player then
				table.remove(novaWaves, index)
			end
		end
		for index = #frozenGrounds, 1, -1 do
			if frozenGrounds[index].player == player then
				table.remove(frozenGrounds, index)
			end
		end
		for id, status in chilled do
			if status.player == player then
				chilled[id] = nil
			end
		end
	elseif abilityId == "Meteor" then
		for index = #meteors, 1, -1 do
			if meteors[index].player == player then
				abilityNetwork:fireAll("MeteorCancelled", meteors[index].id)
				table.remove(meteors, index)
			end
		end
	elseif abilityId == "Turret" then
		for index = #turrets, 1, -1 do
			if turrets[index].player == player then
				removeTurretAt(index)
			end
		end
	elseif abilityId == "Vortex" then
		for index = #vortexes, 1, -1 do
			if vortexes[index].player == player then
				removeVortexAt(index, false)
			end
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
		for _, abilityId in ABILITY_IDS do
			if runtime.equipped[abilityId] and root and now >= runtime.nextAttackAt[abilityId] then
				local definition = AbilityDefinitions.ById[abilityId]
				local level = data.Levels[abilityId] or 1
				local rage = RageController.IsActive(player)
				local stats = if rage then definition.GetRageStats(level) else definition.GetStats(level)
				ClassController.ApplyWeaponStats(player, abilityId, stats)
				stats = PassiveEffects.ModifyWeaponStats(player, abilityId, stats)
				local attacked = ATTACKERS[abilityId](player, runtime, stats, root, now)
				runtime.nextAttackAt[abilityId] = now + (if attacked
					then stats.Cooldown * PassiveEffects.GetCooldownMultiplier(player)
					else math.min(stats.Cooldown, 0.3))
			end
		end
	end
end

local function stepSimulation()
	local now = Workspace:GetServerTimeNow()
	if now < nextScheduleAt then
		return
	end
	nextScheduleAt = now + SCHEDULER_INTERVAL
	updateNovaWaves(now)
	updateFrozenGround(now)
	updateMeteors(now)
	updateTurrets(now)
	updateVortexes(now)
	scheduleAttacks(now)
end

function AdditionalWeapons.Init(network, dataGetter)
	abilityNetwork = network
	getAbilityData = dataGetter
	nextScheduleAt = Workspace:GetServerTimeNow()
	ZombieController.GetZombieDamagedSignal():Connect(onZombieDamaged)
	simulationConnection = RunService.Heartbeat:Connect(stepSimulation)
end

function AdditionalWeapons.OnPlayerAdded(player: Player)
	local now = Workspace:GetServerTimeNow()
	runtimes[player] = {
		token = 0,
		equipped = {},
		nextAttackAt = {
			Shotgun = now + 0.2, FrostNova = now + 0.25, Meteor = now + 0.3,
			Turret = now + 0.35, Vortex = now + 0.4,
		},
	}
	AdditionalWeapons.Refresh(player)
end

function AdditionalWeapons.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local data = getAbilityData(player)
	for _, abilityId in ABILITY_IDS do
		local equipped = isEquipped(data, abilityId)
		if runtime.equipped[abilityId] and not equipped then
			runtime.token += 1
			cleanupAbility(player, abilityId)
		end
		runtime.equipped[abilityId] = equipped
	end
end

function AdditionalWeapons.ForceImmediate(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, abilityId in ABILITY_IDS do
		if runtime.equipped[abilityId] then
			runtime.nextAttackAt[abilityId] = now + 0.06
		end
	end
	local root = getAliveRoot(player)
	if root and runtime.equipped.Turret then
		local data = getAbilityData(player)
		local stats = AbilityDefinitions.ById.Turret.GetRageStats(data.Levels.Turret or 1)
		stats = PassiveEffects.ModifyWeaponStats(player, "Turret", stats)
		for index = 1, 2 do
			local offset = root.CFrame.RightVector * (if index == 1 then -2 else 2)
			local ground = getGroundPosition(player, root.Position + offset)
			if ground then
				deployTurret(player, stats, ground + Vector3.yAxis * 0.65, now + index * 0.001)
			end
		end
	end
	if root and runtime.equipped.Vortex then
		local alreadyMobile = false
		for _, vortex in vortexes do
			if vortex.player == player and vortex.mobile then
				alreadyMobile = true
				break
			end
		end
		if not alreadyMobile then
			local data = getAbilityData(player)
			local stats = AbilityDefinitions.ById.Vortex.GetRageStats(data.Levels.Vortex or 1)
			ClassController.ApplyWeaponStats(player, "Vortex", stats)
			stats = PassiveEffects.ModifyWeaponStats(player, "Vortex", stats)
			stats.Radius *= 1.15
			createVortex(player, stats, root.Position, now, true)
		end
	end
end

function AdditionalWeapons.Restart(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	runtime.token += 1
	for _, abilityId in ABILITY_IDS do
		cleanupAbility(player, abilityId)
		runtime.nextAttackAt[abilityId] = Workspace:GetServerTimeNow() + 0.25
	end
	AdditionalWeapons.Refresh(player)
end

function AdditionalWeapons.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.token += 1
		for _, abilityId in ABILITY_IDS do
			cleanupAbility(player, abilityId)
		end
	end
	runtimes[player] = nil
end

return AdditionalWeapons
