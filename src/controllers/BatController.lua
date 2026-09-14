local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local LocalPlayer = Players.LocalPlayer
local BatController = {}
local HookedTools: { [Tool]: boolean } = {}
local Network
local RandomGenerator = Random.new()

local function GetBatInfo(BatId)
	for _, Info in BatInfo do
		if Info.Id == BatId then return Info end
	end
end

local function GetTargetModel(Part): Model?
	local Current = Part
	while Current and Current ~= Workspace do
		if Current:IsA("Model") and (CollectionService:HasTag(Current, "Crate") or Current:FindFirstChildOfClass("Humanoid")) then
			return Current
		end
		Current = Current.Parent
	end
	return nil
end

local function ShowPredictedImpact(Model, Handle, Info)
	local Highlight = Instance.new("Highlight")
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.FillTransparency = 0.35
	Highlight.OutlineTransparency = 1
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Parent = Model
	TweenService:Create(Highlight, TweenInfo.new(0.16), { FillTransparency = 1 }):Play()
	Debris:AddItem(Highlight, 0.18)
	local SoundNames = if CollectionService:HasTag(Model, "Crate") then Info.ImpactSoundNames else Info.PlayerHitSoundNames
	local SoundName = SoundNames[RandomGenerator:NextInteger(1, #SoundNames)]
	Sounds.Play(SoundName, Handle, 70)
end

local function DetectTargets(Tool, Info)
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local Handle = Tool:FindFirstChild("Handle")
	if not Character or not RootPart or not RootPart:IsA("BasePart") or not Handle or not Handle:IsA("BasePart") then return end
	local Parameters = OverlapParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = { Character }
	local HitboxCFrame = RootPart.CFrame * CFrame.new(0, 0, -Info.Range / 2)
	local HitboxSize = Vector3.new(Info.HitboxWidth, Info.HitboxHeight, Info.Range)
	local Targets = {}
	local Seen = {}
	for _, Part in Workspace:GetPartBoundsInBox(HitboxCFrame, HitboxSize, Parameters) do
		local Model = GetTargetModel(Part)
		if Model and not Seen[Model] then
			Seen[Model] = true
			table.insert(Targets, Model)
			ShowPredictedImpact(Model, Handle, Info)
		end
	end
	Network:fire("Swing", Targets)
end

local function Swing(Tool, Info)
	if Tool.Enabled == false or Tool.Parent ~= LocalPlayer.Character then return end
	Tool.Enabled = false
	local Handle = Tool:FindFirstChild("Handle")
	if not Handle or not Handle:IsA("BasePart") then Tool.Enabled = true; return end
	local OriginalGrip = Tool.Grip
	local Trail = Handle:FindFirstChildOfClass("Trail")
	if Trail then Trail.Enabled = true end
	Sounds.Play(Info.SwingSoundName, Handle, 70)
	TweenService:Create(
		Tool,
		TweenInfo.new(Info.ImpactDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Grip = OriginalGrip * CFrame.Angles(0, math.rad(18), math.rad(72)) }
	):Play()
	task.delay(Info.ImpactDelay, function()
		if Tool.Parent == LocalPlayer.Character then DetectTargets(Tool, Info) end
		TweenService:Create(
			Tool,
			TweenInfo.new(math.max(Info.SwingCooldown - Info.ImpactDelay, 0.05), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Grip = OriginalGrip }
		):Play()
	end)
	task.delay(Info.SwingCooldown, function()
		if Trail and Trail.Parent then Trail.Enabled = false end
		if Tool.Parent then Tool.Enabled = true end
	end)
end

local function HookTool(Tool)
	if not Tool:IsA("Tool") or HookedTools[Tool] then return end
	local BatId = Tool:GetAttribute("BatId")
	local Info = if type(BatId) == "string" then GetBatInfo(BatId) else nil
	if not Info then return end
	HookedTools[Tool] = true
	Tool.Equipped:Connect(function()
		local Handle = Tool:FindFirstChild("Handle")
		if Handle then Sounds.Play(Info.EquipSoundName, Handle, 55) end
	end)
	Tool.Activated:Connect(function() Swing(Tool, Info) end)
	Tool.Destroying:Once(function() HookedTools[Tool] = nil end)
end

local function HookContainer(Container)
	for _, Child in Container:GetChildren() do HookTool(Child) end
	Container.ChildAdded:Connect(HookTool)
end

function BatController:Init()
	Network = Networker.client.new("BatController", self)
	task.spawn(function()
		HookContainer(LocalPlayer:WaitForChild("Backpack"))
	end)
end

function BatController.OnCharacterAdded(Character)
	HookContainer(Character)
end

return BatController
