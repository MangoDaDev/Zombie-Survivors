local UpgradeConfig = require(script.Parent.UpgradeConfig)

local CleaningConfig = {
	AutoCompletionThreshold = 0.9,
	BrushRadiusPixels = 54,
	CameraFieldOfView = 70,
	MinimumItemCameraDistance = 3.9,
	ItemCameraDistancePerStud = 0.42,
	ItemVerticalOffset = -0.45,
	ItemTiltDegrees = -8,
	SprayVFXWidthScale = 1,
	SprayEndpointResponsiveness = 24,
	ToolPositionResponsiveness = 24,
	ToolScreenPosition = Vector2.new(0.82, 0.82),
	ToolCameraDepth = 1.65,
	ToolCursorMovementScale = Vector2.new(0.018, 0.012),
	ToolCursorRotationDegrees = Vector2.new(4, 6),
	ToolRotationCorrectionDegrees = Vector3.new(0, -90, 0),
	FakeArmThickness = 0.38,
	FakeArmScreenPosition = Vector2.new(0.92, 0.88),
	FakeArmCameraDepth = 0.85,
	SpongeSurfaceOffset = 0.12,
	SpongeSurfaceResponsiveness = 30,
	SpongeScrubDistance = 0.12,
	SpongeScrubSideDistance = 0.035,
	SpongeScrubFrequency = 9,
	StepTransitionDelay = 0.45,
	FullCompletionDelay = 1,
	RestorationRewardRate = 0.75,
	MinimumRestorationReward = 30,
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
			DirtColor = Color3.fromRGB(88, 68, 50),
			DirtAmountMinimum = 0.78,
			DirtAmountMaximum = 0.96,
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

function CleaningConfig.GetToolUnlockCost(ToolId: string): number
	if ToolId == "Spray" then return 0 end
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if Effect and Effect.Type == "ToolUnlock" and Effect.ToolId == ToolId then
			return Upgrade.Cost
		end
	end
	return math.huge
end

function CleaningConfig.GetStepsForItem(ItemInfo): { any }
	local Steps = {}
	local ItemPrice = if type(ItemInfo.Price) == "number" then ItemInfo.Price else 0
	for _, StepInfo in CleaningConfig.Steps do
		if ItemPrice >= CleaningConfig.GetToolUnlockCost(StepInfo.ToolId) then
			table.insert(Steps, StepInfo)
		end
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
