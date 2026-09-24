local Images = require(script.Parent.Parent.Parent.UI.Images)
local AbilityDefinitions = require(script.Parent.Parent.Abilities.AbilityDefinitions)

local RollDefinitions = {}

RollDefinitions.InventoryDataKey = "RollInventory"
RollDefinitions.TotalRollsDataKey = "TotalRolls"

-- These timings are shared only so the authoritative server cadence stays aligned with the client presentation.
RollDefinitions.Timing = {
	ReelDuration = 2.6,
	ResultHoldDuration = 0.8,
	BonusActivationDuration = 0.72,
	AutoRollDelay = 0.45,
	DiscoveryAutoResumeDelay = 5,
}

-- BaseOdds becomes a relative weight (1 / BaseOdds). Replace this table to ship real rewards;
-- neither the RNG implementation nor the presentation contains placeholder-specific branches.
RollDefinitions.Items = {
	{
		Id = "Pebble",
		Name = "Pebble",
		Image = Images.StoneBat,
		BaseOdds = 2,
		Rarity = "Common",
		RarityRank = 1,
		Color = Color3.fromRGB(174, 183, 194),
	},
	{
		Id = "Leaf",
		Name = "Leaf",
		Image = Images.Luck,
		BaseOdds = 5,
		Rarity = "Uncommon",
		RarityRank = 2,
		Color = Color3.fromRGB(87, 211, 105),
	},
	{
		Id = "Berry",
		Name = "Berry",
		Image = Images.Cash,
		BaseOdds = 15,
		Rarity = "Rare",
		RarityRank = 3,
		Color = Color3.fromRGB(84, 164, 255),
	},
	{
		Id = "Star",
		Name = "Star",
		Image = Images.Sparkle,
		BaseOdds = 50,
		Rarity = "Epic",
		RarityRank = 4,
		Color = Color3.fromRGB(190, 103, 255),
	},
	{
		Id = "Crystal",
		Name = "Crystal",
		Image = Images.DiamondBat,
		BaseOdds = 150,
		Rarity = "Legendary",
		RarityRank = 5,
		Color = Color3.fromRGB(77, 239, 255),
	},
	{
		Id = "Crown",
		Name = "Crown",
		Image = Images.Rebirth,
		BaseOdds = 750,
		Rarity = "Mythic",
		RarityRank = 6,
		Color = Color3.fromRGB(255, 198, 72),
	},
	{
		Id = "Void",
		Name = "Void",
		Image = Images.Vignette,
		BaseOdds = 5000,
		Rarity = "Omniscient",
		RarityRank = 7,
		Color = Color3.fromRGB(255, 83, 202),
	},
}

for _, ability in AbilityDefinitions.List do
	if ability.Roll then
		table.insert(RollDefinitions.Items, {
			Id = "Ability_" .. ability.Id,
			Name = ability.Name,
			Image = ability.Icon,
			BaseOdds = ability.Roll.BaseOdds,
			Rarity = ability.Roll.Rarity,
			RarityRank = ability.Roll.RarityRank,
			Color = ability.Color,
			AbilityId = ability.Id,
		})
	end
end

RollDefinitions.ById = {}
for _, item in RollDefinitions.Items do
	item.Weight = 1 / item.BaseOdds
	RollDefinitions.ById[item.Id] = item
end

return RollDefinitions
