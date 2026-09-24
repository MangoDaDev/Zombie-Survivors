local CoinDropConfig = {
	-- Prediction uses the same nominal range/timing as the authoritative fallback so confirmation is visually seamless.
	CollectionRadius = 9,
	CollectionDuration = 0.4,
	PredictionInterval = 0.05,
	MaxPredictionBatch = 12,
}

return table.freeze(CoinDropConfig)
