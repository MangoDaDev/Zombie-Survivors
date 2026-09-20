local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local Networker = require(ReplicatedStorage.Packages.networker)
local PaintRenderer = require(ReplicatedStorage.Modules.Game.PaintRenderer)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local RestorationTargetRenderer = require(ReplicatedStorage.Modules.Game.RestorationTargetRenderer)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local LocalPlayer = Players.LocalPlayer
local FixingController = {}
local Network
local CameraBound = false
local HiddenParts: { [BasePart]: number } = {}
local UsingTool = false
local ActiveToolId: string?
local RequestedToolId: string?
local FixPrompt: ProximityPrompt?
local CharacterConnections: { RBXScriptConnection } = {}
local ToolLoop: Sound?
local ToolBeam: Beam?
local ToolEndPart: Part?
local ToolStartAttachment: Attachment?
local ToolEndAttachment: Attachment?
local ToolEmitter: ParticleEmitter?
local ToolVFXAttachment: Attachment?
local CreatedStartAttachment = false
local CreatedToolEmitter = false
local SmoothedToolPosition: Vector3?
local SmoothedVisualToolCFrame: CFrame?
local SmoothedFakeArmEndPosition: Vector3?
local SmoothedSurfaceNormal: Vector3?
local CurrentToolColor: Color3?
local FakeArm: Part?
local ViewmodelContainer: Folder?
local ViewmodelTool: Tool?
local ViewmodelHandle: BasePart?
local ViewmodelSourceTool: Tool?
local ViewmodelPartOffsets: { [BasePart]: CFrame } = {}
local ControlsDisabled = false
local OriginalFieldOfView: number?
local OriginalCameraType: Enum.CameraType?
local StopToolEffects
local UpdateVisualTool
local GetFixingItemModel
local HideCharacterPart
local ReportLocalProgress
local ClearStepHighlights
local UpdateStepHints
local UpdateHammerPresentation
local LocalTargetStates = {}
local LocalStepCaches = {}
local LocalStepId: string?
local LocalStepTotal = 0
local LocalStepRemaining = 0
local TargetHighlights: { [BasePart]: Highlight } = {}
local TargetHintTransparencies: { [BasePart]: number } = {}
local HintStepId: string?
local HintStepStartedAt = 0
local HintStepGeneration = 0
local LastReportedRemaining = 0
local LastProgressReport = 0
local CompletionRequested = false
local LastDirtFeedback = 0
local LastSpongeBubbleSound = -math.huge
local HammerStrikeStartedAt: number?
local HammerStrikeApplied = false
local HammerStrikeAimPosition: Vector3?
local HammerStrikeSurfaceNormal: Vector3?
local HammerInputHeld = false
local CameraEntryId = 0
local BaseCameraCFrame: CFrame?
local OriginalCameraCFrame: CFrame?
local OriginalCameraRootOffset: CFrame?
local CameraImpulse = 0
local CameraPush = 0
local LastCleanPosition: Vector3?
local ActiveTouchInput: InputObject?
local ActiveItemRadiusMultiplier = 1

local CAMERA_BINDING_NAME = "CleaningCameraAndArm"
local CAMERA_SETUP_TIMEOUT = 10
local DISABLE_CONTROLS_ACTION_NAME = "DisableFixingControls"
local DISABLE_CONTROLS_PRIORITY = Enum.ContextActionPriority.High.Value
local TOOL_SOUND_MAX_DISTANCE = 50

local function SinkPlayerAction(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function DisablePlayerControls()
	if ControlsDisabled then return end
	ContextActionService:BindActionAtPriority(
		DISABLE_CONTROLS_ACTION_NAME,
		SinkPlayerAction,
		false,
		DISABLE_CONTROLS_PRIORITY,
		table.unpack(Enum.PlayerActions:GetEnumItems())
	)
	ControlsDisabled = true
end

local function EnablePlayerControls()
	if not ControlsDisabled then return end
	ContextActionService:UnbindAction(DISABLE_CONTROLS_ACTION_NAME)
	ControlsDisabled = false
end

local function GetToolInfo(ToolId: string)
	for _, ToolInfo in CleaningConfig.Tools do
		if ToolInfo.Id == ToolId then return ToolInfo end
	end
end

local function GetEquippedCleaningTool(): (Tool?, any?)
	local Character = LocalPlayer.Character
	if not Character then return nil, nil end
	for _, Child in Character:GetChildren() do
		local ToolInfo = ToolResolver.GetCleaningToolInfo(Child)
		if ToolInfo then return Child, ToolInfo end
	end
	return nil, nil
end

local function GetItemRadiusMultiplier(ItemSize: Vector3): number
	local ItemMagnitude = ItemSize.Magnitude
	if ItemMagnitude < CleaningConfig.ItemRadiusScaleStartSize then
		local SmallSizeAlpha = math.clamp(
			(ItemMagnitude - CleaningConfig.ItemRadiusScaleSmallSize)
				/ math.max(CleaningConfig.ItemRadiusScaleStartSize - CleaningConfig.ItemRadiusScaleSmallSize, 0.01),
			0,
			1
		)
		return CleaningConfig.ItemRadiusScaleMaximumMultiplier
			+ (1 - CleaningConfig.ItemRadiusScaleMaximumMultiplier) * SmallSizeAlpha
	end
	local SizeAlpha = math.clamp(
		(ItemMagnitude - CleaningConfig.ItemRadiusScaleStartSize)
			/ math.max(CleaningConfig.ItemRadiusScaleFullSize - CleaningConfig.ItemRadiusScaleStartSize, 0.01),
		0,
		1
	)
	return 1 + (CleaningConfig.ItemRadiusScaleMinimumMultiplier - 1) * SizeAlpha
end

local function IsSurfaceContactTool(ToolInfo): boolean
	return ToolInfo.Id == "Sponge"
		or ToolInfo.Id == "SoftBrush"
		or ToolInfo.Id == "Polisher"
		or ToolInfo.Id == "Hammer"
end

local function GetToolRadiusScale(ToolInfo): number
	local Ownership = DataService:get("Upgrades")
	-- Keep the radius viewport-relative across devices, with only a moderate taper for genuinely large item bounds.
	return (ToolInfo.RadiusScale or CleaningConfig.BrushRadiusScale)
		* CleaningConfig.ToolRadiusMultiplier
		* UpgradeLogic.GetToolRadiusMultiplier(Ownership, ToolInfo.Id)
		* ActiveItemRadiusMultiplier
end

local function GetWorldToolRadius(Camera: Camera, ToolInfo, WorldPosition: Vector3): number
	local CameraPosition = Camera.CFrame:PointToObjectSpace(WorldPosition)
	local Depth = math.max(-CameraPosition.Z, 0.1)
	local ViewHeight = 2 * Depth * math.tan(math.rad(Camera.FieldOfView / 2))
	return GetToolRadiusScale(ToolInfo) * ViewHeight
end

local function UpdateToolInterface()
	local Tool, ToolInfo = GetEquippedCleaningTool()
	local RequiredToolId = RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
	local IsFixing = RuntimeState.Get(LocalPlayer, "IsFixing", false) == true
	if ToolInfo and ToolInfo.Id == RequiredToolId then RequestedToolId = nil end
	if IsFixing and Tool and ToolInfo and ToolInfo.Id ~= RequiredToolId and RequestedToolId ~= ToolInfo.Id then
		RequestedToolId = ToolInfo.Id
		if UsingTool then
			ReportLocalProgress(true)
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			Network:fire("StopUsingTool")
		end
		Network:fire("SelectTool", ToolInfo.Id)
	end
	local IsApplicable = IsFixing
		and Tool ~= nil
		and ToolInfo ~= nil
		and ToolInfo.Id == RequiredToolId
		and RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) ~= true
	RuntimeState.Set(LocalPlayer, "CleaningRadiusVisible", IsApplicable)
	if not IsApplicable then RuntimeState.Set(LocalPlayer, "CleaningBrushRadius", nil) end
	if UsingTool and (not IsApplicable or ToolInfo.Id ~= ActiveToolId) then
		ReportLocalProgress(true)
		UsingTool = false
		ActiveToolId = nil
		StopToolEffects()
		Network:fire("StopUsingTool")
	end
end

local function UpdateFixPrompt()
	if not FixPrompt then return end
	local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
	local ItemInfo = ToolResolver.GetItemInfo(Tool)
	local ItemId = ItemInfo and ItemInfo.Id
	local Fixing = DataService:get("Fixing") or {}
	local State = if type(ItemId) == "number" then Fixing[tostring(ItemId)] else nil
	FixPrompt.Enabled = RuntimeState.Get(LocalPlayer, "IsFixing", false) ~= true
		and type(ItemId) == "number"
		and (type(State) ~= "table" or State.Completed ~= true)
end

local function HideForeignFixPrompt(Descendant: Instance)
	if not Descendant:IsA("ProximityPrompt") or Descendant.Name ~= "FixItemPrompt" then return end
	-- Only the owner should see the interaction prompt on their fixing table.
	if not Descendant:FindFirstAncestor(`Museum_{LocalPlayer.UserId}`) then Descendant.Enabled = false end
end

local function WatchCharacter(Character: Model)
	for _, Connection in CharacterConnections do Connection:Disconnect() end
	CharacterConnections = {
		Character.ChildAdded:Connect(function() task.defer(UpdateFixPrompt); task.defer(UpdateToolInterface) end),
		Character.ChildRemoved:Connect(function() task.defer(UpdateFixPrompt); task.defer(UpdateToolInterface) end),
		Character.DescendantAdded:Connect(function(Descendant)
			if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true and Descendant:IsA("BasePart") then
				HideCharacterPart(Descendant)
			end
		end),
	}
	task.defer(UpdateFixPrompt)
	task.defer(UpdateToolInterface)
end

HideCharacterPart = function(Part: BasePart)
	if HiddenParts[Part] == nil then HiddenParts[Part] = Part.LocalTransparencyModifier end
	Part.LocalTransparencyModifier = 1
end

local function HideCharacter(Character: Model)
	for _, Descendant in Character:GetDescendants() do
		if Descendant:IsA("BasePart") then HideCharacterPart(Descendant) end
	end
end

StopToolEffects = function()
	if ToolLoop then ToolLoop:Stop(); ToolLoop:Destroy(); ToolLoop = nil end
	if ToolEmitter then
		if CreatedToolEmitter then ToolEmitter:Destroy() else ToolEmitter.Enabled = false end
		ToolEmitter = nil
	end
	CreatedToolEmitter = false
	if ToolVFXAttachment then ToolVFXAttachment:Destroy(); ToolVFXAttachment = nil end
	if ToolBeam then ToolBeam:Destroy(); ToolBeam = nil end
	if ToolStartAttachment and CreatedStartAttachment then ToolStartAttachment:Destroy() end
	ToolStartAttachment = nil
	CreatedStartAttachment = false
	if ToolEndAttachment then ToolEndAttachment:Destroy(); ToolEndAttachment = nil end
	if ToolEndPart then ToolEndPart:Destroy(); ToolEndPart = nil end
	SmoothedToolPosition = nil
	CurrentToolColor = nil
end

local function StartToolEffects(Tool: Tool, ToolInfo)
	StopToolEffects()
	local StartObject = Tool:FindFirstChild(ToolInfo.VFXStartPartName, true)
	if not StartObject then return end
	local VFXFolder = if type(ToolInfo.VFXFolderName) == "string" then ReplicatedStorage.Assets.VFX:FindFirstChild(ToolInfo.VFXFolderName) else nil
	local VFXTemplate = if VFXFolder and type(ToolInfo.VFXName) == "string" then VFXFolder:FindFirstChild(ToolInfo.VFXName) else nil
	if VFXTemplate and VFXTemplate:IsA("Beam") then
		if StartObject:IsA("Attachment") then
			ToolStartAttachment = StartObject
		elseif StartObject:IsA("BasePart") then
			ToolStartAttachment = Instance.new("Attachment")
			ToolStartAttachment.Name = "ToolVFXStartAttachment"
			ToolStartAttachment.Parent = StartObject
			CreatedStartAttachment = true
		end
		if ToolStartAttachment then
			ToolEndPart = Instance.new("Part")
			ToolEndPart.Name = "ToolVFXEndpoint"
			ToolEndPart.Anchored = true
			ToolEndPart.CanCollide = false
			ToolEndPart.CanQuery = false
			ToolEndPart.CanTouch = false
			ToolEndPart.Size = Vector3.one * 0.05
			ToolEndPart.Transparency = 1
			ToolEndPart.Parent = Workspace
			ToolEndAttachment = Instance.new("Attachment")
			ToolEndAttachment.Name = "ToolVFXEndAttachment"
			ToolEndAttachment.Parent = ToolEndPart
			ToolBeam = VFXTemplate:Clone()
			ToolBeam.Attachment0 = ToolStartAttachment
			ToolBeam.Attachment1 = ToolEndAttachment
			ToolBeam.Enabled = false
			ToolBeam.Parent = ToolStartAttachment.Parent
		end
	end
	if VFXTemplate and VFXTemplate:IsA("ParticleEmitter") then
		ToolEmitter = VFXTemplate:Clone()
		ToolEmitter.Enabled = true
		ToolEmitter.Parent = StartObject
		CreatedToolEmitter = true
	end
	-- The authored hairdryer wind is a directional attachment containing several emitters.
	if VFXTemplate and VFXTemplate:IsA("Attachment") and StartObject:IsA("BasePart") then
		ToolVFXAttachment = VFXTemplate:Clone()
		ToolVFXAttachment.Name = "ToolVFXAttachment"
		ToolVFXAttachment.Parent = StartObject
		for _, Descendant in ToolVFXAttachment:GetDescendants() do
			if Descendant:IsA("ParticleEmitter") then Descendant.Enabled = true end
		end
	end
	if not ToolEmitter and not ToolVFXAttachment then ToolEmitter = StartObject:FindFirstChildWhichIsA("ParticleEmitter", true) end
	if not ToolEmitter and not ToolVFXAttachment and StartObject.Parent then ToolEmitter = StartObject.Parent:FindFirstChildWhichIsA("ParticleEmitter", true) end
	if ToolEmitter then ToolEmitter.Enabled = true end
	local SoundTemplate = if type(ToolInfo.LoopSoundName) == "string" then Sounds.Get(ToolInfo.LoopSoundName) else nil
	if SoundTemplate then
		ToolLoop = SoundTemplate:Clone()
		ToolLoop.Looped = ToolInfo.Id ~= "Sponge"
		if type(ToolInfo.LoopSoundVolume) == "number" then ToolLoop.Volume = ToolInfo.LoopSoundVolume end
		ToolLoop.RollOffMaxDistance = TOOL_SOUND_MAX_DISTANCE
		ToolLoop.Parent = if StartObject:IsA("Attachment") then StartObject.Parent else StartObject
		-- Sponge bubbles are contact-timed below; one reusable Sound prevents scrub overlap.
		if ToolInfo.Id ~= "Sponge" then ToolLoop:Play() end
	end
end

local function Restore(Instant: boolean?)
	CameraEntryId += 1
	local RestoreId = CameraEntryId
	UsingTool = false
	ActiveToolId = nil
	RequestedToolId = nil
	StopToolEffects()
	if ViewmodelContainer then ViewmodelContainer:Destroy(); ViewmodelContainer = nil end
	ViewmodelTool = nil
	ViewmodelHandle = nil
	ViewmodelSourceTool = nil
	ViewmodelPartOffsets = {}
	SmoothedVisualToolCFrame = nil
	SmoothedFakeArmEndPosition = nil
	SmoothedSurfaceNormal = nil
	FakeArm = nil
	if CameraBound then RunService:UnbindFromRenderStep(CAMERA_BINDING_NAME); CameraBound = false end
	local Camera = Workspace.CurrentCamera
	local CameraType = OriginalCameraType
	local FieldOfView = OriginalFieldOfView
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local TargetCFrame = if OriginalCameraRootOffset and RootPart and RootPart:IsA("BasePart")
		then RootPart.CFrame * OriginalCameraRootOffset
		else OriginalCameraCFrame
	BaseCameraCFrame = nil
	CameraImpulse = 0
	CameraPush = 0
	ActiveItemRadiusMultiplier = 1
	local function FinishRestore()
		if RestoreId ~= CameraEntryId then return end
		for Part, Transparency in HiddenParts do if Part.Parent then Part.LocalTransparencyModifier = Transparency end end
		HiddenParts = {}
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if Humanoid and Humanoid.Parent then Camera.CameraSubject = Humanoid end
		if CameraType then Camera.CameraType = CameraType end
		if FieldOfView then Camera.FieldOfView = FieldOfView end
		EnablePlayerControls()
		OriginalCameraType = nil
		OriginalFieldOfView = nil
		OriginalCameraCFrame = nil
		OriginalCameraRootOffset = nil
	end
	if not Instant and CameraType and TargetCFrame and Camera.CameraType == Enum.CameraType.Scriptable then
		local Tween = TweenService:Create(Camera, TweenInfo.new(CleaningConfig.CameraExitDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = TargetCFrame,
			FieldOfView = FieldOfView or Camera.FieldOfView,
		})
		Tween.Completed:Once(FinishRestore)
		Tween:Play()
	else
		FinishRestore()
	end
	RuntimeState.Set(LocalPlayer, "CleaningRadiusVisible", false)
	RuntimeState.Set(LocalPlayer, "CleaningBrushRadius", nil)
	ClearStepHighlights(true)
	HintStepId = nil
	HintStepStartedAt = 0
	HintStepGeneration += 1
	LocalTargetStates = {}
	LocalStepCaches = {}
	LocalStepId = nil
	LocalStepTotal = 0
	LocalStepRemaining = 0
	LastReportedRemaining = 0
	CompletionRequested = false
	LastCleanPosition = nil
	HammerStrikeStartedAt = nil
	HammerStrikeApplied = false
	HammerStrikeAimPosition = nil
	HammerStrikeSurfaceNormal = nil
	HammerInputHeld = false
end

local function GetScreenWorldPosition(Camera, ScreenPosition, Depth): Vector3
	local ViewportSize = Camera.ViewportSize
	local HalfHeight = Depth * math.tan(math.rad(Camera.FieldOfView / 2))
	local HalfWidth = HalfHeight * ViewportSize.X / math.max(ViewportSize.Y, 1)
	local CameraPosition = Vector3.new((ScreenPosition.X * 2 - 1) * HalfWidth, (1 - ScreenPosition.Y * 2) * HalfHeight, -Depth)
	return Camera.CFrame:PointToWorldSpace(CameraPosition)
end

local function GetCursorPosition(): Vector2
	-- Keep cleaning input in raw screen space so it matches the IgnoreGuiInset HUD.
	if ActiveTouchInput then
		local TouchPosition = Vector2.new(ActiveTouchInput.Position.X, ActiveTouchInput.Position.Y)
		local TouchOffset = Workspace.CurrentCamera.ViewportSize.Y * CleaningConfig.MobileTouchAimOffsetScale
		-- Keep the mobile fixing radius and its actual hit area visible above the player's finger.
		return Vector2.new(TouchPosition.X, math.max(TouchPosition.Y - TouchOffset, 0))
	end
	return UserInputService:GetMouseLocation()
end

local function GetPlayerArmColor(Character): Color3
	for _, Name in { "RightHand", "Right Arm", "RightLowerArm", "RightUpperArm" } do
		local Part = Character:FindFirstChild(Name, true)
		if Part and Part:IsA("BasePart") then return Part.Color end
	end
	local BodyColors = Character:FindFirstChildOfClass("BodyColors")
	return if BodyColors then BodyColors.RightArmColor.Color else Color3.fromRGB(255, 204, 153)
end

local function CreateViewmodelContainer(Character)
	local Camera = Workspace.CurrentCamera
	ViewmodelContainer = Instance.new("Folder")
	ViewmodelContainer.Name = "LocalFixingViewmodel"
	ViewmodelContainer.Parent = Camera
	FakeArm = Instance.new("Part")
	FakeArm.Name = "LocalFixingArm"
	FakeArm.Anchored = true
	FakeArm.CanCollide = false
	FakeArm.CanQuery = false
	FakeArm.CanTouch = false
	FakeArm.CastShadow = false
	FakeArm.Color = GetPlayerArmColor(Character)
	FakeArm.Material = Enum.Material.SmoothPlastic
	FakeArm.Parent = ViewmodelContainer
end

local function DestroyViewmodelTool()
	StopToolEffects()
	if ViewmodelTool then ViewmodelTool:Destroy() end
	ViewmodelTool = nil
	ViewmodelHandle = nil
	ViewmodelSourceTool = nil
	ViewmodelPartOffsets = {}
	SmoothedVisualToolCFrame = nil
	SmoothedFakeArmEndPosition = nil
	SmoothedSurfaceNormal = nil
end

local function CreateViewmodelTool(SourceTool: Tool, ToolInfo)
	DestroyViewmodelTool()
	if not ViewmodelContainer then return end
	local Template = ReplicatedStorage.Assets.Tools:FindFirstChild(ToolInfo.TemplateName)
	if not Template or not Template:IsA("Tool") then return end
	local Clone = Template:Clone()
	local Handle = Clone:FindFirstChild("Handle", true)
	if not Handle or not Handle:IsA("BasePart") then Clone:Destroy(); return end
	Clone.Name = `Local{SourceTool.Name}Viewmodel`
	for _, Descendant in Clone:GetDescendants() do
		if Descendant:IsA("BasePart") then
			ViewmodelPartOffsets[Descendant] = Handle.CFrame:ToObjectSpace(Descendant.CFrame)
			Descendant.Anchored = true
			Descendant.CanCollide = false
			Descendant.CanQuery = false
			Descendant.CanTouch = false
			Descendant.CastShadow = false
			Descendant.LocalTransparencyModifier = 0
		elseif Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") or Descendant:IsA("Trail") then
			Descendant.Enabled = false
		elseif Descendant:IsA("LuaSourceContainer") then
			Descendant:Destroy()
		end
	end
	for _, Descendant in Clone:GetDescendants() do
		if Descendant:IsA("Weld") or Descendant:IsA("WeldConstraint") or Descendant:IsA("Motor6D") then Descendant:Destroy() end
	end
	Clone.Parent = ViewmodelContainer
	ViewmodelTool = Clone
	ViewmodelHandle = Handle
	ViewmodelSourceTool = SourceTool
end

local function GetFixingCameraCFrame(Camera: Camera, CameraPart: BasePart, TableSurface: BasePart, Box: BasePart): CFrame
	local TargetPosition = Box.Position
	local SurfaceNormal = TableSurface.CFrame.UpVector
	local FrontDirection = CameraPart.Position - TargetPosition
	FrontDirection -= SurfaceNormal * FrontDirection:Dot(SurfaceNormal)
	if FrontDirection.Magnitude < 0.01 then
		FrontDirection = -TableSurface.CFrame.LookVector
	else
		FrontDirection = FrontDirection.Unit
	end

	local Elevation = math.rad(CleaningConfig.ItemCameraElevationDegrees)
	local ViewDirection = (FrontDirection * math.cos(Elevation) + SurfaceNormal * math.sin(Elevation)).Unit
	local VerticalFieldOfView = math.rad(CleaningConfig.CameraFieldOfView)
	local AspectRatio = Camera.ViewportSize.X / math.max(Camera.ViewportSize.Y, 1)
	local HorizontalFieldOfView = 2 * math.atan(math.tan(VerticalFieldOfView / 2) * AspectRatio)
	local HalfHeight = Box.Size.Y / 2
	-- The item rotates during restoration, so frame its full yaw envelope instead of only its starting orientation.
	local FootprintRadius = Vector2.new(Box.Size.X, Box.Size.Z).Magnitude / 2
	local VerticalExtent = HalfHeight * math.cos(Elevation) + FootprintRadius * math.sin(Elevation)
	local DepthExtent = HalfHeight * math.sin(Elevation) + FootprintRadius * math.cos(Elevation)
	local RequiredFitDistance = math.max(
		FootprintRadius / math.max(math.tan(HorizontalFieldOfView / 2), 0.01),
		VerticalExtent / math.max(math.tan(VerticalFieldOfView / 2), 0.01)
	)
	local ItemSize = Box.Size.Magnitude
	local SmallItemFactor = 1 - math.clamp(
		(ItemSize - CleaningConfig.ItemCameraSmallSize)
			/ math.max(CleaningConfig.ItemCameraLargeSize - CleaningConfig.ItemCameraSmallSize, 0.01),
		0,
		1
	)
	local Margin = CleaningConfig.ItemCameraLargeItemMargin
		+ (CleaningConfig.ItemCameraSmallItemMargin - CleaningConfig.ItemCameraLargeItemMargin) * SmallItemFactor
	local Distance = math.max(CleaningConfig.ItemCameraNearDistance, DepthExtent + RequiredFitDistance * Margin)
	return CFrame.lookAt(TargetPosition + ViewDirection * Distance, TargetPosition, SurfaceNormal)
end

local function EnterFixingView()
	local IsFixing = RuntimeState.Get(LocalPlayer, "IsFixing", false) == true
	Restore(IsFixing)
	if not IsFixing then return end
	local EntryId = CameraEntryId
	task.spawn(function()
		local Character, Camera, CameraPart, TableSurface, Box
		local Deadline = os.clock() + CAMERA_SETUP_TIMEOUT
		repeat
			Character = LocalPlayer.Character
			Camera = Workspace.CurrentCamera
			local Museums = Workspace:FindFirstChild("PlayerMuseums")
			local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
			local TableModel = Museum and Museum:FindFirstChild("Table")
			CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
			TableSurface = TableModel and TableModel:FindFirstChild("PromptPart")
			local FixingItem = Museum and Museum:FindFirstChild(`FixingItem_{LocalPlayer.UserId}`)
			Box = FixingItem and FixingItem:FindFirstChild("BoundingBox")
			if Character and Camera
				and CameraPart and CameraPart:IsA("BasePart")
				and TableSurface and TableSurface:IsA("BasePart")
				and Box and Box:IsA("BasePart")
			then break end
			RunService.Heartbeat:Wait()
		until os.clock() >= Deadline
			or EntryId ~= CameraEntryId
			or RuntimeState.Get(LocalPlayer, "IsFixing", false) ~= true

		if EntryId ~= CameraEntryId or RuntimeState.Get(LocalPlayer, "IsFixing", false) ~= true then return end
		if not Character or not Camera
			or not CameraPart or not CameraPart:IsA("BasePart")
			or not TableSurface or not TableSurface:IsA("BasePart")
			or not Box or not Box:IsA("BasePart")
		then
			warn("Fixing camera setup timed out while waiting for the restoration item")
			Network:fire("Exit")
			return
		end

		DisablePlayerControls()
		ActiveItemRadiusMultiplier = GetItemRadiusMultiplier(Box.Size)
		OriginalFieldOfView = Camera.FieldOfView
		OriginalCameraType = Camera.CameraType
		OriginalCameraCFrame = Camera.CFrame
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		OriginalCameraRootOffset = if RootPart and RootPart:IsA("BasePart")
			then RootPart.CFrame:ToObjectSpace(Camera.CFrame)
			else nil
		Camera.CameraType = Enum.CameraType.Scriptable
		BaseCameraCFrame = GetFixingCameraCFrame(Camera, CameraPart, TableSurface, Box)
		local EntryComplete = false
		local EntryTween = TweenService:Create(Camera, TweenInfo.new(CleaningConfig.CameraEntryDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = BaseCameraCFrame,
			FieldOfView = CleaningConfig.CameraFieldOfView,
		})
		EntryTween.Completed:Once(function()
			if EntryId == CameraEntryId then EntryComplete = true end
		end)
		EntryTween:Play()
		task.delay(CleaningConfig.CameraEntryDuration * 0.3, function()
			if EntryId ~= CameraEntryId or not Character.Parent then return end
			HideCharacter(Character)
			CreateViewmodelContainer(Character)
		end)
		RunService:BindToRenderStep(CAMERA_BINDING_NAME, Enum.RenderPriority.Last.Value, function(DeltaTime)
			if not CameraPart.Parent or not TableSurface.Parent or not Box.Parent then
				Restore()
				Network:fire("Exit")
				return
			end
			if EntryComplete and BaseCameraCFrame and EntryId == CameraEntryId then
				CameraImpulse *= math.exp(-18 * DeltaTime)
				local DesiredPush = if RuntimeState.Get(LocalPlayer, "CleaningRestorationComplete", false) == true then 0.22 else CameraPush
				CameraPush += (DesiredPush - CameraPush) * (1 - math.exp(-7 * DeltaTime))
				Camera.CFrame = BaseCameraCFrame * CFrame.new(0, 0, -(CameraPush + CameraImpulse))
			end
			if UpdateVisualTool then UpdateVisualTool(DeltaTime) end
		end)
		CameraBound = true
		task.defer(UpdateToolInterface)
		task.defer(UpdateStepHints)
	end)
end

GetFixingItemModel = function(): Model?
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	if not Museum then return nil end
	local Model = Museum:FindFirstChild(`FixingItem_{LocalPlayer.UserId}`)
	return if Model and Model:IsA("Model") then Model else nil
end

local function RaycastFixingItem(
	Camera: Camera,
	ScreenPosition: Vector2,
	Parameters: RaycastParams,
	RayLength: number
): RaycastResult?
	local Ray = Camera:ViewportPointToRay(ScreenPosition.X, ScreenPosition.Y)
	return Workspace:Raycast(Ray.Origin, Ray.Direction * RayLength, Parameters)
end

local function GetAimPosition(ToolInfo): (Vector3?, BasePart?, Vector3?)
	local Camera = Workspace.CurrentCamera
	local MousePosition = GetCursorPosition()
	local FixingItem = GetFixingItemModel()
	if not FixingItem then return nil, nil, nil end
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Include
	Parameters.FilterDescendantsInstances = { FixingItem }
	local Box = FixingItem:FindFirstChild("BoundingBox")
	local RayLength = if Box and Box:IsA("BasePart")
		then (Camera.CFrame.Position - Box.Position).Magnitude + Box.Size.Magnitude
		else 30
	local Result = RaycastFixingItem(Camera, MousePosition, Parameters, RayLength)
	if not Result then return nil, nil, nil end
	if not ToolInfo or not IsSurfaceContactTool(ToolInfo) then
		return Result.Position, if Result.Instance:IsA("BasePart") then Result.Instance else nil, Result.Normal
	end

	-- Average only genuinely nearby geometry so layered parts at different depths cannot shake the tool.
	local ScreenRadius = GetToolRadiusScale(ToolInfo)
		* Camera.ViewportSize.Y
		* CleaningConfig.SurfaceNormalSampleRadiusMultiplier
	local WorldRadius = GetWorldToolRadius(Camera, ToolInfo, Result.Position)
		* CleaningConfig.SurfaceNormalSampleRadiusMultiplier
	local NormalSum = Result.Normal * CleaningConfig.SurfaceNormalCenterWeight
	local TotalWeight = CleaningConfig.SurfaceNormalCenterWeight
	for SampleIndex = 1, CleaningConfig.SurfaceNormalSampleCount do
		local RadiusAlpha = math.sqrt(SampleIndex / CleaningConfig.SurfaceNormalSampleCount)
		local Angle = SampleIndex * CleaningConfig.SurfaceNormalSampleAngle
		local SampleOffset = Vector2.new(math.cos(Angle), math.sin(Angle)) * ScreenRadius * RadiusAlpha
		local SampleResult = RaycastFixingItem(Camera, MousePosition + SampleOffset, Parameters, RayLength)
		if SampleResult then
			local Distance = (SampleResult.Position - Result.Position).Magnitude
			if Distance <= WorldRadius then
				local DistanceAlpha = Distance / math.max(WorldRadius, 0.001)
				local Weight = CleaningConfig.SurfaceNormalMinimumSampleWeight
					+ (1 - CleaningConfig.SurfaceNormalMinimumSampleWeight) * (1 - DistanceAlpha) ^ 2
				NormalSum += SampleResult.Normal * Weight
				TotalWeight += Weight
			end
		end
	end
	local AverageNormal = NormalSum / TotalWeight
	if AverageNormal.Magnitude < 0.01 then AverageNormal = Result.Normal end
	return Result.Position, if Result.Instance:IsA("BasePart") then Result.Instance else nil, AverageNormal.Unit
end

local function GetAirflowDirection(AimPosition: Vector3, Origin: Vector3): Vector3?
	local Offset = AimPosition - Origin
	return if Offset.Magnitude > 0.01 then Offset.Unit else nil
end

local function UpdateDirectionalToolEffects(AimPosition: Vector3?)
	if not AimPosition or not ToolVFXAttachment then return end
	local Parent = ToolVFXAttachment.Parent
	if not Parent or not Parent:IsA("BasePart") then return end
	local Origin = ToolVFXAttachment.WorldPosition
	local Up = GetAirflowDirection(AimPosition, Origin)
	if not Up then return end
	local Camera = Workspace.CurrentCamera
	local Right = Camera.CFrame.RightVector - Up * Camera.CFrame.RightVector:Dot(Up)
	if Right.Magnitude < 0.01 then Right = Camera.CFrame.UpVector - Up * Camera.CFrame.UpVector:Dot(Up) end
	Right = Right.Unit
	local Back = Right:Cross(Up).Unit
	ToolVFXAttachment.CFrame = Parent.CFrame:ToObjectSpace(CFrame.fromMatrix(Origin, Right, Up, Back))
end

local function GetItemInfo(ItemId: number)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
end

local function RemoveTargetHighlight(Target: BasePart, Instant: boolean?)
	local Highlight = TargetHighlights[Target]
	local Transparency = TargetHintTransparencies[Target]
	TargetHighlights[Target] = nil
	TargetHintTransparencies[Target] = nil
	if Target.Parent and Transparency ~= nil then Target.Transparency = Transparency end
	if not Highlight then return end
	if Instant or not Highlight.Parent then
		Highlight:Destroy()
		return
	end
	local Tween = TweenService:Create(Highlight, TweenInfo.new(CleaningConfig.StepHintFadeDuration), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	Tween.Completed:Once(function()
		Highlight:Destroy()
	end)
	Tween:Play()
end

ClearStepHighlights = function(Instant: boolean?)
	local HighlightedTargets = {}
	for Target in TargetHighlights do table.insert(HighlightedTargets, Target) end
	for _, Target in HighlightedTargets do RemoveTargetHighlight(Target, Instant) end
end

local function AddTargetHighlight(Target: BasePart)
	if TargetHighlights[Target] or not Target.Parent then return end
	-- Highlight does not reliably render over translucent targets, so preserve their live value and make hints opaque locally.
	TargetHintTransparencies[Target] = Target.Transparency
	Target.Transparency = 0
	local Highlight = Instance.new("Highlight")
	Highlight.Name = "RestorationHintHighlight"
	Highlight.Adornee = Target
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillColor = CleaningConfig.StepHintFillColor
	Highlight.FillTransparency = 1
	Highlight.OutlineColor = CleaningConfig.StepHintOutlineColor
	Highlight.OutlineTransparency = 1
	Highlight.Parent = Target
	TargetHighlights[Target] = Highlight
	TweenService:Create(Highlight, TweenInfo.new(CleaningConfig.StepHintFadeDuration, Enum.EasingStyle.Quad), {
		FillTransparency = CleaningConfig.StepHintFillTransparency,
		OutlineTransparency = CleaningConfig.StepHintOutlineTransparency,
	}):Play()
end

local function SetHintAwareTransparency(Target: BasePart, Transparency: number)
	if TargetHighlights[Target] then
		TargetHintTransparencies[Target] = Transparency
		Target.Transparency = 0
	else
		Target.Transparency = Transparency
	end
end

local function ResetLocalStep()
	LocalTargetStates = {}
	LocalStepId = nil
	LocalStepTotal = 0
	LocalStepRemaining = 0
	LastReportedRemaining = 0
	LastProgressReport = 0
	CompletionRequested = false
	LastCleanPosition = nil
end

local function FinishRemainingTargets(ToolId: string)
	local Step = CleaningConfig.GetStep(ToolId)
	if not Step then return end
	RuntimeState.Set(LocalPlayer, "CleaningStepName", "Finishing...")
	local RemainingStates = {}
	for _, State in LocalTargetStates do
		if not State.Completed and State.Part.Parent then table.insert(RemainingStates, State) end
	end
	if LastCleanPosition then
		table.sort(RemainingStates, function(A, B)
			return (A.Part.Position - LastCleanPosition).Magnitude < (B.Part.Position - LastCleanPosition).Magnitude
		end)
	end
	local Duration = CleaningConfig.AssistedCleanupDuration
	for Index, State in RemainingStates do
		local Target = State.Part
		local Delay = (#RemainingStates > 1 and (Index - 1) / (#RemainingStates - 1) or 0) * Duration * 0.35
			task.delay(Delay, function()
				if not CompletionRequested or not Target.Parent then return end
				if (Step.Type == "Paint" or Step.Type == "Polish") and State.OriginalAppearance then
					TweenService:Create(Target, TweenInfo.new(Duration * 0.65, Enum.EasingStyle.Quad), {
						Color = State.OriginalAppearance.Color,
						Transparency = State.OriginalAppearance.Transparency,
					}):Play()
				elseif Step.Type == "Bent" and State.CurrentRelativeCFrame and State.RestoredRelativeCFrame then
					local Transform = Instance.new("CFrameValue")
					Transform.Value = State.CurrentRelativeCFrame
					local Connection = Transform:GetPropertyChangedSignal("Value"):Connect(function()
						if CompletionRequested and Target.Parent then State.CurrentRelativeCFrame = Transform.Value end
					end)
					local Tween = TweenService:Create(Transform, TweenInfo.new(Duration * 0.65, Enum.EasingStyle.Quad), {
						Value = State.RestoredRelativeCFrame,
					})
					Tween.Completed:Once(function()
						Connection:Disconnect()
						Transform:Destroy()
					end)
					Tween:Play()
				else
					TweenService:Create(Target, TweenInfo.new(Duration * 0.65, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
				end
			end)
	end
	task.delay(Duration, function()
		if not CompletionRequested or LocalStepId ~= ToolId then return end
		for _, State in RemainingStates do
			if not State.Part.Parent then continue end
			State.Completed = true
			if (Step.Type == "Paint" or Step.Type == "Polish") and State.OriginalAppearance then
				PaintRenderer.ApplyAppearance(State.Part, State.OriginalAppearance)
			elseif Step.Type == "Bent" then
				State.CurrentHealth = 0
				State.CurrentRelativeCFrame = State.RestoredRelativeCFrame
			else
				State.Part:Destroy()
			end
		end
		if Step.Type == "Bent" then UpdateHammerPresentation() end
		LocalStepRemaining = 0
		RuntimeState.Set(LocalPlayer, "CleaningProgress", 1)
		ReportLocalProgress(true)
		Network:fire("CompleteStep", ToolId)
	end)
end

local function PrepareLocalStep(ToolId: string): boolean
	if LocalStepId and #LocalTargetStates > 0 then
		LocalStepCaches[LocalStepId] = {
			TargetStates = LocalTargetStates,
			Total = LocalStepTotal,
			Remaining = LocalStepRemaining,
			LastReportedRemaining = LastReportedRemaining,
			CompletionRequested = CompletionRequested,
		}
	end
	local CachedStep = LocalStepCaches[ToolId]
	if CachedStep then
		LocalTargetStates = CachedStep.TargetStates
		LocalStepId = ToolId
		LocalStepTotal = CachedStep.Total
		LocalStepRemaining = CachedStep.Remaining
		LastReportedRemaining = CachedStep.LastReportedRemaining
		CompletionRequested = CachedStep.CompletionRequested
		return #LocalTargetStates > 0
	end
	ResetLocalStep()
	local Step = CleaningConfig.GetStep(ToolId)
	local Model = GetFixingItemModel()
	local ItemId = RuntimeState.Get(LocalPlayer, "CleaningItemId")
	local ItemInfo = if type(ItemId) == "number" then GetItemInfo(ItemId) else nil
	if not Step or not Model or not ItemInfo then return false end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then Template = nil end

	local Targets = {}
	local OriginalAppearances = {}
	local SavedTargetCount = RuntimeState.Get(LocalPlayer, "CleaningStepRemaining", 2)
	if Step.Type == "Dirt" then
		local Dirt = Model:FindFirstChild("Dirt")
		if Dirt then
			for _, Target in Dirt:GetChildren() do
				if Target:IsA("BasePart") then table.insert(Targets, Target) end
			end
		end
	elseif Step.Type == "Grease" then
		local Grease = Model:FindFirstChild("Grease")
		if Grease then
			for _, Target in Grease:GetChildren() do
				if Target:IsA("BasePart") then table.insert(Targets, Target) end
			end
		end
	elseif Step.Type == "Paint" or Step.Type == "Polish" then
		Targets = PaintRenderer.GetPaintParts(Model)
		if Template then
			for _, Target in Targets do
				local Appearance = PaintRenderer.GetOriginalAppearance(Model, Target, Template)
				if Step.Type == "Paint" and RuntimeState.Get(LocalPlayer, "CleaningPolishCompleted") ~= true and Appearance then
					Appearance = table.clone(Appearance)
					Appearance.Color = PaintRenderer.GetDullColor(Appearance.Color)
				elseif Step.Type == "Polish" and RuntimeState.Get(LocalPlayer, "CleaningPaintCompleted") ~= true then
					Appearance = {
						BrickColor = Target.BrickColor,
						Color = PaintRenderer.GetCleanerColor(Target.Color),
						Material = Target.Material,
						MaterialVariant = Target.MaterialVariant,
						Reflectance = Target.Reflectance,
						Transparency = Target.Transparency,
					}
				end
				OriginalAppearances[Target] = Appearance
			end
		end
	elseif Step.Type == "Bent" then
		Targets = RestorationTargetRenderer.GetBentTargets(Model, SavedTargetCount)
	else
		local FolderName = if Step.Type == "Bent" and Model:FindFirstChild("BentComponents")
			then "BentComponents"
			elseif Step.Type == "Metal" and Model:FindFirstChild("MetalComponents") then "MetalComponents" else Step.Type
		local Folder = Model:FindFirstChild(FolderName)
		if Folder then
			for _, Target in Folder:GetChildren() do
				if Target:IsA("BasePart") then table.insert(Targets, Target) end
			end
		end
	end

	local MaximumHealth = if Step.Type == "Dirt" then ItemInfo.DirtHP else Step.TargetHP
	local BendRotation = if Step.Type == "Bent"
		then Step.BendRotationDegrees or Vector3.new(28, -18, 12)
		else nil
	local DamageRotation = if BendRotation
		then CFrame.Angles(math.rad(BendRotation.X), math.rad(BendRotation.Y), math.rad(BendRotation.Z))
		else nil
	-- Reverse the exact authored bend locally so every Hammer target has a reliable repair orientation.
	for _, Target in Targets do
		local CurrentHealth = MaximumHealth
		local StartCFrame = Target.CFrame
		local Box = if Step.Type == "Bent" then Model:FindFirstChild("BoundingBox") else nil
		local CurrentRelativeCFrame = if Box and Box:IsA("BasePart") then Box.CFrame:ToObjectSpace(Target.CFrame) else nil
		local RestoredRelativeCFrame = if Box and Box:IsA("BasePart") and DamageRotation
			then Box.CFrame:ToObjectSpace(Target.CFrame * DamageRotation:Inverse())
			else nil
		table.insert(LocalTargetStates, {
			Part = Target,
			CurrentHealth = CurrentHealth,
			MaximumHealth = MaximumHealth,
			DamagedColor = Target.Color,
			OriginalAppearance = OriginalAppearances[Target],
			StartCFrame = StartCFrame,
			CurrentRelativeCFrame = CurrentRelativeCFrame,
			DamagedRelativeCFrame = CurrentRelativeCFrame,
			RestoredRelativeCFrame = RestoredRelativeCFrame,
			BaseTransparency = Target.Transparency,
			Completed = CurrentHealth <= 0,
		})
	end
	local ExpectedTargetCount = math.max(0, math.round(SavedTargetCount))
	if #LocalTargetStates < ExpectedTargetCount then
		-- The item model and target folder can replicate before all target parts. Leave the step
		-- unprepared so held cleaning input retries as the remaining descendants arrive.
		ResetLocalStep()
		return false
	end
	LocalStepId = ToolId
	LocalStepTotal = RuntimeState.Get(LocalPlayer, "CleaningStepTotal", #Targets)
	LocalStepRemaining = SavedTargetCount
	LastReportedRemaining = LocalStepRemaining
	return #LocalTargetStates > 0
end

UpdateStepHints = function()
	local IsFixing = RuntimeState.Get(LocalPlayer, "IsFixing", false) == true
	local ToolId = RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
	local IsComplete = RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) == true
	if not IsFixing or type(ToolId) ~= "string" or IsComplete then
		if HintStepId then
			ClearStepHighlights(true)
			HintStepGeneration += 1
		end
		HintStepId = nil
		HintStepStartedAt = 0
		return
	end

	if HintStepId ~= ToolId then
		ClearStepHighlights(true)
		HintStepId = ToolId
		HintStepStartedAt = os.clock()
		HintStepGeneration += 1
		local ScheduledGeneration = HintStepGeneration
		local Step = CleaningConfig.GetStep(ToolId)
		if Step and Step.Type ~= "Bent" then
			task.delay(CleaningConfig.StepHintDelay, function()
				if ScheduledGeneration == HintStepGeneration then UpdateStepHints() end
			end)
		end
	end
	if LocalStepId ~= ToolId and not PrepareLocalStep(ToolId) then return end

	local Step = CleaningConfig.GetStep(ToolId)
	-- Hammer damage should be obvious immediately; other steps reveal remaining targets after the player stalls.
	local ShouldShow = Step and (Step.Type == "Bent" or os.clock() - HintStepStartedAt >= CleaningConfig.StepHintDelay)
	if not ShouldShow or CompletionRequested then
		ClearStepHighlights(true)
		return
	end

	local RemainingTargets = {}
	for _, State in LocalTargetStates do
		if not State.Completed and State.CurrentHealth > 0 and State.Part.Parent then
			RemainingTargets[State.Part] = true
			AddTargetHighlight(State.Part)
		end
	end
	local HighlightedTargets = {}
	for Target in TargetHighlights do table.insert(HighlightedTargets, Target) end
	for _, Target in HighlightedTargets do
		if not RemainingTargets[Target] then RemoveTargetHighlight(Target, false) end
	end
end

ReportLocalProgress = function(Force: boolean)
	if not LocalStepId or LocalStepRemaining == LastReportedRemaining then return end
	local Now = os.clock()
	if not Force and Now - LastProgressReport < 0.15 then return end
	LastProgressReport = Now
	LastReportedRemaining = LocalStepRemaining
	Network:fire("ReportProgress", LocalStepId, LocalStepRemaining)
end

local function PlayLocalDirtFeedback(Target: BasePart)
	local OriginalSize = Target.Size
	local OriginalColor = Target.Color
	local Tween = TweenService:Create(Target, TweenInfo.new(0.06, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = OriginalSize * Vector3.new(1.18, 0.82, 1.12),
		Color = OriginalColor:Lerp(Color3.new(1, 1, 1), 0.7),
	})
	Tween.Completed:Once(function()
		if Target.Parent then
			TweenService:Create(Target, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = OriginalSize,
				Color = OriginalColor,
			}):Play()
		end
	end)
	Tween:Play()
	local Now = os.clock()
	if Now - LastDirtFeedback >= 0.16 then
		LastDirtFeedback = Now
		local Model = GetFixingItemModel()
		if Model then Sounds.Play(CleaningConfig.DirtDamageSoundName, Model.PrimaryPart or Model, TOOL_SOUND_MAX_DISTANCE) end
	end
end

local function GetLocalProgress(): number
	local PartialProgress = 0
	for _, State in LocalTargetStates do
		if not State.Completed and State.MaximumHealth > 0 then
			PartialProgress += 1 - math.clamp(State.CurrentHealth / State.MaximumHealth, 0, 1)
		end
	end
	return math.clamp((LocalStepTotal - LocalStepRemaining + PartialProgress) / math.max(LocalStepTotal, 1), 0, 1)
end

UpdateHammerPresentation = function()
	if LocalStepId ~= "Hammer"
		or RuntimeState.Get(LocalPlayer, "CleaningStepToolId") ~= "Hammer"
		or RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) == true
	then return end
	local Model = GetFixingItemModel()
	local Box = Model and Model:FindFirstChild("BoundingBox")
	if not Model or not Box or not Box:IsA("BasePart") then return end
	for _, State in LocalTargetStates do
		if State.Part.Parent and State.CurrentRelativeCFrame then
			State.Part.CFrame = Box.CFrame * State.CurrentRelativeCFrame
		end
	end
	local LocalProgress = GetLocalProgress()
	local DisplayedProgress = RuntimeState.Get(LocalPlayer, "CleaningProgress", 0)
	-- Hammer progress is client-owned and monotonic for the duration of the active step.
	if type(DisplayedProgress) ~= "number" or DisplayedProgress < LocalProgress then
		RuntimeState.Set(LocalPlayer, "CleaningProgress", LocalProgress)
	end
end

local function GetProjectedDistanceToPart(AimPosition: Vector3, Part: BasePart): number
	local Camera = Workspace.CurrentCamera
	local AimDirection = Camera.CFrame:VectorToObjectSpace((AimPosition - Camera.CFrame.Position).Unit)
	local PartPosition = Camera.CFrame:PointToObjectSpace(Part.Position)
	local Depth = -PartPosition.Z
	if Depth <= 0.01 or AimDirection.Z >= -0.001 then return math.huge end
	local RayPosition = AimDirection * (Depth / -AimDirection.Z)
	local HalfSize = Part.Size / 2
	local CameraRight = Camera.CFrame.RightVector
	local CameraUp = Camera.CFrame.UpVector
	local HorizontalExtent = math.abs(CameraRight:Dot(Part.CFrame.RightVector)) * HalfSize.X
		+ math.abs(CameraRight:Dot(Part.CFrame.UpVector)) * HalfSize.Y
		+ math.abs(CameraRight:Dot(Part.CFrame.LookVector)) * HalfSize.Z
	local VerticalExtent = math.abs(CameraUp:Dot(Part.CFrame.RightVector)) * HalfSize.X
		+ math.abs(CameraUp:Dot(Part.CFrame.UpVector)) * HalfSize.Y
		+ math.abs(CameraUp:Dot(Part.CFrame.LookVector)) * HalfSize.Z
	local HorizontalDistance = math.max(math.abs(PartPosition.X - RayPosition.X) - HorizontalExtent, 0)
	local VerticalDistance = math.max(math.abs(PartPosition.Y - RayPosition.Y) - VerticalExtent, 0)
	local ViewHeight = 2 * Depth * math.tan(math.rad(Camera.FieldOfView / 2))
	return Vector2.new(HorizontalDistance, VerticalDistance).Magnitude / math.max(ViewHeight, 0.001)
end

local function UpdateSpongeBubbleSound(GreaseTargetCount: number)
	if GreaseTargetCount <= 0 or not ToolLoop then return end
	local MaximumRateTargetCount = math.max(CleaningConfig.SpongeBubbleTargetsForMaximumRate, 1)
	local GreaseAmount = math.clamp((GreaseTargetCount - 1) / math.max(MaximumRateTargetCount - 1, 1), 0, 1)
	local Interval = CleaningConfig.SpongeBubbleMaximumInterval
		+ (CleaningConfig.SpongeBubbleMinimumInterval - CleaningConfig.SpongeBubbleMaximumInterval) * GreaseAmount
	Interval = math.max(Interval, CleaningConfig.SpongeBubbleMinimumInterval)
	local Now = os.clock()
	if Now - LastSpongeBubbleSound < Interval then return end

	LastSpongeBubbleSound = Now
	ToolLoop.TimePosition = 0
	ToolLoop:Play()
end

local function ApplyToolLocally(ToolInfo, DeltaTime: number, AimPosition: Vector3?)
	-- Restoration interaction is intentionally client-authoritative so feedback never waits on network latency.
	if LocalStepId ~= ToolInfo.Id and not PrepareLocalStep(ToolInfo.Id) then return end
	local Step = CleaningConfig.GetStep(ToolInfo.Id)
	if not Step or CompletionRequested then return end
	local Ownership = DataService:get("Upgrades")
	local Strength = ToolInfo.StrengthPerSecond
		* CleaningConfig.ToolStrengthMultiplier
		* UpgradeLogic.GetToolStrengthMultiplier(Ownership, ToolInfo.Id)
	local RadiusScale = GetToolRadiusScale(ToolInfo)
	local ProgressChanged = false
	local AppliedToTarget = false
	local GreaseTargetCount = 0
	local AffectedTargetStates = {}
	local TargetsInRadius = 0
	local NearestTargetState
	local NearestTargetDistance = math.huge

	for _, State in LocalTargetStates do
		local Target = State.Part
		if State.Completed or not Target.Parent then continue end
		-- Project the cleaning circle through the active item's full depth; same-item geometry never occludes targets.
		if not AimPosition then continue end
		local Distance = GetProjectedDistanceToPart(AimPosition, Target)
		if Distance > RadiusScale then continue end
		TargetsInRadius += 1
		if Step.Type == "Bent" then
			-- A hammer strike still affects only the nearest part, but every part in range contributes to slowdown.
			if Distance < NearestTargetDistance then
				NearestTargetState = State
				NearestTargetDistance = Distance
			end
		else
			table.insert(AffectedTargetStates, State)
		end
	end
	if NearestTargetState then table.insert(AffectedTargetStates, NearestTargetState) end
	-- Every additional target adds a gentle penalty, capped so clustered work never drops below half speed.
	local SlowdownDivisor = math.min(
		CleaningConfig.MaximumMultiTargetSlowdown,
		1 + math.max(TargetsInRadius - 1, 0) * CleaningConfig.MultiTargetSlowdownPerAdditionalTarget
	)
	local Damage = if Step.Type == "Bent"
		-- A base Hammer realigns one isolated target in exactly three hits; upgrades still improve it.
		then Step.TargetHP / (ToolInfo.HitsPerTarget or 3)
			* UpgradeLogic.GetToolStrengthMultiplier(Ownership, ToolInfo.Id)
			/ SlowdownDivisor
		else Strength * math.clamp(DeltaTime, 0, 0.2) / SlowdownDivisor
	local EffectDeltaTime = DeltaTime * CleaningConfig.ToolStrengthMultiplier / SlowdownDivisor

	for _, State in AffectedTargetStates do
		local Target = State.Part
		AppliedToTarget = true
		if Step.Type == "Grease" then GreaseTargetCount += 1 end
		local PreviousHealth = State.CurrentHealth
		State.CurrentHealth = math.max(0, PreviousHealth - Damage)
		if Step.Type == "Bent" and State.DamagedRelativeCFrame and State.RestoredRelativeCFrame then
			local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
			State.CurrentRelativeCFrame = if State.CurrentHealth <= 0
				then State.RestoredRelativeCFrame
				else State.DamagedRelativeCFrame:Lerp(State.RestoredRelativeCFrame, RestoredAmount)
			local Model = GetFixingItemModel()
			local Box = Model and Model:FindFirstChild("BoundingBox")
			if Box and Box:IsA("BasePart") then Target.CFrame = Box.CFrame * State.CurrentRelativeCFrame end
		elseif Step.Type == "Dirt" then
			local Now = os.clock()
			if Now - (State.LastFeedback or 0) >= 0.16 then
				State.LastFeedback = Now
				PlayLocalDirtFeedback(Target)
			end
		elseif Step.Type == "Grease" or Step.Type == "LightDust" then
			local BaseTransparency = State.BaseTransparency
			SetHintAwareTransparency(
				Target,
				BaseTransparency + (1 - BaseTransparency) * (1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001))
			)
		elseif Step.Type == "Metal" then
			local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
			local ToolPosition = if SmoothedVisualToolCFrame then SmoothedVisualToolCFrame.Position else Workspace.CurrentCamera.CFrame.Position
			local Direction = (ToolPosition - State.StartCFrame.Position).Unit
			local ResistanceCurve = RestoredAmount ^ 1.7
			Target.CFrame = State.StartCFrame + Direction * (ToolInfo.PullDistance or 1.4) * ResistanceCurve
		elseif Step.Type == "LooseDebris" then
			local ToolPosition = if SmoothedVisualToolCFrame then SmoothedVisualToolCFrame.Position else Workspace.CurrentCamera.CFrame.Position
			local Direction = GetAirflowDirection(AimPosition, ToolPosition)
			if Direction then Target.CFrame += Direction * (ToolInfo.BlowSpeed or 8) * EffectDeltaTime end
			local CurrentTransparency = TargetHintTransparencies[Target] or Target.Transparency
			SetHintAwareTransparency(Target, math.clamp(CurrentTransparency + EffectDeltaTime * 0.9, 0, 1))
		elseif State.OriginalAppearance then
			local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
			Target.Color = State.DamagedColor:Lerp(State.OriginalAppearance.Color, RestoredAmount)
		end

		if PreviousHealth > 0 and State.CurrentHealth <= 0 then
			State.Completed = true
			LocalStepRemaining = math.max(0, LocalStepRemaining - 1)
			ProgressChanged = true
			LastCleanPosition = Target.Position
			CameraImpulse = math.max(CameraImpulse, CleaningConfig.CameraTargetImpulseDistance)
			if Step.Type == "Dirt" or Step.Type == "Grease" or Step.Type == "LightDust" or Step.Type == "LooseDebris" or Step.Type == "Metal" then
				Target:Destroy()
			elseif Step.Type == "Bent" then
				State.CurrentRelativeCFrame = State.RestoredRelativeCFrame
			elseif State.OriginalAppearance then
				PaintRenderer.ApplyAppearance(Target, State.OriginalAppearance)
			end
		end
	end
	if Step.Type == "Grease" then UpdateSpongeBubbleSound(GreaseTargetCount) end
	if AppliedToTarget and Step.Type == "Bent" then
		local Model = GetFixingItemModel()
		if Model then Sounds.Play(ToolInfo.ImpactSoundName, Model.PrimaryPart or Model, TOOL_SOUND_MAX_DISTANCE) end
	end

	if ProgressChanged then
		ReportLocalProgress(false)
		UpdateStepHints()
	end
	local Progress = GetLocalProgress()
	RuntimeState.Set(LocalPlayer, "CleaningProgress", Progress)
	CameraPush = CleaningConfig.CameraFinalPushDistance * math.clamp(
		(Progress - (CleaningConfig.AutoCompletionThreshold - 0.1)) / 0.1,
		0,
		1
	)
	if Progress >= CleaningConfig.AutoCompletionThreshold then
		CompletionRequested = true
		UpdateStepHints()
		UsingTool = false
		ActiveToolId = nil
		HammerInputHeld = false
		StopToolEffects()
		ReportLocalProgress(true)
		FinishRemainingTargets(ToolInfo.Id)
	end
end

local function GetHandleSurfaceOffset(HandleCFrame: CFrame, SurfaceNormal: Vector3): number
	if not ViewmodelHandle then return CleaningConfig.ItemSurfaceOffset end
	local HalfSize = ViewmodelHandle.Size / 2
	local Normal = SurfaceNormal.Unit
	local Extent = math.abs(Normal:Dot(HandleCFrame.RightVector)) * HalfSize.X
		+ math.abs(Normal:Dot(HandleCFrame.UpVector)) * HalfSize.Y
		+ math.abs(Normal:Dot(HandleCFrame.LookVector)) * HalfSize.Z
	return Extent + CleaningConfig.ItemSurfaceOffset
end

local function GetSurfaceToolCFrame(AimPosition: Vector3, SurfaceNormal: Vector3): CFrame
	local Camera = Workspace.CurrentCamera
	local Up = SurfaceNormal.Unit
	local Right = Camera.CFrame.RightVector - Up * Camera.CFrame.RightVector:Dot(Up)
	if Right.Magnitude < 0.01 then Right = Camera.CFrame.UpVector - Up * Camera.CFrame.UpVector:Dot(Up) end
	Right = Right.Unit
	local Back = Right:Cross(Up).Unit
	local SurfaceCFrame = CFrame.fromMatrix(AimPosition, Right, Up, Back)
	local RotationDegrees = CleaningConfig.ToolRotationCorrectionDegrees
	local HandleCFrame = SurfaceCFrame
		* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
	return SurfaceCFrame + Up * GetHandleSurfaceOffset(HandleCFrame, Up)
end

local function GetDesiredToolCFrame(ToolInfo): CFrame
	local Camera = Workspace.CurrentCamera
	local RotationDegrees = ToolInfo.SurfaceRotationDegrees or Vector3.zero
	local ViewportSize = Camera.ViewportSize
	local CursorPosition = GetCursorPosition()
	local CursorDirection = Vector2.new(
		math.clamp(CursorPosition.X / math.max(ViewportSize.X, 1) * 2 - 1, -1, 1),
		math.clamp(CursorPosition.Y / math.max(ViewportSize.Y, 1) * 2 - 1, -1, 1)
	)
	local MovementScale = CleaningConfig.ToolCursorMovementScale
	local ScreenPosition = CleaningConfig.ToolScreenPosition
		+ Vector2.new(CursorDirection.X * MovementScale.X, CursorDirection.Y * MovementScale.Y)
	local ToolPosition = GetScreenWorldPosition(Camera, ScreenPosition, CleaningConfig.ToolCameraDepth)
	local TargetPosition = Camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -10))
	local CursorRotation = CleaningConfig.ToolCursorRotationDegrees
	local DesiredCFrame = CFrame.lookAt(ToolPosition, TargetPosition, Camera.CFrame.UpVector)
		* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
		* CFrame.Angles(math.rad(-CursorDirection.Y * CursorRotation.X), math.rad(CursorDirection.X * CursorRotation.Y), 0)
	return DesiredCFrame * CFrame.new(ToolInfo.IdlePositionOffset or Vector3.zero)
end

local function GetSmoothedSurfaceNormal(SurfaceNormal: Vector3, DeltaTime: number): Vector3
	if not SmoothedSurfaceNormal then
		SmoothedSurfaceNormal = SurfaceNormal.Unit
		return SmoothedSurfaceNormal
	end
	local Blend = 1 - math.exp(-CleaningConfig.SurfaceNormalResponsiveness * DeltaTime)
	local BlendedNormal = SmoothedSurfaceNormal:Lerp(SurfaceNormal.Unit, Blend)
	SmoothedSurfaceNormal = if BlendedNormal.Magnitude > 0.01 then BlendedNormal.Unit else SurfaceNormal.Unit
	return SmoothedSurfaceNormal
end

local function GetSpongeUseCFrame(AimPosition: Vector3, SurfaceNormal: Vector3): CFrame
	local SurfaceCFrame = GetSurfaceToolCFrame(AimPosition, SurfaceNormal)
	local Up = SurfaceCFrame.UpVector
	local Right = SurfaceCFrame.RightVector
	local Back = SurfaceCFrame.LookVector
	local ScrubTime = os.clock() * CleaningConfig.SpongeScrubFrequency
	local ScrubOffset = Right * math.sin(ScrubTime) * CleaningConfig.SpongeScrubDistance
		+ Back * math.sin(ScrubTime * 0.5) * CleaningConfig.SpongeScrubSideDistance
	return SurfaceCFrame + ScrubOffset
end

local function GetHammerUseCFrame(AimPosition: Vector3, SurfaceNormal: Vector3, StrikeProgress: number): CFrame
	local SurfaceCFrame = GetSurfaceToolCFrame(AimPosition, SurfaceNormal)
	local Up = SurfaceCFrame.UpVector
	local ContactProgress = CleaningConfig.HammerContactProgress
	local RaisedAmount = if StrikeProgress <= ContactProgress
		then 1 - StrikeProgress / ContactProgress
		else (StrikeProgress - ContactProgress) / (1 - ContactProgress)
	local Position = SurfaceCFrame.Position + Up * CleaningConfig.HammerStrikeLiftDistance * RaisedAmount
	return (SurfaceCFrame - SurfaceCFrame.Position + Position)
		* CFrame.Angles(math.rad(-CleaningConfig.HammerRaisedAngleDegrees * RaisedAmount), 0, 0)
end

local function StopHammerUse()
	UsingTool = false
	ActiveToolId = nil
	HammerStrikeStartedAt = nil
	HammerStrikeApplied = false
	StopToolEffects()
	ReportLocalProgress(true)
	Network:fire("StopUsingTool")
end

local function StartHammerStrike(AimPosition: Vector3, SurfaceNormal: Vector3)
	HammerStrikeStartedAt = os.clock()
	HammerStrikeApplied = false
	HammerStrikeAimPosition = AimPosition
	HammerStrikeSurfaceNormal = SurfaceNormal
end

local function PositionViewmodelTool(ToolCFrame: CFrame)
	local RotationDegrees = CleaningConfig.ToolRotationCorrectionDegrees
	local CorrectedToolCFrame = ToolCFrame
		* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
	for Part, Offset in ViewmodelPartOffsets do
		if Part.Parent then Part.CFrame = CorrectedToolCFrame * Offset end
	end
end

UpdateVisualTool = function(DeltaTime)
	if RuntimeState.Get(LocalPlayer, "IsFixing", false) ~= true then return end
	UpdateHammerPresentation()
	local Tool, ToolInfo = GetEquippedCleaningTool()
	if Tool ~= ViewmodelSourceTool then
		if Tool and ToolInfo then CreateViewmodelTool(Tool, ToolInfo) else DestroyViewmodelTool() end
	end
	if not Tool or not ToolInfo or not ViewmodelTool or not ViewmodelHandle then
		if FakeArm then FakeArm.Transparency = 1 end
		return
	end
	local DesiredCFrame = GetDesiredToolCFrame(ToolInfo)
	local Responsiveness = ToolInfo.PositionResponsiveness or CleaningConfig.ToolPositionResponsiveness
	local RotationResponsiveness = Responsiveness
	local IsFollowingSurface = false
	local HammerContactPosition: Vector3?
	if ToolInfo.Id == "Hammer" and HammerStrikeStartedAt and HammerStrikeAimPosition and HammerStrikeSurfaceNormal then
		local StrikeDuration = math.max(ToolInfo.StrikeInterval or 0.28, 0.01)
		local StrikeProgress = math.clamp((os.clock() - HammerStrikeStartedAt) / StrikeDuration, 0, 1)
		local SurfaceNormal = GetSmoothedSurfaceNormal(HammerStrikeSurfaceNormal, DeltaTime)
		DesiredCFrame = GetHammerUseCFrame(HammerStrikeAimPosition, SurfaceNormal, StrikeProgress)
		Responsiveness = ToolInfo.PositionResponsiveness or CleaningConfig.ToolPositionResponsiveness
		IsFollowingSurface = true
		if not HammerStrikeApplied and StrikeProgress >= CleaningConfig.HammerContactProgress then
			HammerStrikeApplied = true
			HammerContactPosition = HammerStrikeAimPosition
		end
		if StrikeProgress >= 1 then
			HammerStrikeStartedAt = nil
			if HammerInputHeld then
				local AimPosition, _, SurfaceNormal = GetAimPosition(ToolInfo)
				if AimPosition and SurfaceNormal then StartHammerStrike(AimPosition, SurfaceNormal) end
			else
				StopHammerUse()
			end
		end
	end
	if UsingTool and (ToolInfo.Id == "Sponge" or ToolInfo.Id == "SoftBrush" or ToolInfo.Id == "Polisher") then
		local AimPosition, _, SurfaceNormal = GetAimPosition(ToolInfo)
		if AimPosition and SurfaceNormal then
			DesiredCFrame = GetSpongeUseCFrame(AimPosition, GetSmoothedSurfaceNormal(SurfaceNormal, DeltaTime))
			Responsiveness = CleaningConfig.SpongeSurfaceResponsiveness
			IsFollowingSurface = true
		end
	end
	if not IsFollowingSurface then SmoothedSurfaceNormal = nil end
	if IsFollowingSurface then RotationResponsiveness = CleaningConfig.ToolSurfaceRotationResponsiveness end
	local PositionBlend = 1 - math.exp(-Responsiveness * DeltaTime)
	local RotationBlend = 1 - math.exp(-RotationResponsiveness * DeltaTime)
	if SmoothedVisualToolCFrame then
		local Position = SmoothedVisualToolCFrame.Position:Lerp(DesiredCFrame.Position, PositionBlend)
		local Rotation = SmoothedVisualToolCFrame.Rotation:Lerp(DesiredCFrame.Rotation, RotationBlend)
		SmoothedVisualToolCFrame = Rotation + Position
	else
		SmoothedVisualToolCFrame = DesiredCFrame
	end
	PositionViewmodelTool(SmoothedVisualToolCFrame)
	if HammerContactPosition then
		ApplyToolLocally(ToolInfo, DeltaTime, HammerContactPosition)
	end
	if FakeArm then
		local Camera = Workspace.CurrentCamera
		local ArmStart = GetScreenWorldPosition(Camera, CleaningConfig.FakeArmScreenPosition, CleaningConfig.FakeArmCameraDepth)
		local DesiredArmEnd = SmoothedVisualToolCFrame.Position
		local ArmEndBlend = if IsFollowingSurface
			then 1 - math.exp(-CleaningConfig.FakeArmEndResponsiveness * DeltaTime)
			else 1
		SmoothedFakeArmEndPosition = if SmoothedFakeArmEndPosition
			then SmoothedFakeArmEndPosition:Lerp(DesiredArmEnd, ArmEndBlend)
			else DesiredArmEnd
		local ArmEnd = SmoothedFakeArmEndPosition
		local ArmLength = (ArmEnd - ArmStart).Magnitude
		if ArmLength > 0.01 then
			-- Keep the shoulder fixed while easing only the tool-side endpoint across surface-normal changes.
			FakeArm.Transparency = 0
			FakeArm.Size = Vector3.new(CleaningConfig.FakeArmThickness, CleaningConfig.FakeArmThickness, ArmLength)
			FakeArm.CFrame = CFrame.lookAt(ArmStart:Lerp(ArmEnd, 0.5), ArmEnd)
		else
			FakeArm.Transparency = 1
			SmoothedFakeArmEndPosition = nil
		end
	end
end

function FixingController.Init()
	Network = Networker.client.new("FixingController", FixingController)
	task.spawn(function()
		local Museums = Workspace:WaitForChild("PlayerMuseums")
		for _, Descendant in Museums:GetDescendants() do HideForeignFixPrompt(Descendant) end
		Museums.DescendantAdded:Connect(HideForeignFixPrompt)
		local Museum = Museums:WaitForChild(`Museum_{LocalPlayer.UserId}`)
		FixPrompt = Museum:WaitForChild("Table"):WaitForChild("PromptPart"):WaitForChild("FixItemPrompt") :: ProximityPrompt
		UpdateFixPrompt()
	end)
	RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(function()
		EnterFixingView()
		UpdateFixPrompt()
		task.defer(UpdateStepHints)
	end)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepToolId"):Connect(function()
		RequestedToolId = nil
		UpdateToolInterface()
		task.defer(UpdateStepHints)
	end)
	DataService:getChangedSignal("Fixing"):Connect(UpdateFixPrompt)
	DataService:getChangedSignal("Upgrades"):Connect(UpdateToolInterface)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepComplete"):Connect(function(IsComplete)
		if IsComplete == true then
			UsingTool = false
			ActiveToolId = nil
			HammerInputHeld = false
			HammerStrikeStartedAt = nil
			StopToolEffects()
		end
		-- Tool and completion state can replicate in either order; always refresh radius visibility.
		UpdateToolInterface()
		task.defer(UpdateStepHints)
	end)
	FixingInterface.ExitRequested:Connect(function()
		if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then
			ReportLocalProgress(true)
			Network:fire("Exit")
		end
	end)
	RunService.RenderStepped:Connect(function(DeltaTime)
		local Tool, ToolInfo = GetEquippedCleaningTool()
		local IsApplicable = Tool ~= nil
			and ToolInfo ~= nil
			and RuntimeState.Get(LocalPlayer, "IsFixing", false) == true
			and ToolInfo.Id == RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
			and RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) ~= true
		local AimPosition, AimPart, SurfaceNormal
		if IsApplicable then
			AimPosition, AimPart, SurfaceNormal = GetAimPosition(ToolInfo)
			RuntimeState.Set(LocalPlayer, "CleaningCursorPosition", GetCursorPosition())
			-- Detection uses this viewport-height fraction directly; pixel conversion is only for drawing the HUD circle.
			RuntimeState.Set(LocalPlayer, "CleaningBrushRadius", GetToolRadiusScale(ToolInfo) * Workspace.CurrentCamera.ViewportSize.Y)
		end
		if not UsingTool then return end
		if not Tool or not ToolInfo or ToolInfo.Id ~= ActiveToolId or ToolInfo.Id ~= RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
			or RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) == true
		then
			UsingTool = false
			ActiveToolId = nil
			HammerInputHeld = false
			HammerStrikeStartedAt = nil
			StopToolEffects()
			Network:fire("StopUsingTool")
			return
		end
		local Camera = Workspace.CurrentCamera
		if AimPosition and ToolEndPart and ToolBeam then
			local Blend = 1 - math.exp(-CleaningConfig.SprayEndpointResponsiveness * DeltaTime)
			SmoothedToolPosition = if SmoothedToolPosition then SmoothedToolPosition:Lerp(AimPosition, Blend) else AimPosition
			ToolEndPart.Position = SmoothedToolPosition
			ToolBeam.Enabled = true
			ToolBeam.Width1 = GetWorldToolRadius(Camera, ToolInfo, AimPosition) * 2 * ToolInfo.VFXWidthScale
			if ToolInfo.ColorFromTarget and AimPart then
				local TargetColor = AimPart.Color
				for _, State in LocalTargetStates do
					if State.Part == AimPart and State.OriginalAppearance then
						TargetColor = State.OriginalAppearance.Color
						break
					end
				end
				if CurrentToolColor then
					local ColorBlend = 1 - math.exp(-(ToolInfo.ColorResponsiveness or 14) * DeltaTime)
					CurrentToolColor = CurrentToolColor:Lerp(TargetColor, ColorBlend)
				else
					CurrentToolColor = TargetColor
				end
				ToolBeam.Color = ColorSequence.new(CurrentToolColor)
			end
		elseif ToolBeam then
			ToolBeam.Enabled = false
		end
		UpdateDirectionalToolEffects(AimPosition)
		if ToolInfo.Id == "Hammer" then
			if not HammerStrikeStartedAt and AimPosition and SurfaceNormal then StartHammerStrike(AimPosition, SurfaceNormal) end
		else
			ApplyToolLocally(ToolInfo, DeltaTime, AimPosition)
		end
	end)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningRestorationComplete"):Connect(function(IsComplete)
		if IsComplete == true then
			StopToolEffects()
			CameraImpulse = 0.08
		end
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		local IsPrimaryInput = Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		if IsPrimaryInput and RuntimeState.Get(LocalPlayer, "IsFixing", false) == true and not UsingTool then
			if Input.UserInputType == Enum.UserInputType.Touch then ActiveTouchInput = Input end
			RuntimeState.Set(LocalPlayer, "CleaningCursorPosition", GetCursorPosition())
			local Tool, ToolInfo = GetEquippedCleaningTool()
			if Tool and ToolInfo and ToolInfo.Id == RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
				and RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) ~= true
			then
				UsingTool = true
				ActiveToolId = ToolInfo.Id
				HammerInputHeld = ToolInfo.Id == "Hammer"
				if Tool ~= ViewmodelSourceTool then CreateViewmodelTool(Tool, ToolInfo) end
				if ViewmodelTool then StartToolEffects(ViewmodelTool, ToolInfo) end
				CameraImpulse = math.max(CameraImpulse, CleaningConfig.CameraToolImpulseDistance)
				Network:fire("StartUsingTool", ToolInfo.Id)
				if ToolInfo.Id == "Hammer" then
					local AimPosition, _, SurfaceNormal = GetAimPosition(ToolInfo)
					if AimPosition and SurfaceNormal then StartHammerStrike(AimPosition, SurfaceNormal) end
				end
			end
		elseif Input.KeyCode == Enum.KeyCode.Q and RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then
			ReportLocalProgress(true)
			Network:fire("Exit")
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		local IsActiveTouch = Input == ActiveTouchInput
		local IsPrimaryInput = Input.UserInputType == Enum.UserInputType.MouseButton1 or IsActiveTouch
		if IsPrimaryInput and UsingTool then
			if ActiveToolId == "Hammer" then
				HammerInputHeld = false
				if not HammerStrikeStartedAt then StopHammerUse() end
			else
				ReportLocalProgress(true)
				UsingTool = false
				ActiveToolId = nil
				StopToolEffects()
				Network:fire("StopUsingTool")
			end
		end
		if IsActiveTouch then ActiveTouchInput = nil end
	end)
	EnterFixingView()
end

function FixingController.OnCharacterAdded(Character)
	if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then
		Restore(true)
		Network:fire("Exit")
	end
	WatchCharacter(Character)
end

return FixingController
