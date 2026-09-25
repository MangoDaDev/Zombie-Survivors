local PartyTeleporterConfig = {
	MinimumPartySize = 1,
	MaximumPartySize = 4,
	DefaultPartySize = 4,
	SetupDuration = 15,
	NormalCountdown = 15,
	FullCountdown = 3,
	LeaveRecoveryCountdown = 3,
	ZoneCheckInterval = 0.15,
	EntryPadding = 2.5,
	RequestCooldown = 0.15,
	TeleportWatchdogDuration = 15,
	-- Studio holds the locked/loading state briefly so local tests exercise the same asynchronous handoff flow.
	StudioTeleportLoadingDelay = 1.5,
	WorldDisplayDistance = 170,
}

return table.freeze(PartyTeleporterConfig)
