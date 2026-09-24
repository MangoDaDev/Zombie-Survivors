return {
	RollCooldown = 0.75,
	RollRequestCooldown = 0.15,
	AutoToggleCooldown = 0.2,
	PresentationToggleCooldown = 0.2,

	-- Persistent luck is combined with temporary clover luck only for the final item selection.
	DefaultLuck = 1,
	MinimumLuck = 0.1,
	MaximumLuck = 100,

	-- A clover is a visible roll result that advances the chain without granting an item.
	-- The first luck result is exactly 1-in-4; every later link in that roll's chain is exactly 1-in-3.
	FirstCloverChance = 1 / 4,
	ChainedCloverChance = 1 / 3,
	StartingCloverLuck = 2,
	CloverLuckGrowth = 2,
	MaximumCloverLuck = 64,
}
