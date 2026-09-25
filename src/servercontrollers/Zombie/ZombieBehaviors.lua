-- Behavior strategies are selected by zombie definitions. New movement or attack
-- styles can be added here without adding type checks to the zombie class.
local ZombieBehaviors = {
	Movement = {},
	Attack = {},
}

function ZombieBehaviors.Movement.DirectChase(zombie, direction, distance, deltaTime, facing)
	local travelDistance = math.min(
		zombie.definition.MoveSpeed * zombie.moveSpeedMultiplier * zombie.statusMoveSpeedMultiplier * deltaTime,
		distance - zombie.definition.AttackRange
	)
	local nextPosition = zombie.cframe.Position + direction * math.max(travelDistance, 0)
	zombie.cframe = CFrame.new(nextPosition) * facing
end

function ZombieBehaviors.Attack.Contact(zombie, targetCandidate, now, distance)
	if zombie.attackInProgress then
		if not zombie.attackDamageApplied and now >= zombie.attackImpactAt then
			-- The hit lands at the end of the visible downward strike, not at wind-up start.
			if targetCandidate
				and targetCandidate.humanoid.Health > 0
				and distance <= zombie.definition.AttackRange * 1.15
			then
				-- The shared method reports only authoritative post-mitigation health loss to defensive passives.
				zombie:DamagePlayer(targetCandidate, zombie.definition.AttackDamage)
			end
			zombie.attackDamageApplied = true
		end

		if now >= zombie.attackEndsAt then
			zombie.attackInProgress = false
		end

		return true
	end

	if not targetCandidate or distance > zombie.definition.AttackRange or now < zombie.nextAttackAt then
		return false
	end

	local definition = zombie.definition
	zombie.attackInProgress = true
	zombie.attackDamageApplied = false
	zombie.attackSequence += 1
	zombie.attackStartedAt = now
	zombie.attackImpactAt = now + definition.AttackWindupDuration + definition.AttackStrikeDuration
	zombie.attackEndsAt = zombie.attackImpactAt + definition.AttackRecoveryDuration
	zombie.nextAttackAt = now + definition.AttackCooldown

	return true
end

return ZombieBehaviors
