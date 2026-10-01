local CoinsConfig = require(script.Parent.CoinsConfig)
local MonetizationConfig = require(script.Parent.MonetizationConfig)
local AbilityDefinitions = require(script.Parent.Abilities.AbilityDefinitions)
local ClassDefinitions = require(script.Parent.Classes.ClassDefinitions)
local RollDefinitions = require(script.Parent.Rolls.RollDefinitions)
local SurvivalStatsConfig = require(script.Parent.SurvivalStatsConfig)
local ZombieIndexConfig = require(script.Parent.Zombies.ZombieIndexConfig)
local AnalyticsConfig = require(script.Parent.AnalyticsConfig)
local ClassesAbilitiesTutorialConfig = require(script.Parent.ClassesAbilitiesTutorialConfig)

return {
	-- Coins are persisted as non-negative whole numbers and are only mutated by trusted server systems.
	[CoinsConfig.DataKey] = CoinsConfig.DefaultBalance,
	-- Receipt history and unused contextual credits make repeatable purchases idempotent and prevent
	-- a delayed Roblox receipt from silently consuming a purchase after its original moment has passed.
	[MonetizationConfig.DataKey] = {
		ProcessedReceipts = {},
		Credits = {
			Revive = 0,
			ReviveTeam = 0,
			RunBoost = 0,
			TakeAll = 0,
		},
	},
	-- Legacy roll fields remain in the schema so existing profiles load without migration or data loss.
	[RollDefinitions.InventoryDataKey] = {},
	[RollDefinitions.TotalRollsDataKey] = 0,
	-- These dormant preferences are preserved for a future lobby or post-run roll flow.
	[RollDefinitions.AutoRollEnabledDataKey] = false,
	[RollDefinitions.PresentationHiddenDataKey] = false,
	-- All abilities must keep ownership, levels, and equipped slots in this persisted JSON-compatible snapshot.
	[AbilityDefinitions.DataKey] = {
		-- Starter ownership is seeded authoritatively during normalization. Keeping these maps empty avoids
		-- duplicating the roster here while still giving new and existing profiles the same current defaults.
		Owned = {},
		Levels = {},
		Equipped = {
			Weapon = {},
			Passive = {},
		},
	},
	-- Class ownership and selection persist separately from transient run ability levels.
	[ClassDefinitions.DataKey] = {
		Owned = { [ClassDefinitions.DefaultId] = true },
		Equipped = ClassDefinitions.DefaultId,
	},
	-- The highest round completed while alive is server-awarded and shown in public player statistics.
	[SurvivalStatsConfig.DataKey] = SurvivalStatsConfig.DefaultRoundsSurvived,
	-- This becomes true only after the returning-player Classes tutorial's authoritative free claim succeeds.
	[ClassesAbilitiesTutorialConfig.DataKey] = false,
	-- Zombie kills and one-time discovery claims are sparse maps keyed only by known zombie IDs.
	[ZombieIndexConfig.DataKey] = {},
	-- Analytics-only progress keeps the versioned onboarding funnel continuous across server teleports.
	[AnalyticsConfig.DataKey] = {
		OnboardingVersion = 0,
		OnboardingStep = 0,
	},
}
