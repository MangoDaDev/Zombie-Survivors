local CoinsConfig = require(script.Parent.CoinsConfig)
local AbilityDefinitions = require(script.Parent.Abilities.AbilityDefinitions)
local RollDefinitions = require(script.Parent.Rolls.RollDefinitions)

return {
	-- Coins are persisted as non-negative whole numbers and are only mutated by trusted server systems.
	[CoinsConfig.DataKey] = CoinsConfig.DefaultBalance,
	-- Rolled rewards are server-awarded item quantities keyed by stable definition IDs.
	[RollDefinitions.InventoryDataKey] = {},
	[RollDefinitions.TotalRollsDataKey] = 0,
	-- Roll controls are player preferences and must restore exactly after the player rejoins.
	[RollDefinitions.AutoRollEnabledDataKey] = false,
	[RollDefinitions.PresentationHiddenDataKey] = false,
	-- All abilities must keep ownership, levels, and equipped slots in this persisted JSON-compatible snapshot.
	[AbilityDefinitions.DataKey] = {
		Owned = {},
		Levels = {},
		Equipped = {
			Weapon = {},
			Passive = {},
		},
	},
}
