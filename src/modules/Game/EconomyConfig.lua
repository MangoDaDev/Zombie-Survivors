local EconomyConfig = {
	StartingCash = 500,
	MinimumRestorationReward = 60,
	RestorationRewardRate = 0.6,
	Rarities = {
		Common = {
			ProgressionStage = 1,
			RestorationTier = 1,
			SourcePriceRange = { 25, 52 },
			PriceRange = { 80, 320 },
			GuestPayRate = 0.08,
		},
		Uncommon = {
			ProgressionStage = 2,
			RestorationTier = 2,
			SourcePriceRange = { 60, 118 },
			PriceRange = { 650, 3_200 },
			GuestPayRate = 0.05,
		},
		Rare = {
			ProgressionStage = 3,
			RestorationTier = 3,
			SourcePriceRange = { 130, 235 },
			PriceRange = { 8_000, 32_000 },
			GuestPayRate = 0.022,
		},
		Epic = {
			ProgressionStage = 4,
			RestorationTier = 4,
			SourcePriceRange = { 240, 460 },
			PriceRange = { 55_000, 220_000 },
			GuestPayRate = 0.009,
		},
		Legendary = {
			ProgressionStage = 5,
			RestorationTier = 5,
			SourcePriceRange = { 500, 880 },
			PriceRange = { 350_000, 950_000 },
			GuestPayRate = 0.004,
		},
		Mythic = {
			ProgressionStage = 6,
			RestorationTier = 6,
			SourcePriceRange = { 900, 1_400 },
			PriceRange = { 1_500_000, 4_500_000 },
			GuestPayRate = 0.0018,
		},
		Secret = {
			ProgressionStage = 7,
			RestorationTier = 7,
			SourcePriceRange = { 1_800, 2_500 },
			PriceRange = { 7_500_000, 20_000_000 },
			GuestPayRate = 0.0008,
		},
	},
}

local function RoundToReadableValue(Value: number): number
	local Interval = if Value >= 1_000_000
		then 10_000
		elseif Value >= 100_000 then 1_000
		elseif Value >= 10_000 then 100
		elseif Value >= 1_000 then 50
		else 5

	return math.max(Interval, math.round(Value / Interval) * Interval)
end

function EconomyConfig.GetRarity(Rarity: string)
	return EconomyConfig.Rarities[Rarity] or EconomyConfig.Rarities.Common
end

function EconomyConfig.GetMinimumItemPrice(): number
	local MinimumPrice = math.huge
	for _, RarityInfo in EconomyConfig.Rarities do
		MinimumPrice = math.min(MinimumPrice, RarityInfo.PriceRange[1])
	end
	return MinimumPrice
end

function EconomyConfig.GetItemPrice(Rarity: string, DifficultyValue: number): number
	local Info = EconomyConfig.GetRarity(Rarity)
	local SourceMinimum = Info.SourcePriceRange[1]
	local SourceMaximum = Info.SourcePriceRange[2]
	local DifficultyAlpha = math.clamp(
		(DifficultyValue - SourceMinimum) / math.max(SourceMaximum - SourceMinimum, 1),
		0,
		1
	)
	local PriceMinimum = Info.PriceRange[1]
	local PriceMaximum = Info.PriceRange[2]

	return RoundToReadableValue(PriceMinimum + (PriceMaximum - PriceMinimum) * DifficultyAlpha)
end

function EconomyConfig.GetGuestPay(Rarity: string, Price: number): number
	local Info = EconomyConfig.GetRarity(Rarity)
	return math.max(1, RoundToReadableValue(Price * Info.GuestPayRate))
end

function EconomyConfig.GetRestorationTier(Rarity: string): number
	return EconomyConfig.GetRarity(Rarity).RestorationTier
end

function EconomyConfig.GetRestorationReward(Price: number): number
	return math.max(EconomyConfig.MinimumRestorationReward, RoundToReadableValue(Price * EconomyConfig.RestorationRewardRate))
end

function EconomyConfig.ApplyToItems(ItemsInfo)
	for _, ItemInfo in ItemsInfo do
		ItemInfo.Price = EconomyConfig.GetItemPrice(ItemInfo.Rarity, ItemInfo.DifficultyValue)
		ItemInfo.GuestPay = EconomyConfig.GetGuestPay(ItemInfo.Rarity, ItemInfo.Price)
		ItemInfo.RestorationTier = EconomyConfig.GetRestorationTier(ItemInfo.Rarity)
	end
end

return EconomyConfig
