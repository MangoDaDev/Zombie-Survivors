local CoinsConfig = require(script.Parent.CoinsConfig)
local AbilityDefinitions = require(script.Parent.Abilities.AbilityDefinitions)
local RollDefinitions = require(script.Parent.Rolls.RollDefinitions)

return {
	-- Coins are persisted as non-negative whole numbers and are only mutated by trusted server systems.
	[CoinsConfig.DataKey] = CoinsConfig.DefaultBalance,
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
}
