local GaussianRandom = require(script.Parent.Parent.Math.GaussianRandom)
local GetRandomFromWeightedTable = require(script.Parent.Parent.Math.GetRandomFromWeightedTable)

local SharedCrateInfo = {
	TemplateFolderName = "Crates",
	SpawnPadding = 4,
	MinimumSpawnSeparation = 8,
	ScaleStandardDeviation = 0.12,
	ScaleLuckStrength = 2,
	HealthBarHideDelay = 1.6,
	HealthBarTweenTime = 0.12,
	DamageSoundName = "CrateDamage",
	BreakSoundNames = { "CrateBreak1", "CrateBreak2", "CrateBreak3" },
	PreviewSwitchCount = 18,
	PreviewStartDelay = 0.01,
	PreviewEndDelay = 0.06,
	-- Keep the player's first roll suspenseful and preview only exciting rare-or-better silhouettes.
	FirstRollPreviewSwitchCount = 28,
	FirstRollPreviewStartDelay = 0.07,
	FirstRollPreviewEndDelay = 0.13,
	FirstRollPreviewScale = 1.5,
	RevealFadeTime = 0.11,
	PurchaseDistance = 13,
	RevealTickSoundName = "ItemRevealTick",
	RevealCompleteSoundName = "ItemRevealComplete",
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
		SpawnBatchSize = 8,
		SpawnInterval = 0.02,
		WallTemplateName = "ResetWall",
	},
	PityDisplay = {
		PartName = "PityDisplay",
		PixelsPerStud = 16,
	},
	NewPlayerDropSequence = {
		{ ItemId = 1 },
		{ ItemId = 14 },
	},
	Crates = {
		-- Every crate keeps a nonzero chance for every rarity; better crates improve weighting and value per durability.
		CreateCrate({
			Id = "CommonCrate",
			DisplayName = "Common",
			TemplateName = "CommonCrate",
			Health = 16,
			MaximumActive = 48,
			SpawnDepthBias = -0.9,
			RarityChances = {
				Common = 87,
				Uncommon = 11,
				Rare = 1.7,
				Epic = 0.25,
				Legendary = 0.045,
				Mythic = 0.0045,
				Secret = 0.0005,
			},
		}),
		CreateCrate({
			Id = "UncommonCrate",
			DisplayName = "Uncommon",
			TemplateName = "UncommonCrate",
			Health = 90,
			MaximumActive = 36,
			SpawnDepthBias = -0.45,
			RarityChances = {
				Common = 32,
				Uncommon = 49,
				Rare = 16,
				Epic = 2.6,
				Legendary = 0.35,
				Mythic = 0.045,
				Secret = 0.005,
			},
		}),
		CreateCrate({
			Id = "RareCrate",
			DisplayName = "Rare",
			TemplateName = "RareCrate",
			Health = 500,
			MaximumActive = 24,
			SpawnDepthBias = 0.1,
			RarityChances = {
				Common = 6,
				Uncommon = 23,
				Rare = 47,
				Epic = 21,
				Legendary = 2.7,
				Mythic = 0.27,
				Secret = 0.03,
			},
		}),
		CreateCrate({
			Id = "EpicCrate",
			DisplayName = "Epic",
			TemplateName = "EpicCrate",
			Health = 2_000,
			MaximumActive = 16,
			SpawnDepthBias = 0.5,
			RarityChances = {
				Common = 1.2,
				Uncommon = 6,
				Rare = 24,
				Epic = 48,
				Legendary = 18,
				Mythic = 2.5,
				Secret = 0.3,
			},
		}),
		CreateCrate({
			Id = "LegendaryCrate",
			DisplayName = "Legendary",
			TemplateName = "LegendaryCrate",
			Health = 6_500,
			MaximumActive = 8,
			SpawnDepthBias = 0.9,
			RarityChances = {
				Common = 0.3,
				Uncommon = 1.2,
				Rare = 8,
				Epic = 30,
				Legendary = 47,
				Mythic = 12,
				Secret = 1.5,
			},
		}),
		CreateCrate({
			Id = "MythicalCrate",
			DisplayName = "Mythical",
			TemplateName = "MythicalCrate",
			Health = 15_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Common = 0.1,
				Uncommon = 0.4,
				Rare = 2.5,
				Epic = 15,
				Legendary = 40,
				Mythic = 36,
				Secret = 6,
			},
			PityOnly = true,
			PityInterval = 450,
			DisplayColor = Color3.fromRGB(255, 48, 65),
		}),
		CreateCrate({
			Id = "SecretCrate",
			DisplayName = "Secret",
			TemplateName = "SecretCrate",
			Health = 30_000,
			MaximumActive = 1,
			SpawnDepthBias = 1,
			RarityChances = {
				Common = 0.05,
				Uncommon = 0.15,
				Rare = 0.8,
				Epic = 5,
				Legendary = 20,
				Mythic = 47,
				Secret = 27,
			},
			PityOnly = true,
			PityInterval = 1_200,
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
	local StandardDeviation = Info.ScaleStandardDeviation
	-- Log-normal sizing has no hard bounds, stays positive, averages 1x, and keeps a longer high-size tail.
	local LogMean = -(StandardDeviation ^ 2) / 2
	return math.exp(GaussianRandom(LogMean, StandardDeviation, Generator))
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
	local RarityEntries = {}
	for _, Rarity in RarityOrder do
		local ChanceWeight = Info and Info.RarityChances and Info.RarityChances[Rarity]
		if type(ChanceWeight) == "number" and ChanceWeight > 0 then
			table.insert(RarityEntries, {
				Rarity = Rarity,
				ChanceWeight = ChanceWeight,
			})
		end
	end
	-- Crate size luck uses the shared weighted-table curve so rare outcomes receive the intended boost.
	local RarityEntry = GetRandomFromWeightedTable.GetRandomFromWeightedTable(RarityEntries, "ChanceWeight", Generator, Luck)
	if not RarityEntry then return nil end

	local Candidates = {}
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Rarity == RarityEntry.Rarity and type(ItemInfo.ChanceWeight) == "number" and ItemInfo.ChanceWeight > 0 then
			table.insert(Candidates, ItemInfo)
		end
	end
	return GetRandomFromWeightedTable.GetRandomFromWeightedTable(Candidates, "ChanceWeight", Generator)
end

function CrateInfo.Validate()
	local PreviousExpectedStage = 0
	local PreviousHealth = 0
	local SeenIds = {}
	for _, Info in CrateInfo.Crates do
		assert(type(Info.Id) == "string" and not SeenIds[Info.Id], `Invalid or duplicate crate id {tostring(Info.Id)}`)
		assert(type(Info.Health) == "number" and Info.Health > 0, `Invalid health for crate {Info.Id}`)
		assert(Info.Health > PreviousHealth, `Crate health must increase at {Info.Id}`)
		assert(type(Info.ScaleStandardDeviation) == "number" and Info.ScaleStandardDeviation > 0,
			`Invalid scale distribution for {Info.Id}`)
		assert(type(Info.ScaleLuckStrength) == "number" and Info.ScaleLuckStrength >= 0,
			`Invalid scale luck strength for {Info.Id}`)
		local Chances = CrateInfo.GetNormalizedRarityChances(Info)
		local TotalChance = 0
		local ExpectedStage = 0
		for Stage, Rarity in RarityOrder do
			local RawChance = Info.RarityChances[Rarity]
			assert(type(RawChance) == "number" and RawChance > 0, `{Info.Id} must keep a nonzero {Rarity} chance`)
			TotalChance += Chances[Rarity] or 0
			ExpectedStage += Stage * (Chances[Rarity] or 0)
		end
		assert(math.abs(TotalChance - 1) < 0.0001, `Crate chances do not normalize for {Info.Id}`)
		assert(ExpectedStage > PreviousExpectedStage, `Crate quality must increase at {Info.Id}`)
		PreviousExpectedStage = ExpectedStage
		PreviousHealth = Info.Health
		SeenIds[Info.Id] = true
	end
end

CrateInfo.Validate()

return CrateInfo
