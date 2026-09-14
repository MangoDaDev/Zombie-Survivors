local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local LocalPlayer = Players.LocalPlayer
local BatController = {}
local HookedTools: { [Tool]: boolean } = {}
local CratePredictions = {}
local CrateReactions = {}
local Network
local RandomGenerator = Random.new()

local function GetBatInfo(BatId)
	for _, Info in BatInfo do
		if Info.Id == BatId then return Info end
	end
end

local function GetCrateInfo(CrateId)
	for _, Info in CrateInfo.Crates do
		if Info.Id == CrateId then return Info end
	end
end

local function GetHealthInterface(Model)
	local PrimaryPart = Model.PrimaryPart
	local Billboard = PrimaryPart and PrimaryPart:FindFirstChild("CrateHealth")
	local Group = Billboard and Billboard:FindFirstChild("Group")
	local Track = Group and Group:FindFirstChild("Track")
	local Fill = Track and Track:FindFirstChild("Fill")
	local HealthLabel = Track and Track:FindFirstChild("Health")
	if Group and Group:IsA("CanvasGroup") and Fill and Fill:IsA("Frame") and HealthLabel and HealthLabel:IsA("TextLabel") then
		return Group, Fill, HealthLabel
	end
	return nil, nil, nil
end

local function RenderPredictedHealth(Model, State)
	if not Model.Parent then return end
	local PendingDamage = 0
	for _, Prediction in State.Pending do PendingDamage += Prediction.Damage end
	local PredictedHealth = math.max(0, State.ConfirmedHealth - PendingDamage)
	if State.ConfirmedHealth > 0 and PredictedHealth <= 0 then PredictedHealth = 1 end
	local MaximumHealth = Model:GetAttribute("MaxHealth") or State.ConfirmedHealth
	local Group, Fill, HealthLabel = GetHealthInterface(Model)
	if not Group then return end
	State.VisibilityId += 1
	local VisibilityId = State.VisibilityId
	TweenService:Create(Group, TweenInfo.new(0.04), { GroupTransparency = 0 }):Play()
	TweenService:Create(Fill, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(PredictedHealth / math.max(MaximumHealth, 1), 1),
	}):Play()
	HealthLabel.Text = `{math.ceil(PredictedHealth)}/{MaximumHealth}`
	local Info = GetCrateInfo(Model:GetAttribute("CrateId"))
	task.delay(if Info then Info.HealthBarHideDelay else 1.6, function()
		if Model.Parent and CratePredictions[Model] == State and State.VisibilityId == VisibilityId then
			TweenService:Create(Group, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		end
	end)
end

local function HoldPredictedHealth(Model, State)
	if not Model.Parent then return end
	local PendingDamage = 0
	for _, Prediction in State.Pending do PendingDamage += Prediction.Damage end
	local PredictedHealth = math.max(0, State.ConfirmedHealth - PendingDamage)
	if State.ConfirmedHealth > 0 and PredictedHealth <= 0 then PredictedHealth = 1 end
	local MaximumHealth = Model:GetAttribute("MaxHealth") or State.ConfirmedHealth
	local Group, Fill, HealthLabel = GetHealthInterface(Model)
	if not Group then return end
	Group.GroupTransparency = 0
	Fill.Size = UDim2.fromScale(PredictedHealth / math.max(MaximumHealth, 1), 1)
	HealthLabel.Text = `{math.ceil(PredictedHealth)}/{MaximumHealth}`
end

local function ReactToCrate(Model, AttackerPosition, Info)
	if not Model.Parent then return end
	local State = CrateReactions[Model]
	if not State then
		State = { BaseCFrame = Model:GetPivot(), ReactionId = 0 }
		CrateReactions[Model] = State
		Model.Destroying:Once(function() CrateReactions[Model] = nil end)
	end
	State.ReactionId += 1
	local ReactionId = State.ReactionId
	local Direction = State.BaseCFrame.Position - AttackerPosition
	local LocalDirection = State.BaseCFrame:VectorToObjectSpace(if Direction.Magnitude > 0 then Direction.Unit else Vector3.zAxis)
	local Angle = math.rad(Info.ImpactReactionAngleDegrees)
	local Kick = CFrame.Angles(-LocalDirection.Z * Angle, 0, LocalDirection.X * Angle)
	task.spawn(function()
		for Index = 1, 6 do
			if not Model.Parent or CrateReactions[Model] ~= State or State.ReactionId ~= ReactionId then return end
			local Weight = math.sin(Index / 6 * math.pi)
			Model:PivotTo(State.BaseCFrame:Lerp(State.BaseCFrame * Kick, Weight))
			task.wait(Info.ImpactReactionDuration / 6)
		end
		if Model.Parent and CrateReactions[Model] == State and State.ReactionId == ReactionId then
			Model:PivotTo(State.BaseCFrame)
		end
	end)
end

local function ReconcileCrateHealth(Model, State)
	local NewHealth = Model:GetAttribute("Health")
	if type(NewHealth) ~= "number" then return end
	if NewHealth > State.ConfirmedHealth then
		return
	end
	local AppliedDamage = math.max(0, State.ConfirmedHealth - NewHealth)
	State.ConfirmedHealth = NewHealth
	while AppliedDamage > 0.001 and #State.Pending > 0 do
		local Prediction = State.Pending[1]
		local ConsumedDamage = math.min(Prediction.Damage, AppliedDamage)
		Prediction.Damage -= ConsumedDamage
		AppliedDamage -= ConsumedDamage
		if Prediction.Damage <= 0.001 then table.remove(State.Pending, 1) end
	end
	State.HoldUntil = os.clock() + 0.25
	RenderPredictedHealth(Model, State)
end

local function PredictCrateDamage(Model, Damage, Info)
	local Health = Model:GetAttribute("Health")
	if type(Health) ~= "number" or Health <= 0 then return end
	local State = CratePredictions[Model]
	if not State then
		State = {
			ConfirmedHealth = Health,
			Pending = {},
			VisibilityId = 0,
		}
		CratePredictions[Model] = State
		State.HealthConnection = Model:GetAttributeChangedSignal("Health"):Connect(function() ReconcileCrateHealth(Model, State) end)
		Model.Destroying:Once(function()
			if State.HealthConnection then State.HealthConnection:Disconnect() end
			CratePredictions[Model] = nil
		end)
	end
	local Prediction = { Damage = Damage }
	table.insert(State.Pending, Prediction)
	State.HoldUntil = os.clock() + Info.PredictionTimeout
	RenderPredictedHealth(Model, State)
	task.delay(Info.PredictionTimeout, function()
		if CratePredictions[Model] ~= State then return end
		local Index = table.find(State.Pending, Prediction)
		if Index then table.remove(State.Pending, Index); RenderPredictedHealth(Model, State) end
	end)
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
	if CollectionService:HasTag(Model, "Crate") then
		PredictCrateDamage(Model, Info.CrateDamage, Info)
		local Character = LocalPlayer.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if RootPart and RootPart:IsA("BasePart") then ReactToCrate(Model, RootPart.Position, Info) end
	end
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
		{
			Grip = OriginalGrip * CFrame.Angles(
				math.rad(Info.SwingRotationDegrees.X),
				math.rad(Info.SwingRotationDegrees.Y),
				math.rad(Info.SwingRotationDegrees.Z)
			),
		}
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
	RunService.RenderStepped:Connect(function()
		local Now = os.clock()
		for Model, State in CratePredictions do
			if #State.Pending > 0 or Now < (State.HoldUntil or 0) then HoldPredictedHealth(Model, State) end
		end
	end)
	task.spawn(function()
		HookContainer(LocalPlayer:WaitForChild("Backpack"))
	end)
end

function BatController:ReactToCrate(Model, AttackerPosition, BatId)
	local Info = if type(BatId) == "string" then GetBatInfo(BatId) else nil
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or not CollectionService:HasTag(Model, "Crate")
		or typeof(AttackerPosition) ~= "Vector3" or not Info
	then return end
	ReactToCrate(Model, AttackerPosition, Info)
end

function BatController.OnCharacterAdded(Character)
	HookContainer(Character)
end

return BatController
