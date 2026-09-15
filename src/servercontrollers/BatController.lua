local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local CrateController = require(ServerStorage.Controllers.CrateController)
local Networker = require(ReplicatedStorage.Packages.networker)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local BatController = {}
local DataService
local Network
local PlayerConnections: { [Player]: RBXScriptConnection } = {}
local UpgradeConnections: { [Player]: RBXScriptConnection } = {}
local LastSwings: { [Player]: number } = {}
local PositionHistory: { [Player]: { { Time: number, CFrame: CFrame } } } = {}
local LastPositionSamples: { [Player]: number } = {}
local MaximumValidationHistoryWindow = 0
local MinimumValidationSampleInterval = math.huge

for _, Info in BatInfo do
	MaximumValidationHistoryWindow = math.max(MaximumValidationHistoryWindow, Info.ValidationHistoryWindow)
	MinimumValidationSampleInterval = math.min(MinimumValidationSampleInterval, Info.ValidationSampleInterval)
end

local function GetBatInfo(BatId)
	for _, Info in BatInfo do
		if Info.Id == BatId then return Info end
	end
end

local function RemoveBats(Player)
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if not Container then continue end
		for _, Child in Container:GetChildren() do
			if Child:IsA("Tool") and type(Child:GetAttribute("BatId")) == "string" then Child:Destroy() end
		end
	end
end

local function EnsureBat(Player)
	if Player.Parent ~= Players or Player:GetAttribute("IsFixing") == true then return end
	local Ownership = DataService:get(Player, "Upgrades")
	local Info = GetBatInfo(UpgradeLogic.GetBatId(Ownership)) or BatInfo[1]
	local CooldownMultiplier = UpgradeLogic.GetBatCooldownMultiplier(Ownership)
	local MatchingBat
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if Container then
			for _, Child in Container:GetChildren() do
				if Child:IsA("Tool") and type(Child:GetAttribute("BatId")) == "string" then
					if Child:GetAttribute("BatId") == Info.Id and not MatchingBat then
						MatchingBat = Child
						Child:SetAttribute("InitialToolOrder", 0)
					else
						Child:Destroy()
					end
				end
			end
		end
	end
	if MatchingBat then
		MatchingBat:SetAttribute("SwingCooldownMultiplier", CooldownMultiplier)
		return
	end
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	local Template = ReplicatedStorage.Assets.Tools:FindFirstChild(Info.TemplateName)
	if not Backpack or not Template or not Template:IsA("Tool") then return end
	local Tool = Template:Clone()
	Tool.Name = Info.DisplayName
	Tool.CanBeDropped = false
	Tool:SetAttribute("BatId", Info.Id)
	Tool:SetAttribute("SwingCooldownMultiplier", CooldownMultiplier)
	Tool:SetAttribute("InitialToolOrder", 0)
	Tool:AddTag("satchelSlot")
	Tool.Parent = Backpack
end

local function IsCFrameInRange(OriginCFrame, TargetPosition, Info): boolean
	local Offset = TargetPosition - OriginCFrame.Position
	local Distance = Offset.Magnitude
	if Distance > Info.Range + Info.ValidationDistanceBuffer then return false end
	if Distance <= 0.01 then return true end
	return OriginCFrame.LookVector:Dot(Offset.Unit) >= Info.MinimumFacingDot
end

local function IsTargetInRange(Player, RootPart, TargetPosition, Info, Now): boolean
	if IsCFrameInRange(RootPart.CFrame, TargetPosition, Info) then return true end
	for _, Snapshot in PositionHistory[Player] or {} do
		if Now - Snapshot.Time <= Info.ValidationHistoryWindow and IsCFrameInRange(Snapshot.CFrame, TargetPosition, Info) then
			return true
		end
	end
	return false
end

local function RecordPositions(Now)
	for _, Player in Players:GetPlayers() do
		if Now - (LastPositionSamples[Player] or 0) < MinimumValidationSampleInterval then continue end
		LastPositionSamples[Player] = Now
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not RootPart or not RootPart:IsA("BasePart") then
			PositionHistory[Player] = nil
			continue
		end
		local History = PositionHistory[Player] or {}
		PositionHistory[Player] = History
		table.insert(History, { Time = Now, CFrame = RootPart.CFrame })
		while History[1] and Now - History[1].Time > MaximumValidationHistoryWindow do
			table.remove(History, 1)
		end
	end
end

function BatController:Swing(Player, Targets)
	if type(Targets) ~= "table" or #Targets > 16 or Player:GetAttribute("IsFixing") == true then return end
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local Tool = Character and Character:FindFirstChildOfClass("Tool")
	local BatId = Tool and Tool:GetAttribute("BatId")
	local Info = if type(BatId) == "string" then GetBatInfo(BatId) else nil
	local Ownership = DataService:get(Player, "Upgrades")
	local OwnedBatId = UpgradeLogic.GetBatId(Ownership)
	local CooldownMultiplier = UpgradeLogic.GetBatCooldownMultiplier(Ownership)
	if not RootPart or not RootPart:IsA("BasePart") or not Info or BatId ~= OwnedBatId then return end
	local Now = os.clock()
	local MinimumServerCooldown = math.max(
		0,
		Info.SwingCooldown * CooldownMultiplier * Info.ServerCooldownFactor - Info.ServerCooldownLeeway
	)
	if Now - (LastSwings[Player] or 0) < MinimumServerCooldown then return end
	LastSwings[Player] = Now
	local HitTargets = {}
	for _, Target in Targets do
		if typeof(Target) ~= "Instance" or HitTargets[Target] then continue end
		HitTargets[Target] = true
		if Target:IsA("Model") and Target:HasTag("Crate") then
			if IsTargetInRange(Player, RootPart, Target:GetPivot().Position, Info, Now) then
				local Damaged = CrateController.DamageCrate(Player, Target, Info.CrateDamage)
				if Damaged and Target.Parent then
					Network:fireAllExcept(Player, "ReactToCrate", Target, RootPart.Position, Info.Id)
				end
			end
			continue
		end
	end
end

function BatController:Init()
	Network = Networker.server.new("BatController", self, { BatController.Swing })
	RunService.Heartbeat:Connect(function()
		RecordPositions(os.clock())
	end)
end

function BatController.SetDataService(Service)
	DataService = Service
end

function BatController.OnPlayerAdded(Player)
	PlayerConnections[Player] = Player:GetAttributeChangedSignal("IsFixing"):Connect(function()
		if Player:GetAttribute("IsFixing") == true then RemoveBats(Player) else task.defer(EnsureBat, Player) end
	end)
	UpgradeConnections[Player] = DataService:getChangedSignal(Player, "Upgrades"):Connect(function()
		task.defer(EnsureBat, Player)
	end)
	task.defer(EnsureBat, Player)
end

function BatController.OnCharacterAdded(Player)
	task.defer(EnsureBat, Player)
end

function BatController.OnPlayerRemoving(Player)
	local Connection = PlayerConnections[Player]
	if Connection then Connection:Disconnect(); PlayerConnections[Player] = nil end
	local UpgradeConnection = UpgradeConnections[Player]
	if UpgradeConnection then UpgradeConnection:Disconnect(); UpgradeConnections[Player] = nil end
	LastSwings[Player] = nil
	PositionHistory[Player] = nil
	LastPositionSamples[Player] = nil
end

return BatController
