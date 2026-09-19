local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local Players = game:GetService "Players"
local TextChatService = game:GetService "TextChatService"
local Workspace = game:GetService "Workspace"

local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)
local CollisionGroups = require(ReplicatedStorage.Modules.Game.CollisionGroups)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local CLASS_INFO = {
	Name = "MuseumVisitor",
	AllowedMethods = {},
}

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

local renderFolder: Folder?
local RenderedVisitors = {}
local RenderConnection: RBXScriptConnection?
local PriorityOwnerUserId = Players.LocalPlayer.UserId
local LastPriorityRefresh = 0
local BackgroundVisitors = {}

local MuseumVisitor = {}
MuseumVisitor.__index = MuseumVisitor

local function GetCurrentMovementCFrame(Visitor, Now: number): CFrame
	local Model = Visitor.model
	local Pivot = Model:GetPivot()
	if Visitor.moveTarget == nil then
		return Pivot
	end

	local MoveAlpha = math.clamp((Now - Visitor.moveStartedAt) / Visitor.moveDuration, 0, 1)
	local Position = Visitor.moveStart.Position:Lerp(Visitor.moveTarget.Position, MoveAlpha)
	local Rotation = if MoveAlpha < 1 then Visitor.moveRotation else Visitor.moveTarget.Rotation
	return CFrame.new(Position) * Rotation
end

local function IsPointInsidePart(Point: Vector3, Part: BasePart): boolean
	local LocalPoint = Part.CFrame:PointToObjectSpace(Point)
	local HalfSize = Part.Size / 2
	return math.abs(LocalPoint.X) <= HalfSize.X
		and math.abs(LocalPoint.Y) <= HalfSize.Y
		and math.abs(LocalPoint.Z) <= HalfSize.Z
end

local function GetViewedMuseumOwnerUserId(): number
	local Character = Players.LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild "HumanoidRootPart"
	local PlayerMuseums = Workspace:FindFirstChild "PlayerMuseums"
	if RootPart == nil or not RootPart:IsA("BasePart") or PlayerMuseums == nil then
		return Players.LocalPlayer.UserId
	end

	for _, Museum in PlayerMuseums:GetChildren() do
		local OwnerUserId = tonumber(string.match(Museum.Name, "^Museum_(%d+)$"))
		if OwnerUserId and OwnerUserId ~= Players.LocalPlayer.UserId then
			for _, Descendant in Museum:GetDescendants() do
				if Descendant.Name == "MuseumArea"
					and Descendant:IsA("BasePart")
					and IsPointInsidePart(RootPart.Position, Descendant)
				then
					return OwnerUserId
				end
			end
		end
	end

	return Players.LocalPlayer.UserId
end

local function RefreshPriorities(Now: number)
	PriorityOwnerUserId = GetViewedMuseumOwnerUserId()
	table.clear(BackgroundVisitors)

	local Camera = Workspace.CurrentCamera
	for Visitor in RenderedVisitors do
		Visitor.isBackgroundPriority = false
		if Visitor.OwnerUserId ~= PriorityOwnerUserId and Visitor.isVisible and Visitor.model and Camera then
			table.insert(BackgroundVisitors, Visitor)
		end
	end

	table.sort(BackgroundVisitors, function(First, Second)
		return (First.model:GetPivot().Position - Camera.CFrame.Position).Magnitude
			< (Second.model:GetPivot().Position - Camera.CFrame.Position).Magnitude
	end)
	for Index = 1, math.min(#BackgroundVisitors, MAX_BACKGROUND_VISITORS) do
		BackgroundVisitors[Index].isBackgroundPriority = true
	end
	LastPriorityRefresh = Now
end

local function StartRenderLoop()
	if RenderConnection then
		return
	end
	RenderConnection = RunService.RenderStepped:Connect(function()
		local Now = Workspace:GetServerTimeNow()
		if Now - LastPriorityRefresh >= PRIORITY_REFRESH_INTERVAL then
			RefreshPriorities(Now)
		end
		for Visitor in RenderedVisitors do
			Visitor:RefreshVisibility(Now)
			if not Visitor.isVisible then
				continue
			end

			local UpdateInterval = 0
			if Visitor.OwnerUserId ~= PriorityOwnerUserId then
				UpdateInterval = if Visitor.isBackgroundPriority then BACKGROUND_UPDATE_INTERVAL else DISTANT_UPDATE_INTERVAL
			end
			if Now >= Visitor.nextVisualUpdateAt then
				local DeltaTime = math.min(Now - Visitor.lastVisualUpdateAt, MAX_BLEND_DELTA_TIME)
				Visitor.lastVisualUpdateAt = Now
				Visitor.nextVisualUpdateAt = Now + UpdateInterval
				Visitor:Update(DeltaTime)
			end
		end
	end)
end

local function StopRenderLoopIfEmpty()
	if next(RenderedVisitors) or not RenderConnection then
		return
	end
	RenderConnection:Disconnect()
	RenderConnection = nil
end

local function GetFeetOffset(Model: Model): Vector3
	local RootPart = Model:FindFirstChild "HumanoidRootPart"
	local Humanoid = Model:FindFirstChildOfClass "Humanoid"
	if RootPart and RootPart:IsA "BasePart" and Humanoid then
		return Vector3.new(0, Humanoid.HipHeight + RootPart.Size.Y / 2, 0)
	end

	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local Pivot = Model:GetPivot()
	local BottomY = BoundingCFrame.Position.Y - BoundingSize.Y / 2
	return Vector3.new(0, Pivot.Position.Y - BottomY, 0)
end

local function GetWalkJoints(Model: Model): { [string]: Motor6D }
	local Joints = {}
	for _, JointName in { "LeftHip", "RightHip", "LeftShoulder", "RightShoulder" } do
		local Joint = Model:FindFirstChild(JointName, true)
		if Joint and Joint:IsA "Motor6D" then
			Joints[JointName] = Joint
		end
	end
	return Joints
end

local function getRenderFolder(): Folder
	if renderFolder and renderFolder.Parent then
		return renderFolder
	end

	local folder = Instance.new "Folder"
	folder.Name = "RenderedMuseumVisitors"
	folder.Parent = Workspace
	renderFolder = folder
	return folder
end

local function prepareModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA "BasePart" then
			descendant.CollisionGroup = CollisionGroups.NPCCharacters
			descendant.CanCollide = descendant.Name ~= "HumanoidRootPart"
				and descendant:FindFirstAncestorOfClass "Accessory" == nil
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	local rootPart = model:FindFirstChild "HumanoidRootPart"
	if rootPart and rootPart:IsA "BasePart" then
		rootPart.Anchored = true
	end
end

local function attachAccessory(model: Model, accessoryTemplate: Accessory)
	local accessory = accessoryTemplate:Clone()
	local handle = accessory:FindFirstChild("Handle")
	local accessoryAttachment = handle and handle:FindFirstChildOfClass("Attachment")
	local characterAttachment = accessoryAttachment and model:FindFirstChild(accessoryAttachment.Name, true)
	if handle == nil or not handle:IsA("BasePart") or accessoryAttachment == nil or characterAttachment == nil then
		accessory:Destroy()
		return
	end

	local characterPart = characterAttachment.Parent
	if characterPart == nil or not characterPart:IsA("BasePart") then
		accessory:Destroy()
		return
	end

	accessory.Parent = model
	handle.CFrame = characterPart.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:Inverse()

	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = characterPart
	weld.C0 = accessoryAttachment.CFrame
	weld.C1 = characterAttachment.CFrame
	weld.Parent = handle
end

local function applyAppearance(model: Model, shirtTemplate, pantsTemplate, hairTemplate, skinColor)
	if shirtTemplate and shirtTemplate:IsA "Shirt" then
		shirtTemplate:Clone().Parent = model
	end
	if pantsTemplate and pantsTemplate:IsA "Pants" then
		pantsTemplate:Clone().Parent = model
	end
	if hairTemplate and hairTemplate:IsA "Accessory" then
		attachAccessory(model, hairTemplate)
	end
	if typeof(skinColor) == "Color3" then
		local bodyColors = model:FindFirstChildOfClass "BodyColors"
		if bodyColors then
			bodyColors.HeadColor3 = skinColor
			bodyColors.LeftArmColor3 = skinColor
			bodyColors.LeftLegColor3 = skinColor
			bodyColors.RightArmColor3 = skinColor
			bodyColors.RightLegColor3 = skinColor
			bodyColors.TorsoColor3 = skinColor
		end
	end
end

local function getFadeInstances(model: Model)
	local instances = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA "BasePart" or descendant:IsA "Decal" then
			table.insert(instances, {
				instance = descendant,
				transparency = descendant.Transparency,
			})
		end
	end
	return instances
end

function MuseumVisitor.new(data)
	local self = setmetatable(data, MuseumVisitor)
	self:Link(CLASS_INFO)
	self:Render()
	return self
end

function MuseumVisitor:Render()
	local template = ReplicatedStorage.Assets.Models.NPCS:FindFirstChild "NPC"
	if template == nil or not template:IsA "Model" then
		warn "MuseumVisitor could not find the NPC template"
		return
	end

	local model = template:Clone()
	model.Name = `MuseumVisitor_{self.UniqueId}`
	applyAppearance(model, self.ShirtTemplate, self.PantsTemplate, self.HairTemplate, self.SkinColor)
	prepareModel(model)
	model.Parent = getRenderFolder()
	self.feetOffset = GetFeetOffset(model)
	self.walkJoints = GetWalkJoints(model)
	self.walkBlend = 0
	model:PivotTo((self.CurrentCFrame or self.SpawnCFrame) + self.feetOffset)
	local BoundingCFrame, BoundingSize = model:GetBoundingBox()
	self.boundingOffset = model:GetPivot():ToObjectSpace(BoundingCFrame)
	self.boundingSize = BoundingSize
	self.isVisible = true
	self.isBackgroundPriority = false
	self.lastVisibilityUpdate = 0
	self.lastVisualUpdateAt = Workspace:GetServerTimeNow()
	self.nextVisualUpdateAt = self.lastVisualUpdateAt

	self.model = model
	self.fadeInstances = getFadeInstances(model)
	self.fadeAlpha = 1
	self.fadeStartAlpha = 1
	self.fadeTargetAlpha = 0
	self.fadeStartedAt = Workspace:GetServerTimeNow()
	self.fadeDuration = FADE_DURATION
	RenderedVisitors[self] = true
	StartRenderLoop()
end

function MuseumVisitor:RefreshVisibility(Now: number)
	if Now - self.lastVisibilityUpdate < VISIBILITY_REFRESH_INTERVAL then
		return
	end
	self.lastVisibilityUpdate = Now

	local Camera = Workspace.CurrentCamera
	local Model = self.model
	if Camera == nil or Model == nil then
		self.isVisible = false
		return
	end

	-- Visibility follows the authoritative timed route even while the rendered model is paused offscreen.
	local BoundingCFrame = GetCurrentMovementCFrame(self, Now) * self.boundingOffset
	local HalfSize = self.boundingSize / 2
	for X = -1, 1, 2 do
		for Y = -1, 1, 2 do
			for Z = -1, 1, 2 do
				local Corner = BoundingCFrame:PointToWorldSpace(Vector3.new(HalfSize.X * X, HalfSize.Y * Y, HalfSize.Z * Z))
				local _, IsVisible = Camera:WorldToViewportPoint(Corner)
				if IsVisible then
					self.isVisible = true
					return
				end
			end
		end
	end
	self.isVisible = false
end

function MuseumVisitor:Update(DeltaTime: number)
	local model = self.model
	if model == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local DesiredRotation = self.rotationTarget
	if self.moveTarget then
		local MoveAlpha = math.clamp((now - self.moveStartedAt) / self.moveDuration, 0, 1)
		local Position = self.moveStart.Position:Lerp(self.moveTarget.Position, MoveAlpha)
		DesiredRotation = if MoveAlpha < 1 then self.moveRotation else self.moveTarget.Rotation
		local RotationAlpha = 1 - math.exp(-TURN_RESPONSIVENESS * DeltaTime)
		local Rotation = model:GetPivot().Rotation:Lerp(DesiredRotation, RotationAlpha)
		model:PivotTo(CFrame.new(Position) * Rotation)
		if MoveAlpha >= 1 then
			self.rotationTarget = self.moveTarget.Rotation
			self.moveTarget = nil
		end
	elseif DesiredRotation then
		local RotationAlpha = 1 - math.exp(-TURN_RESPONSIVENESS * DeltaTime)
		local Pivot = model:GetPivot()
		model:PivotTo(CFrame.new(Pivot.Position) * Pivot.Rotation:Lerp(DesiredRotation, RotationAlpha))
	end

	local WalkTarget = if self.moveTarget then 1 else 0
	local WalkAlpha = 1 - math.exp(-WALK_BLEND_RESPONSIVENESS * DeltaTime)
	self.walkBlend += (WalkTarget - self.walkBlend) * WalkAlpha
	local WalkSwing = math.sin(now * WALK_CYCLE_SPEED) * WALK_SWING_ANGLE * self.walkBlend
	for JointName, Joint in self.walkJoints do
		local Direction = if JointName == "LeftHip" or JointName == "RightShoulder" then 1 else -1
		Joint.Transform = CFrame.Angles(WalkSwing * Direction, 0, 0)
	end

	if self.fadeTargetAlpha ~= nil then
		local alpha = math.clamp((now - self.fadeStartedAt) / self.fadeDuration, 0, 1)
		self.fadeAlpha = self.fadeStartAlpha + (self.fadeTargetAlpha - self.fadeStartAlpha) * alpha
		for _, fadeInfo in self.fadeInstances do
			fadeInfo.instance.Transparency = fadeInfo.transparency + (1 - fadeInfo.transparency) * self.fadeAlpha
		end
		if alpha >= 1 then
			self.fadeTargetAlpha = nil
		end
	end
end

function MuseumVisitor:MoveTo(targetCFrame: CFrame, duration: number)
	if self.model == nil then
		return
	end
	self.moveStart = GetCurrentMovementCFrame(self, Workspace:GetServerTimeNow())
	self.moveTarget = targetCFrame + self.feetOffset
	self.rotationTarget = nil
	local MoveDirection = self.moveTarget.Position - self.moveStart.Position
	if MoveDirection.Magnitude > 0.01 then
		local FlatDirection = Vector3.new(MoveDirection.X, 0, MoveDirection.Z)
		self.moveRotation = if FlatDirection.Magnitude > 0.01
			then CFrame.lookAt(Vector3.zero, FlatDirection).Rotation
			else self.moveStart.Rotation
	else
		self.moveRotation = self.moveStart.Rotation
	end
	self.moveStartedAt = Workspace:GetServerTimeNow()
	self.moveDuration = math.max(duration, 0.01)
end

function MuseumVisitor:ShowCash(amount: number)
	if not self.isVisible then
		return
	end
	local model = self.model
	local rootPart = model and model:FindFirstChild "HumanoidRootPart"
	if rootPart == nil or not rootPart:IsA "BasePart" then
		return
	end

	local billboard = Instance.new "BillboardGui"
	billboard.Name = "CashEffect"
	billboard.Adornee = rootPart
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Size = UDim2.fromScale(4, 1.3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	billboard.Parent = rootPart

	local label = Instance.new "TextLabel"
	label.BackgroundTransparency = 1
	label.FontFace = COMIC_FONT
	label.Size = UDim2.fromScale(1, 1)
	label.Text = `+{FormatNumber(amount) or "0"}`
	label.TextColor3 = Color3.fromRGB(72, 232, 91)
	label.TextScaled = true
	label.Parent = billboard

	local stroke = Instance.new "UIStroke"
	stroke.Color = Color3.new(0, 0, 0)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.06
	stroke.Parent = label

	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startedAt) / CASH_EFFECT_DURATION, 0, 1)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5 + alpha * 2, 0)
		label.TextTransparency = alpha
		stroke.Transparency = alpha
		if alpha >= 1 then
			connection:Disconnect()
			billboard:Destroy()
		end
	end)

	Sounds.Play("CoinJingle", rootPart)
	Sounds.Play("Coin", rootPart)
end

function MuseumVisitor:Say(message: string)
	if not self.isVisible then
		return
	end
	local model = self.model
	local head = model and model:FindFirstChild "Head"
	if head and head:IsA "BasePart" and message ~= "" then
		TextChatService:DisplayBubble(head, message)
	end
end

function MuseumVisitor:FadeOut(duration: number)
	self.fadeStartAlpha = self.fadeAlpha or 0
	self.fadeTargetAlpha = 1
	self.fadeStartedAt = Workspace:GetServerTimeNow()
	self.fadeDuration = math.max(duration, 0.01)
end

function MuseumVisitor:Destroy()
	RenderedVisitors[self] = nil
	StopRenderLoopIfEmpty()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

SharedClass:Link(MuseumVisitor, CLASS_INFO)

return MuseumVisitor
