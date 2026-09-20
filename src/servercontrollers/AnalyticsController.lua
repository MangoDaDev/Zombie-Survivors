local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumConfig = require(ReplicatedStorage.Modules.Game.MuseumConfig)
local Networker = require(ReplicatedStorage.Packages.networker)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local AnalyticsController = {}
local DataService

local CUSTOM_FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local FUNNEL_NAMES = {
	CratePurchase = "CratePurchase",
	ItemRestoration = "ItemRestoration",
	MuseumProgression = "MuseumProgression",
	RestorationDecision = "RestorationDecision",
	SessionProgression = "SessionProgression",
	UpgradePurchase = "UpgradePurchase",
}

local ONBOARDING_STEPS = {
	PlayerJoined = { Number = 1, Name = "Player Joined" },
	OnboardingStarted = { Number = 2, Name = "Onboarding Started" },
	FirstCrateFound = { Number = 3, Name = "First Crate Found" },
	FirstCrateBroken = { Number = 4, Name = "First Crate Broken" },
	FirstItemRevealed = { Number = 5, Name = "First Item Revealed" },
	FirstItemPurchased = { Number = 6, Name = "First Item Purchased" },
	ItemBroughtToMuseum = { Number = 7, Name = "Item Brought To Museum" },
	RestorationStarted = { Number = 8, Name = "Restoration Started" },
	RequiredRestorationStepCompleted = { Number = 9, Name = "Required Restoration Step Completed" },
	FirstRestorationCompleted = { Number = 10, Name = "First Restoration Completed" },
	RestorationRewardCollected = { Number = 11, Name = "Restoration Reward Collected" },
	FirstItemDisplayed = { Number = 12, Name = "First Item Displayed" },
	FirstVisitorIncomeEarned = { Number = 13, Name = "First Visitor Income Earned" },
	FirstUpgradePurchased = { Number = 14, Name = "First Upgrade Purchased" },
	SecondCrateBroken = { Number = 15, Name = "Second Crate Broken" },
	SecondItemRestored = { Number = 16, Name = "Second Item Restored" },
	OnboardingCompleted = { Number = 17, Name = "Onboarding Completed" },
}

local SESSION_MILESTONES = {
	{ Minutes = 5, Step = 2 },
	{ Minutes = 10, Step = 3 },
	{ Minutes = 20, Step = 4 },
	{ Minutes = 30, Step = 5 },
}

local PlayerSessions = {}
local CrateSessions: { [Player]: { [Model]: any } } = {}
local RestorationSessions: { [Player]: { [number]: any } } = {}
local DecisionSessions: { [Player]: { [number]: any } } = {}
local UpgradeSessions: { [Player]: any } = {}

local function GetItemInfo(ItemId: number)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
end

local function IsOnboarding(Player: Player): boolean
	return DataService:get(Player, "TutorialStep") ~= TutorialConfig.CompleteStep
end

local function BuildFields(Values): { [string]: string }
	local Fields = {}
	for Index, Value in Values do
		if Index > #CUSTOM_FIELD_KEYS then break end
		if Value ~= nil then Fields[CUSTOM_FIELD_KEYS[Index]] = tostring(Value) end
	end
	return Fields
end

local function GetItemFields(Player: Player, ItemInfo)
	return BuildFields({
		`Item={ItemInfo.Name}`,
		`Rarity={ItemInfo.Rarity}`,
		`Onboarding={tostring(IsOnboarding(Player))}`,
	})
end

local function GetAnalyticsState(Player: Player)
	local SavedState = DataService:get(Player, "Analytics")
	local State = if type(SavedState) == "table" then table.clone(SavedState) else {}
	State.OnboardingHighestStep = if type(State.OnboardingHighestStep) == "number" then State.OnboardingHighestStep else 0
	State.CratesBroken = if type(State.CratesBroken) == "number" then State.CratesBroken else 0
	State.RestorationsCompleted = if type(State.RestorationsCompleted) == "number" then State.RestorationsCompleted else 0
	State.UpgradesPurchased = if type(State.UpgradesPurchased) == "number" then State.UpgradesPurchased else 0
	State.FirstVisitorIncomeEarned = State.FirstVisitorIncomeEarned == true
	return State
end

local function SaveAnalyticsState(Player: Player, State)
	DataService:set(Player, "Analytics", State)
end

local function CanSend(Player: Player): boolean
	-- Roblox analytics events only send from published servers; Studio still exercises deduplication state.
	return not RunService:IsStudio() and Player.Parent == Players
end

local function LogCustomEvent(Player: Player, EventName: string, Fields, Value: number?)
	if CanSend(Player) then AnalyticsService:LogCustomEvent(Player, EventName, Value or 1, Fields) end
end

local function LogFunnelStep(Player: Player, FunnelName: string, SessionId: string, Step: number, StepName: string, Fields)
	if CanSend(Player) then AnalyticsService:LogFunnelStepEvent(Player, FunnelName, SessionId, Step, StepName, Fields) end
end

local function AdvanceOnboarding(Player: Player, StepId: string, Fields): boolean
	local Step = ONBOARDING_STEPS[StepId]
	if not Step then return false end
	local State = GetAnalyticsState(Player)
	if State.OnboardingHighestStep ~= Step.Number - 1 then return false end
	if CanSend(Player) then AnalyticsService:LogOnboardingFunnelStepEvent(Player, Step.Number, Step.Name, Fields) end
	State.OnboardingHighestStep = Step.Number
	SaveAnalyticsState(Player, State)
	return true
end

local function GetTutorialBootstrapStep(Player: Player): number
	local TutorialStep = DataService:get(Player, "TutorialStep")
	local Steps = {
		PickUpItem = 2,
		BringItemHome = 6,
		StartCleaning = 7,
		UseTool = 8,
		CleanThis = 8,
		DisplayItem = 11,
		EarnMoney = 12,
		OpenUpgrades = 13,
		BuySponge = 13,
		Complete = 17,
	}
	return Steps[TutorialStep] or 0
end

local function GetMuseumProgressionStep(DisplayLimit: number): (number, string)
	local Step = math.max(1, DisplayLimit - UpgradeConfig.DefaultDisplayLimit + 1)
	local LevelNumber = MuseumConfig.GetLevelCount(DisplayLimit)
	local LevelInfo = MuseumConfig.Levels[LevelNumber]
	if LevelInfo and DisplayLimit == LevelInfo.StartSlot and LevelNumber > 1 then
		return Step, `Floor {LevelNumber} And Display {DisplayLimit} Unlocked`
	end
	return Step, if Step == 1 then "Museum Started" else `Display {DisplayLimit} Unlocked`
end

function AnalyticsController.TrackCrateDiscovered(Player: Player, Crate: Model, CrateInfo)
	local Sessions = CrateSessions[Player]
	if not Sessions or not Crate or not CrateInfo then return nil end
	local Session = Sessions[Crate]
	if Session then return Session.Id end
	Session = { Id = HttpService:GenerateGUID(false), Broken = false }
	Sessions[Crate] = Session
	local Fields = BuildFields({ `Crate={CrateInfo.DisplayName or CrateInfo.Id}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "CrateDiscovered", Fields)
	LogFunnelStep(Player, FUNNEL_NAMES.CratePurchase, Session.Id, 1, "Crate Discovered", Fields)
	AdvanceOnboarding(Player, "FirstCrateFound", Fields)
	return Session.Id
end

function AnalyticsController.TrackCrateBroken(Player: Player, Crate: Model, CrateInfo)
	local SessionId = AnalyticsController.TrackCrateDiscovered(Player, Crate, CrateInfo)
	local Session = CrateSessions[Player] and CrateSessions[Player][Crate]
	if not SessionId or not Session or Session.Broken then return SessionId end
	Session.Broken = true
	local Fields = BuildFields({ `Crate={CrateInfo.DisplayName or CrateInfo.Id}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "CrateBroken", Fields)
	LogFunnelStep(Player, FUNNEL_NAMES.CratePurchase, SessionId, 2, "Crate Broken", Fields)
	local State = GetAnalyticsState(Player)
	State.CratesBroken = math.min(State.CratesBroken + 1, 2)
	SaveAnalyticsState(Player, State)
	if State.CratesBroken == 1 then
		AdvanceOnboarding(Player, "FirstCrateBroken", Fields)
	elseif State.CratesBroken == 2 then
		AdvanceOnboarding(Player, "SecondCrateBroken", Fields)
	end
	return SessionId
end

function AnalyticsController.TrackItemRevealed(Player: Player, ItemId: number, CrateInfo, CrateSessionId: string?)
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo or Player.Parent ~= Players then return end
	local Fields = BuildFields({ `Item={ItemInfo.Name}`, `Rarity={ItemInfo.Rarity}`, `Crate={CrateInfo.DisplayName or CrateInfo.Id}` })
	LogCustomEvent(Player, "ItemRevealed", Fields)
	if CrateSessionId then LogFunnelStep(Player, FUNNEL_NAMES.CratePurchase, CrateSessionId, 3, "Item Revealed", Fields) end
	AdvanceOnboarding(Player, "FirstItemRevealed", Fields)
end

function AnalyticsController.TrackItemPurchased(Player: Player, ItemId: number, Source: string, CrateSessionId: string?)
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo then return end
	local Fields = GetItemFields(Player, ItemInfo)
	LogCustomEvent(Player, "ItemPurchased", BuildFields({ `Item={ItemInfo.Name}`, `Rarity={ItemInfo.Rarity}`, `Source={Source}` }))
	if CrateSessionId then LogFunnelStep(Player, FUNNEL_NAMES.CratePurchase, CrateSessionId, 4, "Item Purchased", Fields) end
	local Session = { Id = HttpService:GenerateGUID(false), Started = false, Completed = false }
	RestorationSessions[Player][ItemId] = Session
	LogFunnelStep(Player, FUNNEL_NAMES.ItemRestoration, Session.Id, 1, "Item Purchased", Fields)
	AdvanceOnboarding(Player, "FirstItemPurchased", Fields)
end

function AnalyticsController.TrackItemBroughtToMuseum(Player: Player, ItemId: number)
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo then return end
	local Fields = GetItemFields(Player, ItemInfo)
	LogCustomEvent(Player, "ItemBroughtToMuseum", Fields)
	AdvanceOnboarding(Player, "ItemBroughtToMuseum", Fields)
end

function AnalyticsController.TrackRestorationStarted(Player: Player, ItemInfo)
	if not ItemInfo then return end
	local Fields = GetItemFields(Player, ItemInfo)
	LogCustomEvent(Player, "RestorationStarted", Fields)
	local Session = RestorationSessions[Player] and RestorationSessions[Player][ItemInfo.Id]
	if Session and not Session.Started then
		Session.Started = true
		LogFunnelStep(Player, FUNNEL_NAMES.ItemRestoration, Session.Id, 2, "Restoration Started", Fields)
	end
	AdvanceOnboarding(Player, "RestorationStarted", Fields)
end

function AnalyticsController.TrackRestorationStepCompleted(Player: Player, ItemInfo, Step)
	if not ItemInfo or not Step then return end
	local Fields = BuildFields({ `Tool={Step.ToolId}`, `Item={ItemInfo.Name}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	-- One event is emitted only when a required step is completed, never for individual tool movements or hits.
	LogCustomEvent(Player, "RestorationStepCompleted", Fields)
	AdvanceOnboarding(Player, "RequiredRestorationStepCompleted", Fields)
end

function AnalyticsController.TrackRestorationCompleted(Player: Player, ItemInfo, Reward: number, RewardCollected: boolean)
	if not ItemInfo then return end
	local Fields = GetItemFields(Player, ItemInfo)
	LogCustomEvent(Player, "RestorationCompleted", Fields)
	local RestorationSession = RestorationSessions[Player] and RestorationSessions[Player][ItemInfo.Id]
	if RestorationSession and not RestorationSession.Completed then
		RestorationSession.Completed = true
		LogFunnelStep(Player, FUNNEL_NAMES.ItemRestoration, RestorationSession.Id, 3, "Restoration Completed", Fields)
	end
	local DecisionSession = { Id = HttpService:GenerateGUID(false), Displayed = false, Sold = false }
	DecisionSessions[Player][ItemInfo.Id] = DecisionSession
	LogFunnelStep(Player, FUNNEL_NAMES.RestorationDecision, DecisionSession.Id, 1, "Restoration Completed", Fields)
	local State = GetAnalyticsState(Player)
	State.RestorationsCompleted = math.min(State.RestorationsCompleted + 1, 2)
	SaveAnalyticsState(Player, State)
	if State.RestorationsCompleted == 1 then
		AdvanceOnboarding(Player, "FirstRestorationCompleted", Fields)
	elseif State.RestorationsCompleted == 2 then
		AdvanceOnboarding(Player, "SecondItemRestored", Fields)
		if AdvanceOnboarding(Player, "OnboardingCompleted", BuildFields({ "CoreLoop=Completed" })) then
			LogCustomEvent(Player, "OnboardingCompleted", BuildFields({ "CoreLoop=Completed" }))
		end
	end
	if RewardCollected then
		LogCustomEvent(Player, "RestorationRewardCollected", Fields, Reward)
		AdvanceOnboarding(Player, "RestorationRewardCollected", Fields)
	end
end

function AnalyticsController.TrackItemDisplayed(Player: Player, ItemId: number, DisplayIndex: number, FloorNumber: number)
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo then return end
	local Fields = BuildFields({ `Item={ItemInfo.Name}`, `Rarity={ItemInfo.Rarity}`, `Floor={FloorNumber}` })
	LogCustomEvent(Player, "ItemDisplayed", Fields)
	local Session = DecisionSessions[Player] and DecisionSessions[Player][ItemId]
	if Session and not Session.Displayed then
		Session.Displayed = true
		LogFunnelStep(Player, FUNNEL_NAMES.RestorationDecision, Session.Id, 2, "Item Displayed", Fields)
	end
	AdvanceOnboarding(Player, "FirstItemDisplayed", BuildFields({ `Item={ItemInfo.Name}`, `Display={DisplayIndex}`, `Floor={FloorNumber}` }))
end

function AnalyticsController.TrackItemSold(Player: Player, ItemId: number, FloorNumber: number, SaleValue: number)
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo then return end
	local Fields = BuildFields({ `Item={ItemInfo.Name}`, `Rarity={ItemInfo.Rarity}`, `Floor={FloorNumber}` })
	LogCustomEvent(Player, "ItemSold", Fields, SaleValue)
	local Session = DecisionSessions[Player] and DecisionSessions[Player][ItemId]
	if Session and not Session.Sold then
		Session.Sold = true
		LogFunnelStep(Player, FUNNEL_NAMES.RestorationDecision, Session.Id, 3, "Item Sold", Fields)
	end
end

function AnalyticsController.TrackFirstVisitorIncome(Player: Player, ItemId: number, FloorNumber: number, Amount: number)
	local State = GetAnalyticsState(Player)
	if State.FirstVisitorIncomeEarned then return end
	local ItemInfo = GetItemInfo(ItemId)
	if not ItemInfo then return end
	State.FirstVisitorIncomeEarned = true
	SaveAnalyticsState(Player, State)
	local Fields = BuildFields({ `Item={ItemInfo.Name}`, `Floor={FloorNumber}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "FirstVisitorIncomeEarned", Fields, Amount)
	AdvanceOnboarding(Player, "FirstVisitorIncomeEarned", Fields)
end

function AnalyticsController.UpgradeMenuOpened(_, Player: Player)
	if Player.Parent ~= Players then return end
	local Session = { Id = HttpService:GenerateGUID(false), SeenUpgrades = {}, Purchased = false }
	UpgradeSessions[Player] = Session
	local Fields = BuildFields({ `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "UpgradeMenuOpened", Fields)
	LogFunnelStep(Player, FUNNEL_NAMES.UpgradePurchase, Session.Id, 1, "Upgrade Menu Opened", Fields)
end

function AnalyticsController.UpgradeViewed(_, Player: Player, UpgradeId: string)
	local Session = UpgradeSessions[Player]
	local Upgrade = if type(UpgradeId) == "string" then UpgradeConfig.Get(UpgradeId) else nil
	if not Session or not Upgrade or Session.SeenUpgrades[UpgradeId] then return end
	Session.SeenUpgrades[UpgradeId] = true
	local Fields = BuildFields({ `Upgrade={Upgrade.Id}`, `Branch={Upgrade.Branch}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "UpgradeViewed", Fields)
	if not Session.Viewed then
		Session.Viewed = true
		LogFunnelStep(Player, FUNNEL_NAMES.UpgradePurchase, Session.Id, 2, "Upgrade Viewed", Fields)
	end
end

function AnalyticsController.TrackUpgradePurchased(Player: Player, Upgrade, PreviousOwnership)
	if not Upgrade then return end
	local Fields = BuildFields({ `Upgrade={Upgrade.Id}`, `Branch={Upgrade.Branch}`, `Onboarding={tostring(IsOnboarding(Player))}` })
	LogCustomEvent(Player, "UpgradePurchased", Fields, Upgrade.Cost)
	local Session = UpgradeSessions[Player]
	if Session and not Session.Purchased then
		Session.Purchased = true
		LogFunnelStep(Player, FUNNEL_NAMES.UpgradePurchase, Session.Id, 3, "Upgrade Purchased", Fields)
	end
	local State = GetAnalyticsState(Player)
	State.UpgradesPurchased += 1
	SaveAnalyticsState(Player, State)
	if State.UpgradesPurchased == 1 then AdvanceOnboarding(Player, "FirstUpgradePurchased", Fields) end
	local Effect = Upgrade.Effect
	if Effect and Effect.Type == "DisplayLimit" then
		local PreviousLimit = UpgradeLogic.GetDisplayLimit(PreviousOwnership)
		local DisplayLimit = Effect.Value
		local FloorNumber = MuseumConfig.GetLevelCount(DisplayLimit)
		local MuseumFields = BuildFields({ `Display={DisplayLimit}`, `Floor={FloorNumber}`, `Onboarding={tostring(IsOnboarding(Player))}` })
		LogCustomEvent(Player, "DisplayUnlocked", MuseumFields)
		local Step, StepName = GetMuseumProgressionStep(DisplayLimit)
		LogFunnelStep(Player, FUNNEL_NAMES.MuseumProgression, "Lifetime", Step, StepName, MuseumFields)
		if MuseumConfig.GetLevelCount(PreviousLimit) < FloorNumber then LogCustomEvent(Player, "MuseumFloorUnlocked", MuseumFields) end
	end
end

function AnalyticsController.SetDataService(Service)
	DataService = Service
end

function AnalyticsController.Init()
	Networker.server.new("AnalyticsController", AnalyticsController, {
		AnalyticsController.UpgradeMenuOpened,
		AnalyticsController.UpgradeViewed,
	})
end

function AnalyticsController.OnPlayerAdded(Player: Player)
	PlayerSessions[Player] = { Id = HttpService:GenerateGUID(false) }
	CrateSessions[Player] = {}
	RestorationSessions[Player] = {}
	DecisionSessions[Player] = {}
	LogCustomEvent(Player, "PlayerJoined", BuildFields({ `Onboarding={tostring(IsOnboarding(Player))}` }))
	local State = GetAnalyticsState(Player)
	if State.OnboardingHighestStep == 0 then
		local BootstrapStep = GetTutorialBootstrapStep(Player)
		if BootstrapStep == 2 then
			AdvanceOnboarding(Player, "PlayerJoined", BuildFields({ "Onboarding=true" }))
			AdvanceOnboarding(Player, "OnboardingStarted", BuildFields({ "Onboarding=true" }))
		else
			State.OnboardingHighestStep = BootstrapStep
			SaveAnalyticsState(Player, State)
		end
	end
	local Ownership = DataService:get(Player, "Upgrades")
	local DisplayLimit = UpgradeLogic.GetDisplayLimit(Ownership)
	local MuseumStep, MuseumStepName = GetMuseumProgressionStep(DisplayLimit)
	LogFunnelStep(Player, FUNNEL_NAMES.MuseumProgression, "Lifetime", MuseumStep, MuseumStepName, BuildFields({
		`Display={DisplayLimit}`,
		`Floor={MuseumConfig.GetLevelCount(DisplayLimit)}`,
	}))
	local Session = PlayerSessions[Player]
	LogFunnelStep(Player, FUNNEL_NAMES.SessionProgression, Session.Id, 1, "Session Started", BuildFields({
		`Onboarding={tostring(IsOnboarding(Player))}`,
	}))
	for _, Milestone in SESSION_MILESTONES do
		task.delay(Milestone.Minutes * 60, function()
			if Player.Parent ~= Players or PlayerSessions[Player] ~= Session then return end
			local Fields = BuildFields({ `Minutes={Milestone.Minutes}`, `Onboarding={tostring(IsOnboarding(Player))}` })
			LogCustomEvent(Player, "SessionMilestoneReached", Fields, Milestone.Minutes)
			LogFunnelStep(Player, FUNNEL_NAMES.SessionProgression, Session.Id, Milestone.Step, `{Milestone.Minutes} Minutes Played`, Fields)
		end)
	end
end

function AnalyticsController.OnPlayerRemoving(Player: Player)
	PlayerSessions[Player] = nil
	CrateSessions[Player] = nil
	RestorationSessions[Player] = nil
	DecisionSessions[Player] = nil
	UpgradeSessions[Player] = nil
end

return AnalyticsController
