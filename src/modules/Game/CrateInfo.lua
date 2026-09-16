local SharedCrateInfo = {
	TemplateFolderName = "Crates",
	RespawnDelay = 0.75,
	SpawnPadding = 4,
	MinimumSpawnSeparation = 8,
	ScaleMinimum = 0.9,
	ScaleMaximum = 1.12,
	HealthBarHideDelay = 1.6,
	HealthBarTweenTime = 0.12,
	DamageSoundName = "CrateDamage",
	BreakSoundNames = { "CrateBreak1", "CrateBreak2", "CrateBreak3" },
	PreviewSwitchCount = 18,
	PreviewStartDelay = 0.01,
	PreviewEndDelay = 0.06,
	RevealFadeTime = 0.11,
	PurchaseDistance = 13,
	RevealTickSoundName = "ItemRevealTick",
	RevealCompleteSoundName = "ItemRevealComplete",
	Respawns = true,
}

local RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local DefaultRandom = Random.new()

local function CreateCrate(Info)
	for Key, Value in SharedCrateInfo do
		if Info[Key] == nil then Info[Key] = Value end
	end
	return Info
end

local CrateInfo = {
	Reset = {
		Interval = 150,
		MinimumWallVisibleTime = 5,
		SpawnInterval = 0.08,
		WallTemplateName = "ResetWall",
	},
	PityDisplay = {
		PartName = "PityDisplay",
		PixelsPerStud = 16,
	},
	NewPlayerDropSequence = { 1, 6, 5 },
	Crates = {
		CreateCrate({
			Id = "CommonCrate",
			DisplayName = "Common",
			TemplateName = "CommonCrate",
			Health = 12,
			MaximumActive = 48,
			SpawnDepthBias = -0.9,
			RarityChances = {
				Common = 72,
				Uncommon = 20,
				Rare = 6,
				Epic = 1.5,
				Legendary = 0.4,
				Mythic = 0.09,
				Secret = 0.01,
			},
		}),
		CreateCrate({
			Id = "UncommonCrate",
			DisplayName = "Uncommon",
			TemplateName = "UncommonCrate",
			Health = 48,
			MaximumActive = 36,
			SpawnDepthBias = -0.45,
			RarityChances = {
				Common = 52,
				Uncommon = 30,
				Rare = 13,
				Epic = 4,
				Legendary = 0.8,
				Mythic = 0.18,
				Secret = 0.02,
			},
		}),
		CreateCrate({
			Id = "RareCrate",
			DisplayName = "Rare",
			TemplateName = "RareCrate",
			Health = 160,
			MaximumActive = 24,
			SpawnDepthBias = 0.1,
			RarityChances = {
				Common = 32,
				Uncommon = 32,
				Rare = 23,
				Epic = 10,
				Legendary = 2.4,
				Mythic = 0.54,
				Secret = 0.06,
			},
		}),
		CreateCrate({
			Id = "EpicCrate",
			DisplayName = "Epic",
			TemplateName = "EpicCrate",
			Health = 600,
			MaximumActive = 16,
			SpawnDepthBias = 0.5,
			RarityChances = {
				Common = 16,
				Uncommon = 27,
				Rare = 29,
				Epic = 20,
				Legendary = 6.5,
				Mythic = 1.35,
				Secret = 0.15,
			},
		}),
		CreateCrate({
			Id = "LegendaryCrate",
			DisplayName = "Legendary",
			TemplateName = "LegendaryCrate",
			Health = 1_800,
			MaximumActive = 8,
			SpawnDepthBias = 0.9,
			RarityChances = {
				Common = 7,
				Uncommon = 16,
				Rare = 27,
				Epic = 28,
				Legendary = 17,
				Mythic = 4.5,
				Secret = 0.5,
			},
		}),
		CreateCrate({
			Id = "MythicalCrate",
			DisplayName = "Mythical",
			TemplateName = "MythicalCrate",
			Health = 5_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Common = 2,
				Uncommon = 8,
				Rare = 18,
				Epic = 28,
				Legendary = 27,
				Mythic = 15,
				Secret = 2,
			},
			PityOnly = true,
			PityInterval = 600,
			Respawns = false,
			DisplayColor = Color3.fromRGB(255, 48, 65),
		}),
		CreateCrate({
			Id = "SecretCrate",
			DisplayName = "Secret",
			TemplateName = "SecretCrate",
			Health = 12_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Common = 0.5,
				Uncommon = 3,
				Rare = 8.5,
				Epic = 18,
				Legendary = 27,
				Mythic = 34,
				Secret = 9,
			},
			PityOnly = true,
			PityInterval = 1_800,
			Respawns = false,
			DisplayColor = Color3.fromRGB(245, 245, 245),
		}),
	},
}

function CrateInfo.Get(CrateId: string)
	for _, Info in CrateInfo.Crates do
		if Info.Id == CrateId then return Info end
	end
end

function CrateInfo.GetRegularCrates(): { any }
	local Results = {}
	for _, Info in CrateInfo.Crates do
		if Info.PityOnly ~= true then table.insert(Results, Info) end
	end
	return Results
end

function CrateInfo.GetPityCrates(): { any }
	local Results = {}
	for _, Info in CrateInfo.Crates do
		if Info.PityOnly == true then table.insert(Results, Info) end
	end
	return Results
end

function CrateInfo.GetNormalizedRarityChances(Info): { [string]: number }
	local Chances = {}
	local Total = 0
	for _, Rarity in RarityOrder do
		local Chance = Info and Info.RarityChances and Info.RarityChances[Rarity]
		if type(Chance) == "number" and Chance > 0 then
			Chances[Rarity] = Chance
			Total += Chance
		end
	end

	if Total <= 0 then
		return { Common = 1 }
	end

	for Rarity, Chance in Chances do
		Chances[Rarity] = Chance / Total
	end
	return Chances
end

function CrateInfo.GetRandomItem(ItemsInfo, Info, RandomGenerator: Random?)
	local Generator = RandomGenerator or DefaultRandom
	local Chances = CrateInfo.GetNormalizedRarityChances(Info)
	local Roll = Generator:NextNumber()
	local SelectedRarity = "Common"
	for _, Rarity in RarityOrder do
		local Chance = Chances[Rarity] or 0
		if Chance > 0 then SelectedRarity = Rarity end
		Roll -= Chance
		if Roll <= 0 then
			SelectedRarity = Rarity
			break
		end
	end

	local Candidates = {}
	local TotalWeight = 0
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Rarity == SelectedRarity and type(ItemInfo.ChanceWeight) == "number" and ItemInfo.ChanceWeight > 0 then
			table.insert(Candidates, ItemInfo)
			TotalWeight += ItemInfo.ChanceWeight
		end
	end
	if TotalWeight <= 0 then return nil end

	local ItemRoll = Generator:NextNumber(0, TotalWeight)
	for _, ItemInfo in Candidates do
		ItemRoll -= ItemInfo.ChanceWeight
		if ItemRoll <= 0 then return ItemInfo end
	end
	return Candidates[#Candidates]
end

return CrateInfo
