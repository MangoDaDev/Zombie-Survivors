local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)

local SpecialState = ZombieProtocol.SpecialState

local ZombieSpecialBehaviors = {}

local function setSpecialState(zombie, state, now, targetPosition, value)
	zombie.specialState = state
	zombie.specialStartedAt = now
	local displayTarget = targetPosition or zombie.cframe.Position
	-- Telegraphs are rendered on the area's floor rather than at HumanoidRootPart/pivot height.
	zombie.specialTarget = Vector3.new(displayTarget.X, zombie.area.CFrame.Position.Y, displayTarget.Z)
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
		zombie.definition.MoveSpeed * zombie.moveSpeedMultiplier * (speedMultiplier or 1) * deltaTime,
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
				zombie.services.QueueSpawn(config.SpawnType, zombie.cframe.Position + offset, zombie.area)
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
				Color = zombie.definition.TintColor,
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
			Color = zombie.definition.TintColor,
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
				Color = zombie.definition.TintColor,
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
		-- A splitter always becomes two children; this transform may exceed an area's population cap by one.
		zombie.services.QueueSpawn(config.SpawnType, zombie.cframe.Position + offset, zombie.area, true)
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
			zombie:_constrainToArea()
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
	if not runtime.frenzyTriggered and zombie.health <= zombie.definition.MaxHealth * config.HealthThreshold then
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
			Color = zombie.definition.TintColor,
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
			Color = zombie.definition.TintColor,
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
	zombie:_constrainToArea()
	runtime.nextUseAt = now + config.Cooldown
	beginSpecial(zombie, SpecialState.Dodge, now, zombie.cframe.Position, config.DisplayDuration)
	zombie.services.BroadcastAbility({
		Kind = "Dodge",
		Position = zombie.cframe.Position,
		Color = zombie.definition.TintColor,
	})
	return 0, true
end

function ZombieSpecialBehaviors.Dodger.Step(zombie, _deltaTime, _target, now)
	if zombie.specialState == SpecialState.Dodge and now - zombie.specialStartedAt >= zombie.definition.Special.DisplayDuration then
		setSpecialState(zombie, SpecialState.None, now)
	end
	return false
end

return ZombieSpecialBehaviors
