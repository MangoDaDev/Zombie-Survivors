local PlayerStatConfig = {
	-- Health remains a fallback for missing character state; starting movement is centralized here so
	-- the authored character and every run modifier compose from the same predictable baseline.
	DefaultBaseMaxHealth = 100,
	-- Run upgrades compose from this baseline and retain the same global cap.
	DefaultBaseWalkSpeed = 20,
	-- Apply one cap after every speed modifier is composed so individual buffs still stack predictably.
	MaximumWalkSpeed = 32,
}

return PlayerStatConfig
