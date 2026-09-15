local SharedBatInfo = {
	ServerCooldownFactor = 0.6,
	ServerCooldownLeeway = 0.08,
	ValidationHistoryWindow = 0.75,
	ValidationSampleInterval = 0.08,
	PredictionTimeout = 2.5,
	ImpactDelay = 0.08,
	ImpactReactionAngleDegrees = 5,
	ImpactReactionDuration = 0.12,
	SwingRotationDegrees = Vector3.new(72, 18, 0),
	HitboxWidth = 7,
	HitboxHeight = 6,
	ValidationDistanceBuffer = 3,
	MinimumFacingDot = -0.25,
	SwingSoundName = "BatSwing",
	EquipSoundName = "BatEquip",
	ImpactSoundNames = { "BatImpact1" },
}

local function CreateBat(Info)
	for Key, Value in SharedBatInfo do
		if Info[Key] == nil then Info[Key] = Value end
	end
	return Info
end

local BatInfo = {
	CreateBat({
		Id = "WoodenBat",
		DisplayName = "Wooden Bat",
		TemplateName = "Wooden Bat",
		Icon = "WoodenBat",
		CrateDamage = 4,
		SwingCooldown = 0.55,
		Range = 7,
	}),
	CreateBat({
		Id = "StoneBat",
		DisplayName = "Stone Bat",
		TemplateName = "Stone Bat",
		Icon = "StoneBat",
		CrateDamage = 20,
		SwingCooldown = 0.52,
		Range = 7.25,
	}),
	CreateBat({
		Id = "BronzeBat",
		DisplayName = "Bronze Bat",
		TemplateName = "Bronze Bat",
		Icon = "BronzeBat",
		CrateDamage = 50,
		SwingCooldown = 0.5,
		Range = 7.35,
	}),
	CreateBat({
		Id = "GoldBat",
		DisplayName = "Gold Bat",
		TemplateName = "Gold Bat",
		Icon = "GoldBat",
		CrateDamage = 100,
		SwingCooldown = 0.48,
		Range = 7.5,
	}),
	CreateBat({
		Id = "EmeraldBat",
		DisplayName = "Emerald Bat",
		TemplateName = "Emerald Bat",
		Icon = "EmeraldBat",
		CrateDamage = 250,
		SwingCooldown = 0.46,
		Range = 7.65,
	}),
	CreateBat({
		Id = "DiamondBat",
		DisplayName = "Diamond Bat",
		TemplateName = "Diamond Bat",
		Icon = "DiamondBat",
		CrateDamage = 650,
		SwingCooldown = 0.44,
		Range = 7.8,
	}),
	CreateBat({
		Id = "ObsidianBat",
		DisplayName = "Obsidian Bat",
		TemplateName = "ObsidianBat",
		Icon = "ObsidianBat",
		CrateDamage = 1_500,
		SwingCooldown = 0.42,
		Range = 8,
	}),
}

return BatInfo
