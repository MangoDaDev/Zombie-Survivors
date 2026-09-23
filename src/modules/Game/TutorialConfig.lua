local TutorialConfig = {
	InitialStep = "PickUpItem",
	CompleteStep = "Complete",
	-- Show this final message when the Paint purchase completes the visible tutorial.
	CompleteText = "Have Fun!",
	Onboarding = {
		-- Force only restoration requirements; the crate must still roll the item itself normally.
		PaintRestorationSteps = { "Spray", "SprayPaint" },
		DirtGreaseRestorationSteps = { "Spray", "Sponge" },
		DustRestorationSteps = { "Spray", "SoftBrush" },
		SoftBrushUpgradeId = "UnlockSoftBrush",
		SoftBrushCashBuffer = 150,
	},
	Steps = {
		PickUpItem = {
			Text = "Pick Up Item",
			Next = "BringItemHome",
		},
		BringItemHome = {
			Text = "Bring Item Home",
			Next = "StartCleaning",
		},
		StartCleaning = {
			Text = "Start Cleaning",
			Next = "UseTool",
		},
		UseTool = {
			Text = "Use The Tool",
			Next = "CleanThis",
		},
		CleanThis = {
			Text = "Clean This",
			Next = "DisplayItem",
		},
		DisplayItem = {
			Text = "Display It",
			Next = "EarnMoney",
		},
		EarnMoney = {
			Text = "Wait For Guests",
			Next = "OpenUpgrades",
		},
		OpenUpgrades = {
			Text = "Open Upgrades",
			-- Keep this legacy step id for saved-player compatibility; it now guides the first Paint purchase.
			Next = "BuySponge",
		},
		BuySponge = {
			Text = "Buy Paint",
			Next = "Complete",
		},
	},
}

function TutorialConfig.GetStep(StepId: string)
	return TutorialConfig.Steps[StepId]
end

return TutorialConfig
