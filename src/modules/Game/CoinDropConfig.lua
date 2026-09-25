local RunProgressionConfig = require(script.Parent.RunProgressionConfig)

local CoinDropConfig = {
	-- Prediction uses the same magnet range/timing as the authoritative fallback; only the server awards currency.
	PickupRadius = RunProgressionConfig.Pickups.Coin.PickupRadius,
	MagnetRadius = RunProgressionConfig.Pickups.Coin.MagnetRadius,
	CollectionDuration = RunProgressionConfig.Pickups.Coin.MagnetDuration,
	Lifetime = RunProgressionConfig.Pickups.Coin.Lifetime,
	PredictionInterval = 0.05,
	MaxPredictionBatch = 12,
}

return table.freeze(CoinDropConfig)
