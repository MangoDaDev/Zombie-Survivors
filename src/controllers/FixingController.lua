local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
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
local CreatedStartAttachment = false
local SmoothedToolPosition: Vector3?
local SmoothedVisualToolCFrame: CFrame?
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

local CAMERA_BINDING_NAME = "CleaningCameraAndArm"
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

local function GetToolRadius(ToolInfo): number
	local Ownership = DataService:get("Upgrades")
	return ToolInfo.RadiusPixels * UpgradeLogic.GetToolRadiusMultiplier(Ownership, ToolInfo.Id)
end

local function UpdateToolInterface()
	local Tool, ToolInfo = GetEquippedCleaningTool()
	local RequiredToolId = RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
	local IsFixing = RuntimeState.Get(LocalPlayer, "IsFixing", false) == true
	if ToolInfo and ToolInfo.Id == RequiredToolId then RequestedToolId = nil end
	if IsFixing and Tool and ToolInfo and ToolInfo.Id ~= RequiredToolId and RequestedToolId ~= ToolInfo.Id then
		RequestedToolId = ToolInfo.Id
		if UsingTool then
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
	RuntimeState.Set(LocalPlayer, "CleaningBrushRadius", if IsApplicable then GetToolRadius(ToolInfo) else nil)
	if UsingTool and (not IsApplicable or ToolInfo.Id ~= ActiveToolId) then
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
	if ToolEmitter then ToolEmitter.Enabled = false; ToolEmitter = nil end
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
	local BeamFolder = if type(ToolInfo.VFXFolderName) == "string" then ReplicatedStorage.Assets.VFX:FindFirstChild(ToolInfo.VFXFolderName) else nil
	local BeamTemplate = if BeamFolder and type(ToolInfo.VFXName) == "string" then BeamFolder:FindFirstChild(ToolInfo.VFXName) else nil
	if BeamTemplate and BeamTemplate:IsA("Beam") then
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
			ToolBeam = BeamTemplate:Clone()
			ToolBeam.Attachment0 = ToolStartAttachment
			ToolBeam.Attachment1 = ToolEndAttachment
			ToolBeam.Enabled = false
			ToolBeam.Parent = ToolStartAttachment.Parent
		end
	end
	ToolEmitter = StartObject:FindFirstChildWhichIsA("ParticleEmitter", true)
	if not ToolEmitter and StartObject.Parent then ToolEmitter = StartObject.Parent:FindFirstChildWhichIsA("ParticleEmitter", true) end
	if ToolEmitter then ToolEmitter.Enabled = true end
	local SoundTemplate = if type(ToolInfo.LoopSoundName) == "string" then Sounds.Get(ToolInfo.LoopSoundName) else nil
	if SoundTemplate then
		ToolLoop = SoundTemplate:Clone()
		ToolLoop.Looped = true
		if type(ToolInfo.LoopSoundVolume) == "number" then ToolLoop.Volume = ToolInfo.LoopSoundVolume end
		ToolLoop.RollOffMaxDistance = TOOL_SOUND_MAX_DISTANCE
		ToolLoop.Parent = if StartObject:IsA("Attachment") then StartObject.Parent else StartObject
		ToolLoop:Play()
	end
end

local function Restore()
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
	FakeArm = nil
	for Part, Transparency in HiddenParts do if Part.Parent then Part.LocalTransparencyModifier = Transparency end end
	HiddenParts = {}
	if CameraBound then RunService:UnbindFromRenderStep(CAMERA_BINDING_NAME); CameraBound = false end
	local Camera = Workspace.CurrentCamera
	if OriginalCameraType then Camera.CameraType = OriginalCameraType; OriginalCameraType = nil end
	if OriginalFieldOfView then Camera.FieldOfView = OriginalFieldOfView; OriginalFieldOfView = nil end
	EnablePlayerControls()
	RuntimeState.Set(LocalPlayer, "CleaningRadiusVisible", false)
	RuntimeState.Set(LocalPlayer, "CleaningBrushRadius", nil)
end

local function GetScreenWorldPosition(Camera, ScreenPosition, Depth): Vector3
	local ViewportSize = Camera.ViewportSize
	local HalfHeight = Depth * math.tan(math.rad(Camera.FieldOfView / 2))
	local HalfWidth = HalfHeight * ViewportSize.X / math.max(ViewportSize.Y, 1)
	local CameraPosition = Vector3.new((ScreenPosition.X * 2 - 1) * HalfWidth, (1 - ScreenPosition.Y * 2) * HalfHeight, -Depth)
	return Camera.CFrame:PointToWorldSpace(CameraPosition)
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

local function EnterFixingView()
	Restore()
	if RuntimeState.Get(LocalPlayer, "IsFixing", false) ~= true then return end
	local Character = LocalPlayer.Character
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not Character or not CameraPart or not CameraPart:IsA("BasePart") then return end
	HideCharacter(Character)
	CreateViewmodelContainer(Character)
	DisablePlayerControls()
	local Camera = Workspace.CurrentCamera
	OriginalFieldOfView = Camera.FieldOfView
	OriginalCameraType = Camera.CameraType
	Camera.FieldOfView = CleaningConfig.CameraFieldOfView
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CameraPart.CFrame
	RunService:BindToRenderStep(CAMERA_BINDING_NAME, Enum.RenderPriority.Last.Value, function(DeltaTime)
		if not CameraPart.Parent then
			Restore()
			Network:fire("Exit")
			return
		end
		Camera.CFrame = CameraPart.CFrame
		if UpdateVisualTool then UpdateVisualTool(DeltaTime) end
	end)
	CameraBound = true
	task.defer(UpdateToolInterface)
end

GetFixingItemModel = function(): Model?
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	if not Museum then return nil end
	local Model = Museum:FindFirstChild(`FixingItem_{LocalPlayer.UserId}`)
	return if Model and Model:IsA("Model") then Model else nil
end

local function GetAimPosition(): (Vector3?, BasePart?, Vector3?)
	local Camera = Workspace.CurrentCamera
	local MousePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local Ray = Camera:ViewportPointToRay(MousePosition.X, MousePosition.Y)
	local FixingItem = GetFixingItemModel()
	if not FixingItem then return nil, nil, nil end
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Include
	Parameters.FilterDescendantsInstances = { FixingItem }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 30, Parameters)
	if not Result then return nil, nil, nil end
	return Result.Position, if Result.Instance:IsA("BasePart") then Result.Instance else nil, Result.Normal
end

local function GetDesiredToolCFrame(ToolInfo): CFrame
	local Camera = Workspace.CurrentCamera
	local RotationDegrees = ToolInfo.SurfaceRotationDegrees or Vector3.zero
	local ViewportSize = Camera.ViewportSize
	local CursorPosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
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
	return CFrame.lookAt(ToolPosition, TargetPosition, Camera.CFrame.UpVector)
		* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
		* CFrame.Angles(math.rad(-CursorDirection.Y * CursorRotation.X), math.rad(CursorDirection.X * CursorRotation.Y), 0)
end

local function GetSpongeUseCFrame(AimPosition: Vector3, SurfaceNormal: Vector3): CFrame
	local Camera = Workspace.CurrentCamera
	local Up = SurfaceNormal.Unit
	local Right = Camera.CFrame.RightVector - Up * Camera.CFrame.RightVector:Dot(Up)
	if Right.Magnitude < 0.01 then Right = Camera.CFrame.UpVector - Up * Camera.CFrame.UpVector:Dot(Up) end
	Right = Right.Unit
	local Back = Right:Cross(Up).Unit
	local ScrubTime = os.clock() * CleaningConfig.SpongeScrubFrequency
	local ScrubOffset = Right * math.sin(ScrubTime) * CleaningConfig.SpongeScrubDistance
		+ Back * math.sin(ScrubTime * 0.5) * CleaningConfig.SpongeScrubSideDistance
	local Position = AimPosition + Up * CleaningConfig.SpongeSurfaceOffset + ScrubOffset
	return CFrame.fromMatrix(Position, Right, Up, Back)
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
	if UsingTool and ToolInfo.Id == "Sponge" then
		local AimPosition, _, SurfaceNormal = GetAimPosition()
		if AimPosition and SurfaceNormal then
			DesiredCFrame = GetSpongeUseCFrame(AimPosition, SurfaceNormal)
			Responsiveness = CleaningConfig.SpongeSurfaceResponsiveness
		end
	end
	local Blend = 1 - math.exp(-Responsiveness * DeltaTime)
	SmoothedVisualToolCFrame = if SmoothedVisualToolCFrame then SmoothedVisualToolCFrame:Lerp(DesiredCFrame, Blend) else DesiredCFrame
	PositionViewmodelTool(SmoothedVisualToolCFrame)
	if FakeArm then
		local Camera = Workspace.CurrentCamera
		local ArmStart = GetScreenWorldPosition(Camera, CleaningConfig.FakeArmScreenPosition, CleaningConfig.FakeArmCameraDepth)
		local ArmEnd = SmoothedVisualToolCFrame.Position
		local ArmLength = (ArmEnd - ArmStart).Magnitude
		if ArmLength > 0.01 then
			FakeArm.Transparency = 0
			FakeArm.Size = Vector3.new(CleaningConfig.FakeArmThickness, CleaningConfig.FakeArmThickness, ArmLength)
			FakeArm.CFrame = CFrame.lookAt(ArmStart:Lerp(ArmEnd, 0.5), ArmEnd)
		else
			FakeArm.Transparency = 1
		end
	end
end

function FixingController.Init()
	Network = Networker.client.new("FixingController", FixingController)
	task.spawn(function()
		local Museums = Workspace:WaitForChild("PlayerMuseums")
		local Museum = Museums:WaitForChild(`Museum_{LocalPlayer.UserId}`)
		FixPrompt = Museum:WaitForChild("Table"):WaitForChild("PromptPart"):WaitForChild("FixItemPrompt") :: ProximityPrompt
		UpdateFixPrompt()
	end)
	RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(function()
		EnterFixingView()
		UpdateFixPrompt()
	end)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepToolId"):Connect(function()
		RequestedToolId = nil
		UpdateToolInterface()
	end)
	DataService:getChangedSignal("Fixing"):Connect(UpdateFixPrompt)
	DataService:getChangedSignal("Upgrades"):Connect(UpdateToolInterface)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepComplete"):Connect(function(IsComplete)
		if IsComplete == true then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
		end
	end)
	FixingInterface.ExitRequested:Connect(function()
		if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then Network:fire("Exit") end
	end)
	RunService.RenderStepped:Connect(function(DeltaTime)
		if not UsingTool then return end
		local Tool, ToolInfo = GetEquippedCleaningTool()
		if not Tool or not ToolInfo or ToolInfo.Id ~= ActiveToolId or ToolInfo.Id ~= RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
			or RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) == true
		then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			Network:fire("StopUsingTool")
			return
		end
		local AimPosition, AimPart = GetAimPosition()
		local Camera = Workspace.CurrentCamera
		local MousePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		if AimPosition and ToolEndPart and ToolBeam then
			local Blend = 1 - math.exp(-CleaningConfig.SprayEndpointResponsiveness * DeltaTime)
			SmoothedToolPosition = if SmoothedToolPosition then SmoothedToolPosition:Lerp(AimPosition, Blend) else AimPosition
			ToolEndPart.Position = SmoothedToolPosition
			ToolBeam.Enabled = true
			local CameraPosition = Camera.CFrame:PointToObjectSpace(SmoothedToolPosition)
			local Depth = math.max(-CameraPosition.Z, 0.1)
			local WorldUnitsPerPixel = 2 * Depth * math.tan(math.rad(Camera.FieldOfView / 2)) / math.max(Camera.ViewportSize.Y, 1)
			ToolBeam.Width1 = GetToolRadius(ToolInfo) * 2 * WorldUnitsPerPixel * ToolInfo.VFXWidthScale
			if ToolInfo.ColorFromTarget and AimPart then
				local TargetColor = AimPart.Color
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
		Network:fire("ApplyTool", ToolInfo.Id, MousePosition, Camera.ViewportSize)
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and RuntimeState.Get(LocalPlayer, "IsFixing", false) == true and not UsingTool then
			local Tool, ToolInfo = GetEquippedCleaningTool()
			if Tool and ToolInfo and ToolInfo.Id == RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
				and RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) ~= true
			then
				UsingTool = true
				ActiveToolId = ToolInfo.Id
				if Tool ~= ViewmodelSourceTool then CreateViewmodelTool(Tool, ToolInfo) end
				if ViewmodelTool then StartToolEffects(ViewmodelTool, ToolInfo) end
				Network:fire("StartUsingTool", ToolInfo.Id)
			end
		elseif Input.KeyCode == Enum.KeyCode.Q and RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then
			Network:fire("Exit")
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and UsingTool then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			Network:fire("StopUsingTool")
		end
	end)
	EnterFixingView()
end

function FixingController.OnCharacterAdded(Character)
	if RuntimeState.Get(LocalPlayer, "IsFixing", false) == true then
		Restore()
		Network:fire("Exit")
	end
	WatchCharacter(Character)
end

return FixingController
