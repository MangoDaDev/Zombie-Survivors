local CleaningConfig = {
	AutoCompletionThreshold = 0.9,
	BrushRadiusPixels = 54,
	CameraFieldOfView = 60,
	CameraEntryDuration = 0.38,
	CameraExitDuration = 0.25,
	CameraToolImpulseDistance = 0.045,
	CameraTargetImpulseDistance = 0.025,
	CameraFinalPushDistance = 0.16,
	AssistedCleanupDuration = 0.32,
	ItemCameraElevationDegrees = 20,
	ItemCameraMinimumDistance = 2,
	ItemCameraPadding = 1.2,
	ItemPresentationRotationDegrees = -8,
	ItemSurfaceOffset = 0.03,
	SprayVFXWidthScale = 1,
	SprayEndpointResponsiveness = 24,
	ToolPositionResponsiveness = 24,
	ToolScreenPosition = Vector2.new(0.82, 0.82),
	ToolCameraDepth = 1.65,
	ToolCursorMovementScale = Vector2.new(0.018, 0.012),
	ToolCursorRotationDegrees = Vector2.new(4, 6),
	ToolRotationCorrectionDegrees = Vector3.new(0, 90, 0),
	FakeArmThickness = 0.38,
	FakeArmScreenPosition = Vector2.new(0.92, 0.88),
	FakeArmCameraDepth = 0.85,
	SpongeSurfaceOffset = 0.12,
	SpongeSurfaceResponsiveness = 30,
	SpongeScrubDistance = 0.12,
	SpongeScrubSideDistance = 0.035,
	SpongeScrubFrequency = 9,
	StepTransitionDelay = 0.45,
	FullCompletionDelay = 1.8,
	DirtDamageSoundName = "Hooked",
	Tools = {
		{
			Id = "Spray",
			DisplayName = "Spray",
			TemplateName = "SprayBottle",
			VFXFolderName = "SprayBottle",
			VFXName = "WaterEffect",
			VFXStartPartName = "EffectStart",
			LoopSoundName = "SprayLoop",
			RadiusPixels = 54,
			StrengthPerSecond = 3.2,
			VFXWidthScale = 1,
			PositionResponsiveness = 22,
		},
		{
			Id = "SprayPaint",
			DisplayName = "Spray Paint",
			TemplateName = "SprayPaint",
			VFXFolderName = "SprayPaint",
			VFXName = "Paint",
			VFXStartPartName = "EffectStart",
			LoopSoundName = "SprayPaintLoop",
			RadiusPixels = 54,
			StrengthPerSecond = 3.2,
			VFXWidthScale = 1,
			ColorFromTarget = true,
			ColorResponsiveness = 14,
			PositionResponsiveness = 22,
		},
		{
			Id = "Sponge",
			DisplayName = "Sponge",
			TemplateName = "Sponge",
			VFXStartPartName = "Handle",
			LoopSoundName = "SpongeLoop",
			RadiusPixels = 36,
			StrengthPerSecond = 2.8,
			VFXWidthScale = 1,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
			PositionResponsiveness = 30,
		},
		{
			Id = "SoftBrush", DisplayName = "Soft Brush", TemplateName = "Soft Brush", VFXStartPartName = "Handle",
			LoopSoundName = "SlowSwoosh", RadiusPixels = 34, StrengthPerSecond = 2.4, PositionResponsiveness = 32,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
		},
		{
			Id = "Polisher", DisplayName = "Polisher", TemplateName = "Polisher", VFXStartPartName = "PolishingPadFront",
			LoopSoundName = "Rolling", RadiusPixels = 42, StrengthPerSecond = 1.9, PositionResponsiveness = 28,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
		},
		{
			Id = "Hairdryer", DisplayName = "Hairdryer", TemplateName = "Hairdryer", VFXStartPartName = "Handle",
			LoopSoundName = "Wind", LoopSoundVolume = 0.55, RadiusPixels = 68, StrengthPerSecond = 3.4,
			PositionResponsiveness = 24, AirflowRange = 8, AirflowConeDegrees = 24, BlowSpeed = 8,
		},
		{
			Id = "Hammer", DisplayName = "Hammer", TemplateName = "Hammer", VFXStartPartName = "Handle",
			RadiusPixels = 30, StrengthPerSecond = 5, PositionResponsiveness = 36, StrikeInterval = 0.28,
			ImpactSoundName = "MetalHitSoft",
		},
		{
			Id = "Magnet", DisplayName = "Magnet", TemplateName = "Magnet", VFXStartPartName = "Magnet",
			LoopSoundName = "MagnetEquip", RadiusPixels = 46, StrengthPerSecond = 1.8, PositionResponsiveness = 26,
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
			Id = "SprayPaint",
			MinimumRestorationTier = 4,
			Type = "Paint",
			IconName = "Paint",
			DisplayName = "Restoring Paint",
			ToolId = "SprayPaint",
			TargetHP = 2,
			DirtColor = Color3.fromRGB(88, 68, 50),
			DirtAmountMinimum = 0.78,
			DirtAmountMaximum = 0.96,
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
			Id = "Hammer", MinimumRestorationTier = 5, Type = "Bent", IconName = "Bent",
			DisplayName = "Realigning Parts", ToolId = "Hammer", TargetHP = 5, CompletionSoundName = "MetalHitSoft",
		},
		{
			Id = "Magnet", MinimumRestorationTier = 6, Type = "Metal", IconName = "Metal",
			DisplayName = "Extracting Metal", ToolId = "Magnet", TargetHP = 3, CompletionSoundName = "MagnetUnequip",
		},
		{
			Id = "Polisher", MinimumRestorationTier = 4, Type = "Polish", IconName = "Polish",
			DisplayName = "Polishing Finish", ToolId = "Polisher", TargetHP = 2, CompletionSoundName = "Reward2",
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

function CleaningConfig.GetStepsForItem(ItemInfo): { any }
	local Steps = {}
	local RestorationTier = if type(ItemInfo.RestorationTier) == "number" then ItemInfo.RestorationTier else 1
	local ConfiguredSteps = if type(ItemInfo.RestorationSteps) == "table" then ItemInfo.RestorationSteps else nil
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

return CleaningConfig
