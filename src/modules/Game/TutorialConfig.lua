local TutorialConfig = {
	InitialStep = "PickUpItem",
	CompleteStep = "Complete",
	Onboarding = {
		DirtGreaseItemId = 5,
		DirtGreaseRestorationSteps = { "Spray", "Sponge" },
		DustItemId = 6,
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
			Next = "BuySponge",
		},
		BuySponge = {
			Text = "Buy Sponge",
			Next = "Complete",
		},
	},
}

function TutorialConfig.GetStep(StepId: string)
	return TutorialConfig.Steps[StepId]
end

return TutorialConfig
