local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)

local STYLE = {
	Walker = {
		CycleSpeed = 4.5,
		LegSwing = 0.42,
		WalkingArmAngle = math.rad(88),
		WalkingArmBob = math.rad(4),
		WalkingArmSpread = math.rad(7),
		Bob = 0.06,
		Sway = 0.05,
		AttackWindupAngle = math.rad(168),
		AttackStrikeAngle = math.rad(32),
	},
	Runner = {
		CycleSpeed = 8,
		LegSwing = 0.72,
		WalkingArmAngle = math.rad(84),
		WalkingArmBob = math.rad(5),
		WalkingArmSpread = math.rad(8),
		Bob = 0.1,
		Sway = 0.08,
		AttackWindupAngle = math.rad(172),
		AttackStrikeAngle = math.rad(28),
	},
	Brute = {
		CycleSpeed = 3.2,
		LegSwing = 0.3,
		WalkingArmAngle = math.rad(82),
		WalkingArmBob = math.rad(3),
		WalkingArmSpread = math.rad(10),
		Bob = 0.09,
		Sway = 0.09,
		AttackWindupAngle = math.rad(175),
		AttackStrikeAngle = math.rad(24),
	},
}

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

local function smoothStep(value)
	return value * value * (3 - 2 * value)
end

local function getAttackPose(definition, style, attackElapsed)
	local windupDuration = definition.AttackWindupDuration
	local strikeDuration = definition.AttackStrikeDuration
	local recoveryDuration = definition.AttackRecoveryDuration

	if attackElapsed < 0 or attackElapsed >= windupDuration + strikeDuration + recoveryDuration then
		return nil, nil, nil
	end

	if attackElapsed < windupDuration then
		local alpha = smoothStep(math.clamp(attackElapsed / windupDuration, 0, 1))
		return style.WalkingArmAngle + (style.AttackWindupAngle - style.WalkingArmAngle) * alpha, alpha, 0
	end

	if attackElapsed < windupDuration + strikeDuration then
		local strikeAlpha = math.clamp((attackElapsed - windupDuration) / strikeDuration, 0, 1)
		-- Cubic acceleration makes the downward portion noticeably faster than the wind-up.
		local aggressiveAlpha = strikeAlpha * strikeAlpha * strikeAlpha
		return style.AttackWindupAngle
			+ (style.AttackStrikeAngle - style.AttackWindupAngle) * aggressiveAlpha,
			1 - aggressiveAlpha,
			aggressiveAlpha
	end

	local recoveryAlpha = smoothStep(math.clamp(
		(attackElapsed - windupDuration - strikeDuration) / recoveryDuration,
		0,
		1
	))
	return style.AttackStrikeAngle * (1 - recoveryAlpha), 0, 1 - recoveryAlpha
end

function ProceduralAnimator.GetPartOffset(definition, partName, pivotOffset, state, elapsed, attackElapsed)
	local style = getStyle(definition.AnimationStyle)
	local isMoving = state == ZombieProtocol.State.Moving
	local movementWave = if isMoving then math.sin(elapsed * style.CycleSpeed) else 0
	local attackArmAngle, windupAmount, strikeAmount = getAttackPose(definition, style, attackElapsed)
	local isArm = partName == "Left Arm" or partName == "Right Arm"
	local side = if partName == "Left Arm" then -1 else 1

	if state == ZombieProtocol.State.Attacking and attackArmAngle then
		if isArm then
			local spread = style.WalkingArmSpread + math.rad(5) * windupAmount
			return rotateAroundPivot(CFrame.Angles(attackArmAngle, 0, side * spread), pivotOffset)
		elseif partName == "Torso" then
			-- Lean back during wind-up, then drive sharply forward with the strike.
			local torsoAngle = math.rad(12) * windupAmount + math.rad(-30) * strikeAmount
			return CFrame.Angles(torsoAngle, 0, 0)
		end
	end

	if isMoving and isArm then
		-- Both arms stay almost horizontal and forward; only a small bob breaks up the silhouette.
		local armAngle = style.WalkingArmAngle + movementWave * style.WalkingArmBob
		return rotateAroundPivot(CFrame.Angles(armAngle, 0, side * style.WalkingArmSpread), pivotOffset)
	elseif partName == "Right Leg" then
		return rotateAroundPivot(CFrame.Angles(movementWave * style.LegSwing, 0, 0), pivotOffset)
	elseif partName == "Left Leg" then
		return rotateAroundPivot(CFrame.Angles(-movementWave * style.LegSwing, 0, 0), pivotOffset)
	elseif partName == "Torso" then
		local bob = math.abs(movementWave) * style.Bob
		return CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, movementWave * style.Sway)
	elseif partName == "Head" then
		return CFrame.Angles(0, movementWave * style.Sway, 0)
	end

	return CFrame.identity
end

return ProceduralAnimator
