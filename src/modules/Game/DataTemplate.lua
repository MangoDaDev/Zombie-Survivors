local CoinsConfig = require(script.Parent.CoinsConfig)
local AbilityDefinitions = require(script.Parent.Abilities.AbilityDefinitions)
local RollDefinitions = require(script.Parent.Rolls.RollDefinitions)

return {
	-- Coins are persisted as non-negative whole numbers and are only mutated by trusted server systems.
	[CoinsConfig.DataKey] = CoinsConfig.DefaultBalance,
	-- Rolled rewards are server-awarded item quantities keyed by stable definition IDs.
	[RollDefinitions.InventoryDataKey] = {},
	[RollDefinitions.TotalRollsDataKey] = 0,
	-- Ability ownership, levels, and equipped slots are one JSON-compatible authoritative snapshot.
	[AbilityDefinitions.DataKey] = {
		Owned = {},
		Levels = {},
		Equipped = {
			Weapon = {},
			Passive = {},
		},
	},
}
