local TutorialConfig = require(script.Parent.TutorialConfig)
local EconomyConfig = require(script.Parent.EconomyConfig)

return {
	Cash = EconomyConfig.StartingCash,
	GuaranteedDropCount = 0,
	Inventory = {},
	Displays = {},
	Fixing = {},
	TutorialStep = TutorialConfig.InitialStep,
	Upgrades = {
		Start = true,
	},
}
