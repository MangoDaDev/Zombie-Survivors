local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local Networker = require(ReplicatedStorage.Packages.networker)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local UpgradeController = {}
local DataService
local PurchaseLocks: { [Player]: boolean } = {}
local ONBOARDING_UPGRADE_ID = "UnlockSponge"

local function CopyOwnership(Value)
	return UpgradeLogic.NormalizeOwnership(Value)
end

local function OwnershipMatches(Value, Ownership): boolean
	if type(Value) ~= "table" then return false end
	for UpgradeId, IsOwned in Ownership do
		if IsOwned == true and Value[UpgradeId] ~= true then return false end
	end
	for UpgradeId, IsOwned in Value do
		if type(UpgradeId) ~= "string" or IsOwned ~= true or Ownership[UpgradeId] ~= true then return false end
	end
	return true
end

function UpgradeController.Purchase(_, Player: Player, UpgradeId: string)
	if PurchaseLocks[Player] or Player.Parent ~= Players or type(UpgradeId) ~= "string" then return false, "Invalid request" end
	local Upgrade = UpgradeConfig.Get(UpgradeId)
	if not Upgrade or Upgrade.Purchasable == false then return false, "That upgrade cannot be purchased" end
	-- Sponge is the only purchasable upgrade until the guided onboarding is complete.
	if DataService:get(Player, "TutorialStep") ~= TutorialConfig.CompleteStep and UpgradeId ~= ONBOARDING_UPGRADE_ID then
		return false, "Finish onboarding first"
	end
	PurchaseLocks[Player] = true
	local Ownership = CopyOwnership(DataService:get(Player, "Upgrades"))
	if UpgradeLogic.IsPurchased(Ownership, UpgradeId) then
		PurchaseLocks[Player] = nil
		return false, "Already purchased"
	end
	if not UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade) then
		PurchaseLocks[Player] = nil
		return false, "Requirements not met"
	end
	local Cash = DataService:get(Player, "Cash")
	if not UpgradeLogic.CanPurchaseUpgrade(Ownership, Upgrade, Cash) then
		PurchaseLocks[Player] = nil
		return false, "Not enough cash"
	end
	local PreviousOwnership = table.clone(Ownership)
	Ownership[UpgradeId] = true
	DataService:set(Player, "Cash", Cash - Upgrade.Cost)
	DataService:set(Player, "Upgrades", Ownership)
	AnalyticsController.TrackUpgradePurchased(Player, Upgrade, PreviousOwnership)
	if UpgradeId == ONBOARDING_UPGRADE_ID then
		GuidanceController.Advance(Player, "BuySponge")
	end
	PurchaseLocks[Player] = nil
	return true, "Purchased", Ownership
end

function UpgradeController.SetDataService(Service) DataService = Service end

function UpgradeController.Init()
	Networker.server.new("UpgradeController", UpgradeController, { UpgradeController.Purchase })
end

function UpgradeController.OnPlayerAdded(Player: Player)
	local SavedOwnership = DataService:get(Player, "Upgrades")
	local Ownership = CopyOwnership(SavedOwnership)
	if not OwnershipMatches(SavedOwnership, Ownership) then
		DataService:set(Player, "Upgrades", Ownership)
	end
end

function UpgradeController.OnPlayerRemoving(Player: Player)
	PurchaseLocks[Player] = nil
end

return UpgradeController
