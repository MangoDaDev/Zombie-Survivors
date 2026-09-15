local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local GuidanceController = {}
local DataService
local Network

local function HasExistingProgress(Player: Player): boolean
	local Inventory = DataService:get(Player, "Inventory")
	local Displays = DataService:get(Player, "Displays")
	local Fixing = DataService:get(Player, "Fixing")
	local Ownership = DataService:get(Player, "Upgrades")
	local HasPurchasedUpgrade = false
	if type(Ownership) == "table" then
		for UpgradeId, IsOwned in Ownership do
			if UpgradeId ~= "Start" and IsOwned == true then HasPurchasedUpgrade = true; break end
		end
	end
	return type(Inventory) == "table" and #Inventory > 0
		or type(Displays) == "table" and next(Displays) ~= nil
		or type(Fixing) == "table" and next(Fixing) ~= nil
		or HasPurchasedUpgrade
end

function GuidanceController.Advance(Player: Player, ExpectedStep: string)
	if Player.Parent ~= Players or DataService:get(Player, "TutorialStep") ~= ExpectedStep then return end
	local Step = TutorialConfig.GetStep(ExpectedStep)
	if Step then DataService:set(Player, "TutorialStep", Step.Next) end
end

function GuidanceController.Show(Player: Player, Text: string, Target: Instance?, TargetKind: string?)
	if not Network or Player.Parent ~= Players then return end
	Network:fire(Player, "ShowMessage", Text, Target, TargetKind)
end

function GuidanceController.OpenedUpgrades(_, Player: Player)
	GuidanceController.Advance(Player, "OpenUpgrades")
	if UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), "Sponge") then
		GuidanceController.Advance(Player, "BuySponge")
	end
end

function GuidanceController.SetDataService(Service)
	DataService = Service
end

function GuidanceController.Init()
	Network = Networker.server.new("GuidanceController", GuidanceController, {
		GuidanceController.OpenedUpgrades,
	})
end

function GuidanceController.OnPlayerAdded(Player: Player)
	if DataService:get(Player, "TutorialStep") == TutorialConfig.InitialStep and HasExistingProgress(Player) then
		DataService:set(Player, "TutorialStep", TutorialConfig.CompleteStep)
	end
end

return GuidanceController
