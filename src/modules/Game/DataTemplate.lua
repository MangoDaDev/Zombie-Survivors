local CoinsConfig = require(script.Parent.CoinsConfig)
local RollDefinitions = require(script.Parent.Rolls.RollDefinitions)

return {
	-- Coins are persisted as non-negative whole numbers and are only mutated by trusted server systems.
	[CoinsConfig.DataKey] = CoinsConfig.DefaultBalance,
	-- Rolled rewards are server-awarded item quantities keyed by stable definition IDs.
	[RollDefinitions.InventoryDataKey] = {},
	[RollDefinitions.TotalRollsDataKey] = 0,
}
