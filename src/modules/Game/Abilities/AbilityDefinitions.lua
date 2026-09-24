local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local AbilityDefinitions = {}

AbilityDefinitions.DataKey = "Abilities"
AbilityDefinitions.Categories = {
	Weapon = "Weapon",
	Passive = "Passive",
}
-- The server treats these five-slot limits as authoritative for every current and future ability.
AbilityDefinitions.EquipLimits = {
	Weapon = 5,
	Passive = 5,
}

local function getDaggerCount(level: number): number
	if level >= 50 then
		return 5
	elseif level >= 20 then
		return 4
	elseif level >= 10 then
		return 3
	elseif level >= 5 then
		return 2
	end
	return 1
end

local dagger = {
	Id = "Dagger",
	Name = "Dagger",
	Category = AbilityDefinitions.Categories.Weapon,
	Description = "Periodically hurls a dagger at the nearest zombie.",
	UpgradeDescription = "Upgrades increase damage and projectile size. Milestones add another dagger to every volley.",
	-- The 3D Studio model is used for the prominent previews; this icon keeps compact roll and badge UI lightweight.
	Icon = Images.Upgrade,
	AssetName = "Dagger",
	Color = Color3.fromRGB(95, 183, 255),
	MaxLevel = 50,
	BaseUpgradeCost = 120,
	UpgradeCostGrowth = 1.145,
	Roll = {
		BaseOdds = 8,
		Rarity = "Rare",
		RarityRank = 3,
	},
	Combat = {
		Cooldown = 1.25,
		Range = 100,
		ProjectileSpeed = 115,
	},
	Milestones = {
		{ Level = 5, Description = "Throws 2 Daggers" },
		{ Level = 10, Description = "Throws 3 Daggers" },
		{ Level = 20, Description = "Throws 4 Daggers" },
		{ Level = 50, Description = "Throws 5 Daggers" },
	},
}

function dagger.GetStats(level: number)
	local clampedLevel = math.clamp(math.floor(level), 1, dagger.MaxLevel)
	return {
		Damage = math.floor(15 + (clampedLevel - 1) * 2.35 + 0.5),
		ProjectileScale = 0.22 + (clampedLevel - 1) * 0.0035,
		DaggerCount = getDaggerCount(clampedLevel),
	}
end

AbilityDefinitions.List = { dagger }
AbilityDefinitions.ById = {
	[dagger.Id] = dagger,
}

function AbilityDefinitions.GetUpgradeCost(ability, currentLevel: number): number?
	if currentLevel >= ability.MaxLevel then
		return nil
	end

	-- Rounding to five keeps costs readable while exponential growth preserves long-term coin value.
	local rawCost = ability.BaseUpgradeCost * ability.UpgradeCostGrowth ^ (currentLevel - 1)
	return math.max(5, math.floor(rawCost / 5 + 0.5) * 5)
end

function AbilityDefinitions.GetNextMilestone(ability, currentLevel: number)
	for _, milestone in ability.Milestones do
		if milestone.Level > currentLevel then
			return milestone
		end
	end
	return nil
end

return AbilityDefinitions
