local CleaningConfig = {
	AutoCompletionThreshold = 0.8,
	BrushRadiusPixels = 72,
	CameraFieldOfView = 70,
	MinimumItemCameraDistance = 3.9,
	ItemCameraDistancePerStud = 0.42,
	ItemVerticalOffset = -0.45,
	ItemTiltDegrees = -8,
	SprayVFXWidthScale = 1,
	SprayEndpointResponsiveness = 24,
	ToolPositionResponsiveness = 24,
	FakeArmThickness = 0.38,
	FakeArmScreenPosition = Vector2.new(0.92, 0.88),
	FakeArmCameraDepth = 0.85,
	StepTransitionDelay = 0.45,
	FullCompletionDelay = 1,
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
			RadiusPixels = 72,
			StrengthPerSecond = 4,
			VFXWidthScale = 1,
			PositionMode = "ScreenAim",
			ScreenPosition = Vector2.new(0.82, 0.82),
			ScreenDepth = 1.65,
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
			RadiusPixels = 72,
			StrengthPerSecond = 4,
			VFXWidthScale = 1,
			ColorFromTarget = true,
			ColorResponsiveness = 14,
			PositionMode = "ScreenAim",
			ScreenPosition = Vector2.new(0.82, 0.82),
			ScreenDepth = 1.65,
			PositionResponsiveness = 22,
		},
		{
			Id = "Sponge",
			DisplayName = "Sponge",
			TemplateName = "Sponge",
			VFXStartPartName = "Handle",
			LoopSoundName = "SpongeLoop",
			RadiusPixels = 46,
			StrengthPerSecond = 3.5,
			VFXWidthScale = 1,
			PositionMode = "Surface",
			SurfaceOffset = 0.08,
			SurfaceRotationDegrees = Vector3.new(0, 90, 0),
			PositionResponsiveness = 30,
		},
	},
	Steps = {
		{
			Id = "Spray",
			Type = "Dirt",
			IconName = "Dirt",
			DisplayName = "Spraying",
			ToolId = "Spray",
			CompletionSoundName = "Reward1",
		},
		{
			Id = "SprayPaint",
			Type = "Paint",
			IconName = "Paint",
			DisplayName = "Restoring Paint",
			ToolId = "SprayPaint",
			TargetHP = 2,
			DirtColor = Color3.fromRGB(105, 72, 43),
			DirtAmountMinimum = 0.4,
			DirtAmountMaximum = 0.8,
			CompletionSoundName = "Reward1",
		},
		{
			Id = "Sponge",
			Type = "Grease",
			IconName = "Grease",
			DisplayName = "Scrubbing",
			ToolId = "Sponge",
			TargetHP = 2,
			PatchColor = Color3.fromRGB(177, 126, 42),
			PatchTransparency = 0.24,
			CompletionSoundName = "Reward1",
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
	for _, StepId in ItemInfo.RestorationSteps or {} do
		local StepInfo = CleaningConfig.GetStep(StepId)
		if StepInfo then table.insert(Steps, StepInfo) end
	end
	return Steps
end

function CleaningConfig.ItemHasStep(ItemInfo, StepId: string): boolean
	return table.find(ItemInfo.RestorationSteps or {}, StepId) ~= nil
end

return CleaningConfig
