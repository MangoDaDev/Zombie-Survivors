local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local UpgradeController = {}
local DataService
local PurchaseLocks: { [Player]: boolean } = {}

local function CopyOwnership(Value)
	local Ownership = {}
	if type(Value) == "table" then
		for UpgradeId, IsOwned in Value do
			if type(UpgradeId) == "string" and IsOwned == true then Ownership[UpgradeId] = true end
		end
	end
	Ownership.Start = true
	return Ownership
end

function UpgradeController:Purchase(Player: Player, UpgradeId: string)
	if PurchaseLocks[Player] or Player.Parent ~= Players or type(UpgradeId) ~= "string" then return false, "Invalid request" end
	local Upgrade = UpgradeConfig.Get(UpgradeId)
	if not Upgrade or Upgrade.Id == "Start" then return false, "That upgrade cannot be purchased" end
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
	if type(Cash) ~= "number" or Cash < Upgrade.Cost then
		PurchaseLocks[Player] = nil
		return false, "Not enough cash"
	end
	Ownership[UpgradeId] = true
	DataService:set(Player, "Cash", Cash - Upgrade.Cost)
	DataService:set(Player, "Upgrades", Ownership)
	PurchaseLocks[Player] = nil
	return true, "Purchased", Ownership
end

function UpgradeController.SetDataService(Service) DataService = Service end

function UpgradeController:Init()
	Networker.server.new("UpgradeController", self, { UpgradeController.Purchase })
end

function UpgradeController.OnPlayerAdded(Player: Player)
	local SavedOwnership = DataService:get(Player, "Upgrades")
	if type(SavedOwnership) ~= "table" or SavedOwnership.Start ~= true then
		DataService:set(Player, "Upgrades", CopyOwnership(SavedOwnership))
	end
end

function UpgradeController.OnPlayerRemoving(Player: Player)
	PurchaseLocks[Player] = nil
end

return UpgradeController
