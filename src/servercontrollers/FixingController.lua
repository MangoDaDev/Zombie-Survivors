local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CarryController = require(ServerStorage.Controllers.CarryController)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)

local CONFIG = { DirtCount = 72, SprayRadius = 3, SprayDamagePerSecond = 4, CompleteAt = 0.8, RotationSpeed = math.rad(12) }
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
	if Session.Connection then Session.Connection:Disconnect() end
	if Session.Model then Session.Model:Destroy() end
	Sessions[Player] = nil
	Player:SetAttribute("IsFixing", false)
	CarryController.SetFixingMode(Player, false)
end
local function StartFixing(Player)
	if Sessions[Player] then return end
	local ItemId = CarryController.GetEquippedItemId(Player)
	local Info = ItemId and GetInfo(ItemId)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local PromptPart = TableModel and TableModel:FindFirstChild("PromptPart")
	if not ItemId or not Info or not PromptPart or not PromptPart:IsA("BasePart") then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Inventory = DataService:get(Player, "Inventory")
	if not RootPart or not RootPart:IsA("BasePart") or (RootPart.Position - PromptPart.Position).Magnitude > 13 or type(Inventory) ~= "table" or table.find(Inventory, ItemId) == nil then return end
	local Fixing = DataService:get(Player, "Fixing") or {}
	local State = Fixing[tostring(ItemId)] or { Total = CONFIG.DirtCount, Remaining = CONFIG.DirtCount, Completed = false }
	if State.Completed == true then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(Info.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	for _, Part in Model:GetDescendants() do if Part:IsA("BasePart") then Part.Anchored = true; Part.CanCollide = false end end
	Model:PivotTo(PromptPart.CFrame * CFrame.new(0, Box.Size.Y / 2 + 0.25, 0))
	Model.Parent = Museum
	local Dirt = if State.Completed then nil else DirtRenderer.Add(Model, State.Remaining, Info.DirtHP)
	Player:SetAttribute("IsFixing", true)
	CarryController.SetFixingMode(Player, true)
	local Session = { ItemId = ItemId, State = State, Model = Model, Dirt = Dirt, LastSpray = os.clock() }
	Session.Connection = RunService.Heartbeat:Connect(function(DeltaTime) if Model.Parent then Model:PivotTo(Model:GetPivot() * CFrame.Angles(0, CONFIG.RotationSpeed * DeltaTime, 0)) end end)
	Sessions[Player] = Session
	SaveState(Player, ItemId, State)
end

function FixingController:Spray(Player, AimPosition)
	local Session = Sessions[Player]
	local Tool = Player.Character and Player.Character:FindFirstChild("SprayBottle")
	if not Session or not Tool or typeof(AimPosition) ~= "Vector3" or not Session.Dirt then return end
	if (AimPosition - Session.Model:GetPivot().Position).Magnitude > 8 then return end
	local Now = os.clock()
	local Damage = CONFIG.SprayDamagePerSecond * math.clamp(Now - Session.LastSpray, 0, 0.2)
	Session.LastSpray = Now
	for _, Dirt in Session.Dirt:GetChildren() do
		if Dirt:IsA("BasePart") and (Dirt.Position - AimPosition).Magnitude <= CONFIG.SprayRadius then
			local HP = (Dirt:GetAttribute("HP") or 0) - Damage
			Dirt:SetAttribute("HP", HP)
			if HP <= 0 then Dirt:Destroy(); Session.State.Remaining -= 1 end
		end
	end
	if Session.State.Remaining / Session.State.Total <= 1 - CONFIG.CompleteAt then
		Session.State.Remaining = 0; Session.State.Completed = true; Session.Dirt:Destroy(); Session.Dirt = nil
	end
	SaveState(Player, Session.ItemId, Session.State)
end
function FixingController:Exit(Player) ClearSession(Player) end
function FixingController:Start(Player) StartFixing(Player) end
function FixingController.SetDataService(Service) DataService = Service end
function FixingController:Init() self.Networker = Networker.server.new("FixingController", self, { FixingController.Start, FixingController.Spray, FixingController.Exit }) end
function FixingController.OnPlayerAdded(Player)
	Player:SetAttribute("IsFixing", false)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local Part = TableModel and TableModel:FindFirstChild("PromptPart")
	if Part and Part:IsA("BasePart") then
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "FixItemPrompt"; Prompt.ActionText = "Fix Item"; Prompt.ObjectText = "Fixing Table"
		Prompt.HoldDuration = 0; Prompt.MaxActivationDistance = 10; Prompt.RequiresLineOfSight = false
		Prompt.Enabled = false; Prompt.UIOffset = Vector2.new(0, -55); Prompt.Parent = Part
	end
end
function FixingController.OnPlayerRemoving(Player) ClearSession(Player) end
return FixingController
