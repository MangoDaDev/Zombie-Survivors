local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local GuidanceController = {}
local DataService
local Network
local TutorialCrates: { [Player]: Model } = {}
local CompletedTutorialCrates: { [Player]: boolean } = {}

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
		return nil
	end
	if CompletedTutorialCrates[Player] then return nil end

	local Crate = TutorialCrates[Player]
	if Crate and Crate.Parent then return Crate end
	Crate = FindClosestCommonCrate(Player)
	TutorialCrates[Player] = Crate
	return Crate
end

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

function GuidanceController.GetTutorialCrate(_, Player: Player): Model?
	return GetTutorialCrateForPlayer(Player)
end

function GuidanceController.GetTutorialCrateForPlayer(Player: Player): Model?
	return GetTutorialCrateForPlayer(Player)
end

function GuidanceController.MarkTutorialCrateBroken(Player: Player, Crate: Model)
	if TutorialCrates[Player] ~= Crate then return end
	CompletedTutorialCrates[Player] = true
end

function GuidanceController.ResetTutorialCrates()
	for _, Player in Players:GetPlayers() do
		if DataService:get(Player, "TutorialStep") ~= "PickUpItem" then continue end
		TutorialCrates[Player] = nil
		CompletedTutorialCrates[Player] = nil
	end
end

function GuidanceController.SetDataService(Service)
	DataService = Service
end

function GuidanceController.Init()
	Network = Networker.server.new("GuidanceController", GuidanceController, {
		GuidanceController.OpenedUpgrades,
		GuidanceController.GetTutorialCrate,
	})
end

function GuidanceController.OnPlayerAdded(Player: Player)
	if DataService:get(Player, "TutorialStep") == TutorialConfig.InitialStep and HasExistingProgress(Player) then
		DataService:set(Player, "TutorialStep", TutorialConfig.CompleteStep)
	end
end

function GuidanceController.OnPlayerRemoving(Player: Player)
	TutorialCrates[Player] = nil
	CompletedTutorialCrates[Player] = nil
end

return GuidanceController
