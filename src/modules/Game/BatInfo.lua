local SharedBatInfo = {
	ServerCooldownFactor = 0.35,
	ServerCooldownLeeway = 0.15,
	ValidationHistoryWindow = 6,
	ValidationSampleInterval = 0.08,
	ImpactDelay = 0.08,
	ImpactReactionAngleDegrees = 5,
	ImpactReactionDuration = 0.12,
	SwingRotationDegrees = Vector3.new(72, 18, 0),
	HitboxWidth = 7,
	HitboxHeight = 6,
	ValidationDistanceBuffer = 6,
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
		Id = "IronBat",
		DisplayName = "Iron Bat",
		TemplateName = "Iron Bat",
		Icon = "IronBat",
		CrateDamage = 80,
		SwingCooldown = 0.49,
		Range = 7.42,
	}),
	CreateBat({
		Id = "GoldBat",
		DisplayName = "Gold Bat",
		TemplateName = "Gold Bat",
		Icon = "GoldBat",
		CrateDamage = 140,
		SwingCooldown = 0.47,
		Range = 7.55,
	}),
	CreateBat({
		Id = "EmeraldBat",
		DisplayName = "Emerald Bat",
		TemplateName = "Emerald Bat",
		Icon = "EmeraldBat",
		CrateDamage = 300,
		SwingCooldown = 0.45,
		Range = 7.7,
	}),
	CreateBat({
		Id = "TitaniumBat",
		DisplayName = "Titanium Bat",
		TemplateName = "Titanium Bat",
		Icon = "TitaniumBat",
		CrateDamage = 550,
		SwingCooldown = 0.43,
		Range = 7.85,
	}),
	CreateBat({
		Id = "DiamondBat",
		DisplayName = "Diamond Bat",
		TemplateName = "Diamond Bat",
		Icon = "DiamondBat",
		CrateDamage = 900,
		SwingCooldown = 0.42,
		Range = 8,
	}),
	CreateBat({
		Id = "ReinforcedSteelBat",
		DisplayName = "Reinforced Steel Bat",
		TemplateName = "Reinforced Steel Bat",
		Icon = "ReinforcedSteelBat",
		CrateDamage = 1_400,
		SwingCooldown = 0.41,
		Range = 8.12,
	}),
	CreateBat({
		Id = "ObsidianBat",
		DisplayName = "Obsidian Bat",
		TemplateName = "ObsidianBat",
		Icon = "ObsidianBat",
		CrateDamage = 2_400,
		SwingCooldown = 0.39,
		Range = 8.3,
	}),
	CreateBat({
		Id = "MeteoriteBat",
		DisplayName = "Meteorite Bat",
		TemplateName = "Meteorite Bat",
		Icon = "MeteoriteBat",
		CrateDamage = 4_500,
		SwingCooldown = 0.37,
		Range = 8.5,
	}),
}

return BatInfo
