local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CarryController = require(ServerStorage.Controllers.CarryController)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)

local CONFIG = {
	SprayRadius = 0.8,
	SprayDamagePerSecond = 4,
	RotationSpeed = math.rad(12),
	RotationResponsiveness = 5,
}
local FixingController = {}
local DataService
local Sessions = {}

local function GetInfo(ItemId)
	for _, Info in ItemsInfo do if Info.Id == ItemId then return Info end end
end
local function SaveState(Player, ItemId, State)
	local Fixing = DataService:get(Player, "Fixing") or {}
	Fixing[tostring(ItemId)] = State
	DataService:set(Player, "Fixing", Fixing)
end
local function ClearSession(Player)
	local Session = Sessions[Player]
	if not Session then return end
	SaveState(Player, Session.ItemId, Session.State)
	if Session.Connection then Session.Connection:Disconnect() end
	if Session.Model then Session.Model:Destroy() end
	if Session.RootPart and Session.RootPart.Parent then
		Session.RootPart.Anchored = Session.RootWasAnchored
	end
	if Session.Prompt and Session.Prompt.Parent then Session.Prompt.Enabled = true end
	Sessions[Player] = nil
	Player:SetAttribute("IsFixing", false)
	CarryController.SetFixingMode(Player, false)
end
local function StartFixing(Player, RequestedItemId)
	if Sessions[Player] then return end
	local EquippedItemId = CarryController.GetEquippedItemId(Player)
	local ItemId = if type(RequestedItemId) == "number" then RequestedItemId else EquippedItemId
	local Info = ItemId and GetInfo(ItemId)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local PromptPart = TableModel and TableModel:FindFirstChild("PromptPart")
	local Prompt = PromptPart and PromptPart:FindFirstChild("FixItemPrompt")
	if not ItemId or not Info or not PromptPart or not PromptPart:IsA("BasePart") then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Inventory = DataService:get(Player, "Inventory")
	if not RootPart or not RootPart:IsA("BasePart") or (RootPart.Position - PromptPart.Position).Magnitude > 13 or type(Inventory) ~= "table" or table.find(Inventory, ItemId) == nil then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(Info.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Fixing = DataService:get(Player, "Fixing") or {}
	local DirtCount = DirtRenderer.GetSuggestedCount(Template)
	local State = Fixing[tostring(ItemId)] or { Total = DirtCount, Remaining = DirtCount, Completed = false }
	if State.Completed == true then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	for _, Part in Model:GetDescendants() do if Part:IsA("BasePart") then Part.Anchored = true; Part.CanCollide = false end end
	Model:PivotTo(PromptPart.CFrame * CFrame.new(0, Box.Size.Y / 2 + 0.25, 0))
	Model.Parent = Museum
	local Dirt = if State.Completed then nil else DirtRenderer.Add(Model, State.Remaining, Info.DirtHP)
	local RootWasAnchored = RootPart.Anchored
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.Anchored = true
	Player:SetAttribute("IsFixing", true)
	CarryController.SetFixingMode(Player, true)
	local Session = {
		ItemId = ItemId,
		State = State,
		Model = Model,
		Dirt = Dirt,
		LastSpray = os.clock(),
		RootPart = RootPart,
		RootWasAnchored = RootWasAnchored,
		Prompt = if Prompt and Prompt:IsA("ProximityPrompt") then Prompt else nil,
		IsSpraying = false,
		CurrentRotationSpeed = CONFIG.RotationSpeed,
	}
	Session.Connection = RunService.Heartbeat:Connect(function(DeltaTime)
		if not Model.Parent then return end
		local TargetRotationSpeed = if Session.IsSpraying then 0 else CONFIG.RotationSpeed
		local Blend = 1 - math.exp(-CONFIG.RotationResponsiveness * DeltaTime)
		Session.CurrentRotationSpeed += (TargetRotationSpeed - Session.CurrentRotationSpeed) * Blend
		if math.abs(TargetRotationSpeed - Session.CurrentRotationSpeed) < math.rad(0.05) then
			Session.CurrentRotationSpeed = TargetRotationSpeed
		end
		Model:PivotTo(Model:GetPivot() * CFrame.Angles(0, Session.CurrentRotationSpeed * DeltaTime, 0))
	end)
	Sessions[Player] = Session
	if Session.Prompt then Session.Prompt.Enabled = false end
	SaveState(Player, ItemId, State)
end

function FixingController:Spray(Player, AimPosition)
	local Session = Sessions[Player]
	local Tool = Player.Character and Player.Character:FindFirstChild("SprayBottle")
	if not Session or not Session.IsSpraying or not Tool or typeof(AimPosition) ~= "Vector3" or not Session.Dirt then return end
	if (AimPosition - Session.Model:GetPivot().Position).Magnitude > 8 then return end
	local Now = os.clock()
	local Damage = CONFIG.SprayDamagePerSecond * math.clamp(Now - Session.LastSpray, 0, 0.2)
	Session.LastSpray = Now
	local ProgressChanged = false
	for _, Dirt in Session.Dirt:GetChildren() do
		if Dirt:IsA("BasePart") and (Dirt.Position - AimPosition).Magnitude <= CONFIG.SprayRadius then
			local HP = (Dirt:GetAttribute("HP") or 0) - Damage
			Dirt:SetAttribute("HP", HP)
			if HP <= 0 then Dirt:Destroy(); Session.State.Remaining -= 1; ProgressChanged = true end
		end
	end
	if Session.State.Remaining <= 0 then
		Session.State.Remaining = 0; Session.State.Completed = true; Session.Dirt:Destroy(); Session.Dirt = nil; ProgressChanged = true
	end
	if ProgressChanged then SaveState(Player, Session.ItemId, Session.State) end
end
function FixingController:StartSpraying(Player)
	local Session = Sessions[Player]
	local Tool = Player.Character and Player.Character:FindFirstChild("SprayBottle")
	if not Session or not Tool then return end
	Session.IsSpraying = true
	Session.LastSpray = os.clock()
end
function FixingController:StopSpraying(Player)
	local Session = Sessions[Player]
	if Session then Session.IsSpraying = false end
end
function FixingController:Exit(Player) ClearSession(Player) end
function FixingController:Start(Player, ItemId) StartFixing(Player, ItemId) end
function FixingController.SetDataService(Service) DataService = Service end
function FixingController:Init()
	self.Networker = Networker.server.new("FixingController", self, {
		FixingController.Start,
		FixingController.StartSpraying,
		FixingController.Spray,
		FixingController.StopSpraying,
		FixingController.Exit,
	})
end
function FixingController.OnPlayerAdded(Player)
	Player:SetAttribute("IsFixing", false)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local Part = TableModel and TableModel:FindFirstChild("PromptPart")
	if Part and Part:IsA("BasePart") then
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "FixItemPrompt"; Prompt.ActionText = "Fix Item"; Prompt.ObjectText = "Fixing Table"
		Prompt.HoldDuration = 0; Prompt.MaxActivationDistance = 10; Prompt.RequiresLineOfSight = false
		Prompt.Enabled = true; Prompt.UIOffset = Vector2.new(0, -55); Prompt.Parent = Part
	end
end
function FixingController.OnPlayerRemoving(Player) ClearSession(Player) end
return FixingController
