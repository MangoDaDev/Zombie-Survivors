-- Zombie-specific balance, timed spawn weighting, and presentation data lives here so the
-- simulation, networking, and rendering code never need type-specific spawn tables.
local ZOMBIE_MOVE_SPEED_MULTIPLIER = 1.7
local ZOMBIE_AGGRO_DISTANCE_MULTIPLIER = 3.5
local ZOMBIE_DAMAGE_MULTIPLIER = 1 / 3
local XP_ADVANTAGE_PER_THREAT_LEVEL = 2

local function define(name, overrides)
	local definition = {
		-- Every named type owns an authored Studio model. Runtime code only clones this exact template.
		AssetName = name,
		MaxHealth = 100,
		XPValue = 5,
		CoinValue = 1,
		ThreatLevel = 1,
		MoveSpeed = 8,
		TurnSpeed = 8,
		AggroDistance = 70,
		-- Melee range is an authored center-to-center contact distance. Keep larger enemies' extra
		-- reach explicit in their definitions instead of applying another global size/range inflation.
		AttackRange = 4.5,
		AttackDamage = 4,
		DamageMultiplier = ZOMBIE_DAMAGE_MULTIPLIER,
		AttackCooldown = 1.25,
		AttackWindupDuration = 0.55,
		AttackStrikeDuration = 0.18,
		AttackRecoveryDuration = 0.25,
		SeparationRadius = 1.6,
		ModelScale = 1,
		EffectColor = Color3.fromRGB(120, 170, 92),
		MovementBehavior = "DirectChase",
		AttackBehavior = "Contact",
		AnimationStyle = "Walker",
		SpawnWeight = 0,
		SpawnUnlockTime = 0,
		SpawnRampDuration = 60,
		SpawnGrowthPerMinute = 0,
		SummonedOnly = false,
	}
	for key, value in overrides do
		definition[key] = value
	end
	local threatLevel = definition.ThreatLevel
	if type(threatLevel) == "number" and threatLevel >= 1 then
		-- Squaring threat keeps dangerous archetypes valuable while cutting the weakest tiers most sharply;
		-- keep XP on its existing independent curve so this coin rebalance does not slow run progression.
		local coinRewardFloor = threatLevel * threatLevel
		local xpRewardFloor = threatLevel * (threatLevel + 1) + threatLevel * XP_ADVANTAGE_PER_THREAT_LEVEL
		definition.CoinValue = math.max(math.floor(definition.CoinValue), coinRewardFloor)
		definition.XPValue = math.max(math.floor(definition.XPValue), xpRewardFloor)
	end
	definition.MoveSpeed *= ZOMBIE_MOVE_SPEED_MULTIPLIER
	definition.AggroDistance *= ZOMBIE_AGGRO_DISTANCE_MULTIPLIER
	return definition
end

local ZombieDefinitions = {
	-- The two immediately available archetypes must fall quickly before the player earns an upgrade:
	-- these values keep the default level-one Dagger at three hits for a Walker and two for a Runner.
	Walker = define("Walker", { MaxHealth = 50, SpawnWeight = 50 }),
	Runner = define("Runner", {
		MaxHealth = 40, XPValue = 4, CoinValue = 3, MoveSpeed = 14, TurnSpeed = 12, ThreatLevel = 2,
		AggroDistance = 90, AttackRange = 4, AttackDamage = 3, AttackCooldown = 0.8,
		AttackWindupDuration = 0.4, AttackStrikeDuration = 0.14, AttackRecoveryDuration = 0.18,
		SeparationRadius = 1.55, AnimationStyle = "Runner", EffectColor = Color3.fromRGB(158, 190, 105),
		SpawnWeight = 18, SpawnGrowthPerMinute = 0.02,
	}),
	Brute = define("Brute", {
		MaxHealth = 300, XPValue = 14, CoinValue = 12, MoveSpeed = 5.5, TurnSpeed = 5, ThreatLevel = 3,
		AggroDistance = 65, AttackRange = 6, AttackDamage = 9, AttackCooldown = 2.2,
		AttackWindupDuration = 0.75, AttackStrikeDuration = 0.22, AttackRecoveryDuration = 0.35,
		SeparationRadius = 1.85, AnimationStyle = "Brute", EffectColor = Color3.fromRGB(104, 139, 75),
		SpawnWeight = 3, SpawnUnlockTime = 60, SpawnGrowthPerMinute = 0.08,
	}),

	Spitter = define("Spitter", {
		MaxHealth = 65, XPValue = 7, CoinValue = 5, ThreatLevel = 2, MoveSpeed = 5.5,
		EffectColor = Color3.fromRGB(120, 225, 62), SpecialBehavior = "Spitter",
		SpawnWeight = 6, SpawnUnlockTime = 45, SpawnGrowthPerMinute = 0.05,
		Special = { Range = 34, MinimumRange = 10, Cooldown = 3.8, Windup = 0.8, ProjectileSpeed = 32, ImpactRadius = 3.5, Damage = 8 },
	}),
	Charger = define("Charger", {
		MaxHealth = 150, XPValue = 9, CoinValue = 7, ThreatLevel = 3, MoveSpeed = 9, AttackDamage = 6,
		EffectColor = Color3.fromRGB(220, 87, 52), SpecialBehavior = "Charger", AnimationStyle = "Runner",
		SpawnWeight = 4, SpawnUnlockTime = 120, SpawnGrowthPerMinute = 0.08,
		Special = { MinimumRange = 9, MaximumRange = 28, Windup = 0.9, ChargeSpeed = 34, ChargeDuration = 0.85, HitRadius = 3.5, Damage = 13, MissRecovery = 1.25, RecoveryDamageMultiplier = 1.5, Cooldown = 4.5 },
	}),
	Screamer = define("Screamer", {
		MaxHealth = 55, XPValue = 10, CoinValue = 7, ThreatLevel = 3, MoveSpeed = 5,
		EffectColor = Color3.fromRGB(196, 94, 220), SpecialBehavior = "Screamer",
		SpawnWeight = 2, SpawnUnlockTime = 240, SpawnGrowthPerMinute = 0.1,
		Special = { Cooldown = 13, Windup = 1.4, MinimumCount = 2, MaximumCount = 3, SpawnRadius = 4.5, SpawnType = "Walker" },
	}),
	Tank = define("Tank", {
		MaxHealth = 850, XPValue = 34, CoinValue = 24, ThreatLevel = 5, MoveSpeed = 3.4, TurnSpeed = 3.5,
		AttackDamage = 14, AttackRange = 7, SeparationRadius = 2.4, ModelScale = 1.35,
		EffectColor = Color3.fromRGB(94, 80, 70), SpecialBehavior = "Tank", AnimationStyle = "Brute",
		SpawnWeight = 1, SpawnUnlockTime = 300, SpawnGrowthPerMinute = 0.14,
		Special = { Radius = 13, Damage = 18, Windup = 1.25, Cooldown = 6.5 },
	}),
	Leaper = define("Leaper", {
		MaxHealth = 60, XPValue = 7, CoinValue = 5, ThreatLevel = 2, MoveSpeed = 10,
		EffectColor = Color3.fromRGB(246, 184, 58), SpecialBehavior = "Leaper", AnimationStyle = "Runner",
		SpawnWeight = 4, SpawnUnlockTime = 60, SpawnGrowthPerMinute = 0.05,
		Special = { MinimumRange = 8, MaximumRange = 25, PredictionTime = 0.4, Windup = 0.45, LeapDuration = 0.7, LeapSpeed = 31, HitRadius = 3.2, Damage = 9, Cooldown = 3.5 },
	}),
	Shielder = define("Shielder", {
		MaxHealth = 270, XPValue = 15, CoinValue = 11, ThreatLevel = 4, MoveSpeed = 5, TurnSpeed = 5,
		ModelScale = 1.08, EffectColor = Color3.fromRGB(70, 128, 190), SpecialBehavior = "Shielder",
		-- Delay this build-check enemy until after the first boss so automatic-weapon builds have time to
		-- develop alternatives; it remains rare while its normal one-minute spawn ramp fills.
		AnimationStyle = "Brute", SpawnWeight = 2, SpawnUnlockTime = 330, SpawnGrowthPerMinute = 0.11,
		-- Frontal direct hits must always make progress. A strong reduction preserves the shield role
		-- without making solo builds that lack an explicit bypass effectively unable to kill it.
		Special = { FrontDotThreshold = 0.15, FrontDamageMultiplier = 0.35 },
	}),
	Bomber = define("Bomber", {
		MaxHealth = 60, XPValue = 8, CoinValue = 6, ThreatLevel = 3, MoveSpeed = 9,
		EffectColor = Color3.fromRGB(244, 73, 58), SpecialBehavior = "Bomber", AnimationStyle = "Runner",
		SpawnWeight = 2, SpawnUnlockTime = 240, SpawnGrowthPerMinute = 0.1,
		Special = { TriggerRange = 9, Countdown = 2.2, Radius = 11, Damage = 28, FriendlyFireDamage = 75 },
	}),
	Grabber = define("Grabber", {
		MaxHealth = 145, XPValue = 10, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 5.5,
		EffectColor = Color3.fromRGB(56, 166, 158), SpecialBehavior = "Grabber",
		SpawnWeight = 3, SpawnUnlockTime = 150, SpawnGrowthPerMinute = 0.08,
		Special = { MinimumRange = 5, Range = 20, Windup = 0.75, Damage = 5, PullSpeed = 34, UpwardSpeed = 5, Cooldown = 5 },
	}),
	Summoner = define("Summoner", {
		MaxHealth = 180, XPValue = 16, CoinValue = 12, ThreatLevel = 4, MoveSpeed = 3.2, ModelScale = 1.12,
		EffectColor = Color3.fromRGB(102, 67, 176), SpecialBehavior = "Summoner", AnimationStyle = "Brute",
		SpawnWeight = 1.5, SpawnUnlockTime = 300, SpawnGrowthPerMinute = 0.12,
		Special = { Cooldown = 10, Windup = 1.5, MinimumCount = 2, MaximumCount = 3, SpawnRadius = 5.5, SpawnType = "Splitling" },
	}),
	Splitter = define("Splitter", {
		MaxHealth = 150, XPValue = 11, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 9, ModelScale = 1.15,
		EffectColor = Color3.fromRGB(76, 196, 126), SpecialBehavior = "Splitter",
		SpawnWeight = 3, SpawnUnlockTime = 180, SpawnGrowthPerMinute = 0.08,
		Special = { Count = 2, SpawnRadius = 2.5, SpawnType = "Splitling" },
	}),
	Splitling = define("Splitling", {
		MaxHealth = 38, XPValue = 2, CoinValue = 1, MoveSpeed = 16, AttackDamage = 2, ModelScale = 0.68,
		ThreatLevel = 0, SeparationRadius = 1.1, EffectColor = Color3.fromRGB(112, 224, 151),
		AnimationStyle = "Runner", SummonedOnly = true,
	}),
	Burrower = define("Burrower", {
		MaxHealth = 150, XPValue = 11, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 9,
		EffectColor = Color3.fromRGB(132, 91, 55), SpecialBehavior = "Burrower", AnimationStyle = "Runner",
		SpawnWeight = 2, SpawnUnlockTime = 270, SpawnGrowthPerMinute = 0.1,
		Special = { HiddenDuration = 1.35, WarningDuration = 1.1, EmergeDuration = 0.45, PredictionTime = 0.35, Cooldown = 6.5 },
	}),
	Frenzy = define("Frenzy", {
		MaxHealth = 150, XPValue = 10, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 5.5,
		EffectColor = Color3.fromRGB(235, 74, 116), SpecialBehavior = "Frenzy",
		SpawnWeight = 3, SpawnUnlockTime = 90, SpawnGrowthPerMinute = 0.06,
		Special = { HealthThreshold = 0.55, Duration = 6, SpeedMultiplier = 2.5 },
	}),
	Medic = define("Medic", {
		MaxHealth = 60, XPValue = 12, CoinValue = 9, ThreatLevel = 3, MoveSpeed = 5,
		EffectColor = Color3.fromRGB(75, 225, 205), SpecialBehavior = "Medic",
		SpawnWeight = 2, SpawnUnlockTime = 180, SpawnGrowthPerMinute = 0.08,
		Special = { Radius = 16, HealAmount = 24, Cooldown = 4, PulseDuration = 0.7 },
	}),
	Hardened = define("Hardened", {
		MaxHealth = 280, XPValue = 16, CoinValue = 12, ThreatLevel = 4, MoveSpeed = 5, ModelScale = 1.08,
		EffectColor = Color3.fromRGB(132, 145, 158), SpecialBehavior = "Hardened", AnimationStyle = "Brute",
		SpawnWeight = 2, SpawnUnlockTime = 210, SpawnGrowthPerMinute = 0.1,
		Special = { Armor = 180 },
	}),
	Dodger = define("Dodger", {
		MaxHealth = 60, XPValue = 8, CoinValue = 6, ThreatLevel = 2, MoveSpeed = 15, TurnSpeed = 14,
		EffectColor = Color3.fromRGB(100, 194, 246), SpecialBehavior = "Dodger", AnimationStyle = "Runner",
		SpawnWeight = 3, SpawnUnlockTime = 75, SpawnGrowthPerMinute = 0.05,
		Special = { Cooldown = 4, Distance = 5.5, DisplayDuration = 0.35 },
	}),

	-- These archetypes deliberately add positioning and target-priority decisions instead of stat-only variants.
	Sludger = define("Sludger", {
		MaxHealth = 125, XPValue = 10, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 5,
		EffectColor = Color3.fromRGB(107, 151, 47), SpecialBehavior = "Sludger",
		SpawnWeight = 4, SpawnUnlockTime = 90, SpawnGrowthPerMinute = 0.07,
		Special = { Radius = 8, Duration = 6, SlowMultiplier = 0.58 },
	}),
	Warden = define("Warden", {
		MaxHealth = 115, XPValue = 15, CoinValue = 11, ThreatLevel = 4, MoveSpeed = 4.5,
		EffectColor = Color3.fromRGB(255, 158, 68), SpecialBehavior = "Warden", AnimationStyle = "Brute",
		SpawnWeight = 1.5, SpawnUnlockTime = 240, SpawnGrowthPerMinute = 0.12,
		Special = { Radius = 19, PulseInterval = 1, BuffDuration = 1.4, SpeedMultiplier = 1.3, DamageMultiplier = 1.25 },
	}),
	CorpseEater = define("CorpseEater", {
		MaxHealth = 190, XPValue = 14, CoinValue = 10, ThreatLevel = 4, MoveSpeed = 7,
		EffectColor = Color3.fromRGB(128, 52, 57), SpecialBehavior = "CorpseEater", AnimationStyle = "Runner",
		SpawnWeight = 2, SpawnUnlockTime = 180, SpawnGrowthPerMinute = 0.1,
		Special = { ConsumeRadius = 14, MaxStacks = 8, HealPerStack = 35, MaxHealthPerStack = 20, SpeedPerStack = 0.05, DamagePerStack = 0.08 },
	}),
	Hexer = define("Hexer", {
		MaxHealth = 85, XPValue = 12, CoinValue = 9, ThreatLevel = 3, MoveSpeed = 4.8,
		EffectColor = Color3.fromRGB(179, 74, 232), SpecialBehavior = "Hexer",
		SpawnWeight = 3, SpawnUnlockTime = 150, SpawnGrowthPerMinute = 0.08,
		Special = { Range = 36, MinimumRange = 8, Cooldown = 5, Windup = 1.45, PredictionTime = 0.45, Radius = 5.5, Damage = 14 },
	}),
	Anchor = define("Anchor", {
		MaxHealth = 210, XPValue = 14, CoinValue = 10, ThreatLevel = 4, MoveSpeed = 4.2,
		EffectColor = Color3.fromRGB(68, 104, 142), SpecialBehavior = "Anchor", AnimationStyle = "Brute",
		SpawnWeight = 2, SpawnUnlockTime = 210, SpawnGrowthPerMinute = 0.1,
		Special = { Range = 18, SlowMultiplier = 0.72, RefreshInterval = 0.3, EffectDuration = 0.45, PulseInterval = 0.9 },
	}),
	Frostbite = define("Frostbite", {
		MaxHealth = 80, XPValue = 10, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 5.2,
		EffectColor = Color3.fromRGB(108, 214, 255), SpecialBehavior = "Frostbite",
		SpawnWeight = 3, SpawnUnlockTime = 120, SpawnGrowthPerMinute = 0.07,
		Special = { Range = 20, MinimumRange = 6, Cooldown = 5.5, Windup = 0.9, ArcDot = 0.55, SlowMultiplier = 0.58, SlowDuration = 2.5 },
	}),
	Rallying = define("Rallying", {
		MaxHealth = 95, XPValue = 12, CoinValue = 9, ThreatLevel = 3, MoveSpeed = 5,
		EffectColor = Color3.fromRGB(239, 196, 72), SpecialBehavior = "Rallying",
		SpawnWeight = 2, SpawnUnlockTime = 180, SpawnGrowthPerMinute = 0.09,
		Special = { Radius = 22, Cooldown = 7, Duration = 4, SpeedMultiplier = 1.75, Types = { Walker = true } },
	}),
	Hoarder = define("Hoarder", {
		MaxHealth = 155, XPValue = 11, CoinValue = 9, ThreatLevel = 3, MoveSpeed = 8.5,
		EffectColor = Color3.fromRGB(230, 174, 57), SpecialBehavior = "Hoarder", AnimationStyle = "Runner",
		SpawnWeight = 2, SpawnUnlockTime = 120, SpawnGrowthPerMinute = 0.08,
		Special = { Radius = 13, Interval = 0.8, MaximumDropsPerPulse = 2 },
	}),
	BroodPod = define("BroodPod", {
		MaxHealth = 180, XPValue = 13, CoinValue = 10, ThreatLevel = 4, MoveSpeed = 0,
		EffectColor = Color3.fromRGB(157, 207, 84), SpecialBehavior = "BroodPod", AnimationStyle = "Brute",
		SpawnWeight = 2, SpawnUnlockTime = 240, SpawnGrowthPerMinute = 0.11,
		Special = { HatchDelay = 6, Count = 4, SpawnRadius = 4, SpawnType = "Splitling" },
	}),
	Martyr = define("Martyr", {
		MaxHealth = 90, XPValue = 11, CoinValue = 8, ThreatLevel = 3, MoveSpeed = 7,
		EffectColor = Color3.fromRGB(244, 116, 91), SpecialBehavior = "Martyr",
		SpawnWeight = 3, SpawnUnlockTime = 180, SpawnGrowthPerMinute = 0.08,
		Special = { Radius = 15, Duration = 5, SpeedMultiplier = 1.45, DamageMultiplier = 1.35 },
	}),
	Stalker = define("Stalker", {
		MaxHealth = 120, XPValue = 15, CoinValue = 11, ThreatLevel = 4, MoveSpeed = 10, TurnSpeed = 12,
		EffectColor = Color3.fromRGB(91, 77, 118), SpecialBehavior = "Stalker", AnimationStyle = "Runner",
		SpawnWeight = 2, SpawnUnlockTime = 300, SpawnGrowthPerMinute = 0.13,
		Special = { WatchedDotThreshold = 0.35, WatchedSpeedMultiplier = 0.2, UnwatchedSpeedMultiplier = 1.7 },
	}),
	Juggernaut = define("Juggernaut", {
		MaxHealth = 480, XPValue = 23, CoinValue = 17, ThreatLevel = 5, MoveSpeed = 4.2, TurnSpeed = 4,
		AttackDamage = 12, ModelScale = 1.22, SeparationRadius = 2.15,
		EffectColor = Color3.fromRGB(154, 104, 64), SpecialBehavior = "Juggernaut", AnimationStyle = "Brute",
		SpawnWeight = 2, SpawnUnlockTime = 240, SpawnGrowthPerMinute = 0.13,
		Special = { BuildTime = 5, MaximumSpeedMultiplier = 2.1, MaximumKnockbackResistance = 0.8, ResetDelay = 0.8 },
	}),
	Boss = define("Boss", {
		-- The Grave Titan belongs only to the scripted round-15 encounter and must never enter weighted waves.
		DisplayName = "Grave Titan",
		IsBoss = true,
		BossHint = "SLAMS, SUMMONS, AND ENRAGES AT 50%",
		MaxHealth = 6000, XPValue = 180, CoinValue = 120, ThreatLevel = 10, MoveSpeed = 4.5, TurnSpeed = 4,
		-- The encounter boss must read as several times larger than a normal zombie at gameplay distance.
		AttackDamage = 24, AttackRange = 10, AttackCooldown = 1.8, ModelScale = 3, SeparationRadius = 4.5,
		EffectColor = Color3.fromRGB(181, 52, 61), SpecialBehavior = "Boss", AnimationStyle = "Brute",
		SpawnWeight = 0, SummonedOnly = true,
		Special = {
			InitialDelay = 4,
			Cooldown = 8,
			Radius = 17,
			SlamTriggerRange = 17,
			SlamWindup = 1.4,
			SlamDamage = 45,
			SummonWindup = 1.8,
			SummonInitialDelay = 6,
			SummonCooldown = 14,
			SummonCount = 5,
			MaximumActiveSummons = 10,
			SummonRadius = 8,
			SummonTypes = { "Walker", "Runner" },
			EnrageHealthThreshold = 0.5,
			EnrageSpeedMultiplier = 1.45,
			EnrageDamageMultiplier = 1.5,
			EnrageCooldownMultiplier = 0.8,
			KnockbackResistance = 0.7,
			DeathShockwaveRadius = 160,
			DeathShockwaveDuration = 1.15,
			DeathDropId = "LuckySkull",
			XPDropCount = 6,
		},
	}),
	PlagueMatron = define("PlagueMatron", {
		-- The round-30 boss kites behind volleys of damaging plague pools and ranged/slowing summons.
		-- Half health adds another pool and shortens cooldowns without shortening warning time.
		DisplayName = "Plague Matron",
		IsBoss = true,
		BossHint = "DODGE PLAGUE VOLLEYS AND CLEAR SUMMONS",
		-- Later health tiers must keep pace with multiple developed weapons, not just enemy round counts.
		MaxHealth = 24000, XPValue = 300, CoinValue = 220, ThreatLevel = 12, MoveSpeed = 6.5, TurnSpeed = 6,
		AttackDamage = 42, AttackRange = 8, AttackCooldown = 1.5, ModelScale = 2.6, SeparationRadius = 4.2,
		EffectColor = Color3.fromRGB(118, 205, 65), SpecialBehavior = "PlagueMatron", AnimationStyle = "Brute",
		SpawnWeight = 0, SummonedOnly = true,
		Special = {
			InitialDelay = 2.5,
			Cooldown = 3.6,
			Range = 60,
			PreferredRange = 25,
			RetreatRange = 14,
			Windup = 1.4,
			PredictionTime = 0.55,
			Radius = 8,
			PoolCount = 3,
			EnragedPoolCount = 4,
			PoolSpread = 15,
			ImpactDamage = 78,
			PoolTickDamage = 12,
			PoolDuration = 8,
			SlowMultiplier = 0.48,
			SummonInitialDelay = 5,
			SummonCooldown = 12,
			SummonWindup = 1.4,
			SummonCount = 6,
			MaximumActiveSummons = 12,
			SummonRadius = 11,
			SummonTypes = { "Runner", "Spitter", "Sludger" },
			EnrageHealthThreshold = 0.5,
			EnrageSpeedMultiplier = 1.3,
			EnrageDamageMultiplier = 1.35,
			EnrageCooldownMultiplier = 0.75,
			KnockbackResistance = 0.78,
			DeathShockwaveRadius = 165,
			DeathShockwaveDuration = 1.2,
			DeathDropId = "LuckySkull",
			XPDropCount = 8,
		},
	}),
	RiftStalker = define("RiftStalker", {
		-- The round-45 boss chains fully warned ambushes before its punish window; half health adds a
		-- third eruption. Fast summons apply pressure while the boss is exposed or underground.
		DisplayName = "Rift Stalker",
		IsBoss = true,
		BossHint = "DODGE CHAIN ERUPTIONS AND CLEAR SUMMONS",
		MaxHealth = 60000, XPValue = 440, CoinValue = 330, ThreatLevel = 14, MoveSpeed = 9, TurnSpeed = 10,
		AttackDamage = 54, AttackRange = 7, AttackCooldown = 1.15, ModelScale = 2.35, SeparationRadius = 3.8,
		EffectColor = Color3.fromRGB(132, 83, 230), SpecialBehavior = "RiftStalker", AnimationStyle = "Runner",
		SpawnWeight = 0, SummonedOnly = true,
		Special = {
			InitialDelay = 2,
			Cooldown = 3.2,
			HiddenDuration = 0.65,
			WarningDuration = 1.2,
			EmergeDuration = 0.55,
			RecoveryDuration = 0.8,
			PredictionTime = 0.7,
			Radius = 12,
			EruptionDamage = 96,
			EruptionCount = 2,
			EnragedEruptionCount = 3,
			SummonInitialDelay = 4,
			SummonCooldown = 10,
			SummonWindup = 1.3,
			SummonCount = 7,
			MaximumActiveSummons = 14,
			SummonRadius = 12,
			SummonTypes = { "Runner", "Leaper", "Burrower" },
			EnrageHealthThreshold = 0.5,
			EnrageSpeedMultiplier = 1.35,
			EnrageDamageMultiplier = 1.4,
			EnrageCooldownMultiplier = 0.75,
			KnockbackResistance = 0.62,
			DeathShockwaveRadius = 170,
			DeathShockwaveDuration = 1.25,
			DeathDropId = "LuckySkull",
			XPDropCount = 10,
		},
	}),
	BoneColossus = define("BoneColossus", {
		-- The round-60 boss closes distance with a swept lane charge and answers close-range builds with
		-- a large stomp. Both attacks retain a vulnerability window while durable summons protect it.
		DisplayName = "Bone Colossus",
		IsBoss = true,
		BossHint = "DODGE CHARGES AND STOMPS; CLEAR SUMMONS",
		MaxHealth = 120000, XPValue = 620, CoinValue = 480, ThreatLevel = 17, MoveSpeed = 6.5, TurnSpeed = 4.5,
		AttackDamage = 72, AttackRange = 11, AttackCooldown = 1.6, ModelScale = 3.4, SeparationRadius = 5.2,
		EffectColor = Color3.fromRGB(225, 188, 112), SpecialBehavior = "BoneColossus", AnimationStyle = "Brute",
		SpawnWeight = 0, SummonedOnly = true,
		Special = {
			InitialDelay = 2.5,
			Cooldown = 4,
			MaximumRange = 72,
			Windup = 1.5,
			ChargeSpeed = 48,
			ChargeDuration = 1.45,
			ChargeWidth = 8,
			ChargeDamage = 135,
			StompRadius = 22,
			StompWindup = 1.2,
			StompDamage = 120,
			RecoveryDuration = 1.35,
			RecoveryDamageMultiplier = 1.4,
			Radius = 4,
			SummonInitialDelay = 4,
			SummonCooldown = 9,
			SummonWindup = 1.5,
			SummonCount = 8,
			MaximumActiveSummons = 16,
			SummonRadius = 15,
			SummonTypes = { "Brute", "Charger", "Shielder", "Juggernaut" },
			EnrageHealthThreshold = 0.5,
			EnrageSpeedMultiplier = 1.4,
			EnrageDamageMultiplier = 1.4,
			EnrageCooldownMultiplier = 0.75,
			KnockbackResistance = 0.9,
			DeathShockwaveRadius = 180,
			DeathShockwaveDuration = 1.35,
			DeathDropId = "LuckySkull",
			XPDropCount = 12,
		},
	}),
}

return ZombieDefinitions
