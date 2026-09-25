local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)
local ZombieBehaviors = require(script.Parent.ZombieBehaviors)
local ZombieSpecialBehaviors = require(script.Parent.ZombieSpecialBehaviors)

local TARGET_REFRESH_INTERVAL = 0.5
local TARGET_HYSTERESIS = 1.15
local KNOCKBACK_DECAY = 9
local MAXIMUM_KNOCKBACK_SPEED = 28

local Zombie = {}
Zombie.__index = Zombie

function Zombie.new(id, typeName, definition, spawnCFrame, area, variation, boundaryRadius, services)
	local self = setmetatable({}, Zombie)

	self.id = id
	self.typeName = typeName
	self.definition = definition
	self.areaId = area.Id
	self.area = area
	self.cframe = spawnCFrame
	self.health = definition.MaxHealth
	self.scale = variation.Scale
	self.moveSpeedMultiplier = variation.MoveSpeed
	self.turnSpeedMultiplier = variation.TurnSpeed
	self.animationSpeedMultiplier = variation.AnimationSpeed
	self.boundaryRadius = boundaryRadius * variation.Scale
	self.knockbackVelocity = Vector3.zero
	self.state = ZombieProtocol.State.Idle
	self.target = nil
	self.attackSequence = 0
	self.attackStartedAt = 0
	self.attackImpactAt = 0
	self.attackEndsAt = 0
	self.attackInProgress = false
	self.attackDamageApplied = false
	self.nextAttackAt = 0
	self.services = services
	self.onPlayerDamaged = services.OnPlayerDamaged
	self.movementBehavior = ZombieBehaviors.Movement[definition.MovementBehavior]
		or ZombieBehaviors.Movement.DirectChase
	self.attackBehavior = ZombieBehaviors.Attack[definition.AttackBehavior]
		or ZombieBehaviors.Attack.Contact
	self.specialBehavior = definition.SpecialBehavior and ZombieSpecialBehaviors[definition.SpecialBehavior] or nil
	self.specialRuntime = {
		nextUseAt = workspace:GetServerTimeNow() + services.Random:NextNumber(1.5, 3.5),
	}
	self.specialState = ZombieProtocol.SpecialState.None
	self.specialSequence = 0
	self.specialStartedAt = 0
	self.specialTarget = spawnCFrame.Position
	self.specialValue = 0
	if self.specialBehavior and self.specialBehavior.Initialize then
		self.specialBehavior.Initialize(self)
	end
	-- Stagger target searches so a large wave does not rescan players on one frame.
	self.nextTargetRefreshAt = (id % 10) * (TARGET_REFRESH_INTERVAL / 10)

	return self
end

function Zombie:DamagePlayer(targetCandidate, amount)
	if not targetCandidate or targetCandidate.humanoid.Health <= 0 then
		return 0
	end
	local healthBefore = targetCandidate.humanoid.Health
	targetCandidate.humanoid:TakeDamage(amount)
	local actualDamage = math.max(healthBefore - targetCandidate.humanoid.Health, 0)
	if actualDamage > 0 and self.onPlayerDamaged then
		self.onPlayerDamaged(self, targetCandidate.player, actualDamage)
	end
	return actualDamage
end

local function getHorizontalOffset(fromPosition, toPosition)
	return Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
end

function Zombie:_constrainToArea()
	local area = self.area
	local localPosition = area.CFrame:PointToObjectSpace(self.cframe.Position)
	-- Keep the full rendered model, not only its simulation pivot, within its assigned spawn area.
	local margin = self.boundaryRadius
	local halfSize = area.Size * 0.5
	local clampedLocalPosition = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X + margin, halfSize.X - margin),
		localPosition.Y,
		math.clamp(localPosition.Z, -halfSize.Y + margin, halfSize.Y - margin)
	)
	local clampedWorldPosition = area.CFrame:PointToWorldSpace(clampedLocalPosition)
	self.cframe = CFrame.new(clampedWorldPosition) * self.cframe.Rotation
end

function Zombie:_refreshTarget(candidates, candidateLookup, now)
	local currentCandidate = self.target and candidateLookup[self.target]
	if currentCandidate then
		local distance = getHorizontalOffset(self.cframe.Position, currentCandidate.position).Magnitude
		if distance <= self.definition.AggroDistance * TARGET_HYSTERESIS then
			self.nextTargetRefreshAt = now + TARGET_REFRESH_INTERVAL
			return currentCandidate
		end
	end

	self.target = nil
	local nearestCandidate
	local nearestDistance = self.definition.AggroDistance

	for _, candidate in candidates do
		local distance = getHorizontalOffset(self.cframe.Position, candidate.position).Magnitude
		if distance <= nearestDistance then
			nearestDistance = distance
			nearestCandidate = candidate
		end
	end

	if nearestCandidate then
		self.target = nearestCandidate.player
	end
	self.nextTargetRefreshAt = now + TARGET_REFRESH_INTERVAL

	return nearestCandidate
end

function Zombie:Step(deltaTime, candidates, candidateLookup, now)
	if self.health <= 0 then
		return
	end

	-- Damage applies an impulse to this server-owned CFrame simulation instead of relying on client
	-- physics. The fast exponential decay produces a readable shove without permanently kiting enemies.
	if self.knockbackVelocity.Magnitude > 0.02 then
		self.cframe += self.knockbackVelocity * deltaTime
		self.knockbackVelocity *= math.exp(-KNOCKBACK_DECAY * deltaTime)
	else
		self.knockbackVelocity = Vector3.zero
	end
	self:_constrainToArea()

	local targetCandidate = self.target and candidateLookup[self.target]
	if now >= self.nextTargetRefreshAt or not targetCandidate then
		targetCandidate = self:_refreshTarget(candidates, candidateLookup, now)
	end

	if not targetCandidate then
		if self.specialBehavior and self.specialBehavior.Step then
			local consumed = self.specialBehavior.Step(
				self,
				deltaTime,
				nil,
				now,
				math.huge,
				self.cframe.LookVector,
				self.cframe.Rotation,
				candidates
			)
			if consumed then
				self:_constrainToArea()
				return
			end
		end
		local isFinishingAttack = self.attackBehavior(self, nil, now, math.huge)
		self.state = if isFinishingAttack then ZombieProtocol.State.Attacking else ZombieProtocol.State.Idle
		return
	end

	local currentPosition = self.cframe.Position
	local offset = getHorizontalOffset(currentPosition, targetCandidate.position)
	local distance = offset.Magnitude
	local direction = if distance > 0.001 then offset.Unit else self.cframe.LookVector
	local facing = self.cframe.Rotation
	if distance > 0.001 then
		local desiredFacing = CFrame.lookAt(currentPosition, currentPosition + direction)
		local turnSpeed = self.definition.TurnSpeed * self.turnSpeedMultiplier
		local turnAlpha = 1 - math.exp(-turnSpeed * deltaTime)
		facing = self.cframe:Lerp(desiredFacing, turnAlpha).Rotation
	end

	if self.specialBehavior and self.specialBehavior.Step then
		local consumed = self.specialBehavior.Step(
			self,
			deltaTime,
			targetCandidate,
			now,
			distance,
			direction,
			facing,
			candidates
		)
		if consumed then
			self:_constrainToArea()
			return
		end
	end

	local isAttacking = self.attackBehavior(self, targetCandidate, now, distance)
	if isAttacking then
		self.cframe = CFrame.new(currentPosition) * facing
		self.state = ZombieProtocol.State.Attacking
		return
	end

	if distance <= self.definition.AttackRange then
		self.cframe = CFrame.new(currentPosition) * facing
		self.state = ZombieProtocol.State.Idle
		return
	end

	-- The authoritative enemy has no physics body; its complete movement state is a CFrame.
	self.movementBehavior(self, direction, distance, deltaTime, facing)
	self:_constrainToArea()
	self.state = ZombieProtocol.State.Moving
end

function Zombie:TakeDamage(amount, hitOrigin, knockbackImpulse, damageContext, now)
	if type(amount) ~= "number" or amount <= 0 or self.health <= 0 then
		return false
	end

	local appliedAmount = amount
	local handled = false
	if self.specialBehavior and self.specialBehavior.ModifyDamage then
		appliedAmount, handled = self.specialBehavior.ModifyDamage(
			self,
			amount,
			hitOrigin,
			damageContext,
			now or workspace:GetServerTimeNow()
		)
	end
	appliedAmount = math.max(appliedAmount or 0, 0)
	self.health = math.max(self.health - appliedAmount, 0)
	if appliedAmount > 0 and typeof(hitOrigin) == "Vector3" and type(knockbackImpulse) == "number" and knockbackImpulse > 0 then
		local offset = self.cframe.Position - hitOrigin
		local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
		if horizontalOffset.Magnitude > 0.001 then
			self.knockbackVelocity += horizontalOffset.Unit * knockbackImpulse
			if self.knockbackVelocity.Magnitude > MAXIMUM_KNOCKBACK_SPEED then
				self.knockbackVelocity = self.knockbackVelocity.Unit * MAXIMUM_KNOCKBACK_SPEED
			end
		end
	end
	if appliedAmount > 0 and self.specialBehavior and self.specialBehavior.OnDamaged then
		self.specialBehavior.OnDamaged(self, appliedAmount, now or workspace:GetServerTimeNow())
	end
	return appliedAmount > 0 or handled
end

function Zombie:IsDead()
	return self.health <= 0
end

function Zombie:OnDeath()
	if self.specialBehavior and self.specialBehavior.OnDeath then
		self.specialBehavior.OnDeath(self)
	end
end

function Zombie:ApplySeparation(displacement)
	-- Separation remains CFrame-only and never creates a physical zombie assembly.
	self.cframe += displacement
	self:_constrainToArea()
end

function Zombie:GetSpawnPacket()
	return {
		self.id,
		self.typeName,
		self.cframe,
		self.state,
		self.attackSequence,
		self.attackStartedAt,
		self.scale,
		self.animationSpeedMultiplier,
		self.health,
		self.definition.MaxHealth,
		self.specialState,
		self.specialSequence,
		self.specialStartedAt,
		self.specialTarget,
		self.specialValue,
	}
end

function Zombie:GetUpdatePacket()
	return {
		self.id,
		self.cframe,
		self.state,
		self.attackSequence,
		self.attackStartedAt,
		self.health,
		self.definition.MaxHealth,
		self.specialState,
		self.specialSequence,
		self.specialStartedAt,
		self.specialTarget,
		self.specialValue,
	}
end

return Zombie
