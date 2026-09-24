-- Behavior strategies are selected by zombie definitions. New movement or attack
-- styles can be added here without adding type checks to the zombie class.
local ZombieBehaviors = {
	Movement = {},
	Attack = {},
}

function ZombieBehaviors.Movement.DirectChase(zombie, direction, distance, deltaTime, facing)
	local travelDistance = math.min(
		zombie.definition.MoveSpeed * deltaTime,
		distance - zombie.definition.AttackRange
	)
	local nextPosition = zombie.cframe.Position + direction * math.max(travelDistance, 0)
	zombie.cframe = CFrame.new(nextPosition) * facing
end

function ZombieBehaviors.Attack.Contact(zombie, targetCandidate, now)
	if now < zombie.nextAttackAt then
		return
	end

	-- Damage remains a server-only strategy even though the matching pose is procedural on clients.
	targetCandidate.humanoid:TakeDamage(zombie.definition.AttackDamage)
	zombie.attackSequence += 1
	zombie.nextAttackAt = now + zombie.definition.AttackCooldown
end

return ZombieBehaviors
