local PlayerStatConfig = {
	-- These are fallbacks only; the authoritative controller captures each spawned Humanoid's authored values.
	DefaultBaseMaxHealth = 100,
	DefaultBaseWalkSpeed = 16,
	-- Apply one cap after every speed modifier is composed so individual buffs still stack predictably.
	MaximumWalkSpeed = 32,
}

return PlayerStatConfig
