local ItemInteractionConfig = {
	WorldItemDespawnDuration = 60,
	ItemBillboardMaxDistance = 500,
	WorldItemTimerUpdateInterval = 0.1,
	-- Carrying temporarily reduces the player's current normal WalkSpeed by 20%.
	CarryWalkSpeedMultiplier = 0.8,
	DropForwardDistance = 4,
	DroppedItemPurchaseDistance = 10,
	UnexpectedMoveDistance = 8,
	PurchasePriceMultiplier = 1.25,
	MaximumPurchasePriceMultiplier = 3,
	BatKnockbackSpeed = 55,
	BatKnockbackUpwardSpeed = 20,
	-- Guest hits should launch them dramatically before they disappear.
	GuestBatKnockbackSpeed = 110,
	GuestBatKnockbackUpwardSpeed = 42,
	MaximumKnockbackSpeed = 70,
	RagdollDuration = 1.1,
	RagdollRecoveryProtectionDuration = 1,
	PvpHitCooldown = 0.8,
	-- Preserve the requested extra two seconds before a struck player can be hit again.
	PvpProtectionDuration = 4.5,
	PvpMaximumHitDistance = 10,
	FixingRotationSpeedDegrees = 24,
	SurfacePlacementAttempts = 4,
	SurfacePlacementOffset = 0.015,
	MaximumDirtCount = 160,
}

return ItemInteractionConfig
