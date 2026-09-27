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
		-- FreeForAll gives every present player a private claim on each coin/XP drop; another player's claim cannot consume it.
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
		-- Once a build has at least three upgradeable abilities, at most one card may introduce
		-- something new. This chance falls as the ten run slots fill so established builds develop.
		NewOfferChanceAtEmpty = 0.4,
		NewOfferChanceAtFull = 0.08,
		-- Permanent ownership is the authoritative gate for new run choices. Keep this escape hatch empty
		-- unless a future global event deliberately makes an ability available without unlocking it.
		AlwaysAvailable = {},
	},

	Rounds = {
		-- A round owns one finite assigned group, delivered in paced reinforcements rather than one spike.
		-- Skipped-round zombies remain alive but no longer block later rounds.
		BaseZombieCount = 4,
		ZombieCountGrowthPerRound = 1,
		FirstRoundDelay = 1.5,
		IntermissionDuration = 3,
		InitialBatchSize = 4,
		ReinforcementBatchSize = 3,
		ReinforcementInterval = 2.25,
		-- Keep skip votes deliberate across round boundaries, especially when one player can pass a vote alone.
		SkipVoteCooldown = 8,
		-- These values govern threat unlocks and strength bias, not player movement or responsiveness.
		RoundDurationEquivalent = 22,
		DifficultyRoundsPerStep = 14,
		MaximumClusterSize = 4,
		BossEncounter = {
			-- Round 15 is a bespoke encounter instead of a weighted wave: one boss approaches while
			-- slow Walkers form a readable arena ring around the living party.
			Round = 15,
			BossType = "Boss",
			BossDistance = 48,
			RingType = "Walker",
			RingRadius = 30,
			BaseRingCount = 12,
			RingCountPerAdditionalPlayer = 4,
			MaximumRingCount = 24,
			RingMoveSpeedMultiplier = 0.45,
		},
	},

	Spawning = {
		-- The main combat floor is 300x300, so groups should enter from meaningfully beyond immediate attack range.
		GroupRadius = 12,
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
		-- Round progression replaces the old continuous spawn clock while retaining the same weighted
		-- enemy unlock curve and increasingly strong-enemy bias.
		StrongZombieBiasPerStep = 0.4,
		-- Assigned group size follows sublinear multiplayer scaling so extra party members add pressure
		-- without multiplying the round linearly.
		PlayerCountExponent = 0.8,
	},
}

function RunProgressionConfig.GetRoundZombieCount(roundNumber: number, playerCount: number): number
	local validRound = math.max(1, math.floor(roundNumber))
	local validPlayerCount = math.max(1, math.floor(playerCount))
	local rounds = RunProgressionConfig.Rounds
	local singlePlayerCount = rounds.BaseZombieCount + (validRound - 1) * rounds.ZombieCountGrowthPerRound
	return math.max(
		1,
		math.floor(singlePlayerCount * validPlayerCount ^ RunProgressionConfig.Spawning.PlayerCountExponent + 0.5)
	)
end

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
