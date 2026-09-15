local TutorialConfig = require(script.Parent.TutorialConfig)

return {
	Cash = 100,
	Inventory = {},
	Displays = {},
	Fixing = {},
	TutorialStep = TutorialConfig.InitialStep,
	Upgrades = {
		Start = true,
	},
}
