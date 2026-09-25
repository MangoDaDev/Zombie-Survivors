local PlayerStatConfig = {
	-- These are fallbacks only; the authoritative controller captures each spawned Humanoid's authored values.
	DefaultBaseMaxHealth = 100,
	-- A lower starting pace lets the faster horde pressure moving players; run upgrades still
	-- compose from this baseline and retain the same global cap.
	DefaultBaseWalkSpeed = 13,
	-- Apply one cap after every speed modifier is composed so individual buffs still stack predictably.
	MaximumWalkSpeed = 32,
}

return PlayerStatConfig
