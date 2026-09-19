local EconomyConfig = {
	-- Values above 1 increase every active and passive payout while reducing upgrade costs.
	ProgressionSpeedMultiplier = 1,
	-- Scales restorable item purchase prices without changing restoration tool costs.
	ItemPurchasePriceMultiplier = 0.5,
	-- Scales restoration rewards and restored-item sale values without changing purchase prices.
	ActiveIncomeMultiplier = 3,
	-- Gives onboarding rarities extra active income, blended back to normal by Legendary.
	OnboardingIncomeMultiplier = 2,
	OnboardingIncomeBlendEndStage = 5,
	-- Scales museum visitor payments only.
	PassiveIncomeMultiplier = 1.5,
	-- Values above 1 increase every upgrade price.
	UpgradeCostMultiplier = 1,
	-- Values above 1 steepen rarity prices and later-stage upgrade costs.
	LateGameCurveMultiplier = 1,

	StartingCash = 750,
	MinimumRestorationReward = 75,
	RestorationRewardRate = 0.75,
	RecoveryCrateId = "CommonCrate",
	RecoveryItemId = 1,
	RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
	Rarities = {
		Common = {
			ProgressionStage = 1,
			RestorationTier = 1,
			SourcePriceRange = { 25, 52 },
			PriceRange = { 120, 500 },
			GuestPayRate = 0.025,
		},
		Uncommon = {
			ProgressionStage = 2,
			RestorationTier = 2,
			SourcePriceRange = { 60, 118 },
			PriceRange = { 800, 2_200 },
			GuestPayRate = 0.018,
		},
		Rare = {
			ProgressionStage = 3,
			RestorationTier = 3,
			SourcePriceRange = { 130, 235 },
			PriceRange = { 4_000, 12_000 },
			GuestPayRate = 0.012,
		},
		Epic = {
			ProgressionStage = 4,
			RestorationTier = 4,
			SourcePriceRange = { 240, 460 },
			PriceRange = { 30_000, 90_000 },
			GuestPayRate = 0.008,
		},
		Legendary = {
			ProgressionStage = 5,
			RestorationTier = 5,
			SourcePriceRange = { 500, 880 },
			PriceRange = { 150_000, 450_000 },
			GuestPayRate = 0.005,
		},
		Mythic = {
			ProgressionStage = 6,
			RestorationTier = 6,
			SourcePriceRange = { 900, 1_400 },
			PriceRange = { 800_000, 2_400_000 },
			GuestPayRate = 0.003,
		},
		Secret = {
			ProgressionStage = 7,
			RestorationTier = 7,
			SourcePriceRange = { 1_800, 2_500 },
			PriceRange = { 5_000_000, 12_000_000 },
			GuestPayRate = 0.002,
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

local function GetLateGameScale(ProgressionStage: number): number
	return EconomyConfig.LateGameCurveMultiplier ^ math.max(ProgressionStage - 3, 0)
end

local function GetActiveIncomeScale(): number
	return EconomyConfig.ProgressionSpeedMultiplier * EconomyConfig.ActiveIncomeMultiplier
end

local function GetPassiveIncomeScale(): number
	return EconomyConfig.ProgressionSpeedMultiplier * EconomyConfig.PassiveIncomeMultiplier
end

function EconomyConfig.GetRarity(Rarity: string)
	return EconomyConfig.Rarities[Rarity] or EconomyConfig.Rarities.Common
end

function EconomyConfig.GetOnboardingIncomeScale(Rarity: string): number
	local ProgressionStage = EconomyConfig.GetRarity(Rarity).ProgressionStage
	local BlendLength = math.max(EconomyConfig.OnboardingIncomeBlendEndStage - 1, 1)
	local BlendAlpha = math.clamp((ProgressionStage - 1) / BlendLength, 0, 1)
	return EconomyConfig.OnboardingIncomeMultiplier + (1 - EconomyConfig.OnboardingIncomeMultiplier) * BlendAlpha
end

function EconomyConfig.GetMinimumItemPrice(): number
	local MinimumPrice = math.huge
	for _, Rarity in EconomyConfig.RarityOrder do
		local Info = EconomyConfig.Rarities[Rarity]
		MinimumPrice = math.min(MinimumPrice, EconomyConfig.GetItemPrice(Rarity, Info.SourcePriceRange[1]))
	end
	return MinimumPrice
end

function EconomyConfig.GetMinimumPriceForRestorationTier(RestorationTier: number): number?
	for _, Rarity in EconomyConfig.RarityOrder do
		local Info = EconomyConfig.Rarities[Rarity]
		if Info.RestorationTier == RestorationTier then
			return EconomyConfig.GetItemPrice(Rarity, Info.SourcePriceRange[1])
		end
	end
	return nil
end

function EconomyConfig.GetItemPrice(Rarity: string, DifficultyValue: number): number
	local Info = EconomyConfig.GetRarity(Rarity)
	local SourceMinimum = Info.SourcePriceRange[1]
	local SourceMaximum = Info.SourcePriceRange[2]
	local DifficultyAlpha =
		math.clamp((DifficultyValue - SourceMinimum) / math.max(SourceMaximum - SourceMinimum, 1), 0, 1)
	local PriceMinimum = Info.PriceRange[1]
	local PriceMaximum = Info.PriceRange[2]
	local BasePrice = PriceMinimum + (PriceMaximum - PriceMinimum) * DifficultyAlpha

	return RoundToReadableValue(
		BasePrice * EconomyConfig.ItemPurchasePriceMultiplier * GetLateGameScale(Info.ProgressionStage)
	)
end

function EconomyConfig.GetSaleValue(Rarity: string, Price: number): number
	return RoundToReadableValue(Price * GetActiveIncomeScale() * EconomyConfig.GetOnboardingIncomeScale(Rarity))
end

function EconomyConfig.GetGuestPay(Rarity: string, Price: number): number
	local Info = EconomyConfig.GetRarity(Rarity)
	return math.max(1, RoundToReadableValue(Price * Info.GuestPayRate * GetPassiveIncomeScale()))
end

function EconomyConfig.GetRestorationTier(Rarity: string): number
	return EconomyConfig.GetRarity(Rarity).RestorationTier
end

function EconomyConfig.GetRestorationReward(Rarity: string, Price: number): number
	return math.max(
		EconomyConfig.MinimumRestorationReward,
		RoundToReadableValue(
			Price
				* EconomyConfig.RestorationRewardRate
				* GetActiveIncomeScale()
				* EconomyConfig.GetOnboardingIncomeScale(Rarity)
		)
	)
end

function EconomyConfig.GetUpgradeCost(BaseCost: number, ProgressionStage: number?): number
	if BaseCost <= 0 then
		return 0
	end
	local Stage = ProgressionStage or 1
	local CostScale = EconomyConfig.UpgradeCostMultiplier
		* GetLateGameScale(Stage)
		/ EconomyConfig.ProgressionSpeedMultiplier
	return RoundToReadableValue(BaseCost * CostScale)
end

function EconomyConfig.GetRecoveryGrant(Cash: number, PurchasePrice: number): number
	return math.max(0, PurchasePrice - math.max(0, Cash))
end

function EconomyConfig.ApplyToItems(ItemsInfo)
	for _, ItemInfo in ItemsInfo do
		ItemInfo.Price = EconomyConfig.GetItemPrice(ItemInfo.Rarity, ItemInfo.DifficultyValue)
		ItemInfo.SaleValue = EconomyConfig.GetSaleValue(ItemInfo.Rarity, ItemInfo.Price)
		ItemInfo.GuestPay = EconomyConfig.GetGuestPay(ItemInfo.Rarity, ItemInfo.Price)
		ItemInfo.RestorationTier = EconomyConfig.GetRestorationTier(ItemInfo.Rarity)
	end
end

function EconomyConfig.ValidateItems(ItemsInfo)
	local SeenIds = {}
	for _, ItemInfo in ItemsInfo do
		local Info = EconomyConfig.Rarities[ItemInfo.Rarity]
		assert(Info, `Unknown item rarity {tostring(ItemInfo.Rarity)}`)
		assert(
			type(ItemInfo.Id) == "number" and not SeenIds[ItemInfo.Id],
			`Invalid or duplicate item id {tostring(ItemInfo.Id)}`
		)
		assert(
			type(ItemInfo.ChanceWeight) == "number" and ItemInfo.ChanceWeight > 0,
			`Invalid chance weight for item {ItemInfo.Id}`
		)
		assert(
			type(ItemInfo.DifficultyValue) == "number"
				and ItemInfo.DifficultyValue >= Info.SourcePriceRange[1]
				and ItemInfo.DifficultyValue <= Info.SourcePriceRange[2],
			`Item {ItemInfo.Id} difficulty is outside its rarity range`
		)
		SeenIds[ItemInfo.Id] = true
	end
end

function EconomyConfig.Validate()
	for _, Value in
		{
			EconomyConfig.ProgressionSpeedMultiplier,
			EconomyConfig.ItemPurchasePriceMultiplier,
			EconomyConfig.ActiveIncomeMultiplier,
			EconomyConfig.OnboardingIncomeMultiplier,
			EconomyConfig.PassiveIncomeMultiplier,
			EconomyConfig.UpgradeCostMultiplier,
			EconomyConfig.LateGameCurveMultiplier,
		}
	do
		assert(type(Value) == "number" and Value > 0, "Economy multipliers must be positive")
	end
	assert(
		type(EconomyConfig.OnboardingIncomeBlendEndStage) == "number"
			and EconomyConfig.OnboardingIncomeBlendEndStage >= 2,
		"Onboarding income blend end stage must be at least 2"
	)

	local PreviousPrice = 0
	local PreviousStage = 0
	local PreviousOnboardingScale = math.huge
	for _, Rarity in EconomyConfig.RarityOrder do
		local Info = EconomyConfig.Rarities[Rarity]
		assert(Info, `Missing rarity economy for {Rarity}`)
		assert(Info.ProgressionStage > PreviousStage, `Rarity stage must increase at {Rarity}`)
		assert(Info.SourcePriceRange[1] <= Info.SourcePriceRange[2], `Invalid source price range for {Rarity}`)
		assert(Info.PriceRange[1] <= Info.PriceRange[2], `Invalid price range for {Rarity}`)
		local MinimumPrice = EconomyConfig.GetItemPrice(Rarity, Info.SourcePriceRange[1])
		assert(MinimumPrice > PreviousPrice, `Minimum item price must increase at {Rarity}`)
		assert(Info.GuestPayRate > 0, `Guest pay rate must be positive for {Rarity}`)
		local OnboardingScale = EconomyConfig.GetOnboardingIncomeScale(Rarity)
		assert(OnboardingScale >= 1, `Onboarding income scale cannot reduce income for {Rarity}`)
		assert(OnboardingScale <= PreviousOnboardingScale, `Onboarding income scale must not increase at {Rarity}`)
		PreviousPrice = MinimumPrice
		PreviousStage = Info.ProgressionStage
		PreviousOnboardingScale = OnboardingScale
	end
end

EconomyConfig.Validate()

return EconomyConfig
