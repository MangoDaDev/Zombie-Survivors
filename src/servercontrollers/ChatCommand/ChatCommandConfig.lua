return table.freeze({
	-- Only these live-game developers and the enabled creator/group owner may execute any chat command.
	DeveloperUserIds = {},
	AllowExperienceCreator = true,
	-- Studio test players are treated as developers so commands can be exercised without publishing test accounts.
	AllowAllInStudio = true,
	-- Group-owned experiences authorize only the owner rank by default.
	GroupMinimumDeveloperRank = 255,
	CommandCooldown = 0.25,
	RespawnCooldown = 2,
})
