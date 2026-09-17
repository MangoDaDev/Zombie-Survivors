local SharedCrateInfo = {
	TemplateFolderName = "Crates",
	RespawnDelay = 0.6,
	SpawnPadding = 4,
	MinimumSpawnSeparation = 8,
	ScaleMinimum = 0.8,
	ScaleMaximum = 1.15,
	ScaleMode = 1.05,
	ScaleLuckStrength = 2,
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
		Interval = 180,
		MinimumWallVisibleTime = 5,
		SpawnInterval = 0.08,
		WallTemplateName = "ResetWall",
	},
	PityDisplay = {
		PartName = "PityDisplay",
		PixelsPerStud = 16,
	},
	NewPlayerDropSequence = { 1, 6, 5, 14 },
	Crates = {
		CreateCrate({
			Id = "CommonCrate",
			DisplayName = "Common",
			TemplateName = "CommonCrate",
			Health = 16,
			MaximumActive = 48,
			SpawnDepthBias = -0.9,
			RarityChances = {
				Common = 88,
				Uncommon = 11,
				Rare = 1,
			},
		}),
		CreateCrate({
			Id = "UncommonCrate",
			DisplayName = "Uncommon",
			TemplateName = "UncommonCrate",
			Health = 72,
			MaximumActive = 36,
			SpawnDepthBias = -0.45,
			RarityChances = {
				Common = 35,
				Uncommon = 50,
				Rare = 14,
				Epic = 1,
			},
		}),
		CreateCrate({
			Id = "RareCrate",
			DisplayName = "Rare",
			TemplateName = "RareCrate",
			Health = 280,
			MaximumActive = 24,
			SpawnDepthBias = 0.1,
			RarityChances = {
				Common = 8,
				Uncommon = 25,
				Rare = 45,
				Epic = 20,
				Legendary = 2,
			},
		}),
		CreateCrate({
			Id = "EpicCrate",
			DisplayName = "Epic",
			TemplateName = "EpicCrate",
			Health = 900,
			MaximumActive = 16,
			SpawnDepthBias = 0.5,
			RarityChances = {
				Common = 2,
				Uncommon = 8,
				Rare = 25,
				Epic = 45,
				Legendary = 18,
				Mythic = 2,
			},
		}),
		CreateCrate({
			Id = "LegendaryCrate",
			DisplayName = "Legendary",
			TemplateName = "LegendaryCrate",
			Health = 2_600,
			MaximumActive = 8,
			SpawnDepthBias = 0.9,
			RarityChances = {
				Uncommon = 2,
				Rare = 13,
				Epic = 32,
				Legendary = 44,
				Mythic = 8,
				Secret = 1,
			},
		}),
		CreateCrate({
			Id = "MythicalCrate",
			DisplayName = "Mythical",
			TemplateName = "MythicalCrate",
			Health = 7_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Rare = 5,
				Epic = 20,
				Legendary = 40,
				Mythic = 30,
				Secret = 5,
			},
			PityOnly = true,
			PityInterval = 420,
			Respawns = false,
			DisplayColor = Color3.fromRGB(255, 48, 65),
		}),
		CreateCrate({
			Id = "SecretCrate",
			DisplayName = "Secret",
			TemplateName = "SecretCrate",
			Health = 18_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Rare = 1,
				Epic = 7,
				Legendary = 22,
				Mythic = 45,
				Secret = 25,
			},
			PityOnly = true,
			PityInterval = 1_200,
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

function CrateInfo.RollScale(Info, RandomGenerator: Random?): number
	local Generator = RandomGenerator or DefaultRandom
	local Minimum = Info.ScaleMinimum
	local Maximum = Info.ScaleMaximum
	local Mode = Info.ScaleMode
	local Range = Maximum - Minimum
	local ModeChance = (Mode - Minimum) / Range
	local Roll = Generator:NextNumber()
	-- This triangular distribution favors slightly larger crates while averaging exactly normal size.
	if Roll < ModeChance then
		return Minimum + math.sqrt(Roll * Range * (Mode - Minimum))
	end
	return Maximum - math.sqrt((1 - Roll) * Range * (Maximum - Mode))
end

function CrateInfo.GetScaleLuck(Info, Scale: number): number
	return math.max(0.05, 1 + (Scale - 1) * Info.ScaleLuckStrength)
end

function CrateInfo.GetNormalizedRarityChances(Info, Luck: number?): { [string]: number }
	local Chances = {}
	local Total = 0
	local LuckMultiplier = if type(Luck) == "number" then math.max(Luck, 0.05) else 1
	for Stage, Rarity in RarityOrder do
		local Chance = Info and Info.RarityChances and Info.RarityChances[Rarity]
		if type(Chance) == "number" and Chance > 0 then
			local AdjustedChance = Chance * LuckMultiplier ^ (Stage - 1)
			Chances[Rarity] = AdjustedChance
			Total += AdjustedChance
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

function CrateInfo.GetRandomItem(ItemsInfo, Info, RandomGenerator: Random?, Luck: number?)
	local Generator = RandomGenerator or DefaultRandom
	local Chances = CrateInfo.GetNormalizedRarityChances(Info, Luck)
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

function CrateInfo.Validate()
	local PreviousExpectedStage = 0
	local SeenIds = {}
	for _, Info in CrateInfo.Crates do
		assert(type(Info.Id) == "string" and not SeenIds[Info.Id], `Invalid or duplicate crate id {tostring(Info.Id)}`)
		assert(type(Info.Health) == "number" and Info.Health > 0, `Invalid health for crate {Info.Id}`)
		assert(type(Info.ScaleMinimum) == "number" and type(Info.ScaleMaximum) == "number"
			and type(Info.ScaleMode) == "number" and Info.ScaleMinimum < Info.ScaleMode
			and Info.ScaleMode < Info.ScaleMaximum, `Invalid scale distribution for {Info.Id}`)
		assert(math.abs((Info.ScaleMinimum + Info.ScaleMode + Info.ScaleMaximum) / 3 - 1) <= 0.02,
			`Average crate scale must remain near normal for {Info.Id}`)
		assert(type(Info.ScaleLuckStrength) == "number" and Info.ScaleLuckStrength >= 0,
			`Invalid scale luck strength for {Info.Id}`)
		local Chances = CrateInfo.GetNormalizedRarityChances(Info)
		local TotalChance = 0
		local ExpectedStage = 0
		for Stage, Rarity in RarityOrder do
			local RawChance = Info.RarityChances[Rarity]
			assert(RawChance == nil or (type(RawChance) == "number" and RawChance >= 0), `Invalid {Rarity} chance for {Info.Id}`)
			TotalChance += Chances[Rarity] or 0
			ExpectedStage += Stage * (Chances[Rarity] or 0)
		end
		assert(math.abs(TotalChance - 1) < 0.0001, `Crate chances do not normalize for {Info.Id}`)
		if Info.PityOnly ~= true then
			assert(ExpectedStage > PreviousExpectedStage, `Regular crate quality must increase at {Info.Id}`)
			PreviousExpectedStage = ExpectedStage
		end
		SeenIds[Info.Id] = true
	end
end

CrateInfo.Validate()

return CrateInfo
