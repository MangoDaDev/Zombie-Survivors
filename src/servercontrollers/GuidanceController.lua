local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local GuidanceController = {}
local DataService
local Network
local TutorialCrates: { [Player]: Model } = {}
local CompletedTutorialCrates: { [Player]: boolean } = {}
local TutorialRewards: { [Player]: Model } = {}
local ONBOARDING = TutorialConfig.Onboarding
local RandomGenerator = Random.new()

local function ChooseOnboardingItem(ItemIds): number
	return ItemIds[RandomGenerator:NextInteger(1, #ItemIds)]
end

local function CopyOnboarding(Value)
	local Progress = if type(Value) == "table" then table.clone(Value) else {}
	Progress.DiscreteProgressionActive = Progress.DiscreteProgressionActive == true
	Progress.DirtGreaseItemReceived = Progress.DirtGreaseItemReceived == true
	Progress.DirtGreaseItemDisplayed = Progress.DirtGreaseItemDisplayed == true
	Progress.SoftBrushFundingGranted = Progress.SoftBrushFundingGranted == true
	Progress.DustFundingGranted = Progress.DustFundingGranted == true
	Progress.DustItemReceived = Progress.DustItemReceived == true
	return Progress
end

local function HasSoftBrush(Player: Player): boolean
	return UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), "SoftBrush")
end

local function HasRestorationSteps(State, RequiredSteps): boolean
	if type(State) ~= "table" or type(State.RestorationSteps) ~= "table" then return false end
	for _, StepId in RequiredSteps do
		if not table.find(State.RestorationSteps, StepId) then return false end
	end
	return true
end

local function HasOnboardingRestoration(Fixing, ItemIds, RequiredSteps): boolean
	for _, ItemId in ItemIds do
		if HasRestorationSteps(Fixing[tostring(ItemId)], RequiredSteps) then return true end
	end
	return false
end

local function FindClosestCommonCrate(Player: Player): Model?
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local CrateFolder = Workspace:FindFirstChild("Crates")
	if not RootPart or not RootPart:IsA("BasePart") or not CrateFolder then return nil end

	local ClosestCrate: Model?
	local ClosestDistance = math.huge
	for _, Crate in CrateFolder:GetChildren() do
		if not Crate:IsA("Model") or Crate.Name ~= "CommonCrate" then continue end
		local Distance = (Crate:GetPivot().Position - RootPart.Position).Magnitude
		if Distance < ClosestDistance then
			ClosestCrate = Crate
			ClosestDistance = Distance
		end
	end
	return ClosestCrate
end

local function GetTutorialCrateForPlayer(Player: Player): Model?
	if DataService:get(Player, "TutorialStep") ~= "PickUpItem" then
		TutorialCrates[Player] = nil
		CompletedTutorialCrates[Player] = nil
		TutorialRewards[Player] = nil
		return nil
	end
	if CompletedTutorialCrates[Player] then return nil end

	local Crate = TutorialCrates[Player]
	if Crate and Crate.Parent then return Crate end
	Crate = FindClosestCommonCrate(Player)
	TutorialCrates[Player] = Crate
	return Crate
end

function GuidanceController.Advance(Player: Player, ExpectedStep: string)
	if Player.Parent ~= Players or DataService:get(Player, "TutorialStep") ~= ExpectedStep then return end
	local Step = TutorialConfig.GetStep(ExpectedStep)
	if Step then
		DataService:set(Player, "TutorialStep", Step.Next)
		if Step.Next == TutorialConfig.CompleteStep then
			-- End the visible tutorial with a brief message after the Sponge purchase.
			GuidanceController.Show(Player, TutorialConfig.CompleteText)
		end
	end
end

function GuidanceController.Show(Player: Player, Text: string, Target: Instance?, TargetKind: string?, ShouldNotify: boolean?)
	if not Network or Player.Parent ~= Players then return end
	Network:fire(Player, "ShowMessage", Text, Target, TargetKind, ShouldNotify == true)
end

function GuidanceController.OpenedUpgrades(_, Player: Player)
	GuidanceController.Advance(Player, "OpenUpgrades")
	if UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), "Sponge") then
		GuidanceController.Advance(Player, "BuySponge")
	end
end

function GuidanceController.GetOnboardingReward(Player: Player)
	local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
	-- The first item received after buying Sponge must include grease, even if opening drops remain.
	if not Progress.DirtGreaseItemReceived
		and UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), "Sponge")
	then
		return {
			ItemId = ChooseOnboardingItem(ONBOARDING.DirtGreaseItemIds),
			RestorationSteps = ONBOARDING.DirtGreaseRestorationSteps,
		}, "DirtGrease"
	end
	if DataService:get(Player, "TutorialStep") == TutorialConfig.CompleteStep
		and not Progress.DiscreteProgressionActive
	then
		return nil
	end
	local GuaranteedDropCount = DataService:get(Player, "GuaranteedDropCount")
	GuaranteedDropCount = if type(GuaranteedDropCount) == "number" then math.max(0, math.floor(GuaranteedDropCount)) else 0
	local GuaranteedReward = CrateInfo.NewPlayerDropSequence[GuaranteedDropCount + 1]
	if GuaranteedReward then
		return { ItemId = ChooseOnboardingItem(GuaranteedReward.ItemIds) }, "Guaranteed", GuaranteedDropCount + 1
	end

	if Progress.DirtGreaseItemDisplayed and HasSoftBrush(Player) and not Progress.DustItemReceived then
		-- The first forced reward after confirmed Soft Brush ownership must contain Dust.
		return {
			ItemId = ChooseOnboardingItem(ONBOARDING.DustItemIds),
			RestorationSteps = ONBOARDING.DustRestorationSteps,
		}, "Dust"
	end
	return nil
end

function GuidanceController.PrepareOnboardingReward(Player: Player, RewardKind: string?, ItemPrice: number)
	if RewardKind ~= "Dust" then return end
	local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
	if Progress.DustFundingGranted then return end
	local Cash = DataService:get(Player, "Cash")
	if type(Cash) == "number" and Cash < ItemPrice then DataService:set(Player, "Cash", ItemPrice) end
	Progress.DustFundingGranted = true
	DataService:set(Player, "Onboarding", Progress)
end

function GuidanceController.EnsureOnboardingRewardAffordable(Player: Player, RewardKind: string?, ItemPrice: number): number?
	local Cash = DataService:get(Player, "Cash")
	if type(Cash) ~= "number" then return nil end
	if RewardKind == "Dust" and Cash < ItemPrice then
		-- Preserve the promised Dust progression even if the original reward expired or cash changed.
		Cash = ItemPrice
		DataService:set(Player, "Cash", Cash)
	end
	return Cash
end

function GuidanceController.MarkOnboardingRewardReceived(Player: Player, RewardKind: string?, GuaranteedIndex: number?)
	if RewardKind == "Guaranteed" and type(GuaranteedIndex) == "number" then
		local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
		Progress.DiscreteProgressionActive = true
		DataService:set(Player, "Onboarding", Progress)
		local CurrentCount = DataService:get(Player, "GuaranteedDropCount")
		if type(CurrentCount) == "number" and CurrentCount == GuaranteedIndex - 1 then
			DataService:set(Player, "GuaranteedDropCount", GuaranteedIndex)
		end
		return
	end
	if RewardKind ~= "DirtGrease" and RewardKind ~= "Dust" then return end
	local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
	Progress.DiscreteProgressionActive = true
	if RewardKind == "DirtGrease" then
		Progress.DirtGreaseItemReceived = true
		DataService:set(Player, "GuaranteedDropCount", math.max(DataService:get(Player, "GuaranteedDropCount") or 0, 3))
	else
		Progress.DustItemReceived = true
		DataService:set(Player, "GuaranteedDropCount", math.max(DataService:get(Player, "GuaranteedDropCount") or 0, 4))
	end
	DataService:set(Player, "Onboarding", Progress)
end

function GuidanceController.MarkOnboardingItemDisplayed(Player: Player, ItemId: number)
	if not table.find(ONBOARDING.DirtGreaseItemIds, ItemId) then return end
	local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
	if not Progress.DirtGreaseItemReceived or Progress.DirtGreaseItemDisplayed then return end
	Progress.DirtGreaseItemDisplayed = true
	if not Progress.SoftBrushFundingGranted then
		local Upgrade = UpgradeConfig.Get(ONBOARDING.SoftBrushUpgradeId)
		local Cash = DataService:get(Player, "Cash")
		local TargetCash = (Upgrade and Upgrade.Cost or 0) + ONBOARDING.SoftBrushCashBuffer
		if type(Cash) == "number" and Cash < TargetCash then DataService:set(Player, "Cash", TargetCash) end
		Progress.SoftBrushFundingGranted = true
	end
	DataService:set(Player, "Onboarding", Progress)
end

function GuidanceController.RefreshUpgradeRequirement(Player: Player)
	if DataService:get(Player, "TutorialStep") == "BuySponge"
		and UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), "Sponge")
	then
		GuidanceController.Advance(Player, "BuySponge")
	end
end

function GuidanceController.GetTutorialCrate(_, Player: Player): Model?
	return GetTutorialCrateForPlayer(Player)
end

function GuidanceController.GetTutorialTarget(_, Player: Player): Model?
	if DataService:get(Player, "TutorialStep") ~= "PickUpItem" then return nil end
	local Reward = TutorialRewards[Player]
	if Reward and Reward.Parent then return Reward end
	return GetTutorialCrateForPlayer(Player)
end

function GuidanceController.GetTutorialCrateForPlayer(Player: Player): Model?
	return GetTutorialCrateForPlayer(Player)
end

function GuidanceController.MarkTutorialCrateBroken(Player: Player, Crate: Model)
	if TutorialCrates[Player] ~= Crate then return end
	CompletedTutorialCrates[Player] = true
end

function GuidanceController.MarkTutorialRewardCreated(Player: Player, Crate: Model, Reward: Model)
	-- Any crate can complete the first break; guide pickup to its own reward.
	if DataService:get(Player, "TutorialStep") ~= "PickUpItem" or TutorialRewards[Player] then return end
	TutorialCrates[Player] = Crate
	TutorialRewards[Player] = Reward
end

function GuidanceController.MarkTutorialRewardRemoved(Player: Player, Reward: Model)
	if TutorialRewards[Player] ~= Reward then return end
	TutorialRewards[Player] = nil
	TutorialCrates[Player] = nil
	CompletedTutorialCrates[Player] = nil
end

function GuidanceController.ResetTutorialCrates()
	for _, Player in Players:GetPlayers() do
		if DataService:get(Player, "TutorialStep") ~= "PickUpItem" then continue end
		TutorialCrates[Player] = nil
		if not TutorialRewards[Player] then CompletedTutorialCrates[Player] = nil end
	end
end

function GuidanceController.SetDataService(Service)
	DataService = Service
end

function GuidanceController.Init()
	Network = Networker.server.new("GuidanceController", GuidanceController, {
		GuidanceController.OpenedUpgrades,
		GuidanceController.GetTutorialCrate,
		GuidanceController.GetTutorialTarget,
	})
end

function GuidanceController.OnPlayerAdded(Player: Player)
	local Progress = CopyOnboarding(DataService:get(Player, "Onboarding"))
	local TutorialStep = DataService:get(Player, "TutorialStep")
	local WasVisibleExtensionStep = TutorialStep == "FindDirtGreaseItem"
		or TutorialStep == "RestoreDirtGreaseItem"
		or TutorialStep == "BuySoftBrush"
		or TutorialStep == "FindDustItem"
	local Fixing = DataService:get(Player, "Fixing")
	if type(Fixing) == "table" then
		Progress.DirtGreaseItemReceived = Progress.DirtGreaseItemReceived
			or HasOnboardingRestoration(Fixing, ONBOARDING.DirtGreaseItemIds, ONBOARDING.DirtGreaseRestorationSteps)
		Progress.DustItemReceived = Progress.DustItemReceived
			or HasOnboardingRestoration(Fixing, ONBOARDING.DustItemIds, ONBOARDING.DustRestorationSteps)
	end
	Progress.DiscreteProgressionActive = Progress.DiscreteProgressionActive
		or WasVisibleExtensionStep
		or Progress.DirtGreaseItemReceived
		or Progress.DustItemReceived
	local GuaranteedDropCount = DataService:get(Player, "GuaranteedDropCount")
	GuaranteedDropCount = if type(GuaranteedDropCount) == "number" then GuaranteedDropCount else 0
	-- Profiles caught between the opening rewards and Sponge continue silently after this migration.
	Progress.DiscreteProgressionActive = Progress.DiscreteProgressionActive
		or (GuaranteedDropCount > 0 and GuaranteedDropCount < 3)
	DataService:set(Player, "Onboarding", Progress)
	if WasVisibleExtensionStep then DataService:set(Player, "TutorialStep", TutorialConfig.CompleteStep) end
	local ReconciledDropCount = if Progress.DustItemReceived then math.max(GuaranteedDropCount, 4)
		elseif Progress.DirtGreaseItemReceived then math.max(GuaranteedDropCount, 3)
		else GuaranteedDropCount
	if ReconciledDropCount ~= GuaranteedDropCount then DataService:set(Player, "GuaranteedDropCount", ReconciledDropCount) end
	local Displays = DataService:get(Player, "Displays")
	if Progress.DirtGreaseItemReceived and type(Displays) == "table" then
		for _, ItemId in Displays do
			if table.find(ONBOARDING.DirtGreaseItemIds, ItemId) then
				GuidanceController.MarkOnboardingItemDisplayed(Player, ItemId)
				break
			end
		end
	end
	GuidanceController.RefreshUpgradeRequirement(Player)
end

function GuidanceController.OnPlayerRemoving(Player: Player)
	TutorialCrates[Player] = nil
	CompletedTutorialCrates[Player] = nil
	TutorialRewards[Player] = nil
end

return GuidanceController
