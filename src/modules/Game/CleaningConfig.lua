local CleaningConfig = {
	AutoCompletionThreshold = 0.8,
	BrushRadiusPixels = 72,
	CameraFieldOfView = 70,
	SprayVFXWidthScale = 1,
	SprayEndpointResponsiveness = 24,
	StepTransitionDelay = 0.45,
	FullCompletionDelay = 1,
	Tools = {
		{
			Id = "Spray",
			DisplayName = "Spray",
			TemplateName = "SprayBottle",
			VFXFolderName = "SprayBottle",
			VFXName = "WaterEffect",
			VFXStartPartName = "EffectStart",
			LoopSoundName = "SprayLoop",
		},
	},
	Steps = {
		{
			Id = "Spray",
			Type = "Dirt",
			DisplayName = "Spraying",
			ToolId = "Spray",
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

return CleaningConfig
