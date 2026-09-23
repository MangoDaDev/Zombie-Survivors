local ItemInteractionConfig = {
	-- Crate rewards remain claimable for 30 seconds after their reveal finishes.
	CrateRewardDespawnDuration = 30,
	WorldItemDespawnDuration = 60,
	-- Keep item identity and value billboards viewable up to 250 studs away.
	ItemBillboardMaxDistance = 250,
	WorldItemTimerUpdateInterval = 0.1,
	-- Carrying temporarily reduces the player's current normal WalkSpeed by 20%.
	CarryWalkSpeedMultiplier = 0.8,
	DropForwardDistance = 4,
	DroppedItemPickupDistance = 10,
	UnexpectedMoveDistance = 8,
	BatKnockbackSpeed = 55,
	BatKnockbackUpwardSpeed = 20,
	-- Guest hits should launch them dramatically before they disappear.
	GuestBatKnockbackSpeed = 110,
	GuestBatKnockbackUpwardSpeed = 42,
	GuestMaximumHitDistance = 10,
	MaximumKnockbackSpeed = 70,
	FallingHitMinimumSpeed = 2,
	-- A larger scale makes the falling-hit bonus approach 2x more slowly.
	FallingHitBonusScale = 54,
	-- Keep the fall-speed curve while letting critical-hit knockback approach 3x.
	FallingHitKnockbackBonusScale = 2,
	RagdollDuration = 1.1,
	RagdollRecoveryProtectionDuration = 1,
	PvpHitCooldown = 0.8,
	-- Preserve the requested extra two seconds before a struck player can be hit again.
	PvpProtectionDuration = 4.5,
	-- PvP exact-hit detection is client-owned; this intentionally generous server cap only blocks map-wide spoofing.
	PvpMaximumHitDistance = 40,
	FixingRotationSpeedDegrees = 24,
	SurfacePlacementAttempts = 4,
	SurfacePlacementOffset = 0.015,
	MaximumDirtCount = 160,
}

function ItemInteractionConfig.GetFallingHitMultiplier(VerticalVelocity: number): number
	-- Hits while falling faster than 2 studs/second grow stronger and approach, but never exceed, 2x.
	local ExcessSpeed = math.max(0, -VerticalVelocity - ItemInteractionConfig.FallingHitMinimumSpeed)
	return 1 + ExcessSpeed / (ExcessSpeed + ItemInteractionConfig.FallingHitBonusScale)
end

return ItemInteractionConfig
