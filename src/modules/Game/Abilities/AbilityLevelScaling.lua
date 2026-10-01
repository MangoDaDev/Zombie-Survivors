local AbilityLevelScaling = {}

local DEFAULT_UPGRADE_EXPONENT = 0.95
local WEAPON_UPGRADE_EXPONENT = 0.8
local WEAPON_AUTHORED_MAXIMUM_PROGRESS = 49

local function getProgress(level: number, maxLevel: number, exponent: number): number
	local clampedLevel = math.clamp(math.floor(level), 1, maxLevel)
	local maximumProgress = maxLevel - 1
	if maximumProgress <= 0 then
		return 0
	end

	local normalizedProgress = (clampedLevel - 1) / maximumProgress
	return maximumProgress * normalizedProgress ^ exponent
end

function AbilityLevelScaling.GetProgress(level: number, maxLevel: number): number
	return getProgress(level, maxLevel, DEFAULT_UPGRADE_EXPONENT)
end

function AbilityLevelScaling.GetWeaponProgress(level: number, maxLevel: number): number
	-- Weapons now finish in 25 levels, but their formulas were balanced around 49 upgrade steps.
	-- Scale the shorter journey back to that authored range so level 1 and maximum-level power stay unchanged.
	local normalizedProgress = getProgress(level, maxLevel, WEAPON_UPGRADE_EXPONENT) / math.max(maxLevel - 1, 1)
	return WEAPON_AUTHORED_MAXIMUM_PROGRESS * normalizedProgress
end

return AbilityLevelScaling
