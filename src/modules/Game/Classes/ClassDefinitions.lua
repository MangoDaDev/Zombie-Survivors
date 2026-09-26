local ClassDefinitions = {}

ClassDefinitions.DataKey = "Classes"
ClassDefinitions.DefaultId = "Survivor"

-- One definition drives the menu, permanent price, starting weapon, server perks, and authored headpiece.
-- Add future classes here and place a same-named block-built model in Assets.Models.Classes.
ClassDefinitions.List = {
	{
		Id = "Survivor",
		Name = "Survivor",
		Description = "A durable scavenger who keeps every pickup within reach.",
		AbilityId = "Dagger",
		PerkText = "+15% max health  |  +25% pickup magnet range",
		UnlockCost = 0,
		Color = Color3.fromRGB(102, 205, 147),
		Bonuses = { MaxHealth = 0.15, PickupMagnet = 0.25 },
	},
	{
		Id = "Scout",
		Name = "Scout",
		Description = "Stay on the move and strike from farther away.",
		AbilityId = "Boomerang",
		PerkText = "+10% move speed  |  +12% projectile range after moving for 3s",
		UnlockCost = 600,
		Color = Color3.fromRGB(103, 187, 255),
		Bonuses = { WalkSpeed = 0.10, MovingProjectileRange = 0.12, MovementSeconds = 3 },
	},
	{
		Id = "Pyromaniac",
		Name = "Pyromaniac",
		Description = "Turn crowded fights into spreading fire and lasting hazards.",
		AbilityId = "Fireball",
		PerkText = "+12% explosion radius  |  +20% damage-over-time duration",
		UnlockCost = 1200,
		Color = Color3.fromRGB(255, 137, 76),
		Bonuses = { ExplosionRadius = 0.12, DamageOverTimeDuration = 0.20 },
	},
	{
		Id = "Stormcaller",
		Name = "Stormcaller",
		Description = "A fragile conduit who strikes faster and sends lightning through larger crowds.",
		AbilityId = "Lightning",
		PerkText = "-8% weapon cooldowns  |  +1 lightning chain target  |  -10% max health",
		UnlockCost = 1800,
		Color = Color3.fromRGB(162, 203, 255),
		Bonuses = { CooldownReduction = 0.08, LightningTargets = 1, MaxHealth = -0.10 },
	},
	{
		Id = "Warden",
		Name = "Warden",
		Description = "Holds the line when the horde closes in.",
		AbilityId = "Aura",
		PerkText = "+15% max health  |  -12% damage near 4+ zombies  |  -5% move speed",
		UnlockCost = 2400,
		Color = Color3.fromRGB(133, 207, 202),
		-- The 14-stud pressure radius is the local crowd threshold, not a global zombie count.
		Bonuses = { MaxHealth = 0.15, NearbyDamageReduction = 0.12, NearbyZombieCount = 4, NearbyRadius = 14, WalkSpeed = -0.05 },
	},
	{
		Id = "Trickshot",
		Name = "Trickshot",
		Description = "Turns each fresh ricochet into a stronger follow-up hit.",
		AbilityId = "Ball",
		PerkText = "+2 ball bounces  |  +5% damage per unique ricochet, up to +25%",
		UnlockCost = 3000,
		Color = Color3.fromRGB(250, 191, 98),
		Bonuses = { BallBounces = 2, UniqueRicochetDamage = 0.05, UniqueRicochetCap = 0.25 },
	},
	{
		Id = "Engineer",
		Name = "Engineer",
		Description = "Builds wider attack lanes and pushes the horde back.",
		AbilityId = "Drill",
		PerkText = "+15% straight-projectile width  |  +10% range  |  +15% knockback",
		UnlockCost = 3600,
		Color = Color3.fromRGB(244, 190, 105),
		Bonuses = { StraightWidth = 0.15, StraightRange = 0.10, Knockback = 0.15 },
	},
	{
		Id = "Demolitionist",
		Name = "Demolitionist",
		Description = "Keeps more traps active and makes every bomb cover more ground.",
		AbilityId = "Mine",
		PerkText = "+25% deployable lifetime  |  +2 active deployables  |  +20% bomb radius",
		UnlockCost = 4200,
		Color = Color3.fromRGB(255, 167, 92),
		Bonuses = { DeployableDuration = 0.25, AdditionalDeployables = 2, BombRadius = 0.20 },
	},
	{
		Id = "Toxicologist",
		Name = "Toxicologist",
		Description = "Weakens enemies while poison and fire wear them down.",
		AbilityId = "Poison",
		PerkText = "+15% damage-over-time damage  |  afflicted zombies move 10% slower",
		UnlockCost = 4800,
		Color = Color3.fromRGB(148, 214, 112),
		Bonuses = { DamageOverTimeDamage = 0.15, AfflictedSlow = 0.10, AfflictedSlowDuration = 1.5 },
	},
	{
		Id = "Berserker",
		Name = "Berserker",
		Description = "Grows faster with each Rage kill, but recovers less health.",
		AbilityId = "Dagger",
		PerkText = "+2s Rage  |  Rage kills stack brief move speed  |  -15% healing received",
		UnlockCost = 5400,
		Color = Color3.fromRGB(255, 108, 112),
		-- Each Rage kill grants 3% speed for 3s, capped at five stacks.
		Bonuses = { RageDuration = 2, RageKillWalkSpeed = 0.03, RageKillDuration = 3, RageKillMaxStacks = 5, HealingReceived = -0.15 },
	},
	{
		Id = "Scavenger",
		Name = "Scavenger",
		Description = "Finds more Coins and keeps powerups available longer at a damage cost.",
		AbilityId = "Mine",
		PerkText = "+15% coin rewards  |  +20% coin pickup radius  |  +5s powerups  |  -8% weapon damage",
		UnlockCost = 6000,
		Color = Color3.fromRGB(224, 202, 118),
		Bonuses = { CoinReward = 0.15, CoinPickupRadius = 0.20, PowerupLifetime = 5, WeaponDamage = -0.08 },
	},
	{
		Id = "BladeDancer",
		Name = "Blade Dancer",
		Description = "Orbits blades faster and earns a brief shield through sustained sword hits.",
		AbilityId = "OrbitingSwords",
		RequiredAbilityId = "OrbitingSwords",
		PerkText = "+12% sword orbit speed and radius  |  every 10th hit grants a brief shield",
		UnlockCost = 7200,
		Color = Color3.fromRGB(180, 161, 255),
		-- The shield cuts incoming zombie damage by 25% for 2s after every tenth sword hit.
		Bonuses = { OrbitSpeed = 0.12, OrbitRadius = 0.12, SwordShieldEveryHits = 10, SwordShieldDuration = 2, SwordShieldDamageReduction = 0.25 },
	},
}

ClassDefinitions.ById = {}
for _, definition in ClassDefinitions.List do
	ClassDefinitions.ById[definition.Id] = definition
end

return ClassDefinitions
