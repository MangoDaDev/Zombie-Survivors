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
		-- Skipped-round zombies remain alive but no longer block later rounds. Population must become the
		-- main source of later-round pressure, so the extra growth eases in mathematically instead of
		-- switching on at a particular round.
		BaseZombieCount = 4,
		ZombieCountGrowthPerRound = 1,
		LateZombieCountGrowthPerRound = 0.3,
		ZombieCountGrowthRampRounds = 6,
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
		-- Bosses are deliberately fifteen rounds apart. Each milestone gets a short warning, a
		-- manageable ring wave, and a telegraphed entrance instead of revealing the full roster early.
		BossEncounters = {
			[15] = {
				Round = 15,
				BossType = "Boss",
				BossDistance = 48,
				RingType = "Walker",
				RingRadius = 30,
				BaseRingCount = 12,
				RingCountPerAdditionalPlayer = 4,
				MaximumRingCount = 24,
				RingMoveSpeedMultiplier = 0.45,
				BuildupDuration = 4.5,
				EntranceDuration = 2.6,
			},
			[30] = {
				Round = 30,
				BossType = "PlagueMatron",
				BossDistance = 50,
				RingType = "Walker",
				RingRadius = 32,
				BaseRingCount = 15,
				RingCountPerAdditionalPlayer = 4,
				MaximumRingCount = 27,
				RingMoveSpeedMultiplier = 0.52,
				BuildupDuration = 5,
				EntranceDuration = 2.8,
			},
			[45] = {
				Round = 45,
				BossType = "RiftStalker",
				BossDistance = 52,
				RingType = "Walker",
				RingRadius = 34,
				BaseRingCount = 18,
				RingCountPerAdditionalPlayer = 4,
				MaximumRingCount = 30,
				RingMoveSpeedMultiplier = 0.58,
				BuildupDuration = 5.25,
				EntranceDuration = 2.8,
			},
			[60] = {
				Round = 60,
				BossType = "BoneColossus",
				BossDistance = 54,
				RingType = "Walker",
				RingRadius = 36,
				BaseRingCount = 21,
				RingCountPerAdditionalPlayer = 4,
				MaximumRingCount = 33,
				RingMoveSpeedMultiplier = 0.64,
				BuildupDuration = 5.5,
				EntranceDuration = 3,
			},
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
		-- Strong archetypes still become more common, but this stays secondary to the accelerating horde
		-- size so later rounds feel denser rather than being dominated by stat-heavy enemies.
		StrongZombieBiasPerStep = 0.2,
		-- Assigned group size follows sublinear multiplayer scaling so extra party members add pressure
		-- without multiplying the round linearly.
		PlayerCountExponent = 0.8,
	},
}

function RunProgressionConfig.GetBossEncounter(roundNumber: number)
	if type(roundNumber) ~= "number" or roundNumber % 1 ~= 0 then
		return nil
	end
	return RunProgressionConfig.Rounds.BossEncounters[roundNumber]
end

function RunProgressionConfig.GetRoundZombieCount(roundNumber: number, playerCount: number): number
	local validRound = math.max(1, math.floor(roundNumber))
	local validPlayerCount = math.max(1, math.floor(playerCount))
	local rounds = RunProgressionConfig.Rounds
	local completedRounds = validRound - 1
	-- x^2 / (x + ramp) starts gently and approaches linear growth, adding late density without an
	-- arbitrary round cutoff or the runaway counts produced by an uncapped power curve.
	local lateGrowth = rounds.LateZombieCountGrowthPerRound
		* completedRounds
		* completedRounds
		/ (completedRounds + rounds.ZombieCountGrowthRampRounds)
	local singlePlayerCount = rounds.BaseZombieCount
		+ completedRounds * rounds.ZombieCountGrowthPerRound
		+ lateGrowth
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
