local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)

local SpecialState = ZombieProtocol.SpecialState

local ZombieSpecialBehaviors = {}

local function setSpecialState(zombie, state, now, targetPosition, value)
	zombie.specialState = state
	zombie.specialStartedAt = now
	local displayTarget = targetPosition or zombie.cframe.Position
	-- Telegraphs are rendered on the arena floor rather than at HumanoidRootPart/pivot height.
	zombie.specialTarget = Vector3.new(displayTarget.X, zombie.arena.GroundY, displayTarget.Z)
	zombie.specialValue = value or 0
end

local function beginSpecial(zombie, state, now, targetPosition, value)
	zombie.specialSequence += 1
	if state == SpecialState.Windup or state == SpecialState.Countdown then
		-- Reuse the existing procedural attack channel so special windups read in the zombie's pose too.
		zombie.attackSequence += 1
		zombie.attackStartedAt = now
	end
	setSpecialState(zombie, state, now, targetPosition, value)
end

local function moveToward(zombie, direction, distance, deltaTime, facing, stopDistance, speedMultiplier)
	local travelDistance = math.min(
		zombie.definition.MoveSpeed
			* zombie.moveSpeedMultiplier
			* zombie.statusMoveSpeedMultiplier
			* zombie.specialMoveSpeedMultiplier
			* zombie.buffMoveSpeedMultiplier
			* (speedMultiplier or 1)
			* deltaTime,
		math.max(distance - stopDistance, 0)
	)
	zombie.cframe = CFrame.new(zombie.cframe.Position + direction * travelDistance) * facing
	zombie.state = if travelDistance > 0 then ZombieProtocol.State.Moving else ZombieProtocol.State.Idle
end

local function damageCandidate(zombie, candidate, amount)
	if candidate and candidate.humanoid.Health > 0 then
		zombie:DamagePlayer(candidate, amount)
	end
end

ZombieSpecialBehaviors.Spitter = {}

function ZombieSpecialBehaviors.Spitter.Step(zombie, deltaTime, target, now, distance, direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime

	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		if now >= runtime.releaseAt then
			local targetPosition = runtime.targetPosition
			zombie.services.LaunchProjectile(zombie, targetPosition, config.ProjectileSpeed, config.ImpactRadius, config.Damage)
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end

	if target and distance <= config.Range and distance >= config.MinimumRange and now >= runtime.nextUseAt then
		local velocity = target.velocity or Vector3.zero
		local travelTime = math.min(distance / config.ProjectileSpeed, 1.2)
		runtime.targetPosition = target.position + Vector3.new(velocity.X, 0, velocity.Z) * travelTime
		runtime.releaseAt = now + config.Windup
		runtime.phase = "Windup"
		beginSpecial(zombie, SpecialState.Windup, now, runtime.targetPosition, config.Windup)
		zombie.state = ZombieProtocol.State.Attacking
		return true
	end
	if target and distance < config.MinimumRange then
		-- Once cornered, fall back to the shared contact chase instead of idling in an exploitable dead zone.
		return false
	end

	if target and distance > config.Range * 0.82 then
		moveToward(zombie, direction, distance, deltaTime, facing, config.Range * 0.72)
	else
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		zombie.state = ZombieProtocol.State.Idle
	end
	return true
end

ZombieSpecialBehaviors.Charger = {}

function ZombieSpecialBehaviors.Charger.Step(zombie, deltaTime, target, now, distance, direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime

	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		if now >= runtime.phaseEndsAt then
			runtime.phase = "Charging"
			runtime.phaseEndsAt = now + config.ChargeDuration
			runtime.hitPlayer = false
			setSpecialState(zombie, SpecialState.Active, now, zombie.cframe.Position + runtime.chargeDirection * config.ChargeSpeed * config.ChargeDuration, config.ChargeDuration)
		end
		return true
	elseif runtime.phase == "Charging" then
		local travel = runtime.chargeDirection * config.ChargeSpeed * deltaTime
		zombie.cframe = CFrame.new(zombie.cframe.Position + travel) * CFrame.lookAt(Vector3.zero, runtime.chargeDirection).Rotation
		zombie.state = ZombieProtocol.State.Moving
		if target and not runtime.hitPlayer and (target.position - zombie.cframe.Position).Magnitude <= config.HitRadius then
			damageCandidate(zombie, target, config.Damage)
			runtime.hitPlayer = true
		end
		if now >= runtime.phaseEndsAt then
			runtime.phase = "Recovery"
			runtime.phaseEndsAt = now + config.MissRecovery
			-- A successful charge still pauses briefly, but only a miss opens the requested damage window.
			runtime.vulnerableUntil = if runtime.hitPlayer then 0 else runtime.phaseEndsAt
			setSpecialState(zombie, SpecialState.Recovery, now, zombie.cframe.Position, config.MissRecovery)
		end
		return true
	elseif runtime.phase == "Recovery" then
		zombie.state = ZombieProtocol.State.Idle
		if now >= runtime.phaseEndsAt then
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end

	if target and distance >= config.MinimumRange and distance <= config.MaximumRange and now >= runtime.nextUseAt then
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		runtime.chargeDirection = direction
		beginSpecial(zombie, SpecialState.Windup, now, target.position, config.Windup)
		zombie.state = ZombieProtocol.State.Attacking
		return true
	end

	return false
end

function ZombieSpecialBehaviors.Charger.ModifyDamage(zombie, amount, _hitOrigin, _damageContext, now)
	if now < (zombie.specialRuntime.vulnerableUntil or 0) then
		return amount * zombie.definition.Special.RecoveryDamageMultiplier, false
	end
	return amount, false
end

local function stepSummoner(zombie, target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		if now >= runtime.phaseEndsAt then
			local amount = zombie.services.Random:NextInteger(config.MinimumCount, config.MaximumCount)
			for index = 1, amount do
				local angle = math.pi * 2 * index / amount + zombie.services.Random:NextNumber(-0.35, 0.35)
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.SpawnRadius
				zombie.services.QueueSpawn(config.SpawnType, zombie.cframe.Position + offset, zombie.arena)
			end
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end

	if target and now >= runtime.nextUseAt then
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, zombie.cframe.Position, config.Windup)
		zombie.state = ZombieProtocol.State.Attacking
		return true
	end
	return false
end

ZombieSpecialBehaviors.Screamer = {}
function ZombieSpecialBehaviors.Screamer.Step(zombie, _deltaTime, target, now)
	return stepSummoner(zombie, target, now)
end

ZombieSpecialBehaviors.Summoner = {}
function ZombieSpecialBehaviors.Summoner.Step(zombie, _deltaTime, target, now)
	return stepSummoner(zombie, target, now)
end

ZombieSpecialBehaviors.Tank = {}

function ZombieSpecialBehaviors.Tank.Step(zombie, _deltaTime, target, now, distance)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		if now >= runtime.phaseEndsAt then
			zombie.services.DamagePlayersInRadius(zombie, zombie.cframe.Position, config.Radius, config.Damage)
			zombie.services.BroadcastAbility({
				Kind = "Shockwave",
				Position = zombie.cframe.Position,
				Radius = config.Radius,
				Color = zombie.definition.EffectColor,
			})
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and distance <= config.Radius and now >= runtime.nextUseAt then
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, zombie.cframe.Position, config.Radius)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Leaper = {}

function ZombieSpecialBehaviors.Leaper.Step(zombie, deltaTime, target, now, distance, direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		if now >= runtime.phaseEndsAt then
			runtime.phase = "Leaping"
			runtime.phaseEndsAt = now + config.LeapDuration
			runtime.hitPlayer = false
			setSpecialState(zombie, SpecialState.Active, now, runtime.targetPosition, config.LeapDuration)
		end
		return true
	elseif runtime.phase == "Leaping" then
		local offset = runtime.targetPosition - zombie.cframe.Position
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > 0.05 then
			local travel = math.min(config.LeapSpeed * deltaTime, horizontal.Magnitude)
			local leapDirection = horizontal.Unit
			zombie.cframe = CFrame.new(zombie.cframe.Position + leapDirection * travel)
				* CFrame.lookAt(Vector3.zero, leapDirection).Rotation
		end
		zombie.state = ZombieProtocol.State.Moving
		if target and not runtime.hitPlayer and (target.position - zombie.cframe.Position).Magnitude <= config.HitRadius then
			damageCandidate(zombie, target, config.Damage)
			runtime.hitPlayer = true
		end
		if now >= runtime.phaseEndsAt or horizontal.Magnitude <= 0.2 then
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and distance >= config.MinimumRange and distance <= config.MaximumRange and now >= runtime.nextUseAt then
		local velocity = target.velocity or Vector3.zero
		runtime.targetPosition = target.position + Vector3.new(velocity.X, 0, velocity.Z) * config.PredictionTime
		runtime.targetPosition = Vector3.new(runtime.targetPosition.X, zombie.cframe.Position.Y, runtime.targetPosition.Z)
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, runtime.targetPosition, config.Windup)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Shielder = {}

function ZombieSpecialBehaviors.Shielder.ModifyDamage(zombie, amount, hitOrigin, damageContext)
	local source = damageContext and damageContext.source
	if source == "Blast" or source == "Burn" or source == "Thorns" then
		-- Area/status/retaliation effects are the explicit shield-bypassing attack family.
		return amount, false
	end
	if typeof(hitOrigin) ~= "Vector3" then
		return amount, false
	end
	local incoming = hitOrigin - zombie.cframe.Position
	local horizontal = Vector3.new(incoming.X, 0, incoming.Z)
	if horizontal.Magnitude > 0.001 and zombie.cframe.LookVector:Dot(horizontal.Unit) >= zombie.definition.Special.FrontDotThreshold then
		zombie.services.BroadcastAbility({
			Kind = "Blocked",
			Position = zombie.cframe.Position,
			Color = zombie.definition.EffectColor,
		})
		return 0, true
	end
	return amount, false
end

ZombieSpecialBehaviors.Bomber = {}

function ZombieSpecialBehaviors.Bomber.Step(zombie, _deltaTime, target, now, distance)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Countdown" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.specialValue = math.max(runtime.phaseEndsAt - now, 0)
		if now >= runtime.phaseEndsAt then
			zombie.services.DamagePlayersInRadius(zombie, zombie.cframe.Position, config.Radius, config.Damage)
			zombie.services.DamageZombiesInRadius(zombie.id, zombie.cframe.Position, config.Radius, config.FriendlyFireDamage)
			zombie.services.BroadcastAbility({
				Kind = "Explosion",
				Position = zombie.cframe.Position,
				Radius = config.Radius,
				Color = zombie.definition.EffectColor,
			})
			zombie.health = 0
		end
		return true
	end
	if target and distance <= config.TriggerRange then
		runtime.phase = "Countdown"
		runtime.phaseEndsAt = now + config.Countdown
		beginSpecial(zombie, SpecialState.Countdown, now, zombie.cframe.Position, config.Countdown)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Grabber = {}

function ZombieSpecialBehaviors.Grabber.Step(zombie, _deltaTime, target, now, distance, _direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		if now >= runtime.phaseEndsAt then
			if target and (target.position - zombie.cframe.Position).Magnitude <= config.Range * 1.15 then
				damageCandidate(zombie, target, config.Damage)
				local pull = zombie.cframe.Position - target.position
				local horizontal = Vector3.new(pull.X, 0, pull.Z)
				if horizontal.Magnitude > 0.001 then
					target.root:ApplyImpulse((horizontal.Unit * config.PullSpeed + Vector3.yAxis * config.UpwardSpeed) * target.root.AssemblyMass)
				end
			end
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and distance >= config.MinimumRange and distance <= config.Range and now >= runtime.nextUseAt then
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, target.position, config.Windup)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Splitter = {}

function ZombieSpecialBehaviors.Splitter.OnDeath(zombie)
	local config = zombie.definition.Special
	for index = 1, config.Count do
		local angle = math.pi * 2 * index / config.Count
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.SpawnRadius
		-- A splitter always becomes two children beside its death position.
		zombie.services.QueueSpawn(config.SpawnType, zombie.cframe.Position + offset, zombie.arena)
	end
end

ZombieSpecialBehaviors.Burrower = {}

function ZombieSpecialBehaviors.Burrower.Step(zombie, _deltaTime, target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Burrowing" then
		zombie.state = ZombieProtocol.State.Idle
		if now >= runtime.phaseEndsAt then
			runtime.phase = "Warning"
			runtime.phaseEndsAt = now + config.WarningDuration
			local velocity = target and target.velocity or Vector3.zero
			local targetPosition = target and (target.position + Vector3.new(velocity.X, 0, velocity.Z) * config.PredictionTime)
				or zombie.cframe.Position
			runtime.targetPosition = Vector3.new(targetPosition.X, zombie.cframe.Position.Y, targetPosition.Z)
			setSpecialState(zombie, SpecialState.Warning, now, runtime.targetPosition, config.WarningDuration)
		end
		return true
	elseif runtime.phase == "Warning" then
		zombie.state = ZombieProtocol.State.Idle
		if now >= runtime.phaseEndsAt then
			zombie.cframe = CFrame.new(runtime.targetPosition) * zombie.cframe.Rotation
			zombie:_constrainToArena()
			runtime.phase = "Emerging"
			runtime.phaseEndsAt = now + config.EmergeDuration
			setSpecialState(zombie, SpecialState.Active, now, zombie.cframe.Position, config.EmergeDuration)
		end
		return true
	elseif runtime.phase == "Emerging" then
		zombie.state = ZombieProtocol.State.Attacking
		if now >= runtime.phaseEndsAt then
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and now >= runtime.nextUseAt then
		runtime.phase = "Burrowing"
		runtime.phaseEndsAt = now + config.HiddenDuration
		beginSpecial(zombie, SpecialState.Burrowed, now, zombie.cframe.Position, config.HiddenDuration)
		return true
	end
	return false
end

function ZombieSpecialBehaviors.Burrower.ModifyDamage(zombie, amount)
	if zombie.specialRuntime.phase == "Burrowing" or zombie.specialRuntime.phase == "Warning" then
		return 0, true
	end
	return amount, false
end

ZombieSpecialBehaviors.Frenzy = {}

function ZombieSpecialBehaviors.Frenzy.Step(zombie, _deltaTime, _target, now)
	local runtime = zombie.specialRuntime
	if runtime.frenzyEndsAt and now < runtime.frenzyEndsAt then
		zombie.specialState = SpecialState.Frenzied
		zombie.specialValue = runtime.frenzyEndsAt - now
	elseif runtime.frenzyEndsAt then
		runtime.frenzyEndsAt = nil
		zombie.moveSpeedMultiplier = runtime.baseMoveSpeedMultiplier
		setSpecialState(zombie, SpecialState.None, now)
	end
	return false
end

function ZombieSpecialBehaviors.Frenzy.OnDamaged(zombie, _amount, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if not runtime.frenzyTriggered and zombie.health <= zombie.maximumHealth * config.HealthThreshold then
		runtime.frenzyTriggered = true
		runtime.baseMoveSpeedMultiplier = zombie.moveSpeedMultiplier
		runtime.frenzyEndsAt = now + config.Duration
		zombie.moveSpeedMultiplier *= config.SpeedMultiplier
		beginSpecial(zombie, SpecialState.Frenzied, now, zombie.cframe.Position, config.Duration)
	end
end

ZombieSpecialBehaviors.Medic = {}

function ZombieSpecialBehaviors.Medic.Step(zombie, _deltaTime, _target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if now >= runtime.nextUseAt then
		zombie.services.HealZombiesInRadius(zombie.id, zombie.cframe.Position, config.Radius, config.HealAmount)
		runtime.nextUseAt = now + config.Cooldown
		beginSpecial(zombie, SpecialState.Pulse, now, zombie.cframe.Position, config.Radius)
		zombie.services.BroadcastAbility({
			Kind = "Heal",
			Position = zombie.cframe.Position,
			Radius = config.Radius,
			Color = zombie.definition.EffectColor,
		})
	elseif zombie.specialState == SpecialState.Pulse and now - zombie.specialStartedAt >= config.PulseDuration then
		setSpecialState(zombie, SpecialState.None, now)
	end
	return false
end

ZombieSpecialBehaviors.Hardened = {}

function ZombieSpecialBehaviors.Hardened.Initialize(zombie)
	zombie.specialRuntime.armor = zombie.definition.Special.Armor
	zombie.specialValue = zombie.specialRuntime.armor
	setSpecialState(zombie, SpecialState.Armored, 0, zombie.cframe.Position, zombie.specialRuntime.armor)
end

function ZombieSpecialBehaviors.Hardened.ModifyDamage(zombie, amount)
	local runtime = zombie.specialRuntime
	if runtime.armor <= 0 then
		return amount, false
	end
	local absorbed = math.min(runtime.armor, amount)
	runtime.armor -= absorbed
	zombie.specialValue = runtime.armor
	if runtime.armor <= 0 then
		zombie.specialSequence += 1
		zombie.specialState = SpecialState.None
		zombie.services.BroadcastAbility({
			Kind = "ArmorBreak",
			Position = zombie.cframe.Position,
			Color = zombie.definition.EffectColor,
		})
	end
	return amount - absorbed, true
end

ZombieSpecialBehaviors.Dodger = {}

function ZombieSpecialBehaviors.Dodger.ModifyDamage(zombie, amount, hitOrigin, damageContext, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	local source = damageContext and damageContext.source
	local canDodge = source ~= "Burn" and source ~= "Thorns" and source ~= "Blast"
	if not canDodge or now < runtime.nextUseAt or typeof(hitOrigin) ~= "Vector3" then
		return amount, false
	end
	local incoming = zombie.cframe.Position - hitOrigin
	local horizontal = Vector3.new(incoming.X, 0, incoming.Z)
	if horizontal.Magnitude <= 0.001 then
		return amount, false
	end
	local side = if zombie.services.Random:NextNumber() < 0.5 then -1 else 1
	local sidestep = Vector3.new(-horizontal.Unit.Z, 0, horizontal.Unit.X) * config.Distance * side
	zombie.cframe += sidestep
	zombie:_constrainToArena()
	runtime.nextUseAt = now + config.Cooldown
	beginSpecial(zombie, SpecialState.Dodge, now, zombie.cframe.Position, config.DisplayDuration)
	zombie.services.BroadcastAbility({
		Kind = "Dodge",
		Position = zombie.cframe.Position,
		Color = zombie.definition.EffectColor,
	})
	return 0, true
end

function ZombieSpecialBehaviors.Dodger.Step(zombie, _deltaTime, _target, now)
	if zombie.specialState == SpecialState.Dodge and now - zombie.specialStartedAt >= zombie.definition.Special.DisplayDuration then
		setSpecialState(zombie, SpecialState.None, now)
	end
	return false
end

ZombieSpecialBehaviors.Sludger = {}

function ZombieSpecialBehaviors.Sludger.OnDeath(zombie)
	local config = zombie.definition.Special
	zombie.services.CreateSlowHazard(
		zombie.cframe.Position,
		config.Radius,
		config.Duration,
		config.SlowMultiplier,
		zombie.definition.EffectColor
	)
end

ZombieSpecialBehaviors.Warden = {}

function ZombieSpecialBehaviors.Warden.Step(zombie, _deltaTime, _target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if now < runtime.nextUseAt then
		return false
	end
	runtime.nextUseAt = now + config.PulseInterval
	zombie.services.BuffZombiesInRadius(
		zombie.id,
		zombie.cframe.Position,
		config.Radius,
		config.SpeedMultiplier,
		config.DamageMultiplier,
		config.BuffDuration
	)
	zombie.services.BroadcastAbility({
		Kind = "WardenAura",
		Position = zombie.cframe.Position,
		Radius = config.Radius,
		Color = zombie.definition.EffectColor,
	})
	return false
end

ZombieSpecialBehaviors.CorpseEater = {}

function ZombieSpecialBehaviors.CorpseEater.Initialize(zombie)
	zombie.specialRuntime.stacks = 0
	zombie.specialRuntime.baseMoveSpeedMultiplier = zombie.moveSpeedMultiplier
end

function ZombieSpecialBehaviors.CorpseEater.OnNearbyDeath(zombie, position)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.stacks >= config.MaxStacks or (zombie.cframe.Position - position).Magnitude > config.ConsumeRadius then
		return
	end
	runtime.stacks += 1
	zombie.maximumHealth += config.MaxHealthPerStack
	zombie.health = math.min(zombie.health + config.HealPerStack + config.MaxHealthPerStack, zombie.maximumHealth)
	zombie.moveSpeedMultiplier = runtime.baseMoveSpeedMultiplier * (1 + runtime.stacks * config.SpeedPerStack)
	zombie.damageGrowthMultiplier = 1 + runtime.stacks * config.DamagePerStack
	zombie.specialValue = runtime.stacks
	zombie.services.BroadcastAbility({
		Kind = "Feast",
		Position = zombie.cframe.Position,
		Radius = 4 + runtime.stacks * 0.35,
		Color = zombie.definition.EffectColor,
	})
end

ZombieSpecialBehaviors.Hexer = {}

function ZombieSpecialBehaviors.Hexer.Step(zombie, deltaTime, target, now, distance, direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * facing
		if now >= runtime.phaseEndsAt then
			zombie.services.DamagePlayersInRadius(zombie, runtime.targetPosition, config.Radius, config.Damage)
			zombie.services.BroadcastAbility({
				Kind = "HexBurst",
				Position = runtime.targetPosition,
				Radius = config.Radius,
				Color = zombie.definition.EffectColor,
			})
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and distance >= config.MinimumRange and distance <= config.Range and now >= runtime.nextUseAt then
		local velocity = target.velocity or Vector3.zero
		local predicted = target.position + Vector3.new(velocity.X, 0, velocity.Z) * config.PredictionTime
		runtime.targetPosition = Vector3.new(predicted.X, zombie.arena.GroundY, predicted.Z)
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, runtime.targetPosition, config.Radius)
		return true
	end
	if target and distance > config.Range * 0.82 then
		moveToward(zombie, direction, distance, deltaTime, facing, config.Range * 0.72)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Anchor = {}

function ZombieSpecialBehaviors.Anchor.Step(zombie, _deltaTime, target, now, distance)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if not target or distance > config.Range then
		return false
	end
	if now >= (runtime.nextRefreshAt or 0) then
		runtime.nextRefreshAt = now + config.RefreshInterval
		zombie.services.ApplyPlayerSlow(zombie, target.player, config.SlowMultiplier, config.EffectDuration)
	end
	if now >= (runtime.nextPulseAt or 0) then
		runtime.nextPulseAt = now + config.PulseInterval
		zombie.services.BroadcastAbility({
			Kind = "AnchorTether",
			Position = zombie.cframe.Position,
			Radius = config.Range,
			Color = zombie.definition.EffectColor,
		})
	end
	return false
end

function ZombieSpecialBehaviors.Anchor.OnDeath(zombie)
	zombie.services.ClearPlayerEffect(zombie)
end

ZombieSpecialBehaviors.Frostbite = {}

function ZombieSpecialBehaviors.Frostbite.Step(zombie, _deltaTime, target, now, distance, direction, facing)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.phase == "Windup" then
		zombie.state = ZombieProtocol.State.Attacking
		zombie.cframe = CFrame.new(zombie.cframe.Position) * CFrame.lookAt(Vector3.zero, runtime.castDirection).Rotation
		if now >= runtime.phaseEndsAt then
			zombie.services.SlowPlayersInCone(
				zombie,
				zombie.cframe.Position,
				runtime.castDirection,
				config.Range,
				config.ArcDot,
				config.SlowMultiplier,
				config.SlowDuration
			)
			zombie.services.BroadcastAbility({
				Kind = "FrostCone",
				Position = zombie.cframe.Position + runtime.castDirection * (config.Range * 0.5),
				Radius = config.Range * 0.55,
				Color = zombie.definition.EffectColor,
			})
			runtime.phase = nil
			runtime.nextUseAt = now + config.Cooldown
			setSpecialState(zombie, SpecialState.None, now)
		end
		return true
	end
	if target and distance >= config.MinimumRange and distance <= config.Range and now >= runtime.nextUseAt then
		runtime.castDirection = direction
		runtime.phase = "Windup"
		runtime.phaseEndsAt = now + config.Windup
		beginSpecial(zombie, SpecialState.Windup, now, target.position, config.Windup)
		return true
	end
	return false
end

ZombieSpecialBehaviors.Rallying = {}

function ZombieSpecialBehaviors.Rallying.Step(zombie, _deltaTime, _target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if now < runtime.nextUseAt then
		return false
	end
	runtime.nextUseAt = now + config.Cooldown
	zombie.services.BuffZombiesInRadius(
		zombie.id,
		zombie.cframe.Position,
		config.Radius,
		config.SpeedMultiplier,
		1,
		config.Duration,
		config.Types
	)
	zombie.services.BroadcastAbility({
		Kind = "Rally",
		Position = zombie.cframe.Position,
		Radius = config.Radius,
		Color = zombie.definition.EffectColor,
	})
	return false
end

ZombieSpecialBehaviors.Hoarder = {}

function ZombieSpecialBehaviors.Hoarder.Initialize(zombie)
	zombie.specialRuntime.stolenCoins = 0
	zombie.specialRuntime.stolenXP = 0
end

function ZombieSpecialBehaviors.Hoarder.Step(zombie, _deltaTime, _target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if now < runtime.nextUseAt then
		return false
	end
	runtime.nextUseAt = now + config.Interval
	local coins, xp = zombie.services.StealRewards(
		zombie.cframe.Position,
		config.Radius,
		config.MaximumDropsPerPulse
	)
	if coins + xp > 0 then
		runtime.stolenCoins += coins
		runtime.stolenXP += xp
		zombie.specialValue = runtime.stolenCoins + runtime.stolenXP
		zombie.services.BroadcastAbility({
			Kind = "Steal",
			Position = zombie.cframe.Position,
			Radius = config.Radius,
			Color = zombie.definition.EffectColor,
		})
	end
	return false
end

function ZombieSpecialBehaviors.Hoarder.OnDeath(zombie)
	local runtime = zombie.specialRuntime
	zombie.services.ReleaseStolenRewards(
		zombie.cframe.Position,
		runtime.stolenCoins or 0,
		runtime.stolenXP or 0,
		zombie.lastDamager,
		zombie.arena.GroundY
	)
end

ZombieSpecialBehaviors.BroodPod = {}

function ZombieSpecialBehaviors.BroodPod.Initialize(zombie)
	local now = workspace:GetServerTimeNow()
	local duration = zombie.definition.Special.HatchDelay
	zombie.specialRuntime.phase = "Incubating"
	zombie.specialRuntime.phaseEndsAt = now + duration
	beginSpecial(zombie, SpecialState.Countdown, now, zombie.cframe.Position, duration)
end

function ZombieSpecialBehaviors.BroodPod.Step(zombie, _deltaTime, _target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	zombie.state = ZombieProtocol.State.Idle
	zombie.specialValue = math.max(runtime.phaseEndsAt - now, 0)
	if runtime.phase == "Incubating" and now >= runtime.phaseEndsAt then
		runtime.phase = "Hatched"
		for index = 1, config.Count do
			local angle = math.pi * 2 * index / config.Count
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.SpawnRadius
			zombie.services.QueueSpawn(config.SpawnType, zombie.cframe.Position + offset, zombie.arena)
		end
		zombie.services.BroadcastAbility({
			Kind = "Hatch",
			Position = zombie.cframe.Position,
			Radius = config.SpawnRadius,
			Color = zombie.definition.EffectColor,
		})
		zombie.health = 0
	end
	return true
end

ZombieSpecialBehaviors.Martyr = {}

function ZombieSpecialBehaviors.Martyr.OnDeath(zombie)
	local config = zombie.definition.Special
	zombie.services.BuffZombiesInRadius(
		zombie.id,
		zombie.cframe.Position,
		config.Radius,
		config.SpeedMultiplier,
		config.DamageMultiplier,
		config.Duration
	)
	zombie.services.BroadcastAbility({
		Kind = "MartyrBuff",
		Position = zombie.cframe.Position,
		Radius = config.Radius,
		Color = zombie.definition.EffectColor,
	})
end

ZombieSpecialBehaviors.Stalker = {}

function ZombieSpecialBehaviors.Stalker.Step(zombie, _deltaTime, target)
	local config = zombie.definition.Special
	if not target then
		zombie.specialMoveSpeedMultiplier = 1
		return false
	end
	local offset = zombie.cframe.Position - target.position
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	if horizontal.Magnitude <= 0.001 then
		return false
	end
	local watched = target.lookVector:Dot(horizontal.Unit) >= config.WatchedDotThreshold
	zombie.specialMoveSpeedMultiplier = if watched then config.WatchedSpeedMultiplier else config.UnwatchedSpeedMultiplier
	return false
end

ZombieSpecialBehaviors.Juggernaut = {}

function ZombieSpecialBehaviors.Juggernaut.Initialize(zombie)
	zombie.specialRuntime.momentum = 0
	zombie.specialRuntime.lastDamagedAt = 0
end

function ZombieSpecialBehaviors.Juggernaut.Step(zombie, deltaTime, target, now)
	local config = zombie.definition.Special
	local runtime = zombie.specialRuntime
	if runtime.resetPending and now > runtime.lastDamagedAt then
		runtime.resetPending = false
		runtime.momentum = 0
	elseif target and now >= runtime.lastDamagedAt + config.ResetDelay then
		runtime.momentum = math.min(runtime.momentum + deltaTime / config.BuildTime, 1)
	end
	zombie.specialMoveSpeedMultiplier = 1 + (config.MaximumSpeedMultiplier - 1) * runtime.momentum
	zombie.knockbackResistance = config.MaximumKnockbackResistance * runtime.momentum
	zombie.specialValue = runtime.momentum
	return false
end

function ZombieSpecialBehaviors.Juggernaut.ModifyDamage(zombie, amount, _hitOrigin, _damageContext, now)
	local runtime = zombie.specialRuntime
	runtime.lastDamagedAt = now
	runtime.resetPending = true
	return amount, false
end

return ZombieSpecialBehaviors
