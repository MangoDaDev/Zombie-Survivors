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

local ABILITY_IDS = { "Crowbar", "Crossfire", "Buzzsaw", "Crusher", "LaserSweep" }
local SCHEDULER_INTERVAL = 0.05
local TAU = math.pi * 2

local ExpandedWeapons = {}

local abilityNetwork
local getAbilityData
local heartbeatConnection
local nextScheduleAt = 0
local nextEffectId = 0
local runtimes = {}
local buzzsaws = {}
local crushers = {}
local lasers = {}

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function isEquipped(data, abilityId: string): boolean
	return type(data) == "table"
		and type(data.Equipped) == "table"
		and type(data.Equipped.Weapon) == "table"
		and table.find(data.Equipped.Weapon, abilityId) ~= nil
end

local function horizontalUnit(vector: Vector3, fallback: Vector3?): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude > 0.001 then
		return horizontal.Unit
	end
	local alternate = fallback or Vector3.zAxis
	return Vector3.new(alternate.X, 0, alternate.Z).Unit
end

local function damageTarget(player: Player, definition, target, amount: number, origin: Vector3, isRage: boolean, multiplier: number?)
	local knockback = (definition.Combat.Knockback or 0)
		* (if isRage then definition.Rage and definition.Rage.KnockbackMultiplier or 1 else 1)
	CombatTargets.DamageTarget(target, math.max(1, math.floor(amount * (multiplier or 1) + 0.5)), origin, knockback, {
		player = player,
		source = definition.Id,
		canApplyHitPassives = true,
	})
end

local function pointToSegmentDistance(point: Vector3, origin: Vector3, direction: Vector3, length: number): (number, number)
	local offset = point - origin
	local along = math.clamp(offset:Dot(direction), 0, length)
	local closest = origin + direction * along
	local horizontal = Vector3.new(point.X - closest.X, 0, point.Z - closest.Z)
	return horizontal.Magnitude, along
end

local function getAimDirection(root: BasePart, range: number): Vector3
	local nearest = CombatTargets.GetNearestHostiles(root.Position, range, 1)[1]
	return if nearest then horizontalUnit(nearest.position - root.Position, root.CFrame.LookVector)
		else horizontalUnit(root.CFrame.LookVector, Vector3.zAxis)
end

local function applyCrowbarSwing(player: Player, stats, root: BasePart, swingIndex: number, damageMultiplier: number?)
	if not root.Parent then return end
	local definition = AbilityDefinitions.ById.Crowbar
	local baseDirection = getAimDirection(root, stats.Reach + 5)
	local direction = if swingIndex % 2 == 0 then -baseDirection else baseDirection
	local halfArcCosine = math.cos(math.rad(stats.ArcDegrees * 0.5))
	local targets = CombatTargets.GetDamageablesInRadius(root.Position, stats.Reach, definition.Combat.MaximumTargets)
	local hitCount = 0
	for _, target in targets do
		local targetDirection = horizontalUnit(target.position - root.Position, direction)
		if direction:Dot(targetDirection) >= halfArcCosine then
			hitCount += 1
		end
	end
	local crowdMultiplier = if stats.CrowdBonus then 1 + math.min(math.max(hitCount - 4, 0) * 0.035, 0.35) else 1
	for _, target in targets do
		local targetDirection = horizontalUnit(target.position - root.Position, direction)
		if direction:Dot(targetDirection) >= halfArcCosine then
			damageTarget(player, definition, target, stats.Damage, root.Position, stats.IsRage == true,
				crowdMultiplier * (damageMultiplier or 1))
			if stats.HeavySlow and target.kind == "Zombie" then
				ZombieController.SlowZombie(target.id, 0.72, 0.45)
			end
		end
	end
	abilityNetwork:fireAll("CrowbarSwung", {
		ownerUserId = player.UserId,
		position = root.Position + Vector3.yAxis * 1.15,
		direction = direction,
		reach = stats.Reach,
		arcDegrees = stats.ArcDegrees,
		swingIndex = swingIndex,
		rage = stats.IsRage == true,
		overcharged = damageMultiplier ~= nil,
	})
end

local function attackCrowbar(player: Player, runtime, stats, root: BasePart, _now: number, damageMultiplier: number?): boolean
	for swingIndex = 1, stats.SwingCount do
		local delayDuration = (swingIndex - 1) * AbilityDefinitions.ById.Crowbar.Combat.FollowUpDelay
		task.delay(delayDuration, function()
			if runtimes[player] == runtime and runtime.equipped.Crowbar then
				local currentRoot = getAliveRoot(player)
				if currentRoot then applyCrowbarSwing(player, stats, currentRoot, swingIndex, damageMultiplier) end
			end
		end)
	end
	return true
end

local function fireCrossfireVolley(player: Player, stats, root: BasePart, rotationOffset: number, damageMultiplier: number?)
	local definition = AbilityDefinitions.ById.Crossfire
	local origin = root.Position + Vector3.yAxis * 1.15
	local endpoints = {}
	-- One broad-phase query feeds every bolt in this volley. Re-scanning the zombie registry for each
	-- direction would multiply server work exactly when Crossfire reaches its eight-bolt milestones.
	local nearbyTargets = CombatTargets.GetDamageablesInRadius(origin, stats.Range + stats.Width, nil)
	for directionIndex = 1, stats.DirectionCount do
		local angle = rotationOffset + TAU * (directionIndex - 1) / stats.DirectionCount
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local endpoint = origin + direction * stats.Range
		table.insert(endpoints, endpoint)
		local hits = {}
		for _, target in nearbyTargets do
			local distance, along = pointToSegmentDistance(target.position, origin, direction, stats.Range)
			if distance <= stats.Width and along > 0 then
				table.insert(hits, { target = target, along = along })
			end
		end
		table.sort(hits, function(left, right) return left.along < right.along end)
		for hitIndex = 1, math.min(#hits, definition.Combat.MaximumTargetsPerBolt) do
			local growth = 1 + (hitIndex - 1) * stats.PierceGrowth
			damageTarget(player, definition, hits[hitIndex].target, stats.Damage, origin, stats.IsRage == true,
				growth * (damageMultiplier or 1))
		end
	end
	abilityNetwork:fireAll("CrossfireFired", {
		ownerUserId = player.UserId,
		origin = origin,
		endpoints = endpoints,
		width = stats.Width,
		rage = stats.IsRage == true,
		overcharged = damageMultiplier ~= nil,
	})
end

local function attackCrossfire(player: Player, runtime, stats, root: BasePart, _now: number, damageMultiplier: number?): boolean
	local baseDirection = horizontalUnit(root.CFrame.LookVector, Vector3.zAxis)
	local baseAngle = math.atan2(baseDirection.Z, baseDirection.X)
	fireCrossfireVolley(player, stats, root, baseAngle, damageMultiplier)
	if stats.FollowUp then
		task.delay(AbilityDefinitions.ById.Crossfire.Combat.FollowUpDelay, function()
			if runtimes[player] == runtime and runtime.equipped.Crossfire then
				local currentRoot = getAliveRoot(player)
				if currentRoot then
					local repeatStats = table.clone(stats)
					repeatStats.Damage *= stats.FollowUpDamageMultiplier
					fireCrossfireVolley(player, repeatStats, currentRoot, baseAngle + math.pi / stats.DirectionCount, damageMultiplier)
				end
			end
		end)
	end
	return true
end

local function removeBuzzsawAt(index: number, ricochet: boolean?)
	local saw = buzzsaws[index]
	table.remove(buzzsaws, index)
	abilityNetwork:fireAll("BuzzsawRemoved", saw.id)
	if ricochet and saw.stats.Ricochet and saw.ricochets < 1 then
		local target = CombatTargets.GetNearestHostiles(saw.position, AbilityDefinitions.ById.Buzzsaw.Combat.Range, 1)[1]
		if target then
			nextEffectId += 1
			local clone = table.clone(saw)
			clone.id = nextEffectId
			clone.position = target.position
			clone.createdAt = Workspace:GetServerTimeNow()
			clone.expiresAt = clone.createdAt + clone.stats.Duration * 0.62
			clone.nextTickAt = clone.createdAt
			clone.ricochets += 1
			clone.hitCounts = {}
			table.insert(buzzsaws, clone)
			abilityNetwork:fireAll("BuzzsawCreated", {
				id = clone.id, ownerUserId = clone.player.UserId, position = clone.position,
				radius = clone.stats.Radius, duration = clone.expiresAt - clone.createdAt,
				rage = clone.stats.IsRage == true, ricochet = true, overcharged = clone.damageMultiplier ~= nil,
			})
		end
	end
end

local function createBuzzsaw(player: Player, stats, position: Vector3, now: number, damageMultiplier: number?)
	local ownedCount = 0
	for _, saw in buzzsaws do
		if saw.player == player then ownedCount += 1 end
	end
	if ownedCount >= AbilityDefinitions.ById.Buzzsaw.Combat.MaximumActive then
		for index, saw in buzzsaws do
			if saw.player == player then removeBuzzsawAt(index, false); break end
		end
	end
	nextEffectId += 1
	local saw = {
		id = nextEffectId, player = player, stats = table.clone(stats), position = position,
		createdAt = now, expiresAt = now + stats.Duration, nextTickAt = now,
		ricochets = 0, hitCounts = {}, damageMultiplier = damageMultiplier,
	}
	table.insert(buzzsaws, saw)
	abilityNetwork:fireAll("BuzzsawCreated", {
		id = saw.id, ownerUserId = player.UserId, position = position, radius = stats.Radius,
		duration = stats.Duration, rage = stats.IsRage == true, ricochet = false,
		overcharged = damageMultiplier ~= nil,
	})
end

local function attackBuzzsaw(player: Player, _runtime, stats, root: BasePart, now: number, damageMultiplier: number?): boolean
	local targets = CombatTargets.GetNearestHostiles(root.Position, AbilityDefinitions.ById.Buzzsaw.Combat.Range, stats.Count)
	if #targets == 0 then return false end
	for sawIndex = 1, stats.Count do
		local target = targets[(sawIndex - 1) % #targets + 1]
		createBuzzsaw(player, stats, target.position, now + sawIndex * 0.001, damageMultiplier)
	end
	return true
end

local function impactCrusher(crusher)
	local definition = AbilityDefinitions.ById.Crusher
	local direction = crusher.direction
	local side = Vector3.yAxis:Cross(direction)
	local origin = crusher.position
	for _, target in CombatTargets.GetDamageablesInRadius(origin, math.max(crusher.stats.Length, crusher.stats.Width), definition.Combat.MaximumTargets) do
		local offset = target.position - origin
		local along = math.abs(offset:Dot(direction))
		local across = math.abs(offset:Dot(side))
		if along <= crusher.stats.Length * 0.5 and across <= crusher.stats.Width * 0.5 then
			damageTarget(crusher.player, definition, target, crusher.stats.Damage, origin,
				crusher.stats.IsRage == true, crusher.damageMultiplier)
			if crusher.stats.Stun and target.kind == "Zombie" then
				ZombieController.SlowZombie(target.id, 0.12, 0.55)
			end
		end
	end
	abilityNetwork:fireAll("CrusherImpacted", {
		id = crusher.id, position = origin, direction = direction, length = crusher.stats.Length,
		width = crusher.stats.Width, rage = crusher.stats.IsRage == true,
		overcharged = crusher.damageMultiplier ~= nil,
	})
end

local function queueCrusher(player: Player, stats, position: Vector3, direction: Vector3, now: number, damageMultiplier: number?)
	nextEffectId += 1
	local crusher = {
		id = nextEffectId, player = player, stats = table.clone(stats), position = position,
		direction = direction, impactAt = now + stats.WarningDuration, damageMultiplier = damageMultiplier,
	}
	table.insert(crushers, crusher)
	abilityNetwork:fireAll("CrusherWarned", {
		id = crusher.id, ownerUserId = player.UserId, position = position, direction = direction,
		length = stats.Length, width = stats.Width, impactAt = crusher.impactAt,
		rage = stats.IsRage == true, overcharged = damageMultiplier ~= nil,
	})
end

local function attackCrusher(player: Player, runtime, stats, root: BasePart, now: number, damageMultiplier: number?): boolean
	local target = CombatTargets.GetNearestHostiles(root.Position, AbilityDefinitions.ById.Crusher.Combat.Range, 1)[1]
	if not target then return false end
	local direction = horizontalUnit(target.position - root.Position, root.CFrame.LookVector)
	queueCrusher(player, stats, target.position, direction, now, damageMultiplier)
	if stats.Aftershock then
		task.delay(stats.WarningDuration + AbilityDefinitions.ById.Crusher.Combat.RepeatDelay, function()
			if runtimes[player] == runtime and runtime.equipped.Crusher then
				local secondStats = table.clone(stats)
				secondStats.Damage *= stats.AftershockDamageMultiplier
				queueCrusher(player, secondStats, target.position, Vector3.yAxis:Cross(direction),
					Workspace:GetServerTimeNow(), damageMultiplier)
			end
		end)
	end
	return true
end

local function attackLaser(player: Player, _runtime, stats, root: BasePart, now: number, damageMultiplier: number?): boolean
	nextEffectId += 1
	local direction = horizontalUnit(root.CFrame.LookVector, Vector3.zAxis)
	local laser = {
		id = nextEffectId, player = player, stats = table.clone(stats),
		startedAt = now, expiresAt = now + stats.Duration, startAngle = math.atan2(direction.Z, direction.X),
		nextStepAt = now, hitRotations = {}, damageMultiplier = damageMultiplier,
	}
	table.insert(lasers, laser)
	abilityNetwork:fireAll("LaserSweepStarted", {
		id = laser.id, ownerUserId = player.UserId, startedAt = now, duration = stats.Duration,
		range = stats.Range, width = stats.Width, rotations = stats.Rotations,
		beamCount = stats.BeamCount, startAngle = laser.startAngle,
		rage = stats.IsRage == true, overcharged = damageMultiplier ~= nil,
	})
	return true
end

local ATTACKERS = {
	Crowbar = attackCrowbar,
	Crossfire = attackCrossfire,
	Buzzsaw = attackBuzzsaw,
	Crusher = attackCrusher,
	LaserSweep = attackLaser,
}

local function updateBuzzsaws(now: number)
	local definition = AbilityDefinitions.ById.Buzzsaw
	for index = #buzzsaws, 1, -1 do
		local saw = buzzsaws[index]
		if saw.player.Parent ~= Players or not runtimes[saw.player] or now >= saw.expiresAt then
			removeBuzzsawAt(index, now >= saw.expiresAt)
		elseif now >= saw.nextTickAt then
			saw.nextTickAt = now + saw.stats.TickInterval
			for _, target in CombatTargets.GetDamageablesInRadius(saw.position, saw.stats.Radius, definition.Combat.MaximumTargets) do
				local hitCount = saw.hitCounts[target.key] or 0
				saw.hitCounts[target.key] = hitCount + 1
				local heatMultiplier = 1 + math.min(hitCount * saw.stats.HeatGrowth, 0.48)
				damageTarget(saw.player, definition, target, saw.stats.Damage, saw.position,
					saw.stats.IsRage == true, heatMultiplier * (saw.damageMultiplier or 1))
			end
		end
	end
end

local function updateCrushers(now: number)
	for index = #crushers, 1, -1 do
		local crusher = crushers[index]
		if crusher.player.Parent ~= Players or not runtimes[crusher.player] then
			abilityNetwork:fireAll("CrusherCancelled", crusher.id)
			table.remove(crushers, index)
		elseif now >= crusher.impactAt then
			impactCrusher(crusher)
			table.remove(crushers, index)
		end
	end
end

local function updateLasers(now: number)
	local definition = AbilityDefinitions.ById.LaserSweep
	for index = #lasers, 1, -1 do
		local laser = lasers[index]
		local root = getAliveRoot(laser.player)
		if not root or not runtimes[laser.player] or now >= laser.expiresAt then
			abilityNetwork:fireAll("LaserSweepEnded", laser.id)
			table.remove(lasers, index)
		elseif now >= laser.nextStepAt then
			laser.nextStepAt = now + definition.Combat.StepInterval
			local alpha = math.clamp((now - laser.startedAt) / laser.stats.Duration, 0, 0.9999)
			local rotationProgress = alpha * laser.stats.Rotations
			local rotationIndex = math.floor(rotationProgress)
			local origin = root.Position + Vector3.yAxis * 1.2
			-- Both beams share a broad-phase result; the narrow segment checks below decide which
			-- beam actually hit. This keeps the Rage double-beam from doubling registry scans.
			local nearbyTargets = CombatTargets.GetDamageablesInRadius(origin,
				laser.stats.Range + laser.stats.Width, definition.Combat.MaximumTargetsPerStep)
			for beamIndex = 1, laser.stats.BeamCount do
				local angle = laser.startAngle + rotationProgress * TAU + TAU * (beamIndex - 1) / laser.stats.BeamCount
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				for _, target in nearbyTargets do
					local distance, along = pointToSegmentDistance(target.position, origin, direction, laser.stats.Range)
					local hitKey = string.format("%s:%d:%d", tostring(target.key), rotationIndex, beamIndex)
					if distance <= laser.stats.Width and along > 0 and not laser.hitRotations[hitKey] then
						laser.hitRotations[hitKey] = true
						local previousHits = laser.hitRotations[target.key] or 0
						laser.hitRotations[target.key] = previousHits + 1
						local searingMultiplier = 1 + math.min(previousHits * laser.stats.SearingGrowth, 0.6)
						damageTarget(laser.player, definition, target, laser.stats.Damage, origin,
							laser.stats.IsRage == true, searingMultiplier * (laser.damageMultiplier or 1))
					end
				end
			end
		end
	end
end

local function repeatActivation(player: Player, runtime, abilityId: string, stats, delayDuration: number, multiplier: number)
	task.delay(delayDuration, function()
		if runtimes[player] ~= runtime or not runtime.equipped[abilityId] then return end
		local root = getAliveRoot(player)
		if root then ATTACKERS[abilityId](player, runtime, stats, root, Workspace:GetServerTimeNow(), multiplier) end
	end)
end

local function scheduleAttacks(now: number)
	if ServerContext.IsLobbyServer() then return end
	for player, runtime in runtimes do
		if player.Parent ~= Players then continue end
		local data = getAbilityData(player)
		local root = getAliveRoot(player)
		for _, abilityId in ABILITY_IDS do
			if runtime.equipped[abilityId] and root and now >= runtime.nextAttackAt[abilityId] then
				local definition = AbilityDefinitions.ById[abilityId]
				local level = data.Levels[abilityId] or 1
				local stats = if RageController.IsActive(player) then definition.GetRageStats(level) else definition.GetStats(level)
				ClassController.ApplyWeaponStats(player, abilityId, stats)
				stats = PassiveEffects.ModifyWeaponStats(player, abilityId, stats)
				local attacked = ATTACKERS[abilityId](player, runtime, stats, root, now, nil)
				if attacked then
					local repeatConfig = PassiveEffects.ConsumeWeaponActivation(player, abilityId)
					if repeatConfig then
						repeatActivation(player, runtime, abilityId, stats, repeatConfig.Delay, repeatConfig.DamageMultiplier)
					end
				end
				runtime.nextAttackAt[abilityId] = now + (if attacked
					then stats.Cooldown * PassiveEffects.GetCooldownMultiplier(player)
					else math.min(stats.Cooldown, 0.3))
			end
		end
	end
end

local function cleanupAbility(player: Player, abilityId: string)
	if abilityId == "Buzzsaw" then
		for index = #buzzsaws, 1, -1 do
			if buzzsaws[index].player == player then removeBuzzsawAt(index, false) end
		end
	elseif abilityId == "Crusher" then
		for index = #crushers, 1, -1 do
			if crushers[index].player == player then
				abilityNetwork:fireAll("CrusherCancelled", crushers[index].id)
				table.remove(crushers, index)
			end
		end
	elseif abilityId == "LaserSweep" then
		for index = #lasers, 1, -1 do
			if lasers[index].player == player then
				abilityNetwork:fireAll("LaserSweepEnded", lasers[index].id)
				table.remove(lasers, index)
			end
		end
	end
	abilityNetwork:fireAll("AbilityEffectsCleared", player.UserId, abilityId)
end

local function stepSimulation()
	local now = Workspace:GetServerTimeNow()
	updateBuzzsaws(now)
	updateCrushers(now)
	updateLasers(now)
	if now >= nextScheduleAt then
		nextScheduleAt = now + SCHEDULER_INTERVAL
		scheduleAttacks(now)
	end
end

function ExpandedWeapons.Init(network, dataGetter)
	abilityNetwork = network
	getAbilityData = dataGetter
	nextScheduleAt = Workspace:GetServerTimeNow()
	heartbeatConnection = RunService.Heartbeat:Connect(stepSimulation)
end

function ExpandedWeapons.OnPlayerAdded(player: Player)
	local now = Workspace:GetServerTimeNow()
	runtimes[player] = {
		equipped = {},
		nextAttackAt = {
			Crowbar = now + 0.2, Crossfire = now + 0.25, Buzzsaw = now + 0.3,
			Crusher = now + 0.35, LaserSweep = now + 0.4,
		},
	}
	ExpandedWeapons.Refresh(player)
end

function ExpandedWeapons.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime or not getAbilityData then return end
	local data = getAbilityData(player)
	for _, abilityId in ABILITY_IDS do
		local equipped = isEquipped(data, abilityId)
		if runtime.equipped[abilityId] and not equipped then cleanupAbility(player, abilityId) end
		runtime.equipped[abilityId] = equipped
	end
end

function ExpandedWeapons.ForceImmediate(player: Player)
	local runtime = runtimes[player]
	if not runtime then return end
	local now = Workspace:GetServerTimeNow() + 0.05
	for _, abilityId in ABILITY_IDS do
		if runtime.equipped[abilityId] then runtime.nextAttackAt[abilityId] = now end
	end
end

function ExpandedWeapons.Restart(player: Player)
	local runtime = runtimes[player]
	if not runtime then return end
	for _, abilityId in ABILITY_IDS do
		cleanupAbility(player, abilityId)
		runtime.nextAttackAt[abilityId] = Workspace:GetServerTimeNow() + 0.25
	end
	ExpandedWeapons.Refresh(player)
end

function ExpandedWeapons.OnPlayerRemoving(player: Player)
	if runtimes[player] then
		for _, abilityId in ABILITY_IDS do cleanupAbility(player, abilityId) end
	end
	runtimes[player] = nil
end

return ExpandedWeapons
