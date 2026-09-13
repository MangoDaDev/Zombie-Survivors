export type ItemInfo = {
	Name: string,
	AssetName: string,
	ChanceWeight: number,
	MoveSpeed: number,
	HeightOffset: number,
}

local ItemsInfo: { ItemInfo } = {
	{
		Name = "Wrench",
		AssetName = "Wrench",
		ChanceWeight = 100,
		MoveSpeed = 8,
		HeightOffset = 0.25,
	},
}

return ItemsInfo
