local AbilityLevelScaling = {}

local DEFAULT_UPGRADE_EXPONENT = 1.05
local WEAPON_UPGRADE_EXPONENT = 1.1
local WEAPON_AUTHORED_MAXIMUM_PROGRESS = 49
local STARTING_PROGRESS = -2

local function getProgress(level: number, maxLevel: number, exponent: number, maximumProgress: number): number
	local clampedLevel = math.clamp(math.floor(level), 1, maxLevel)
	local upgradeCount = maxLevel - 1
	if upgradeCount <= 0 then
		return 0
	end

	local normalizedProgress = (clampedLevel - 1) / upgradeCount
	-- Level one intentionally begins below the old baseline. The curve then catches up to the existing
	-- maximum so early abilities need investment while a completed build keeps its authored ceiling.
	return STARTING_PROGRESS + (maximumProgress - STARTING_PROGRESS) * normalizedProgress ^ exponent
end

function AbilityLevelScaling.GetProgress(level: number, maxLevel: number): number
	return getProgress(level, maxLevel, DEFAULT_UPGRADE_EXPONENT, maxLevel - 1)
end

function AbilityLevelScaling.GetWeaponProgress(level: number, maxLevel: number): number
	-- Weapons finish in 25 levels, but their formulas were balanced around 49 upgrade steps. Their
	-- slightly back-loaded curve makes each investment matter without exceeding the established cap.
	return getProgress(level, maxLevel, WEAPON_UPGRADE_EXPONENT, WEAPON_AUTHORED_MAXIMUM_PROGRESS)
end

return AbilityLevelScaling
