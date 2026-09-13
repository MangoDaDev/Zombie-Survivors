export type ItemInfo = {
	Id: number,
	Name: string,
	AssetName: string,
	ChanceWeight: number,
	Price: number,
	GuestPay: number,
	MoveSpeed: number,
	CarryOffset: CFrame?,
}

local ItemsInfo: { ItemInfo } = {
	{
		Id = 1,
		Name = "Wrench",
		AssetName = "Wrench",
		ChanceWeight = 50,
		Price = 25,
		GuestPay = 2,
		MoveSpeed = 8,
	},
	{
		Id = 2,
		Name = "Knife",
		AssetName = "Knife",
		ChanceWeight = 30,
		Price = 40,
		GuestPay = 4,
		MoveSpeed = 8,
	},
	{
		Id = 3,
		Name = "Hammer",
		AssetName = "Hammer",
		ChanceWeight = 15,
		Price = 60,
		GuestPay = 6,
		MoveSpeed = 8,
	},
	{
		Id = 4,
		Name = "Cleaver",
		AssetName = "Cleaver",
		ChanceWeight = 5,
		Price = 100,
		GuestPay = 10,
		MoveSpeed = 8,
	},
}

return ItemsInfo
