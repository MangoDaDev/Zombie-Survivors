local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local ClassController = require(ServerStorage.Controllers.ClassController)
local RageController = require(ServerStorage.Controllers.RageController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local CombatTargets = require(script.Parent.CombatTargets)
local PassiveEffects = require(script.Parent.PassiveEffects)

local TAU = math.pi * 2
local ABILITY_ID = "OrbitingSwords"
local VISUAL_SYNC_INTERVAL = 1.5

type Runtime = {
	active: boolean,
	token: number,
	angle: number,
	rotationTravel: number,
	nextReleaseTravel: number,
	momentum: number,
	lastKillAt: number,
	lastStepAt: number,
	lastSyncAt: number,
	lastSignature: string,
	syncSequence: number,
	hitTimes: { [any]: { [number]: number } },
	woundedUntil: { [number]: number },
}

local OrbitingSwords = {}

local abilityNetwork
local getAbilityData
local runtimes: { [Player]: Runtime } = {}

local function isEquipped(data): boolean
	local equipped = type(data.Equipped) == "table" and data.Equipped.Weapon
	return type(equipped) == "table" and table.find(equipped, ABILITY_ID) ~= nil
end

local function getHorizontalDistance(left: Vector3, right: Vector3): number
	local offset = left - right
	return Vector2.new(offset.X, offset.Z).Magnitude
end

local function makeRuntime(): Runtime
	return {
		active = false,
		token = 0,
		angle = 0,
		rotationTravel = 0,
		nextReleaseTravel = math.huge,
		momentum = 0,
		lastKillAt = -math.huge,
		lastStepAt = workspace:GetServerTimeNow(),
		lastSyncAt = -math.huge,
		lastSignature = "",
		syncSequence = 0,
		hitTimes = {},
		woundedUntil = {},
	}
end

local function sendInactive(player: Player, runtime: Runtime)
	runtime.syncSequence += 1
	abilityNetwork:fireAll("OrbitingSwordsState", {
		ownerUserId = player.UserId,
		active = false,
		sequence = runtime.syncSequence,
	})
end

local function sendVisualState(player: Player, runtime: Runtime, stats, level: number, now: number)
	local rageSwordCount = stats.AdditionalSwords or 0
	local momentumStep = math.floor(runtime.momentum * 20 + 0.5)
	local signature = string.format(
		"%d:%d:%d:%d:%d",
		level,
		stats.IsRage and 1 or 0,
		stats.MainSwordCount,
		rageSwordCount,
		momentumStep
	)
	if signature == runtime.lastSignature and now - runtime.lastSyncAt < VISUAL_SYNC_INTERVAL then
		return
	end

	runtime.lastSignature = signature
	runtime.lastSyncAt = now
	runtime.syncSequence += 1
	abilityNetwork:fireAll("OrbitingSwordsState", {
		ownerUserId = player.UserId,
		active = true,
		sequence = runtime.syncSequence,
		serverTime = now,
		angle = runtime.angle,
		rotationSpeed = stats.RotationSpeed * (1 + runtime.momentum),
		orbitRadius = stats.OrbitRadius,
		swordScale = stats.SwordScale,
		mainSwordCount = stats.MainSwordCount,
		additionalSwordCount = rageSwordCount,
		innerOrbit = stats.InnerOrbit,
		innerRadius = stats.OrbitRadius * AbilityDefinitions.ById[ABILITY_ID].Combat.InnerRadiusMultiplier,
		innerScale = stats.SwordScale * AbilityDefinitions.ById[ABILITY_ID].Combat.InnerScaleMultiplier,
		rage = stats.IsRage == true,
	})
end

local function applySwordDamage(
	player: Player,
	runtime: Runtime,
	stats,
	target,
	baseDamage: number,
	now: number,
	hitOrigin: Vector3
)
	local definition = AbilityDefinitions.ById[ABILITY_ID]
	local damage = baseDamage
	if stats.Wounded and (runtime.woundedUntil[target.key] or 0) > now then
		damage *= definition.Combat.WoundDamageMultiplier
	end

	local knockback = definition.Combat.Knockback
		* (if stats.IsRage then definition.Rage.KnockbackMultiplier or 1 else 1)
	local damaged, killed = CombatTargets.DamageTarget(
		target,
		math.floor(damage + 0.5),
		hitOrigin,
		knockback,
		{
			player = player,
			source = ABILITY_ID,
			canApplyHitPassives = true,
		}
	)
	if not damaged then
		return
	end
	if target.kind == "Zombie" then
		ClassController.RegisterSwordHit(player)
	end
	if stats.Wounded then
		-- Each successful hit consumes the prior wound bonus and refreshes it for the next Sword hit.
		runtime.woundedUntil[target.key] = now + definition.Combat.WoundDuration
	end
	if killed and stats.Momentum then
		runtime.momentum = math.min(
			runtime.momentum + definition.Combat.MomentumPerKill,
			definition.Combat.MaximumMomentum
		)
		runtime.lastKillAt = now
		runtime.lastSignature = ""
	end
end

local function hitWithSword(
	player: Player,
	runtime: Runtime,
	stats,
	swordKey: any,
	swordPosition: Vector3,
	hitRadius: number,
	damageMultiplier: number,
	candidates,
	now: number
)
	local swordHits = runtime.hitTimes[swordKey]
	if not swordHits then
		swordHits = {}
		runtime.hitTimes[swordKey] = swordHits
	end

	local hitsThisStep = 0
	local maximumHits = AbilityDefinitions.ById[ABILITY_ID].Combat.MaximumHitsPerSwordStep
	for _, target in candidates do
		if getHorizontalDistance(target.position, swordPosition) <= hitRadius + (target.radius or 0)
			and now - (swordHits[target.key] or -math.huge) >= stats.HitCooldown
		then
			swordHits[target.key] = now
			applySwordDamage(player, runtime, stats, target, stats.Damage * damageMultiplier, now, swordPosition)
			hitsThisStep += 1
			if hitsThisStep >= maximumHits then
				break
			end
		end
	end
end

local function fireReleasedBlade(player: Player, runtime: Runtime, stats, root: BasePart, now: number, token: number)
	local definition = AbilityDefinitions.ById[ABILITY_ID]
	local origin = root.Position + Vector3.new(
		math.cos(runtime.angle) * stats.OrbitRadius,
		1.2,
		math.sin(runtime.angle) * stats.OrbitRadius
	)
	local targets = CombatTargets.GetNearestHostiles(origin, definition.Combat.ReleaseRange, 1)
	local target = targets[1]
	local radial = Vector3.new(math.cos(runtime.angle), 0, math.sin(runtime.angle))
	local targetPosition = if target then target.position else origin + radial * 18

	abilityNetwork:fireAll("SwordReleased", {
		ownerUserId = player.UserId,
		startPosition = origin,
		targetPosition = targetPosition,
		launchAt = now + 0.04,
		outwardDuration = definition.Combat.ReleaseTravelDuration,
		scale = stats.SwordScale * 0.82,
		rage = stats.IsRage == true,
	})

	if target then
		task.delay(0.04 + definition.Combat.ReleaseTravelDuration, function()
			if player.Parent == Players and runtimes[player] == runtime and runtime.token == token then
				applySwordDamage(
					player,
					runtime,
					stats,
					target,
					stats.Damage * definition.Combat.ReleaseDamageMultiplier,
					workspace:GetServerTimeNow(),
					origin
				)
			end
		end)
	end
end

local function cleanHitState(runtime: Runtime, now: number)
	for _, swordHits in runtime.hitTimes do
		for targetId, hitAt in swordHits do
			if now - hitAt > 5 then
				swordHits[targetId] = nil
			end
		end
	end
	for targetId, expiresAt in runtime.woundedUntil do
		if expiresAt <= now then
			runtime.woundedUntil[targetId] = nil
		end
	end
end

local function runOrbit(player: Player, runtime: Runtime, token: number)
	local definition = AbilityDefinitions.ById[ABILITY_ID]
	while player.Parent == Players and runtimes[player] == runtime and runtime.token == token and runtime.active do
		local now = workspace:GetServerTimeNow()
		local data = getAbilityData(player)
		if not isEquipped(data) then
			OrbitingSwords.Refresh(player)
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			task.wait(definition.Combat.SimulationInterval)
			continue
		end

		local level = data.Levels[ABILITY_ID] or 1
		local rageActive = RageController.IsActive(player)
		local stats = if rageActive then definition.GetRageStats(level) else definition.GetStats(level)
		ClassController.ApplyWeaponStats(player, ABILITY_ID, stats)
		stats = PassiveEffects.ModifyWeaponStats(player, ABILITY_ID, stats)
		local deltaTime = math.clamp(now - runtime.lastStepAt, 0, 0.15)
		runtime.lastStepAt = now

		if stats.Momentum and now - runtime.lastKillAt > definition.Combat.MomentumHoldDuration then
			runtime.momentum = math.max(runtime.momentum - definition.Combat.MomentumDecayPerSecond * deltaTime, 0)
		elseif not stats.Momentum then
			runtime.momentum = 0
		end

		local angularSpeed = stats.RotationSpeed * (1 + runtime.momentum)
		local angleStep = angularSpeed * deltaTime
		runtime.angle = (runtime.angle + angleStep) % TAU
		runtime.rotationTravel += angleStep
		if ServerContext.IsLobbyServer() then
			-- Lobby swords stay visible and animated, but never query targets, deal damage, or release blades.
			runtime.nextReleaseTravel = math.huge
			sendVisualState(player, runtime, stats, level, now)
			task.wait(definition.Combat.SimulationInterval)
			continue
		end
		local center = root.Position + Vector3.new(0, 1.2, 0)
		local hitRadius = definition.Combat.HitRadius * (stats.SwordScale / definition.Combat.BaseScale)
		-- Inflate by half this frame's arc so high Rage speed cannot tunnel between discrete server checks.
		hitRadius += math.min(stats.OrbitRadius * angleStep * 0.5, 1.5)
		local candidates = CombatTargets.GetDamageablesInRadius(
			root.Position,
			stats.OrbitRadius + hitRadius + 1,
			definition.Combat.MaximumCandidates
		)

		for swordIndex = 1, stats.MainSwordCount do
			local angle = runtime.angle + TAU * (swordIndex - 1) / stats.MainSwordCount
			local swordPosition = center + Vector3.new(
				math.cos(angle) * stats.OrbitRadius,
				0,
				math.sin(angle) * stats.OrbitRadius
			)
			hitWithSword(
				player,
				runtime,
				stats,
				swordIndex,
				swordPosition,
				hitRadius,
				1,
				candidates,
				now
			)
		end
		local additionalSwordCount = stats.AdditionalSwords or 0
		for swordIndex = 1, additionalSwordCount do
			-- Rage copies occupy gaps between permanent blades instead of replacing their readable formation.
			local gapIndex = math.floor((swordIndex - 1) * stats.MainSwordCount / additionalSwordCount) + 1
			local angle = runtime.angle + TAU * (gapIndex - 0.5) / stats.MainSwordCount
			local swordPosition = center + Vector3.new(
				math.cos(angle) * stats.OrbitRadius,
				0,
				math.sin(angle) * stats.OrbitRadius
			)
			hitWithSword(
				player,
				runtime,
				stats,
				"Rage" .. swordIndex,
				swordPosition,
				hitRadius,
				0.8,
				candidates,
				now
			)
		end

		if stats.InnerOrbit then
			local innerAngle = -runtime.angle * 1.35
			local innerRadius = stats.OrbitRadius * definition.Combat.InnerRadiusMultiplier
			local innerPosition = center + Vector3.new(
				math.cos(innerAngle) * innerRadius,
				0,
				math.sin(innerAngle) * innerRadius
			)
			hitWithSword(
				player,
				runtime,
				stats,
				"Inner",
				innerPosition,
				hitRadius * definition.Combat.InnerScaleMultiplier,
				definition.Combat.InnerDamageMultiplier,
				candidates,
				now
			)
		end

		if stats.BladeRelease then
			if runtime.nextReleaseTravel == math.huge then
				runtime.nextReleaseTravel = runtime.rotationTravel + stats.ReleaseEveryRotations * TAU
			elseif runtime.rotationTravel >= runtime.nextReleaseTravel then
				fireReleasedBlade(player, runtime, stats, root, now, token)
				runtime.nextReleaseTravel += stats.ReleaseEveryRotations * TAU
			end
		else
			runtime.nextReleaseTravel = math.huge
		end

		sendVisualState(player, runtime, stats, level, now)
		if now - runtime.lastSyncAt < definition.Combat.SimulationInterval * 2 then
			cleanHitState(runtime, now)
		end
		task.wait(definition.Combat.SimulationInterval)
	end
end

local function start(player: Player, runtime: Runtime)
	runtime.active = true
	runtime.token += 1
	runtime.lastStepAt = workspace:GetServerTimeNow()
	runtime.lastSignature = ""
	local token = runtime.token
	task.spawn(runOrbit, player, runtime, token)
end

local function stop(player: Player, runtime: Runtime)
	if not runtime.active then
		return
	end
	runtime.active = false
	runtime.token += 1
	sendInactive(player, runtime)
end

function OrbitingSwords.Init(network, dataGetter)
	abilityNetwork = network
	getAbilityData = dataGetter
end

function OrbitingSwords.OnPlayerAdded(player: Player)
	local runtime = makeRuntime()
	runtimes[player] = runtime
	OrbitingSwords.Refresh(player)
end

function OrbitingSwords.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	local shouldRun = isEquipped(getAbilityData(player))
	if shouldRun and not runtime.active then
		start(player, runtime)
	elseif not shouldRun and runtime.active then
		stop(player, runtime)
	end
end

function OrbitingSwords.Restart(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	stop(player, runtime)
	runtime.hitTimes = {}
	runtime.woundedUntil = {}
	runtime.momentum = 0
	runtime.rotationTravel = 0
	runtime.nextReleaseTravel = math.huge
	OrbitingSwords.Refresh(player)
end

function OrbitingSwords.ForceSync(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.lastSignature = ""
	end
end

function OrbitingSwords.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		stop(player, runtime)
	end
	runtimes[player] = nil
end

return OrbitingSwords
