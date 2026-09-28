local AbilityLevelScaling = {}

<<<<<<< HEAD
local DEFAULT_UPGRADE_EXPONENT = 0.95
local WEAPON_UPGRADE_EXPONENT = 0.8

local function getProgress(level: number, maxLevel: number, exponent: number): number
=======
local EARLY_UPGRADE_EXPONENT = 0.95

function AbilityLevelScaling.GetProgress(level: number, maxLevel: number): number
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
	local clampedLevel = math.clamp(math.floor(level), 1, maxLevel)
	local maximumProgress = maxLevel - 1
	if maximumProgress <= 0 then
		return 0
	end

<<<<<<< HEAD
	local normalizedProgress = (clampedLevel - 1) / maximumProgress
	return maximumProgress * normalizedProgress ^ exponent
end

function AbilityLevelScaling.GetProgress(level: number, maxLevel: number): number
	return getProgress(level, maxLevel, DEFAULT_UPGRADE_EXPONENT)
end

function AbilityLevelScaling.GetWeaponProgress(level: number, maxLevel: number): number
	-- Weapon upgrades earned during a normal run should create a clearly noticeable power increase.
	-- Preserve both the authored level-one baseline and level-50 cap so only the journey is rebalanced.
	return getProgress(level, maxLevel, WEAPON_UPGRADE_EXPONENT)
=======
	-- Keep maximum-level power unchanged while making each early upgrade slightly more valuable.
	-- The exponent is intentionally close to linear so low levels get a gentle boost, not a power spike.
	local normalizedProgress = (clampedLevel - 1) / maximumProgress
	return maximumProgress * normalizedProgress ^ EARLY_UPGRADE_EXPONENT
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
end

return AbilityLevelScaling
