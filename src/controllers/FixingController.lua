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
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local LocalPlayer = Players.LocalPlayer
local FixingController = {}
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
local ToolGrip: Motor6D?
local ToolGripTransform = CFrame.identity
local OriginalFieldOfView: number?
local StopToolEffects
local UpdateVisualTool

local CAMERA_BINDING_NAME = "CleaningCameraAndArm"
local TOOL_SOUND_MAX_DISTANCE = 50

local function GetToolInfo(ToolId: string)
	for _, ToolInfo in CleaningConfig.Tools do
		if ToolInfo.Id == ToolId then return ToolInfo end
	end
end

local function GetEquippedCleaningTool(): (Tool?, any?)
	local Character = LocalPlayer.Character
	if not Character then return nil, nil end
	for _, Child in Character:GetChildren() do
		if Child:IsA("Tool") then
			local ToolId = Child:GetAttribute("CleaningToolId")
			local ToolInfo = if type(ToolId) == "string" then GetToolInfo(ToolId) else nil
			if ToolInfo then return Child, ToolInfo end
		end
	end
	return nil, nil
end

local function UpdateToolInterface()
	local Tool, ToolInfo = GetEquippedCleaningTool()
	local RequiredToolId = LocalPlayer:GetAttribute("CleaningStepToolId")
	local IsFixing = LocalPlayer:GetAttribute("IsFixing") == true
	if ToolInfo and ToolInfo.Id == RequiredToolId then RequestedToolId = nil end
	if IsFixing and Tool and ToolInfo and ToolInfo.Id ~= RequiredToolId and RequestedToolId ~= ToolInfo.Id then
		RequestedToolId = ToolInfo.Id
		if UsingTool then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			FixingController.Networker:fire("StopUsingTool")
		end
		FixingController.Networker:fire("SelectTool", ToolInfo.Id)
	end
	local IsApplicable = IsFixing
		and Tool ~= nil
		and ToolInfo ~= nil
		and ToolInfo.Id == RequiredToolId
		and LocalPlayer:GetAttribute("CleaningStepComplete") ~= true
	LocalPlayer:SetAttribute("CleaningRadiusVisible", IsApplicable)
	LocalPlayer:SetAttribute("CleaningBrushRadius", if IsApplicable then ToolInfo.RadiusPixels else nil)
	if UsingTool and (not IsApplicable or ToolInfo.Id ~= ActiveToolId) then
		UsingTool = false
		ActiveToolId = nil
		StopToolEffects()
		FixingController.Networker:fire("StopUsingTool")
	end
end

local function UpdateFixPrompt()
	if not FixPrompt then return end
	local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
	local ItemId = Tool and Tool:GetAttribute("ItemId")
	local Fixing = DataService:get("Fixing") or {}
	local State = if type(ItemId) == "number" then Fixing[tostring(ItemId)] else nil
	FixPrompt.Enabled = LocalPlayer:GetAttribute("IsFixing") ~= true and type(ItemId) == "number" and (type(State) ~= "table" or State.Completed ~= true)
end

local function WatchCharacter(Character: Model)
	for _, Connection in CharacterConnections do Connection:Disconnect() end
	CharacterConnections = {
		Character.ChildAdded:Connect(function() task.defer(UpdateFixPrompt); task.defer(UpdateToolInterface) end),
		Character.ChildRemoved:Connect(function() task.defer(UpdateFixPrompt); task.defer(UpdateToolInterface) end),
	}
	task.defer(UpdateFixPrompt)
	task.defer(UpdateToolInterface)
end

local function IsFixingToolPart(Part: BasePart): boolean
	local Tool = Part:FindFirstAncestorOfClass("Tool")
	return Tool ~= nil and type(Tool:GetAttribute("FixingTool")) == "string"
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
	if ToolGrip and ToolGrip.Parent then ToolGrip.Transform = ToolGripTransform end
	ToolGrip = nil
	ToolGripTransform = CFrame.identity
	SmoothedVisualToolCFrame = nil
	if FakeArm then FakeArm:Destroy(); FakeArm = nil end
	for Part, Transparency in HiddenParts do if Part.Parent then Part.LocalTransparencyModifier = Transparency end end
	HiddenParts = {}
	if CameraBound then RunService:UnbindFromRenderStep(CAMERA_BINDING_NAME); CameraBound = false end
	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Custom
	if OriginalFieldOfView then Camera.FieldOfView = OriginalFieldOfView; OriginalFieldOfView = nil end
	LocalPlayer:SetAttribute("CleaningRadiusVisible", false)
	LocalPlayer:SetAttribute("CleaningBrushRadius", nil)
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

local function CreateFakeArm(Character)
	FakeArm = Instance.new("Part")
	FakeArm.Name = "LocalFixingArm"
	FakeArm.Anchored = true
	FakeArm.CanCollide = false
	FakeArm.CanQuery = false
	FakeArm.CanTouch = false
	FakeArm.CastShadow = false
	FakeArm.Color = GetPlayerArmColor(Character)
	FakeArm.Material = Enum.Material.SmoothPlastic
	FakeArm.Parent = Workspace
end

local function EnterFixingView()
	Restore()
	if LocalPlayer:GetAttribute("IsFixing") ~= true then return end
	local Character = LocalPlayer.Character
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not Character or not CameraPart or not CameraPart:IsA("BasePart") then return end
	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and not IsFixingToolPart(Part) then
			HiddenParts[Part] = Part.LocalTransparencyModifier
			Part.LocalTransparencyModifier = 1
		end
	end
	CreateFakeArm(Character)
	local Camera = Workspace.CurrentCamera
	OriginalFieldOfView = Camera.FieldOfView
	Camera.FieldOfView = CleaningConfig.CameraFieldOfView
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CameraPart.CFrame
	RunService:BindToRenderStep(CAMERA_BINDING_NAME, Enum.RenderPriority.Last.Value, function(DeltaTime)
		Camera.CFrame = CameraPart.CFrame
		if UpdateVisualTool then UpdateVisualTool(DeltaTime) end
	end)
	CameraBound = true
	task.defer(UpdateToolInterface)
end

local function GetFixingItemModel(): Model?
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	if not Museum then return nil end
	for _, Child in Museum:GetChildren() do
		if Child:IsA("Model") and Child:GetAttribute("FixingItemOwnerUserId") == LocalPlayer.UserId then return Child end
	end
	return nil
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

local function GetToolGrip(Tool): Motor6D?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	for _, Descendant in Character:GetDescendants() do
		if Descendant:IsA("Motor6D") and Descendant.Part1 and Descendant.Part1:IsDescendantOf(Tool) then return Descendant end
	end
	return nil
end

local function GetDesiredToolCFrame(ToolInfo, AimPosition, AimNormal): CFrame
	local Camera = Workspace.CurrentCamera
	local RotationDegrees = ToolInfo.SurfaceRotationDegrees or Vector3.zero
	if ToolInfo.PositionMode == "Surface" and UsingTool and AimPosition and AimNormal then
		local UpVector = if math.abs(AimNormal:Dot(Camera.CFrame.UpVector)) > 0.96 then Camera.CFrame.RightVector else Camera.CFrame.UpVector
		return CFrame.lookAt(AimPosition + AimNormal * (ToolInfo.SurfaceOffset or 0), AimPosition + AimNormal, UpVector)
			* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
	end
	local ScreenPosition = ToolInfo.ScreenPosition or Vector2.new(0.82, 0.82)
	local ToolPosition = GetScreenWorldPosition(Camera, ScreenPosition, ToolInfo.ScreenDepth or 1.65)
	local TargetPosition = AimPosition or Camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -10))
	return CFrame.lookAt(ToolPosition, TargetPosition, Camera.CFrame.UpVector)
		* CFrame.Angles(math.rad(RotationDegrees.X), math.rad(RotationDegrees.Y), math.rad(RotationDegrees.Z))
end

UpdateVisualTool = function(DeltaTime)
	if LocalPlayer:GetAttribute("IsFixing") ~= true then return end
	local Tool, ToolInfo = GetEquippedCleaningTool()
	local NewToolGrip = Tool and GetToolGrip(Tool) or nil
	if NewToolGrip ~= ToolGrip then
		if ToolGrip and ToolGrip.Parent then ToolGrip.Transform = ToolGripTransform end
		ToolGrip = NewToolGrip
		ToolGripTransform = if ToolGrip then ToolGrip.Transform else CFrame.identity
		SmoothedVisualToolCFrame = nil
	end
	if not Tool or not ToolInfo or not ToolGrip or not ToolGrip.Part0 or not ToolGrip.Part1 then
		if FakeArm then FakeArm.Transparency = 1 end
		return
	end
	local AimPosition, _, AimNormal = GetAimPosition()
	local DesiredCFrame = GetDesiredToolCFrame(ToolInfo, AimPosition, AimNormal)
	local Responsiveness = ToolInfo.PositionResponsiveness or CleaningConfig.ToolPositionResponsiveness
	local Blend = 1 - math.exp(-Responsiveness * DeltaTime)
	SmoothedVisualToolCFrame = if SmoothedVisualToolCFrame then SmoothedVisualToolCFrame:Lerp(DesiredCFrame, Blend) else DesiredCFrame
	ToolGrip.Transform = ToolGrip.C0:Inverse() * ToolGrip.Part0.CFrame:Inverse() * SmoothedVisualToolCFrame * ToolGrip.C1
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

function FixingController:Init()
	self.Networker = Networker.client.new("FixingController", self)
	task.spawn(function()
		local Museums = Workspace:WaitForChild("PlayerMuseums")
		local Museum = Museums:WaitForChild(`Museum_{LocalPlayer.UserId}`)
		FixPrompt = Museum:WaitForChild("Table"):WaitForChild("PromptPart"):WaitForChild("FixItemPrompt") :: ProximityPrompt
		UpdateFixPrompt()
	end)
	LocalPlayer:GetAttributeChangedSignal("IsFixing"):Connect(function() EnterFixingView(); UpdateFixPrompt() end)
	LocalPlayer:GetAttributeChangedSignal("CleaningStepToolId"):Connect(function()
		RequestedToolId = nil
		UpdateToolInterface()
	end)
	DataService:getChangedSignal("Fixing"):Connect(UpdateFixPrompt)
	LocalPlayer:GetAttributeChangedSignal("CleaningStepComplete"):Connect(function()
		if LocalPlayer:GetAttribute("CleaningStepComplete") == true then UsingTool = false; ActiveToolId = nil; StopToolEffects() end
	end)
	FixingInterface.ExitRequested:Connect(function()
		if LocalPlayer:GetAttribute("IsFixing") == true then self.Networker:fire("Exit") end
	end)
	RunService.RenderStepped:Connect(function(DeltaTime)
		if not UsingTool then return end
		local Tool, ToolInfo = GetEquippedCleaningTool()
		if not Tool or not ToolInfo or ToolInfo.Id ~= ActiveToolId or ToolInfo.Id ~= LocalPlayer:GetAttribute("CleaningStepToolId")
			or LocalPlayer:GetAttribute("CleaningStepComplete") == true
		then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			self.Networker:fire("StopUsingTool")
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
			ToolBeam.Width1 = ToolInfo.RadiusPixels * 2 * WorldUnitsPerPixel * ToolInfo.VFXWidthScale
			if ToolInfo.ColorFromTarget and AimPart then
				local OriginalColor = AimPart:GetAttribute("PaintOriginalColor")
				local TargetColor = if typeof(OriginalColor) == "Color3" then OriginalColor else AimPart.Color
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
		self.Networker:fire("ApplyTool", ToolInfo.Id, MousePosition, Camera.ViewportSize)
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and LocalPlayer:GetAttribute("IsFixing") == true and not UsingTool then
			local Tool, ToolInfo = GetEquippedCleaningTool()
			if Tool and ToolInfo and ToolInfo.Id == LocalPlayer:GetAttribute("CleaningStepToolId")
				and LocalPlayer:GetAttribute("CleaningStepComplete") ~= true
			then
				UsingTool = true
				ActiveToolId = ToolInfo.Id
				StartToolEffects(Tool, ToolInfo)
				self.Networker:fire("StartUsingTool", ToolInfo.Id)
			end
		elseif Input.KeyCode == Enum.KeyCode.Q and LocalPlayer:GetAttribute("IsFixing") == true then self.Networker:fire("Exit") end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and UsingTool then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			self.Networker:fire("StopUsingTool")
		end
	end)
	EnterFixingView()
end

function FixingController.OnCharacterAdded(Character)
	if LocalPlayer:GetAttribute("IsFixing") == true then Restore() end
	WatchCharacter(Character)
end

return FixingController
