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
