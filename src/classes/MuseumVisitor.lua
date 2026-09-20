local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local CollisionGroups = require(ReplicatedStorage.Modules.Game.CollisionGroups)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local FADE_DURATION = 0.8
local CASH_EFFECT_DURATION = 1.2
local COMIC_FONT = UIStyle.Font
local TURN_RESPONSIVENESS = 16
local WALK_CYCLE_SPEED = 10
local WALK_SWING_ANGLE = math.rad(28)
local WALK_BLEND_RESPONSIVENESS = 12
local PRIORITY_REFRESH_INTERVAL = 0.2
local VISIBILITY_REFRESH_INTERVAL = 0.15
local BACKGROUND_UPDATE_INTERVAL = 0.1
local DISTANT_UPDATE_INTERVAL = 0.35
local MAX_BACKGROUND_VISITORS = 12
local MAX_BLEND_DELTA_TIME = 0.1
local BACKGROUND_RENDER_DISTANCE = 500
local BACKGROUND_SCREEN_MARGIN = 160
local BACKGROUND_RELEASE_DELAY = 1.5
local MAX_POOLED_MODELS = 32

local LocalPlayer = Players.LocalPlayer
local TrackedVisitors = {}
local BackgroundVisitors = {}
local RenderPool = {}
local MuseumAreas = {}
local MuseumConnections = {}
local RenderConnection: RBXScriptConnection?
local RenderFolder: Folder?
local RenderTemplate: Model?
local TemplateFeetOffset = Vector3.zero
local PriorityOwnerUserId = LocalPlayer.UserId
local LastPriorityRefresh = 0
local ViewedOwnerChangedHandler

local MuseumVisitor = {}
MuseumVisitor.__index = MuseumVisitor

local function GetCurrentMovementCFrame(Visitor, Now: number): CFrame
	if Visitor.MoveTarget == nil then return Visitor.CurrentVisualCFrame end
	local MoveAlpha = math.clamp((Now - Visitor.MoveStartedAt) / Visitor.MoveDuration, 0, 1)
	local Position = Visitor.MoveStart.Position:Lerp(Visitor.MoveTarget.Position, MoveAlpha)
	local Rotation = if MoveAlpha < 1 then Visitor.MoveRotation else Visitor.MoveTarget.Rotation
	return CFrame.new(Position) * Rotation
end

local function GetFeetOffset(Model: Model): Vector3
	local RootPart = Model:FindFirstChild("HumanoidRootPart")
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local ReferenceY = if RootPart and RootPart:IsA("BasePart") then RootPart.Position.Y else Model:GetPivot().Position.Y
	return Vector3.new(0, ReferenceY - (BoundingCFrame.Position.Y - BoundingSize.Y / 2), 0)
end

local function EnsureMotor(Model: Model, Name: string, Part0Name: string, Part1Name: string, C0: CFrame, C1: CFrame)
	local ExistingMotor = Model:FindFirstChild(Name, true)
	if ExistingMotor and ExistingMotor:IsA("Motor6D") then return ExistingMotor end
	local Part0 = Model:FindFirstChild(Part0Name)
	local Part1 = Model:FindFirstChild(Part1Name)
	if not Part0 or not Part0:IsA("BasePart") or not Part1 or not Part1:IsA("BasePart") then return nil end
	local Motor = Instance.new("Motor6D")
	Motor.Name = Name
	Motor.Part0 = Part0
	Motor.Part1 = Part1
	Motor.C0 = C0
	Motor.C1 = C1
	Motor.Parent = Part0
	return Motor
end

local function EnsureR6Joints(Model: Model)
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.RigType ~= Enum.HumanoidRigType.R6 then return end
	local RootRotation = CFrame.Angles(-math.pi / 2, 0, math.pi)
	local LeftRotation = CFrame.Angles(0, -math.pi / 2, 0)
	local RightRotation = CFrame.Angles(0, math.pi / 2, 0)
	EnsureMotor(Model, "RootJoint", "HumanoidRootPart", "Torso", RootRotation, RootRotation)
	EnsureMotor(Model, "Neck", "Torso", "Head", CFrame.new(0, 1, 0) * RootRotation, CFrame.new(0, -0.5, 0) * RootRotation)
	EnsureMotor(Model, "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0) * LeftRotation, CFrame.new(0.5, 0.5, 0) * LeftRotation)
	EnsureMotor(Model, "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0) * RightRotation, CFrame.new(-0.5, 0.5, 0) * RightRotation)
	EnsureMotor(Model, "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0) * LeftRotation, CFrame.new(-0.5, 1, 0) * LeftRotation)
	EnsureMotor(Model, "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0) * RightRotation, CFrame.new(0.5, 1, 0) * RightRotation)
end

local function GetWalkJoints(Model: Model)
	local Joints = {}
	for _, JointInfo in {
		{ Names = { "Left Hip", "LeftHip" }, Direction = -1 },
		{ Names = { "Right Hip", "RightHip" }, Direction = -1 },
		{ Names = { "Left Shoulder", "LeftShoulder" }, Direction = 1 },
		{ Names = { "Right Shoulder", "RightShoulder" }, Direction = 1 },
	} do
		for _, JointName in JointInfo.Names do
			local Joint = Model:FindFirstChild(JointName, true)
			if Joint and Joint:IsA("Motor6D") then
				table.insert(Joints, { Joint = Joint, Direction = JointInfo.Direction })
				break
			end
		end
	end
	return Joints
end

local function PrepareModel(Model: Instance)
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.CollisionGroup = CollisionGroups.NPCCharacters
			Descendant.CanCollide = Descendant.Name ~= "HumanoidRootPart"
				and Descendant:FindFirstAncestorOfClass("Accessory") == nil
			Descendant.CanQuery = false
			Descendant.CanTouch = false
			Descendant.Massless = true
		end
	end
	local RootPart = Model:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then RootPart.Anchored = true end
end

local function ResetRagdoll(Visitor)
	local Model = Visitor.Model
	if not Model then return end
	for _, JointInfo in Visitor.RagdollJoints or {} do
		if JointInfo.Motor.Parent then
			JointInfo.Motor.Enabled = true
			JointInfo.Motor.Transform = CFrame.identity
		end
		JointInfo.Constraint:Destroy()
		JointInfo.NoCollisionConstraint:Destroy()
		JointInfo.Attachment0:Destroy()
		JointInfo.Attachment1:Destroy()
	end
	Visitor.RagdollJoints = nil
	Visitor.IsRagdolled = false
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid.PlatformStand = false end
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.AssemblyLinearVelocity = Vector3.zero
			Descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	PrepareModel(Model)
end

local function GetRenderTemplate(): Model?
	if RenderTemplate then return RenderTemplate end
	local Source = ReplicatedStorage.Assets.Models.NPCS:FindFirstChild("NPC")
	if not Source or not Source:IsA("Model") then
		warn("MuseumVisitor could not find the NPC template")
		return nil
	end
	local Template = Source:Clone()
	EnsureR6Joints(Template)
	local Humanoid = Template:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		-- Guest overhead names must stay hidden; dialogue is shown through chat bubbles instead.
		Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		Humanoid.NameDisplayDistance = 0
		Humanoid.HealthDisplayDistance = 0
	end
	local RootPart = Template:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then Template.PrimaryPart = RootPart end
	local Descendants = Template:GetDescendants()
	for Index = #Descendants, 1, -1 do
		local Descendant = Descendants[Index]
		-- Preserve the authored R6 body attachments so every accessory can use its exact matching frame.
		if Descendant:IsA("Sound") or Descendant:IsA("Animator") or Descendant:IsA("ValueBase") then
			Descendant:Destroy()
		end
	end
	PrepareModel(Template)
	TemplateFeetOffset = GetFeetOffset(Template)
	Template.Name = "MuseumVisitorRenderTemplate"
	RenderTemplate = Template
	return Template
end

local function GetRenderFolder(): Folder
	if RenderFolder and RenderFolder.Parent then return RenderFolder end
	local Folder = Instance.new("Folder")
	Folder.Name = "RenderedMuseumVisitors"
	Folder.Parent = Workspace
	RenderFolder = Folder
	return Folder
end

local function RemoveAppearance(Model: Model)
	for _, Child in Model:GetChildren() do
		if Child:IsA("Shirt") or Child:IsA("Pants") or Child:IsA("Accessory") then Child:Destroy() end
	end
end

local function AttachAccessory(Model: Model, AccessoryTemplate: Accessory)
	local Accessory = AccessoryTemplate:Clone()
	local Handle = Accessory:FindFirstChild("Handle")
	if not Handle or not Handle:IsA("BasePart") then
		Accessory:Destroy()
		return
	end
	local AccessoryAttachment
	local CharacterAttachment
	for _, Child in Handle:GetChildren() do
		if Child:IsA("Attachment") then
			AccessoryAttachment = AccessoryAttachment or Child
			local MatchingAttachment = Model:FindFirstChild(Child.Name, true)
			if MatchingAttachment and MatchingAttachment:IsA("Attachment") then
				AccessoryAttachment = Child
				CharacterAttachment = MatchingAttachment
				break
			end
		end
	end
	local CharacterPart = CharacterAttachment and CharacterAttachment.Parent
	local AccessoryCFrame = AccessoryAttachment and AccessoryAttachment.CFrame
	local CharacterCFrame = CharacterAttachment and CharacterAttachment.CFrame
	if not CharacterPart or not CharacterPart:IsA("BasePart") or not AccessoryCFrame or not CharacterCFrame then
		local Head = Model:FindFirstChild("Head")
		if not Head or not Head:IsA("BasePart") then Accessory:Destroy(); return end
		CharacterPart = Head
		AccessoryCFrame = Accessory.AttachmentPoint
		CharacterCFrame = CFrame.new(0, Head.Size.Y / 2, 0)
	end
	Accessory.Parent = Model
	Handle.CFrame = CharacterPart.CFrame * CharacterCFrame * AccessoryCFrame:Inverse()
	local Weld = Instance.new("Weld")
	Weld.Name = "AccessoryWeld"
	Weld.Part0 = Handle
	Weld.Part1 = CharacterPart
	Weld.C0 = AccessoryCFrame
	Weld.C1 = CharacterCFrame
	Weld.Parent = Handle
	for _, Descendant in Accessory:GetDescendants() do
		if Descendant:IsA("TouchTransmitter") or Descendant:IsA("Configuration") or Descendant:IsA("ValueBase") then
			Descendant:Destroy()
		end
	end
	PrepareModel(Accessory)
end

local function ApplyAppearance(Model: Model, Visitor)
	RemoveAppearance(Model)
	local ShirtTemplate = Visitor.ShirtTemplate
	local PantsTemplate = Visitor.PantsTemplate
	local HairTemplate = Visitor.HairTemplate
	if ShirtTemplate and ShirtTemplate:IsA("Shirt") then ShirtTemplate:Clone().Parent = Model end
	if PantsTemplate and PantsTemplate:IsA("Pants") then PantsTemplate:Clone().Parent = Model end
	if HairTemplate and HairTemplate:IsA("Accessory") then AttachAccessory(Model, HairTemplate) end
	if typeof(Visitor.SkinColor) == "Color3" then
		local BodyColors = Model:FindFirstChildOfClass("BodyColors")
		if BodyColors then
			BodyColors.HeadColor3 = Visitor.SkinColor
			BodyColors.LeftArmColor3 = Visitor.SkinColor
			BodyColors.LeftLegColor3 = Visitor.SkinColor
			BodyColors.RightArmColor3 = Visitor.SkinColor
			BodyColors.RightLegColor3 = Visitor.SkinColor
			BodyColors.TorsoColor3 = Visitor.SkinColor
		end
	end
end

local function GetFadeInstances(Model: Model)
	local Instances = {}
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") or Descendant:IsA("Decal") then
			table.insert(Instances, { Instance = Descendant, Transparency = Descendant.Transparency })
		end
	end
	return Instances
end

local function AcquireModel(Visitor): Model?
	local Template = GetRenderTemplate()
	if not Template then return nil end
	local Model = table.remove(RenderPool) or Template:Clone()
	Model.Name = `MuseumVisitor_{Visitor.UniqueId}`
	CollectionService:AddTag(Model, "MuseumVisitor")
	ApplyAppearance(Model, Visitor)
	Model.Parent = GetRenderFolder()
	Visitor.WalkJoints = GetWalkJoints(Model)
	Visitor.FadeInstances = GetFadeInstances(Model)
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	Visitor.BoundingOffset = Model:GetPivot():ToObjectSpace(BoundingCFrame)
	Visitor.BoundingSize = BoundingSize
	Visitor.Model = Model
	Model:PivotTo(GetCurrentMovementCFrame(Visitor, Workspace:GetServerTimeNow()))
	return Model
end

local function ReleaseModel(Visitor)
	local Model = Visitor.Model
	if not Model then return end
	ResetRagdoll(Visitor)
	CollectionService:RemoveTag(Model, "MuseumVisitor")
	for _, FadeInfo in Visitor.FadeInstances or {} do
		if FadeInfo.Instance.Parent then FadeInfo.Instance.Transparency = FadeInfo.Transparency end
	end
	for _, WalkJoint in Visitor.WalkJoints or {} do WalkJoint.Joint.Transform = CFrame.identity end
	for Connection in Visitor.EffectConnections or {} do Connection:Disconnect() end
	if Visitor.EffectConnections then table.clear(Visitor.EffectConnections) end
	for _, Descendant in Model:GetDescendants() do
		if Descendant.Name == "CashEffect" and Descendant:IsA("BillboardGui") then Descendant:Destroy() end
	end
	RemoveAppearance(Model)
	Model.Parent = nil
	Model.Name = "PooledMuseumVisitor"
	Visitor.Model = nil
	Visitor.WalkJoints = nil
	Visitor.FadeInstances = nil
	if #RenderPool < MAX_POOLED_MODELS then table.insert(RenderPool, Model) else Model:Destroy() end
end

local function IsPointInsidePart(Point: Vector3, Part: BasePart): boolean
	local LocalPoint = Part.CFrame:PointToObjectSpace(Point)
	local HalfSize = Part.Size / 2
	return math.abs(LocalPoint.X) <= HalfSize.X and math.abs(LocalPoint.Y) <= HalfSize.Y and math.abs(LocalPoint.Z) <= HalfSize.Z
end

local function RemoveMuseumAreas(Museum: Model)
	for Index = #MuseumAreas, 1, -1 do
		if MuseumAreas[Index].Museum == Museum then table.remove(MuseumAreas, Index) end
	end
	local Connections = MuseumConnections[Museum]
	if Connections then for _, Connection in Connections do Connection:Disconnect() end end
	MuseumConnections[Museum] = nil
end

local function AddMuseumArea(Museum: Model, OwnerUserId: number, Descendant: Instance)
	if Descendant.Name ~= "MuseumArea" or not Descendant:IsA("BasePart") then return end
	for _, AreaInfo in MuseumAreas do if AreaInfo.Part == Descendant then return end end
	table.insert(MuseumAreas, { Museum = Museum, OwnerUserId = OwnerUserId, Part = Descendant })
end

local function RegisterMuseum(Museum: Instance)
	if not Museum:IsA("Model") or MuseumConnections[Museum] then return end
	local OwnerUserId = tonumber(string.match(Museum.Name, "^Museum_(%d+)$"))
	if not OwnerUserId then return end
	for _, Descendant in Museum:GetDescendants() do AddMuseumArea(Museum, OwnerUserId, Descendant) end
	MuseumConnections[Museum] = {
		Museum.DescendantAdded:Connect(function(Descendant) AddMuseumArea(Museum, OwnerUserId, Descendant) end),
		Museum.DescendantRemoving:Connect(function(Descendant)
			for Index = #MuseumAreas, 1, -1 do
				if MuseumAreas[Index].Part == Descendant then table.remove(MuseumAreas, Index) end
			end
		end),
	}
end

local function ConnectMuseumFolder(Folder: Instance)
	if Folder.Name ~= "PlayerMuseums" then return end
	for _, Museum in Folder:GetChildren() do RegisterMuseum(Museum) end
	Folder.ChildAdded:Connect(RegisterMuseum)
	Folder.ChildRemoved:Connect(function(Museum) if Museum:IsA("Model") then RemoveMuseumAreas(Museum) end end)
end

local function SetupMuseumAreaCache()
	local Folder = Workspace:FindFirstChild("PlayerMuseums")
	if Folder then ConnectMuseumFolder(Folder) end
	Workspace.ChildAdded:Connect(function(Child)
		if Child.Name == "PlayerMuseums" then ConnectMuseumFolder(Child) end
	end)
end

local function GetViewedMuseumOwnerUserId(): number
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return LocalPlayer.UserId end
	for _, AreaInfo in MuseumAreas do
		if AreaInfo.OwnerUserId ~= LocalPlayer.UserId and AreaInfo.Part.Parent
			and IsPointInsidePart(RootPart.Position, AreaInfo.Part)
		then
			return AreaInfo.OwnerUserId
		end
	end
	return LocalPlayer.UserId
end

local function IsPotentiallyVisible(Visitor, Camera: Camera, Now: number): (boolean, number)
	local Position = GetCurrentMovementCFrame(Visitor, Now).Position
	local Offset = Position - Camera.CFrame.Position
	local DistanceSquared = Offset:Dot(Offset)
	if DistanceSquared > BACKGROUND_RENDER_DISTANCE * BACKGROUND_RENDER_DISTANCE then return false, DistanceSquared end
	local ScreenPosition = Camera:WorldToViewportPoint(Position)
	local ViewportSize = Camera.ViewportSize
	local Visible = ScreenPosition.Z > 0
		and ScreenPosition.X >= -BACKGROUND_SCREEN_MARGIN
		and ScreenPosition.X <= ViewportSize.X + BACKGROUND_SCREEN_MARGIN
		and ScreenPosition.Y >= -BACKGROUND_SCREEN_MARGIN
		and ScreenPosition.Y <= ViewportSize.Y + BACKGROUND_SCREEN_MARGIN
	return Visible, DistanceSquared
end

local function AddBackgroundPriorityCandidate(Visitor, DistanceSquared: number)
	local InsertIndex = #BackgroundVisitors + 1
	for Index, Candidate in BackgroundVisitors do
		if DistanceSquared < Candidate.DistanceSquared then InsertIndex = Index; break end
	end
	table.insert(BackgroundVisitors, InsertIndex, { Visitor = Visitor, DistanceSquared = DistanceSquared })
	if #BackgroundVisitors > MAX_BACKGROUND_VISITORS then table.remove(BackgroundVisitors) end
end

local function RefreshPriorities(Now: number)
	local ViewedOwnerUserId = GetViewedMuseumOwnerUserId()
	if ViewedOwnerUserId ~= PriorityOwnerUserId then
		PriorityOwnerUserId = ViewedOwnerUserId
		if ViewedOwnerChangedHandler then ViewedOwnerChangedHandler(ViewedOwnerUserId) end
	end
	table.clear(BackgroundVisitors)
	local Camera = Workspace.CurrentCamera
	for Visitor in TrackedVisitors do
		Visitor.IsBackgroundPriority = false
		local ShouldRender = Visitor.OwnerUserId == PriorityOwnerUserId
		if not ShouldRender and Camera then
			local IsVisible, DistanceSquared = IsPotentiallyVisible(Visitor, Camera, Now)
			if IsVisible then
				Visitor.LastPotentiallyVisibleAt = Now
				AddBackgroundPriorityCandidate(Visitor, DistanceSquared)
				ShouldRender = true
			elseif Visitor.LastPotentiallyVisibleAt and Now - Visitor.LastPotentiallyVisibleAt < BACKGROUND_RELEASE_DELAY then
				ShouldRender = true
			end
		end
		if ShouldRender and not Visitor.Model then AcquireModel(Visitor) elseif not ShouldRender and Visitor.Model then ReleaseModel(Visitor) end
	end
	for Index = 1, #BackgroundVisitors do
		BackgroundVisitors[Index].Visitor.IsBackgroundPriority = true
	end
	LastPriorityRefresh = Now
end

local function StartRenderLoop()
	if RenderConnection then return end
	RenderConnection = RunService.RenderStepped:Connect(function()
		local Now = Workspace:GetServerTimeNow()
		if Now - LastPriorityRefresh >= PRIORITY_REFRESH_INTERVAL then RefreshPriorities(Now) end
		for Visitor in TrackedVisitors do
			if not Visitor.Model then continue end
			if Now >= Visitor.NextVisibilityUpdateAt then Visitor:RefreshVisibility(Now) end
			if not Visitor.IsVisible or Now < Visitor.NextVisualUpdateAt then continue end
			local UpdateInterval = 0
			if Visitor.OwnerUserId ~= PriorityOwnerUserId then
				UpdateInterval = if Visitor.IsBackgroundPriority then BACKGROUND_UPDATE_INTERVAL else DISTANT_UPDATE_INTERVAL
			end
			local DeltaTime = math.min(Now - Visitor.LastVisualUpdateAt, MAX_BLEND_DELTA_TIME)
			Visitor.LastVisualUpdateAt = Now
			Visitor.NextVisualUpdateAt = Now + UpdateInterval
			Visitor:Update(DeltaTime, Now)
		end
	end)
end

local function StopRenderLoopIfEmpty()
	if ViewedOwnerChangedHandler or next(TrackedVisitors) or not RenderConnection then return end
	RenderConnection:Disconnect()
	RenderConnection = nil
end

function MuseumVisitor.new(Data)
	GetRenderTemplate()
	local Self = setmetatable(Data, MuseumVisitor)
	Self.CurrentVisualCFrame = (Self.CurrentCFrame or Self.SpawnCFrame) + TemplateFeetOffset
	Self.WalkBlend = 0
	Self.FadeAlpha = 1
	Self.FadeStartAlpha = 1
	Self.FadeTargetAlpha = 0
	Self.FadeStartedAt = Workspace:GetServerTimeNow()
	Self.FadeDuration = FADE_DURATION
	Self.IsVisible = true
	Self.IsBackgroundPriority = false
	Self.NextVisibilityUpdateAt = 0
	Self.LastVisualUpdateAt = Self.FadeStartedAt
	Self.NextVisualUpdateAt = Self.LastVisualUpdateAt
	Self.EffectConnections = {}
	TrackedVisitors[Self] = true
	StartRenderLoop()
	return Self
end

function MuseumVisitor:RefreshVisibility(Now: number)
	self.NextVisibilityUpdateAt = Now + VISIBILITY_REFRESH_INTERVAL
	local Camera = Workspace.CurrentCamera
	local Model = self.Model
	if not Camera or not Model then self.IsVisible = false; return end
	local BoundingCFrame = GetCurrentMovementCFrame(self, Now) * self.BoundingOffset
	local HalfSize = self.BoundingSize / 2
	for X = -1, 1, 2 do
		for Y = -1, 1, 2 do
			for Z = -1, 1, 2 do
				local Corner = BoundingCFrame:PointToWorldSpace(Vector3.new(HalfSize.X * X, HalfSize.Y * Y, HalfSize.Z * Z))
				local _, IsVisible = Camera:WorldToViewportPoint(Corner)
				if IsVisible then self.IsVisible = true; return end
			end
		end
	end
	self.IsVisible = false
end

function MuseumVisitor:Update(DeltaTime: number, Now: number)
	local Model = self.Model
	if not Model then return end
	if self.IsRagdolled then
		if self.FadeTargetAlpha ~= nil then
			local Alpha = math.clamp((Now - self.FadeStartedAt) / self.FadeDuration, 0, 1)
			self.FadeAlpha = self.FadeStartAlpha + (self.FadeTargetAlpha - self.FadeStartAlpha) * Alpha
			for _, FadeInfo in self.FadeInstances do
				FadeInfo.Instance.Transparency = FadeInfo.Transparency + (1 - FadeInfo.Transparency) * self.FadeAlpha
			end
			if Alpha >= 1 then self.FadeTargetAlpha = nil end
		end
		return
	end
	local DesiredRotation = self.RotationTarget
	if self.MoveTarget then
		local MoveAlpha = math.clamp((Now - self.MoveStartedAt) / self.MoveDuration, 0, 1)
		local Position = self.MoveStart.Position:Lerp(self.MoveTarget.Position, MoveAlpha)
		DesiredRotation = if MoveAlpha < 1 then self.MoveRotation else self.MoveTarget.Rotation
		local RotationAlpha = 1 - math.exp(-TURN_RESPONSIVENESS * DeltaTime)
		local Rotation = Model:GetPivot().Rotation:Lerp(DesiredRotation, RotationAlpha)
		Model:PivotTo(CFrame.new(Position) * Rotation)
		if MoveAlpha >= 1 then
			self.CurrentVisualCFrame = self.MoveTarget
			self.RotationTarget = self.MoveTarget.Rotation
			self.MoveTarget = nil
		end
	elseif DesiredRotation then
		local RotationAlpha = 1 - math.exp(-TURN_RESPONSIVENESS * DeltaTime)
		local Pivot = Model:GetPivot()
		Model:PivotTo(CFrame.new(Pivot.Position) * Pivot.Rotation:Lerp(DesiredRotation, RotationAlpha))
	end
	local WalkTarget = if self.MoveTarget then 1 else 0
	local WalkAlpha = 1 - math.exp(-WALK_BLEND_RESPONSIVENESS * DeltaTime)
	self.WalkBlend += (WalkTarget - self.WalkBlend) * WalkAlpha
	local WalkSwing = math.sin(Now * WALK_CYCLE_SPEED) * WALK_SWING_ANGLE * self.WalkBlend
	for _, WalkJoint in self.WalkJoints do
		-- Standard R6 motors swing forward on local Z; local X makes the limbs move sideways like a floss dance.
		WalkJoint.Joint.Transform = CFrame.Angles(0, 0, WalkSwing * WalkJoint.Direction)
	end
	if self.FadeTargetAlpha ~= nil then
		local Alpha = math.clamp((Now - self.FadeStartedAt) / self.FadeDuration, 0, 1)
		self.FadeAlpha = self.FadeStartAlpha + (self.FadeTargetAlpha - self.FadeStartAlpha) * Alpha
		for _, FadeInfo in self.FadeInstances do
			FadeInfo.Instance.Transparency = FadeInfo.Transparency + (1 - FadeInfo.Transparency) * self.FadeAlpha
		end
		if Alpha >= 1 then self.FadeTargetAlpha = nil end
	end
end

function MuseumVisitor:MoveTo(TargetCFrame: CFrame, Duration: number)
	local Now = Workspace:GetServerTimeNow()
	self.MoveStart = GetCurrentMovementCFrame(self, Now)
	self.CurrentVisualCFrame = self.MoveStart
	self.MoveTarget = TargetCFrame + TemplateFeetOffset
	self.RotationTarget = nil
	local MoveDirection = self.MoveTarget.Position - self.MoveStart.Position
	local FlatDirection = Vector3.new(MoveDirection.X, 0, MoveDirection.Z)
	self.MoveRotation = if FlatDirection.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, FlatDirection).Rotation else self.MoveStart.Rotation
	self.MoveStartedAt = Now
	self.MoveDuration = math.max(Duration, 0.01)
end

function MuseumVisitor:ShowCash(Amount: number)
	if not self.IsVisible then return end
	local RootPart = self.Model and self.Model:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return end
	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "CashEffect"
	Billboard.Adornee = RootPart
	Billboard.AlwaysOnTop = true
	Billboard.MaxDistance = 300
	Billboard.Size = UDim2.fromScale(4, 1.3)
	Billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	Billboard.Parent = RootPart
	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.FontFace = COMIC_FONT
	Label.Size = UDim2.fromScale(1, 1)
	Label.Text = `+{FormatNumber(Amount) or "0"}`
	Label.TextColor3 = Color3.fromRGB(72, 232, 91)
	Label.TextScaled = true
	Label.Parent = Billboard
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.new(0, 0, 0)
	Stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	Stroke.Thickness = 0.06
	Stroke.Parent = Label
	local StartedAt = os.clock()
	local Connection
	Connection = RunService.RenderStepped:Connect(function()
		local Alpha = math.clamp((os.clock() - StartedAt) / CASH_EFFECT_DURATION, 0, 1)
		Billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5 + Alpha * 2, 0)
		Label.TextTransparency = Alpha
		Stroke.Transparency = Alpha
		if Alpha >= 1 then
			Connection:Disconnect()
			self.EffectConnections[Connection] = nil
			Billboard:Destroy()
		end
	end)
	self.EffectConnections[Connection] = true
	Sounds.Play("CoinJingle", RootPart)
	Sounds.Play("Coin", RootPart)
end

function MuseumVisitor:Say(Message: string)
	if not self.IsVisible then return end
	local Head = self.Model and self.Model:FindFirstChild("Head")
	if Head and Head:IsA("BasePart") and Message ~= "" then TextChatService:DisplayBubble(Head, Message) end
end

function MuseumVisitor:Ragdoll(Knockback: Vector3)
	if self.IsRagdolled then return end
	local Model = self.Model
	if not Model then return end
	self.IsRagdolled = true
	self.MoveTarget = nil
	self.RotationTarget = nil
	self.WalkBlend = 0
	self.RagdollJoints = {}
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("Motor6D") and Descendant.Part0 and Descendant.Part1 then
			local Attachment0 = Instance.new("Attachment")
			Attachment0.Name = "RagdollAttachment"
			Attachment0.CFrame = Descendant.C0
			Attachment0.Parent = Descendant.Part0
			local Attachment1 = Instance.new("Attachment")
			Attachment1.Name = "RagdollAttachment"
			Attachment1.CFrame = Descendant.C1
			Attachment1.Parent = Descendant.Part1
			local Constraint = Instance.new("BallSocketConstraint")
			Constraint.Name = "RagdollBallSocket"
			Constraint.Attachment0 = Attachment0
			Constraint.Attachment1 = Attachment1
			Constraint.LimitsEnabled = true
			Constraint.UpperAngle = 55
			Constraint.TwistLimitsEnabled = true
			Constraint.TwistLowerAngle = -45
			Constraint.TwistUpperAngle = 45
			Constraint.Parent = Descendant.Part0
			local NoCollisionConstraint = Instance.new("NoCollisionConstraint")
			NoCollisionConstraint.Name = "RagdollNoCollision"
			NoCollisionConstraint.Part0 = Descendant.Part0
			NoCollisionConstraint.Part1 = Descendant.Part1
			NoCollisionConstraint.Parent = Descendant.Part0
			Descendant.Enabled = false
			table.insert(self.RagdollJoints, {
				Motor = Descendant,
				Attachment0 = Attachment0,
				Attachment1 = Attachment1,
				Constraint = Constraint,
				NoCollisionConstraint = NoCollisionConstraint,
			})
		end
	end
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then Descendant.Massless = false end
	end
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid.PlatformStand = true end
	local RootPart = Model:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		RootPart.Anchored = false
		RootPart.AssemblyLinearVelocity = Knockback
	end
end

function MuseumVisitor:FadeOut(Duration: number)
	self.FadeStartAlpha = self.FadeAlpha or 0
	self.FadeTargetAlpha = 1
	self.FadeStartedAt = Workspace:GetServerTimeNow()
	self.FadeDuration = math.max(Duration, 0.01)
end

function MuseumVisitor:Destroy()
	TrackedVisitors[self] = nil
	ReleaseModel(self)
	StopRenderLoopIfEmpty()
end

function MuseumVisitor.SetViewedOwnerChangedHandler(Handler)
	ViewedOwnerChangedHandler = Handler
	StartRenderLoop()
end

SetupMuseumAreaCache()
GetRenderTemplate()

return MuseumVisitor
