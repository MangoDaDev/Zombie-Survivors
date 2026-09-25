-- Zombie-specific balance and presentation data lives here so the simulation,
-- spawning, networking, and rendering code never need type-specific branches.
-- XPValue and CoinValue feed the central death reward pipeline. Stronger variants should generally
-- increase encounter pressure and reward value instead of relying on health scaling alone.
local ZOMBIE_MOVE_SPEED_MULTIPLIER = 1.35
local ZOMBIE_ATTACK_RANGE_MULTIPLIER = 1.35
local ZOMBIE_AGGRO_DISTANCE_MULTIPLIER = 2.5

local function define(overrides)
	local definition = {
		AssetName = "Walker",
		MaxHealth = 100,
		XPValue = 5,
		CoinValue = 4,
		MoveSpeed = 8,
		TurnSpeed = 8,
		AggroDistance = 70,
		AttackRange = 4.5,
		AttackDamage = 4,
		AttackCooldown = 1.25,
		AttackWindupDuration = 0.55,
		AttackStrikeDuration = 0.18,
		AttackRecoveryDuration = 0.25,
		SeparationRadius = 1.6,
		ModelScale = 1,
		TintColor = nil,
		MovementBehavior = "DirectChase",
		AttackBehavior = "Contact",
		AnimationStyle = "Walker",
	}
	for key, value in overrides do
		definition[key] = value
	end
	-- Every archetype receives the same pressure increase so slow specials and fast runners both
	-- remain true to their role while moving players can no longer kite contact attacks for free.
	definition.MoveSpeed *= ZOMBIE_MOVE_SPEED_MULTIPLIER
	definition.AttackRange *= ZOMBIE_ATTACK_RANGE_MULTIPLIER
	-- Sight ranges are scaled for the 300x300 combat floor so distant spawns immediately join the chase.
	definition.AggroDistance *= ZOMBIE_AGGRO_DISTANCE_MULTIPLIER
	return definition
end

local ZombieDefinitions = {
	Walker = define({}),
	Runner = define({
		AssetName = "Runner", MaxHealth = 70, XPValue = 4, CoinValue = 3, MoveSpeed = 14, TurnSpeed = 12,
		AggroDistance = 90, AttackRange = 4, AttackDamage = 3, AttackCooldown = 0.8,
		AttackWindupDuration = 0.4, AttackStrikeDuration = 0.14, AttackRecoveryDuration = 0.18,
		SeparationRadius = 1.55, AnimationStyle = "Runner",
	}),
	Brute = define({
		AssetName = "Brute", MaxHealth = 300, XPValue = 14, CoinValue = 12, MoveSpeed = 5.5, TurnSpeed = 5,
		AggroDistance = 65, AttackRange = 6, AttackDamage = 9, AttackCooldown = 2.2,
		AttackWindupDuration = 0.75, AttackStrikeDuration = 0.22, AttackRecoveryDuration = 0.35,
		SeparationRadius = 1.85, AnimationStyle = "Brute",
	}),

	Spitter = define({
		MaxHealth = 65, XPValue = 7, CoinValue = 5, MoveSpeed = 5.5, TintColor = Color3.fromRGB(120, 225, 62), SpecialBehavior = "Spitter",
		Special = { Range = 34, MinimumRange = 10, Cooldown = 3.8, Windup = 0.8, ProjectileSpeed = 32, ImpactRadius = 3.5, Damage = 8 },
	}),
	Charger = define({
		AssetName = "Runner", MaxHealth = 150, XPValue = 9, CoinValue = 7, MoveSpeed = 9, AttackDamage = 6,
		TintColor = Color3.fromRGB(220, 87, 52), SpecialBehavior = "Charger", AnimationStyle = "Runner",
		Special = { MinimumRange = 9, MaximumRange = 28, Windup = 0.9, ChargeSpeed = 34, ChargeDuration = 0.85, HitRadius = 3.5, Damage = 13, MissRecovery = 1.25, RecoveryDamageMultiplier = 1.5, Cooldown = 4.5 },
	}),
	Screamer = define({
		MaxHealth = 55, XPValue = 10, CoinValue = 7, MoveSpeed = 5, TintColor = Color3.fromRGB(196, 94, 220), SpecialBehavior = "Screamer",
		Special = { Cooldown = 13, Windup = 1.4, MinimumCount = 2, MaximumCount = 3, SpawnRadius = 4.5, SpawnType = "Walker" },
	}),
	Tank = define({
		AssetName = "Brute", MaxHealth = 850, XPValue = 34, CoinValue = 24, MoveSpeed = 3.4, TurnSpeed = 3.5, AttackDamage = 14,
		AttackRange = 7, SeparationRadius = 2.4, ModelScale = 1.35, TintColor = Color3.fromRGB(94, 80, 70),
		SpecialBehavior = "Tank", AnimationStyle = "Brute",
		Special = { Radius = 13, Damage = 18, Windup = 1.25, Cooldown = 6.5 },
	}),
	Leaper = define({
		AssetName = "Runner", MaxHealth = 60, XPValue = 7, CoinValue = 5, MoveSpeed = 10, TintColor = Color3.fromRGB(246, 184, 58),
		SpecialBehavior = "Leaper", AnimationStyle = "Runner",
		Special = { MinimumRange = 8, MaximumRange = 25, PredictionTime = 0.4, Windup = 0.45, LeapDuration = 0.7, LeapSpeed = 31, HitRadius = 3.2, Damage = 9, Cooldown = 3.5 },
	}),
	Shielder = define({
		AssetName = "Brute", MaxHealth = 270, XPValue = 15, CoinValue = 11, MoveSpeed = 5, TurnSpeed = 5, ModelScale = 1.08,
		TintColor = Color3.fromRGB(70, 128, 190), SpecialBehavior = "Shielder", AnimationStyle = "Brute",
		-- A positive dot means the damage origin is in front of the authoritative facing direction.
		Special = { FrontDotThreshold = 0.15 },
	}),
	Bomber = define({
		AssetName = "Runner", MaxHealth = 60, XPValue = 8, CoinValue = 6, MoveSpeed = 9, TintColor = Color3.fromRGB(244, 73, 58),
		SpecialBehavior = "Bomber", AnimationStyle = "Runner",
		Special = { TriggerRange = 9, Countdown = 2.2, Radius = 11, Damage = 28, FriendlyFireDamage = 75 },
	}),
	Grabber = define({
		MaxHealth = 145, XPValue = 10, CoinValue = 8, MoveSpeed = 5.5, TintColor = Color3.fromRGB(56, 166, 158), SpecialBehavior = "Grabber",
		Special = { MinimumRange = 5, Range = 20, Windup = 0.75, Damage = 5, PullSpeed = 34, UpwardSpeed = 5, Cooldown = 5 },
	}),
	Summoner = define({
		AssetName = "Brute", MaxHealth = 180, XPValue = 16, CoinValue = 12, MoveSpeed = 3.2, ModelScale = 1.12,
		TintColor = Color3.fromRGB(102, 67, 176), SpecialBehavior = "Summoner", AnimationStyle = "Brute",
		Special = { Cooldown = 10, Windup = 1.5, MinimumCount = 2, MaximumCount = 3, SpawnRadius = 5.5, SpawnType = "Splitling" },
	}),
	Splitter = define({
		MaxHealth = 150, XPValue = 11, CoinValue = 8, MoveSpeed = 9, ModelScale = 1.15, TintColor = Color3.fromRGB(76, 196, 126),
		SpecialBehavior = "Splitter", Special = { Count = 2, SpawnRadius = 2.5, SpawnType = "Splitling" },
	}),
	-- Splitlings are internal offspring and are deliberately absent from every weighted spawn pool.
	Splitling = define({
		AssetName = "Runner", MaxHealth = 38, XPValue = 2, CoinValue = 1, MoveSpeed = 16, AttackDamage = 2, ModelScale = 0.68,
		SeparationRadius = 1.1, TintColor = Color3.fromRGB(112, 224, 151), AnimationStyle = "Runner",
	}),
	Burrower = define({
		AssetName = "Runner", MaxHealth = 150, XPValue = 11, CoinValue = 8, MoveSpeed = 9, TintColor = Color3.fromRGB(132, 91, 55),
		SpecialBehavior = "Burrower", AnimationStyle = "Runner",
		Special = { HiddenDuration = 1.35, WarningDuration = 1.1, EmergeDuration = 0.45, PredictionTime = 0.35, Cooldown = 6.5 },
	}),
	Frenzy = define({
		MaxHealth = 150, XPValue = 10, CoinValue = 8, MoveSpeed = 5.5, TintColor = Color3.fromRGB(235, 74, 116), SpecialBehavior = "Frenzy",
		Special = { HealthThreshold = 0.55, Duration = 6, SpeedMultiplier = 2.5 },
	}),
	Medic = define({
		MaxHealth = 60, XPValue = 12, CoinValue = 9, MoveSpeed = 5, TintColor = Color3.fromRGB(75, 225, 205), SpecialBehavior = "Medic",
		Special = { Radius = 16, HealAmount = 24, Cooldown = 4, PulseDuration = 0.7 },
	}),
	Hardened = define({
		AssetName = "Brute", MaxHealth = 280, XPValue = 16, CoinValue = 12, MoveSpeed = 5, ModelScale = 1.08,
		TintColor = Color3.fromRGB(132, 145, 158), SpecialBehavior = "Hardened", AnimationStyle = "Brute",
		Special = { Armor = 180 },
	}),
	Dodger = define({
		AssetName = "Runner", MaxHealth = 60, XPValue = 8, CoinValue = 6, MoveSpeed = 15, TurnSpeed = 14,
		TintColor = Color3.fromRGB(100, 194, 246), SpecialBehavior = "Dodger", AnimationStyle = "Runner",
		Special = { Cooldown = 4, Distance = 5.5, DisplayDuration = 0.35 },
	}),
}

return ZombieDefinitions
