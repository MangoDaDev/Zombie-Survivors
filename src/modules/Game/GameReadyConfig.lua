local GameReadyConfig = {
	-- A unanimous ready vote starts combat immediately, while this fallback guarantees that a
	-- missing or unresponsive party member cannot hold the game server indefinitely.
	Duration = 30,
}

return table.freeze(GameReadyConfig)
