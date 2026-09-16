local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local Networker = require(ReplicatedStorage.Packages.networker)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local UpgradeController = {}
local DataService
local PurchaseLocks: { [Player]: boolean } = {}

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
	Ownership[UpgradeId] = true
	DataService:set(Player, "Cash", Cash - Upgrade.Cost)
	DataService:set(Player, "Upgrades", Ownership)
	if UpgradeId == "UnlockSponge" then GuidanceController.Advance(Player, "BuySponge") end
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
