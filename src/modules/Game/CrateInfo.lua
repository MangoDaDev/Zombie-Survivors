local CrateInfo = {
	Reset = {
		Interval = 150,
		MinimumWallVisibleTime = 5,
		SpawnInterval = 0.08,
		WallTemplateName = "ResetWall",
	},
	Crates = {
		{
			Id = "StandardCrate",
			TemplateFolderName = "Crates",
			TemplateName = "Crate",
			Health = 20,
			MaximumActive = 28,
			RespawnDelay = 1.5,
			SpawnPadding = 4,
			MinimumSpawnSeparation = 8,
			ScaleMinimum = 0.9,
			ScaleMaximum = 1.12,
			HealthBarHideDelay = 1.6,
			HealthBarTweenTime = 0.12,
			DamageSoundName = "CrateDamage",
			BreakSoundNames = { "CrateBreak1", "CrateBreak2", "CrateBreak3" },
			ActualLootLuck = 1,
			PreviewLootLuck = 3,
			PreviewSwitchCount = 22,
			PreviewStartDelay = 0.035,
			PreviewEndDelay = 0.273,
			RevealFadeTime = 0.2,
			RevealLifetime = 45,
			PurchaseDistance = 13,
			RevealTickSoundName = "ItemRevealTick",
			RevealCompleteSoundName = "ItemRevealComplete",
		},
	},
}

return CrateInfo
