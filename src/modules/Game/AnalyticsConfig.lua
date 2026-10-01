local AnalyticsConfig = {}

AnalyticsConfig.DataKey = "AnalyticsProgress"
AnalyticsConfig.OnboardingVersion = 1

-- Funnel and step names are a reporting contract. Keep existing names stable so dashboard history
-- remains comparable; add a versioned funnel instead of silently repurposing an existing step.
AnalyticsConfig.Funnels = {
	Onboarding = {
		-- LogOnboardingFunnelStepEvent reports to Roblox's fixed one-time "Onboarding" dashboard.
		DashboardName = "Onboarding",
		Steps = {
			"Profile Loaded",
			"Lobby Character Ready",
			"Joined Party Elevator",
			"Party Setup Confirmed",
			"Game Ready",
			"First Ability Choice Applied",
			"First Round Completed",
		},
	},
	LifetimeProgression = {
		Name = "LifetimeRoundProgressionV1",
		Steps = {
			"Survived 1 Round",
			"Survived 5 Rounds",
			"Survived 15 Rounds",
			"Survived 30 Rounds",
			"Survived 60 Rounds",
		},
	},
	GameplayLoop = {
		Name = "FirstRoundGameplayLoopV1",
		Steps = {
			"Game Ready",
			"Combat Started",
			"First Zombie Defeated",
			"First Level Reached",
			"First Ability Choice Applied",
			"First Round Completed",
		},
	},
	AbilityShop = {
		Name = "AbilityShopCheckoutV1",
		Steps = {
			"Shop Opened",
			"Item Selected",
			"Purchase Attempted",
			"Purchase Completed",
		},
	},
	ClassShop = {
		Name = "ClassShopCheckoutV1",
		Steps = {
			"Shop Opened",
			"Item Selected",
			"Purchase Attempted",
			"Purchase Completed",
		},
	},
	MonetizationCheckout = {
		Name = "MonetizationCheckoutV1",
		Steps = {
			"Purchase Prompt Authorized",
			"Paid Benefit Applied",
		},
	},
	RunAbilityChoice = {
		Name = "RunAbilityChoiceV1",
		Steps = {
			"Choices Offered",
			"Choice Selected",
			"Choice Applied",
		},
	},
	Replay = {
		Name = "PostRunReplayV1",
		Steps = {
			"Run Ended",
			"Replay Requested",
			"Party Unanimous",
			"New Run Started",
		},
	},
}

AnalyticsConfig.LifetimeRoundMilestones = { 1, 5, 15, 30, 60 }

return AnalyticsConfig
