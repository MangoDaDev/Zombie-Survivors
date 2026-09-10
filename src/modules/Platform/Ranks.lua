export type Rank = {
	Name: string,
	Users: { number },
	Emoji: string,
}

local Ranks: { Rank } = {
	{
		Name = "Owner",
		Users = { 3509523943, 5666751590, -1, -2, 10887546665 },
		Emoji = "👑",
	},
}

return Ranks
