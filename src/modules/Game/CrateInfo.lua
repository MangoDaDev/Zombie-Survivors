local SharedCrateInfo = {
	TemplateFolderName = "Crates",
	RespawnDelay = 1.5,
	SpawnPadding = 4,
	MinimumSpawnSeparation = 8,
	ScaleMinimum = 0.9,
	ScaleMaximum = 1.12,
	HealthBarHideDelay = 1.6,
	HealthBarTweenTime = 0.12,
	DamageSoundName = "CrateDamage",
	BreakSoundNames = { "CrateBreak1", "CrateBreak2", "CrateBreak3" },
	PreviewSwitchCount = 18,
	PreviewStartDelay = 0.04,
	PreviewEndDelay = 0.22,
	RevealFadeTime = 0.2,
	RevealLifetime = 60,
	PurchaseDistance = 13,
	RevealTickSoundName = "ItemRevealTick",
	RevealCompleteSoundName = "ItemRevealComplete",
	Respawns = true,
}

local function CreateCrate(Info)
	for Key, Value in SharedCrateInfo do
		if Info[Key] == nil then Info[Key] = Value end
	end
	return Info
end

local CrateInfo = {
	Reset = {
		Interval = 300,
		MinimumWallVisibleTime = 5,
		SpawnInterval = 0.08,
		WallTemplateName = "ResetWall",
	},
	PityDisplay = {
		PartName = "PityDisplay",
		PixelsPerStud = 16,
	},
	Crates = {
		CreateCrate({
			Id = "CommonCrate",
			DisplayName = "Common",
			TemplateName = "CommonCrate",
			Health = 24,
			MaximumActive = 24,
			ActualLootLuck = 1,
			PreviewLootLuck = 3,
		}),
		CreateCrate({
			Id = "UncommonCrate",
			DisplayName = "Uncommon",
			TemplateName = "UncommonCrate",
			Health = 80,
			MaximumActive = 18,
			ActualLootLuck = 2,
			PreviewLootLuck = 6,
		}),
		CreateCrate({
			Id = "RareCrate",
			DisplayName = "Rare",
			TemplateName = "RareCrate",
			Health = 240,
			MaximumActive = 12,
			ActualLootLuck = 4,
			PreviewLootLuck = 12,
		}),
		CreateCrate({
			Id = "EpicCrate",
			DisplayName = "Epic",
			TemplateName = "EpicCrate",
			Health = 600,
			MaximumActive = 8,
			ActualLootLuck = 8,
			PreviewLootLuck = 24,
		}),
		CreateCrate({
			Id = "LegendaryCrate",
			DisplayName = "Legendary",
			TemplateName = "LegendaryCrate",
			Health = 1_800,
			MaximumActive = 4,
			ActualLootLuck = 16,
			PreviewLootLuck = 48,
		}),
		CreateCrate({
			Id = "MythicalCrate",
			DisplayName = "Mythical",
			TemplateName = "MythicalCrate",
			Health = 5_000,
			MaximumActive = 1,
			ActualLootLuck = 32,
			PreviewLootLuck = 96,
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
			ActualLootLuck = 64,
			PreviewLootLuck = 192,
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

return CrateInfo
