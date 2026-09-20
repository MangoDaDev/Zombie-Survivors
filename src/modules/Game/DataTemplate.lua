local TutorialConfig = require(script.Parent.TutorialConfig)
local EconomyConfig = require(script.Parent.EconomyConfig)

return {
	Cash = EconomyConfig.StartingCash,
	GuaranteedDropCount = 0,
	HasRolledCrate = false,
	Onboarding = {
		DiscreteProgressionActive = false,
		DirtGreaseItemReceived = false,
		DirtGreaseItemDisplayed = false,
		SoftBrushFundingGranted = false,
		DustFundingGranted = false,
		DustItemReceived = false,
	},
	Analytics = {
		OnboardingHighestStep = 0,
		CratesBroken = 0,
		RestorationsCompleted = 0,
		UpgradesPurchased = 0,
		FirstVisitorIncomeEarned = false,
	},
	Inventory = {},
	InventoryKeys = {},
	Displays = {},
	DisplayItemKeys = {},
	Fixing = {},
	TutorialStep = TutorialConfig.InitialStep,
	Upgrades = {
		Start = true,
	},
}
