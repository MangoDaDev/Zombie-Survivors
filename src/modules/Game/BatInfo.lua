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
		CrateDamage = 12,
		SwingCooldown = 0.52,
		Range = 7.25,
	}),
	CreateBat({
		Id = "BronzeBat",
		DisplayName = "Bronze Bat",
		TemplateName = "Bronze Bat",
		Icon = "BronzeBat",
		CrateDamage = 32,
		SwingCooldown = 0.5,
		Range = 7.35,
	}),
	CreateBat({
		Id = "IronBat",
		DisplayName = "Iron Bat",
		TemplateName = "Iron Bat",
		Icon = "IronBat",
		CrateDamage = 65,
		SwingCooldown = 0.49,
		Range = 7.42,
	}),
	CreateBat({
		Id = "GoldBat",
		DisplayName = "Gold Bat",
		TemplateName = "Gold Bat",
		Icon = "GoldBat",
		CrateDamage = 130,
		SwingCooldown = 0.47,
		Range = 7.55,
	}),
	CreateBat({
		Id = "EmeraldBat",
		DisplayName = "Emerald Bat",
		TemplateName = "Emerald Bat",
		Icon = "EmeraldBat",
		CrateDamage = 260,
		SwingCooldown = 0.45,
		Range = 7.7,
	}),
	CreateBat({
		Id = "TitaniumBat",
		DisplayName = "Titanium Bat",
		TemplateName = "Titanium Bat",
		Icon = "TitaniumBat",
		CrateDamage = 450,
		SwingCooldown = 0.43,
		Range = 7.85,
	}),
	CreateBat({
		Id = "DiamondBat",
		DisplayName = "Diamond Bat",
		TemplateName = "Diamond Bat",
		Icon = "DiamondBat",
		CrateDamage = 750,
		SwingCooldown = 0.42,
		Range = 8,
	}),
	CreateBat({
		Id = "ReinforcedSteelBat",
		DisplayName = "Reinforced Steel Bat",
		TemplateName = "Reinforced Steel Bat",
		Icon = "ReinforcedSteelBat",
		CrateDamage = 1_150,
		SwingCooldown = 0.41,
		Range = 8.12,
	}),
	CreateBat({
		Id = "ObsidianBat",
		DisplayName = "Obsidian Bat",
		TemplateName = "ObsidianBat",
		Icon = "ObsidianBat",
		CrateDamage = 1_800,
		SwingCooldown = 0.39,
		Range = 8.3,
	}),
	CreateBat({
		Id = "MeteoriteBat",
		DisplayName = "Meteorite Bat",
		TemplateName = "Meteorite Bat",
		Icon = "MeteoriteBat",
		CrateDamage = 2_800,
		SwingCooldown = 0.37,
		Range = 8.5,
	}),
}

local PreviousDamage = 0
local PreviousCooldown = math.huge
for _, Info in BatInfo do
	assert(Info.CrateDamage > PreviousDamage, `Bat damage must increase at {Info.Id}`)
	assert(Info.SwingCooldown <= PreviousCooldown, `Bat cooldown must not increase at {Info.Id}`)
	PreviousDamage = Info.CrateDamage
	PreviousCooldown = Info.SwingCooldown
end

return BatInfo
