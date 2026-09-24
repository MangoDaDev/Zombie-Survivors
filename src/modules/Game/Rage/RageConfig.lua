local RageConfig = {
	Maximum = 100,
	-- Rage always fills from empty to ready over 30 seconds; combat volume must not shorten this cycle.
	ChargeDuration = 30,
	Duration = 10,
	ActivationKey = Enum.KeyCode.R,
	ActivationRequestCooldown = 0.25,
}

return RageConfig
