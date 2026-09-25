local RunProgressionConfig = {
	-- Run levels are transient. This curve deliberately grows sub-exponentially enough that later
	-- hordes still produce visible progress without letting early levels arrive all at once.
	XP = {
		-- Ten XP makes the first level arrive after roughly two basic zombie drops; the unchanged
		-- growth terms quickly take over so this accelerates the opening more than the late run.
		BaseRequirement = 10,
		LinearGrowth = 8,
		CurveCoefficient = 1.5,
		CurvePower = 1.35,
		MaximumLevel = 200,
	},

	Pickups = {
		Ownership = "FreeForAll", -- Change to "Killer" to reserve both reward types for the killing player.
		XP = {
			PickupRadius = 2.4,
			MagnetRadius = 15,
			MagnetInitialSpeed = 16,
			MagnetAcceleration = 52,
			Lifetime = 45,
			ScatterRadius = NumberRange.new(1.5, 3.75),
			ScatterDuration = NumberRange.new(0.35, 0.55),
			-- Scale and tier multipliers make the single XP drop visually outweigh a multi-coin burst.
			BaseVisualScale = 1.25,
			VisualHeight = 1.35,
			VisualTiers = {
				{ Name = "Blue", MinimumValue = 1, Color = Color3.fromRGB(55, 145, 255), ScaleMultiplier = 1 },
				{ Name = "Green", MinimumValue = 12, Color = Color3.fromRGB(68, 235, 132), ScaleMultiplier = 1.12 },
				{ Name = "PinkPurple", MinimumValue = 24, Color = Color3.fromRGB(226, 79, 255), ScaleMultiplier = 1.25 },
			},
			MaximumActive = 240,
		},
		Coin = {
			PickupRadius = 2.5,
			MagnetRadius = 12,
			MagnetDuration = 0.42,
			Lifetime = 35,
		},
	},

	Abilities = {
		ChoiceCount = 3,
		-- Permanent ownership is the authoritative gate for new run choices. Keep this escape hatch empty
		-- unless a future global event deliberately makes an ability available without unlocking it.
		AlwaysAvailable = {},
		StartingAbilities = { "Dagger" },
	},

	Spawning = {
		-- The main combat floor is 300x300, so groups should enter from meaningfully beyond immediate attack range.
		MinimumDistance = 45,
		PreferredDistance = NumberRange.new(48, 72),
		AttemptsPerGroup = 24,
		-- Some groups deliberately form in the player's travel lane so endlessly running in one direction
		-- cannot leave the entire horde behind. Velocity wins over facing once the player is actually moving.
		ForwardSpawnChance = 0.3,
		ForwardSpawnConeDegrees = 32,
		MovementHeadingSpeedThreshold = 3,
		-- Non-interception hordes rotate through every surrounding sector instead of repeatedly
		-- sampling the same easy-to-escape side of the player.
		SurroundSectorCount = 8,
		SurroundSectorAdvance = 3,
		SurroundSpawnJitterDegrees = 12,
		DirectedSpawnAttemptFraction = 0.6,
		-- Difficulty never caps: each five-minute step adds cadence pressure, larger hordes, and a
		-- stronger bias toward the highest-threat zombie types available in the current area.
		DifficultyStepSeconds = 300,
		SpawnRateIncreasePerStep = 2,
		GroupSizeBonusPerStep = 3,
		StrongZombieBiasPerStep = 0.65,
		-- Total horde pressure follows the requested sublinear multiplayer curve: players ^ 0.8.
		PlayerCountExponent = 0.8,
		MinimumSpawnInterval = 0.35,
	},
}

function RunProgressionConfig.GetXPRequirement(level: number): number
	local validLevel = math.max(1, math.floor(level))
	local curve = RunProgressionConfig.XP
	local completedLevels = validLevel - 1
	local raw = curve.BaseRequirement
		+ curve.LinearGrowth * completedLevels
		+ curve.CurveCoefficient * completedLevels ^ curve.CurvePower
	-- Five-XP steps are easy to read in the HUD and simple to rebalance.
	return math.max(5, math.floor(raw / 5 + 0.5) * 5)
end

function RunProgressionConfig.GetXPVisualTier(value: number)
	local tiers = RunProgressionConfig.Pickups.XP.VisualTiers
	local selectedTier = tiers[1]
	for _, tier in tiers do
		if value >= tier.MinimumValue then
			selectedTier = tier
		else
			break
		end
	end
	return selectedTier
end

return table.freeze(RunProgressionConfig)
