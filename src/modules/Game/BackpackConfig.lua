-- Currently unused while carried simulator loot is archived. Preserved for future wearable progression.

local BackpackConfig = {
	ModelName = "CoinBackpack",
	TargetPartName = "GatheredNeck",
	Stages = {
		{ MinimumCoins = 0, AssetName = "Stage1", MountOffsetZ = 0.6 },
		{ MinimumCoins = 25, AssetName = "Stage2", MountOffsetZ = 0.68 },
		{ MinimumCoins = 50, AssetName = "Stage3", MountOffsetZ = 0.76 },
		{ MinimumCoins = 100, AssetName = "Stage4", MountOffsetZ = 0.86 },
		{ MinimumCoins = 200, AssetName = "Stage5", MountOffsetZ = 0.98 },
	},
}

-- The smallest bag remains equipped at zero coins; higher stages communicate progressively fuller runs.
function BackpackConfig.GetStage(carriedCoins: number)
	local selectedStage = BackpackConfig.Stages[1]
	for _, stage in BackpackConfig.Stages do
		if carriedCoins < stage.MinimumCoins then
			break
		end
		selectedStage = stage
	end
	return selectedStage
end

for _, stage in BackpackConfig.Stages do
	table.freeze(stage)
end
table.freeze(BackpackConfig.Stages)

return table.freeze(BackpackConfig)
