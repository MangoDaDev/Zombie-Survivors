local CoinsConfig = {
	DataKey = "Coins",
	DefaultBalance = 0,
	-- Keep persisted balances within Luau's exact integer range so additions and purchases cannot lose precision.
	MaximumBalance = 9_007_199_254_740_991,
}

return table.freeze(CoinsConfig)
