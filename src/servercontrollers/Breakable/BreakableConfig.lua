-- Breakables are server-owned combat targets. Keep spawn density, durability, and feedback timing
-- here so adding a new authored model never requires changing the runtime controller.
local BreakableConfig = {
	RuntimeFolderName = "RuntimeBreakables",
	SpawnCount = 36,
	EdgeMargin = 12,
	MinimumSpacing = 11,
	SpawnSafeRadius = 22,
	PlacementAttempts = 30,
	RespawnDelay = NumberRange.new(14, 22),
	HitFeedbackCooldown = 0.08,
	HitKickDistance = 0.18,
	HitKickDuration = 0.07,
	FragmentLifetime = 2.4,
	FragmentFadeDelay = 1.05,
	FragmentFadeDuration = 0.65,
	Templates = {
		{ Name = "Crate", MaxHealth = 90, Weight = 30 },
		{ Name = "Barrel", MaxHealth = 120, Weight = 24 },
		{ Name = "Gravestone", MaxHealth = 150, Weight = 15 },
		{ Name = "Pedestal", MaxHealth = 170, Weight = 10 },
		{ Name = "Cannon", MaxHealth = 220, Weight = 8 },
		{ Name = "Iron cage", MaxHealth = 240, Weight = 6 },
		{ Name = "Broken fountain", MaxHealth = 260, Weight = 4 },
		{ Name = "Stone well", MaxHealth = 300, Weight = 3 },
	},
	HitSounds = { "CrateDamage", "CrateDamage1", "CrateDamage2" },
	BreakSounds = { "CrateBreak1", "CrateBreak2", "CrateBreak3" },
}

return BreakableConfig
