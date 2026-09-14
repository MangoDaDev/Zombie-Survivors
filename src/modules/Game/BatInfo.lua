local BatInfo = {
	{
		Id = "StandardBat",
		DisplayName = "Bat",
		TemplateName = "Bat",
		CrateDamage = 4,
		PlayerDamage = 8,
		SwingCooldown = 0.55,
		ImpactDelay = 0.08,
		Range = 7,
		HitboxWidth = 7,
		HitboxHeight = 6,
		ValidationDistanceBuffer = 3,
		MinimumFacingDot = -0.25,
		PlayerKnockback = 18,
		SwingSoundName = "BatSwing",
		EquipSoundName = "BatEquip",
		ImpactSoundNames = { "BatImpact1" },
		PlayerHitSoundNames = { "BatImpact1" },
	},
}

return BatInfo
