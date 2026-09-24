local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)

local STYLE = {
	Walker = {
		CycleSpeed = 4.5,
		LimbSwing = 0.42,
		Bob = 0.06,
		Sway = 0.05,
		AttackSwing = 1.05,
	},
	Runner = {
		CycleSpeed = 8,
		LimbSwing = 0.72,
		Bob = 0.1,
		Sway = 0.08,
		AttackSwing = 1.25,
	},
	Brute = {
		CycleSpeed = 3.2,
		LimbSwing = 0.3,
		Bob = 0.09,
		Sway = 0.09,
		AttackSwing = 1.45,
	},
}

local ATTACK_ANIMATION_DURATION = 0.55

local ProceduralAnimator = {}

local function getStyle(styleName)
	return STYLE[styleName] or STYLE.Walker
end

function ProceduralAnimator.GetPartPivotOffset(partName, partSize)
	if partName == "Left Arm" or partName == "Right Arm" then
		-- Arms pivot from the midpoint of their upper half, not their geometric center.
		return Vector3.new(0, partSize.Y * 0.25, 0)
	elseif partName == "Left Leg" or partName == "Right Leg" then
		-- Legs hinge from their top so the hip stays planted while the foot swings.
		return Vector3.new(0, partSize.Y * 0.5, 0)
	end

	return Vector3.zero
end

local function rotateAroundPivot(rotation, pivotOffset)
	return CFrame.new(pivotOffset) * rotation * CFrame.new(-pivotOffset)
end

function ProceduralAnimator.GetPartOffset(styleName, partName, pivotOffset, state, elapsed, attackElapsed)
	local style = getStyle(styleName)
	local isMoving = state == ZombieProtocol.State.Moving
	local movementWave = if isMoving then math.sin(elapsed * style.CycleSpeed) else 0
	local movementSwing = movementWave * style.LimbSwing

	if state == ZombieProtocol.State.Attacking and attackElapsed <= ATTACK_ANIMATION_DURATION then
		local attackAlpha = math.clamp(attackElapsed / ATTACK_ANIMATION_DURATION, 0, 1)
		local attackWave = math.sin(attackAlpha * math.pi)
		if partName == "Left Arm" or partName == "Right Arm" then
			return rotateAroundPivot(CFrame.Angles(-attackWave * style.AttackSwing, 0, 0), pivotOffset)
		elseif partName == "Torso" then
			return CFrame.Angles(-attackWave * 0.18, 0, 0)
		end
	end

	if partName == "Left Arm" or partName == "Right Leg" then
		return rotateAroundPivot(CFrame.Angles(movementSwing, 0, 0), pivotOffset)
	elseif partName == "Right Arm" or partName == "Left Leg" then
		return rotateAroundPivot(CFrame.Angles(-movementSwing, 0, 0), pivotOffset)
	elseif partName == "Torso" then
		local bob = math.abs(movementWave) * style.Bob
		return CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, movementWave * style.Sway)
	elseif partName == "Head" then
		return CFrame.Angles(0, movementWave * style.Sway, 0)
	end

	return CFrame.identity
end

return ProceduralAnimator
