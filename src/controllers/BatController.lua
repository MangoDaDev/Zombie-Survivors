local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local CollisionGroups = require(ReplicatedStorage.Modules.Game.CollisionGroups)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local CrateRuntime = require(ReplicatedStorage.Modules.Game.CrateRuntime)
local CrateController = require(ReplicatedStorage.Controllers.CrateController)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local LocalPlayer = Players.LocalPlayer
local BatController = {}
local HookedTools: { [Tool]: boolean } = {}
local CratePredictions = {}
local CrateReactions = {}
local DebrisFolder: Folder
local ActiveDebrisCount = 0
local Network
local RandomGenerator = Random.new()
local MAXIMUM_DEBRIS_COUNT = 80
local DebrisCollisionDuration = 0.55
local CreateCrateDebris
local ShakeCamera

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
	local RuntimeCrate = CrateRuntime.Get(Model)
	local MaximumHealth = RuntimeCrate and RuntimeCrate.MaximumHealth or State.ConfirmedHealth
	local Group, Fill, HealthLabel = GetHealthInterface(Model)
	if not Group then return end
	State.VisibilityId += 1
	local VisibilityId = State.VisibilityId
	TweenService:Create(Group, TweenInfo.new(0.04), { GroupTransparency = 0 }):Play()
	TweenService:Create(Fill, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(PredictedHealth / math.max(MaximumHealth, 1), 1),
	}):Play()
	HealthLabel.Text = `{math.ceil(PredictedHealth)}/{MaximumHealth}`
	local Info = GetCrateInfo(RuntimeCrate and RuntimeCrate.CrateId or Model.Name)
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
	local RuntimeCrate = CrateRuntime.Get(Model)
	local MaximumHealth = RuntimeCrate and RuntimeCrate.MaximumHealth or State.ConfirmedHealth
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

local function ReconcileCrateHealth(Model, State, NewHealth)
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

local function PredictCrateDamage(Model, Damage, PredictionId, InitialHealth)
	local RuntimeCrate = CrateRuntime.Get(Model)
	local Health = RuntimeCrate and RuntimeCrate.Health or InitialHealth
	if type(Health) ~= "number" or Health <= 0 then return false end
	local State = CratePredictions[Model]
	if not State then
		State = {
			ConfirmedHealth = Health,
			Pending = {},
			VisibilityId = 0,
		}
		CratePredictions[Model] = State
		State.HealthConnection = CrateRuntime.GetHealthChangedSignal(Model):Connect(function(NewHealth)
			ReconcileCrateHealth(Model, State, NewHealth)
		end)
		Model.Destroying:Once(function()
			if State.HealthConnection then State.HealthConnection:Disconnect() end
			CratePredictions[Model] = nil
			CrateRuntime.Clear(Model)
		end)
	end
	local Prediction = { Damage = Damage, Id = PredictionId }
	table.insert(State.Pending, Prediction)
	local PendingDamage = 0
	for _, PendingPrediction in State.Pending do PendingDamage += PendingPrediction.Damage end
	local PredictedHealth = math.max(0, State.ConfirmedHealth - PendingDamage)
	State.HoldUntil = math.huge
	RenderPredictedHealth(Model, State)
	return PredictedHealth <= 0
end

local function RejectCratePrediction(Model, PredictionId, Reason)
	if RunService:IsStudio() then warn(`Crate hit prediction rejected: {Reason or "Unknown"}`) end
	local State = CratePredictions[Model]
	if State then
		for Index, Prediction in State.Pending do
			if Prediction.Id ~= PredictionId then continue end
			table.remove(State.Pending, Index)
			State.HoldUntil = os.clock() + 0.25
			RenderPredictedHealth(Model, State)
			break
		end
		local PendingDamage = 0
		for _, Prediction in State.Pending do PendingDamage += Prediction.Damage end
		if State.ConfirmedHealth - PendingDamage > 0 then
			CrateController.CancelPredictedRevealsForCrate(Model)
			return
		end
	end
	CrateController.CancelPredictedReveal(PredictionId)
end

local function GetTargetModel(Part): Model?
	local Current = Part
	while Current and Current ~= Workspace do
		if Current:IsA("Model") and CollectionService:HasTag(Current, "Crate") then
			return Current
		end
		if Current:IsA("Model") then
			local TargetPlayer = Players:GetPlayerFromCharacter(Current)
			if TargetPlayer and TargetPlayer ~= LocalPlayer then return Current end
		end
		Current = Current.Parent
	end
	return nil
end

local function CanTargetCrate(Model: Model): boolean
	if DataService:get("TutorialStep") ~= "PickUpItem" then return true end
	return RuntimeState.Get(LocalPlayer, "GuidanceTarget") == Model
end

local function ShowPredictedImpact(Model, Handle, Info)
	local PredictionId
	if CollectionService:HasTag(Model, "Crate") then
		PredictionId = HttpService:GenerateGUID(false)
		local RuntimeCrate = CrateRuntime.Get(Model)
		local CrateInfoEntry = GetCrateInfo(RuntimeCrate and RuntimeCrate.CrateId or Model.Name)
		local IsPredictedFinalHit = PredictCrateDamage(
			Model,
			Info.CrateDamage,
			PredictionId,
			CrateInfoEntry and CrateInfoEntry.Health
		)
		local Character = LocalPlayer.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if RootPart and RootPart:IsA("BasePart") then ReactToCrate(Model, RootPart.Position, Info) end
		local Part = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
		if Part then
			if CrateInfoEntry then Sounds.Play(CrateInfoEntry.DamageSoundName, Part, 80) end
			local Center = Model:GetPivot().Position
			local Direction = RootPart and RootPart.Position - Center or Vector3.yAxis
			CreateCrateDebris(Center, if Direction.Magnitude > 0.01 then Direction.Unit else Vector3.yAxis, Part.Color, Part.Material, IsPredictedFinalHit)
		end
		if IsPredictedFinalHit and CrateInfoEntry then
			-- Keep lethal-hit break presentation client-side so latency never delays the crate disappearing.
			CrateController.BeginPredictedReveal(PredictionId, Model, CrateInfoEntry.Id)
			ShakeCamera(0.075, 0.14)
			local BreakSoundNames = CrateInfoEntry and CrateInfoEntry.BreakSoundNames
			if BreakSoundNames and #BreakSoundNames > 0 then
				local BreakSoundName = BreakSoundNames[RandomGenerator:NextInteger(1, #BreakSoundNames)]
				local BreakSound = Sounds.Play(BreakSoundName, Handle, 75)
				if BreakSound then BreakSound.Volume *= 0.65 end
			end
		end
	end
	local Highlight = Instance.new("Highlight")
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.FillTransparency = 0.35
	Highlight.OutlineTransparency = 1
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Parent = Model
	TweenService:Create(Highlight, TweenInfo.new(0.16), { FillTransparency = 1 }):Play()
	Debris:AddItem(Highlight, 0.18)
	local SoundName = Info.ImpactSoundNames[RandomGenerator:NextInteger(1, #Info.ImpactSoundNames)]
	Sounds.Play(SoundName, Handle, 70)
	return PredictionId
end

ShakeCamera = function(Strength: number, Duration: number)
	task.spawn(function()
		local StartedAt = os.clock()
		while os.clock() - StartedAt < Duration do
			RunService.RenderStepped:Wait()
			local Camera = Workspace.CurrentCamera
			local Alpha = 1 - (os.clock() - StartedAt) / Duration
			local Offset = Vector3.new(
				RandomGenerator:NextNumber(-1, 1),
				RandomGenerator:NextNumber(-1, 1),
				0
			) * Strength * Alpha
			Camera.CFrame *= CFrame.new(Offset)
		end
	end)
end

CreateCrateDebris = function(Position: Vector3, Normal: Vector3, Color: Color3, Material: Enum.Material, IsFinalHit: boolean)
	local FragmentCount = if IsFinalHit then 18 else 7
	for _ = 1, FragmentCount do
		if ActiveDebrisCount >= MAXIMUM_DEBRIS_COUNT then break end
		local Fragment = Instance.new("Part")
		Fragment.Name = "LocalCrateDebris"
		Fragment.Anchored = false
		-- Crate studs briefly bounce only on the ground before becoming non-collidable.
		Fragment.CanCollide = true
		Fragment.CanQuery = false
		Fragment.CanTouch = false
		Fragment.CastShadow = false
		Fragment.CollisionGroup = CollisionGroups.CrateDebris
		Fragment.Color = Color
		Fragment.Material = Material
		Fragment.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.35, 0.55, 1, 1)
		local MaximumSize = if IsFinalHit then 1.25 else 0.9
		Fragment.Size = Vector3.new(
			RandomGenerator:NextNumber(0.4, MaximumSize),
			RandomGenerator:NextNumber(0.35, MaximumSize),
			RandomGenerator:NextNumber(0.4, MaximumSize)
		)
		Fragment.CFrame = CFrame.new(Position)
		Fragment.Parent = DebrisFolder
		ActiveDebrisCount += 1
		Fragment.Destroying:Once(function() ActiveDebrisCount = math.max(0, ActiveDebrisCount - 1) end)
		local RandomDirection = Normal * RandomGenerator:NextNumber(0.45, 0.85)
			+ Vector3.new(
				RandomGenerator:NextNumber(-1.15, 1.15),
				RandomGenerator:NextNumber(1.05, 1.75),
				RandomGenerator:NextNumber(-1.15, 1.15)
			)
		local Speed = RandomGenerator:NextNumber(if IsFinalHit then 24 else 16, if IsFinalHit then 38 else 27)
		Fragment.AssemblyLinearVelocity = RandomDirection.Unit * Speed
		Fragment.AssemblyAngularVelocity = Vector3.new(
			RandomGenerator:NextNumber(-18, 18),
			RandomGenerator:NextNumber(-18, 18),
			RandomGenerator:NextNumber(-18, 18)
		)
		local Lifetime = RandomGenerator:NextNumber(0.9, if IsFinalHit then 1.45 else 1.15)
		task.delay(DebrisCollisionDuration, function()
			if Fragment.Parent then Fragment.CanCollide = false end
		end)
		task.delay(Lifetime * 0.55, function()
			if Fragment.Parent then
				TweenService:Create(Fragment, TweenInfo.new(Lifetime * 0.45), { Transparency = 1, Size = Fragment.Size * 0.35 }):Play()
			end
		end)
		Debris:AddItem(Fragment, Lifetime)
	end
end

local function DetectTargets(Tool, Info, SwingTime)
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local Handle = Tool:FindFirstChild("Handle")
	if not Character or not RootPart or not RootPart:IsA("BasePart") or not Handle or not Handle:IsA("BasePart") then return 0 end
	local Parameters = OverlapParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = { Character }
	local HitboxCFrame = RootPart.CFrame * CFrame.new(0, 0, -Info.Range / 2)
	local HitboxSize = Vector3.new(Info.HitboxWidth, Info.HitboxHeight, Info.Range)
	local Targets = {}
	local Seen = {}
	for _, Part in Workspace:GetPartBoundsInBox(HitboxCFrame, HitboxSize, Parameters) do
		local Model = GetTargetModel(Part)
		local IsCrate = Model and CollectionService:HasTag(Model, "Crate")
		if Model and not Seen[Model] and (not IsCrate or CanTargetCrate(Model)) then
			Seen[Model] = true
			local PredictionId = ShowPredictedImpact(Model, Handle, Info)
			table.insert(Targets, { Model = Model, PredictionId = PredictionId })
		end
	end
	-- An empty scan must not consume the authoritative swing cooldown.
	if #Targets > 0 then Network:fire("Swing", Targets, Info.Id, SwingTime) end
	return #Targets
end

local function Swing(Tool, Info)
	if Tool.Enabled == false or Tool.Parent ~= LocalPlayer.Character then return end
	Tool.Enabled = false
	local Handle = Tool:FindFirstChild("Handle")
	if not Handle or not Handle:IsA("BasePart") then Tool.Enabled = true; return end
	local OriginalGrip = Tool.Grip
	local Ownership = DataService:get("Upgrades")
	local CooldownMultiplier = UpgradeLogic.GetBatCooldownMultiplier(Ownership)
	local SwingCooldown = Info.SwingCooldown * CooldownMultiplier
	local Trail = Handle:FindFirstChildOfClass("Trail")
	if Trail then Trail.Enabled = true end
	Sounds.Play(Info.SwingSoundName, Handle, 70)
	-- Resolve local crate hits immediately; animation timing must never delay break prediction or roulette.
	local SwingTime = Workspace:GetServerTimeNow()
	local TargetCount = DetectTargets(Tool, Info, SwingTime)
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
		-- Retry once at the visual impact frame only when the immediate scan found nothing.
		if TargetCount == 0 and Tool.Parent == LocalPlayer.Character then DetectTargets(Tool, Info, SwingTime) end
		TweenService:Create(
			Tool,
			TweenInfo.new(math.max(SwingCooldown - Info.ImpactDelay, 0.05), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Grip = OriginalGrip }
		):Play()
	end)
	task.delay(SwingCooldown, function()
		if Trail and Trail.Parent then Trail.Enabled = false end
		if Tool.Parent then Tool.Enabled = true end
	end)
end

local function HookTool(Tool)
	if not Tool:IsA("Tool") or HookedTools[Tool] then return end
	local Info = ToolResolver.GetBatInfo(Tool)
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

function BatController.Init()
	DebrisFolder = Instance.new("Folder")
	DebrisFolder.Name = "LocalCrateDebris"
	DebrisFolder.Parent = Workspace
	Network = Networker.client.new("BatController", BatController)
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

function BatController.CrateHitConfirmed(_, Position, Normal, Color, Material, IsFinalHit, BatId, PredictionId)
	if typeof(Position) ~= "Vector3" or typeof(Normal) ~= "Vector3" or Normal.Magnitude < 0.01
		or typeof(Color) ~= "Color3" or typeof(Material) ~= "EnumItem" or type(IsFinalHit) ~= "boolean"
		or type(BatId) ~= "string" or not GetBatInfo(BatId)
		or (PredictionId ~= nil and type(PredictionId) ~= "string")
	then return end
	-- Hit and break feedback is predicted locally at swing time; the server only confirms authority.
	if not IsFinalHit and PredictionId then CrateController.CancelPredictedReveal(PredictionId) end
end

function BatController.CrateHitRejected(_, Model, PredictionId, Reason)
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or type(PredictionId) ~= "string"
		or (Reason ~= nil and type(Reason) ~= "string")
	then return end
	RejectCratePrediction(Model, PredictionId, Reason)
end

function BatController.ReactToCrate(_, Model, AttackerPosition, BatId)
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
