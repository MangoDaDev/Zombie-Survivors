local TutorialConfig = {
	InitialStep = "PickUpItem",
	CompleteStep = "Complete",
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
			Text = "Use Required Tool",
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
