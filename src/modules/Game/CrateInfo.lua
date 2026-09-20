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
	SpongeTutorialReward = {
		ItemId = 6,
		GuaranteedDropCount = 2,
		RestorationSteps = { "Spray", "Sponge" },
	},
	NewPlayerDropSequence = { 1, 6, 5, 14 },
	Crates = {
		-- Keep higher-tier rewards gated behind the matching bat progression through sharply increasing durability.
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
			Health = 160,
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
			Health = 1_000,
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
			Health = 5_000,
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
			Health = 20_000,
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
			Health = 60_000,
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
			PityInterval = 450,
			DisplayColor = Color3.fromRGB(255, 48, 65),
		}),
		CreateCrate({
			Id = "SecretCrate",
			DisplayName = "Secret",
			TemplateName = "SecretCrate",
			Health = 160_000,
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
			assert(RawChance == nil or (type(RawChance) == "number" and RawChance >= 0), `Invalid {Rarity} chance for {Info.Id}`)
			TotalChance += Chances[Rarity] or 0
			ExpectedStage += Stage * (Chances[Rarity] or 0)
		end
		assert(math.abs(TotalChance - 1) < 0.0001, `Crate chances do not normalize for {Info.Id}`)
		if Info.PityOnly ~= true then
			assert(ExpectedStage > PreviousExpectedStage, `Regular crate quality must increase at {Info.Id}`)
			PreviousExpectedStage = ExpectedStage
		end
		PreviousHealth = Info.Health
		SeenIds[Info.Id] = true
	end
end

CrateInfo.Validate()

return CrateInfo
