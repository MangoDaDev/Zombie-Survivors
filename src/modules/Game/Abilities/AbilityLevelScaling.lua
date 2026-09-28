local AbilityLevelScaling = {}

local EARLY_UPGRADE_EXPONENT = 0.95

function AbilityLevelScaling.GetProgress(level: number, maxLevel: number): number
	local clampedLevel = math.clamp(math.floor(level), 1, maxLevel)
	local maximumProgress = maxLevel - 1
	if maximumProgress <= 0 then
		return 0
	end

	-- Keep maximum-level power unchanged while making each early upgrade slightly more valuable.
	-- The exponent is intentionally close to linear so low levels get a gentle boost, not a power spike.
	local normalizedProgress = (clampedLevel - 1) / maximumProgress
	return maximumProgress * normalizedProgress ^ EARLY_UPGRADE_EXPONENT
end

return AbilityLevelScaling
