local CleaningConfig = {
	AutoCompletionThreshold = 0.85,
	BrushRadiusScale = 0.075,
	CameraFieldOfView = 60,
	CameraEntryDuration = 0.38,
	CameraExitDuration = 0.25,
	CameraToolImpulseDistance = 0.045,
	CameraTargetImpulseDistance = 0.025,
	CameraFinalPushDistance = 0.16,
	AssistedCleanupDuration = 0.25,
	ItemCameraElevationDegrees = 20,
	ItemCameraNearDistance = 0.5,
	ItemCameraLargeItemMargin = 1.14,
	ItemCameraSmallItemMargin = 1.38,
	ItemCameraSmallSize = 2.5,
	ItemCameraLargeSize = 7,
	ItemRadiusScaleStartSize = 7,
	ItemRadiusScaleFullSize = 13,
	ItemRadiusScaleMinimumMultiplier = 0.82,
	ItemPresentationRotationDegrees = -8,
	ItemSurfaceOffset = 0.03,
	SprayVFXWidthScale = 1,
	SprayEndpointResponsiveness = 24,
	ToolPositionResponsiveness = 24,
	-- Surface positions stay responsive while normal-driven rotation eases across sharp edges.
	ToolSurfaceRotationResponsiveness = 2,
	SurfaceNormalSampleCount = 12,
	SurfaceNormalSampleRadiusMultiplier = 0.72,
	SurfaceNormalSampleAngle = math.pi * (3 - math.sqrt(5)),
	ToolScreenPosition = Vector2.new(0.85, 0.85),
	ToolCameraDepth = 2.5,
	ToolCursorMovementScale = Vector2.new(0.018, 0.012),
	ToolCursorRotationDegrees = Vector2.new(4, 6),
	ToolRotationCorrectionDegrees = Vector3.new(0, 90, 0),
	FakeArmThickness = 0.38,
	FakeArmScreenPosition = Vector2.new(0.92, 0.88),
	FakeArmCameraDepth = 0.85,
	FakeArmEndResponsiveness = 14,
	SpongeSurfaceResponsiveness = 30,
	SpongeScrubDistance = 0.12,
	SpongeScrubSideDistance = 0.035,
	SpongeScrubFrequency = 9,
	SpongeBubbleMinimumInterval = 0.2,
	SpongeBubbleMaximumInterval = 0.65,
	SpongeBubbleTargetsForMaximumRate = 5,
	HammerStrikeLiftDistance = 0.48,
	HammerContactProgress = 0.42,
	HammerRaisedAngleDegrees = 42,
	StepTransitionDelay = 0.3,
	FullCompletionDelay = 1.2,
	DirtDamageSoundName = "Hooked",
	Tools = {
		{
			Id = "Spray", DisplayName = "Spray", TemplateName = "SprayBottle", VFXFolderName = "SprayBottle",
			VFXName = "WaterEffect", VFXStartPartName = "EffectStart", LoopSoundName = "SprayLoop",
			RadiusScale = 0.08, StrengthPerSecond = 3.6, VFXWidthScale = 1, PositionResponsiveness = 22,
		},
		{
			Id = "Sponge", DisplayName = "Sponge", TemplateName = "Sponge", VFXFolderName = "Bubbles",
			VFXName = "ParticleEmitter", VFXStartPartName = "Handle", LoopSoundName = "Bubble",
			RadiusScale = 0.055, StrengthPerSecond = 3.2, VFXWidthScale = 1,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0), PositionResponsiveness = 30,
		},
		{
			Id = "SoftBrush", DisplayName = "Soft Brush", TemplateName = "Soft Brush", VFXStartPartName = "Handle",
			LoopSoundName = "SlowSwoosh", RadiusScale = 0.052, StrengthPerSecond = 3, PositionResponsiveness = 32,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
		},
		{
			Id = "Hairdryer", DisplayName = "Hairdryer", TemplateName = "Hairdryer", VFXFolderName = "Hairdryer",
			VFXName = "Main", VFXStartPartName = "Handle",
			LoopSoundName = "Wind", LoopSoundVolume = 0.55, RadiusScale = 0.1, StrengthPerSecond = 3.8,
			PositionResponsiveness = 24, AirflowRange = 8, AirflowConeDegrees = 24, BlowSpeed = 8,
		},
		{
			Id = "SprayPaint", DisplayName = "Spray Paint", TemplateName = "SprayPaint", VFXFolderName = "SprayPaint",
			VFXName = "Paint", VFXStartPartName = "EffectStart", LoopSoundName = "SprayPaintLoop",
			RadiusScale = 0.08, StrengthPerSecond = 3.4, VFXWidthScale = 1, ColorFromTarget = true,
			ColorResponsiveness = 14, PositionResponsiveness = 22,
		},
		{
			Id = "Polisher", DisplayName = "Polisher", TemplateName = "Polisher", VFXStartPartName = "PolishingPadFront",
			LoopSoundName = "Rolling", RadiusScale = 0.065, StrengthPerSecond = 2.8, PositionResponsiveness = 28,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
		},
		{
			Id = "Hammer", DisplayName = "Hammer", TemplateName = "Hammer", VFXStartPartName = "Handle",
			RadiusScale = 0.045, StrengthPerSecond = 5, PositionResponsiveness = 36, StrikeInterval = 0.28,
			ImpactSoundName = "MetalHitSoft",
		},
		{
			Id = "Magnet", DisplayName = "Magnet", TemplateName = "Magnet", VFXStartPartName = "Magnet",
			LoopSoundName = "MagnetEquip", RadiusScale = 0.07, StrengthPerSecond = 2.6, PositionResponsiveness = 26,
			PullDistance = 1.4,
		},
	},
	Steps = {
		{
			Id = "Spray",
			MinimumRestorationTier = 1,
			Type = "Dirt",
			IconName = "Dirt",
			DisplayName = "Spraying",
			ToolId = "Spray",
			CompletionSoundName = "Reward1",
		},
		{
			Id = "Sponge",
			MinimumRestorationTier = 2,
			Type = "Grease",
			IconName = "Grease",
			DisplayName = "Scrubbing",
			ToolId = "Sponge",
			TargetHP = 2,
			PatchColor = Color3.fromRGB(177, 126, 42),
			PatchTransparency = 0.24,
			CompletionSoundName = "Reward1",
		},
		{
			Id = "SoftBrush", MinimumRestorationTier = 2, Type = "LightDust", IconName = "LightDust",
			DisplayName = "Brushing Dust", ToolId = "SoftBrush", TargetHP = 1.5,
			PatchColor = Color3.fromRGB(132, 136, 141), PatchTransparency = 0.48, CompletionSoundName = "Reward1",
		},
		{
			Id = "Hairdryer", MinimumRestorationTier = 3, Type = "LooseDebris", IconName = "LooseDebris",
			DisplayName = "Blowing Debris", ToolId = "Hairdryer", TargetHP = 1, CompletionSoundName = "Swoosh",
		},
		{
			Id = "SprayPaint", MinimumRestorationTier = 4, Type = "Paint", IconName = "Paint",
			DisplayName = "Restoring Paint", ToolId = "SprayPaint", TargetHP = 2,
			DirtColor = Color3.fromRGB(88, 68, 50), DirtAmountMinimum = 0.78, DirtAmountMaximum = 0.96,
			CompletionSoundName = "Reward1",
		},
		{
			Id = "Polisher", MinimumRestorationTier = 4, Type = "Polish", IconName = "Polish",
			DisplayName = "Polishing Finish", ToolId = "Polisher", TargetHP = 2, CompletionSoundName = "Reward2",
		},
		{
			Id = "Hammer", MinimumRestorationTier = 5, Type = "Bent", IconName = "Bent",
			DisplayName = "Realigning Parts", ToolId = "Hammer", TargetHP = 5,
			BendRotationDegrees = Vector3.new(28, -18, 12), CompletionSoundName = "MetalHitSoft",
		},
		{
			Id = "Magnet", MinimumRestorationTier = 6, Type = "Metal", IconName = "Metal",
			DisplayName = "Extracting Metal", ToolId = "Magnet", TargetHP = 3,
			-- Keep Magnet work substantial without treating every item part as magnetic.
			TargetDensity = 1.4, MinimumTargets = 4, MaximumTargets = 24,
			CompletionSoundName = "MagnetUnequip",
		},
	},
	FullCompletion = {
		SoundNames = { "Reward5", "Confetti" },
		ParticleToolTemplateName = "SprayBottle",
		ParticlePartName = "EffectStart",
		ParticleCount = 40,
	},
}

function CleaningConfig.GetTool(ToolId: string)
	for _, ToolInfo in CleaningConfig.Tools do
		if ToolInfo.Id == ToolId then return ToolInfo end
	end
end

function CleaningConfig.GetStep(StepId: string)
	for _, StepInfo in CleaningConfig.Steps do
		if StepInfo.Id == StepId then return StepInfo end
	end
end

function CleaningConfig.GetStepsForItem(ItemInfo, FixingState): { any }
	local Steps = {}
	local RestorationTier = if type(ItemInfo.RestorationTier) == "number" then ItemInfo.RestorationTier else 1
	local ConfiguredSteps = if type(FixingState) == "table" and type(FixingState.RestorationSteps) == "table"
		then FixingState.RestorationSteps
		else if type(ItemInfo.RestorationSteps) == "table" then ItemInfo.RestorationSteps else nil
	local Settings = if type(ItemInfo.RestorationSettings) == "table" then ItemInfo.RestorationSettings else {}
	for _, StepInfo in CleaningConfig.Steps do
		local IsRequired = if ConfiguredSteps then table.find(ConfiguredSteps, StepInfo.Id) ~= nil else RestorationTier >= StepInfo.MinimumRestorationTier
		if not IsRequired then continue end
		local ResolvedStep = table.clone(StepInfo)
		local StepSettings = Settings[StepInfo.Id]
		if type(StepSettings) == "table" then
			for Key, Value in StepSettings do ResolvedStep[Key] = Value end
		end
		table.insert(Steps, ResolvedStep)
	end
	return Steps
end

function CleaningConfig.ItemHasStep(ItemInfo, StepId: string): boolean
	for _, StepInfo in CleaningConfig.GetStepsForItem(ItemInfo) do
		if StepInfo.Id == StepId then return true end
	end
	return false
end

function CleaningConfig.Validate()
	local Tools = {}
	for _, ToolInfo in CleaningConfig.Tools do
		assert(type(ToolInfo.Id) == "string" and not Tools[ToolInfo.Id], `Invalid or duplicate cleaning tool {tostring(ToolInfo.Id)}`)
		assert(ToolInfo.StrengthPerSecond > 0 and ToolInfo.RadiusScale > 0, `Invalid cleaning balance for {ToolInfo.Id}`)
		Tools[ToolInfo.Id] = true
	end
	local PreviousTier = 0
	for _, StepInfo in CleaningConfig.Steps do
		assert(Tools[StepInfo.ToolId], `Restoration step {StepInfo.Id} has no configured tool`)
		assert(StepInfo.MinimumRestorationTier >= PreviousTier, `Restoration tiers must not decrease at {StepInfo.Id}`)
		PreviousTier = StepInfo.MinimumRestorationTier
	end
end

function CleaningConfig.IsCleaningComplete(FixingState): boolean
	if type(FixingState) ~= "table" then
		return false
	end
	if FixingState.Completed == true then
		return true
	end
	if type(FixingState.Steps) == "table" then
		for _, StepInfo in CleaningConfig.Steps do
			if StepInfo.Type == "Dirt" then
				local StepState = FixingState.Steps[StepInfo.Id]
				return type(StepState) == "table" and StepState.Completed == true
			end
		end
	end
	return type(FixingState.Remaining) == "number" and FixingState.Remaining <= 0
end

CleaningConfig.Validate()

return CleaningConfig
