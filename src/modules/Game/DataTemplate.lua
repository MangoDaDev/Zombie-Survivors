local TutorialConfig = require(script.Parent.TutorialConfig)

return {
	Cash = 300,
	GuaranteedDropCount = 0,
	Inventory = {},
	Displays = {},
	Fixing = {},
	TutorialStep = TutorialConfig.InitialStep,
	Upgrades = {
		Start = true,
	},
}
