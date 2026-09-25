local RunProgressionConfig = {
	-- Run levels are transient. This curve deliberately grows sub-exponentially enough that later
	-- hordes still produce visible progress without letting early levels arrive all at once.
	XP = {
		BaseRequirement = 24,
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
			VisualHeight = 1.15,
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
		-- A fresh profile needs a viable run before the dormant permanent-unlock flow has awarded anything.
		-- Permanent discoveries expand this pool; these baseline abilities are never persisted as discoveries.
		AlwaysAvailable = { "Dagger", "OrbitingSwords", "Fireball" },
		StartingAbilities = { "Dagger" },
	},

	Spawning = {
		MinimumDistance = 30,
		PreferredDistance = NumberRange.new(34, 52),
		OutsideViewDot = 0.3,
		AttemptsPerGroup = 16,
		ElapsedRampSeconds = 480,
		MaximumElapsedRamp = 1.75,
		PlayersCapPerExtra = 0.55,
		PlayersRatePerExtra = 0.3,
		MinimumSpawnInterval = 0.55,
		MaximumGroupMultiplier = 2,
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

return table.freeze(RunProgressionConfig)
