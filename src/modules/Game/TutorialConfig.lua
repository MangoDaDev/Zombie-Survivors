local TutorialConfig = {
	InitialStep = "PickUpItem",
	CompleteStep = "Complete",
	Onboarding = {
		-- These alternatives all receive the same guaranteed grease restoration steps.
		DirtGreaseItemIds = { 5, 20, 95, 18 },
		DirtGreaseRestorationSteps = { "Spray", "Sponge" },
		-- These alternatives all receive the same guaranteed Dust restoration steps.
		DustItemIds = { 6, 91, 100 },
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
