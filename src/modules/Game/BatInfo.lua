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
	PlayerHitSoundNames = { "BatPlayerHit1" },
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
		CrateDamage = 4,
		PlayerDamage = 8,
		SwingCooldown = 0.55,
		Range = 7,
		PlayerKnockback = 18,
	}),
	CreateBat({
		Id = "StoneBat",
		DisplayName = "Stone Bat",
		TemplateName = "Stone Bat",
		CrateDamage = 5.25,
		PlayerDamage = 10,
		SwingCooldown = 0.52,
		Range = 7.25,
		PlayerKnockback = 19,
	}),
	CreateBat({
		Id = "GoldBat",
		DisplayName = "Gold Bat",
		TemplateName = "Gold Bat",
		CrateDamage = 7,
		PlayerDamage = 12,
		SwingCooldown = 0.48,
		Range = 7.5,
		PlayerKnockback = 20,
	}),
}

return BatInfo
