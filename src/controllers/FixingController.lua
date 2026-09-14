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
local Shoulder: Motor6D?
local ShoulderTransform = CFrame.identity
local UsingTool = false
local ActiveToolId: string?
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
local OriginalFieldOfView: number?
local StopToolEffects

local ARM_SCREEN_POSITION = Vector2.new(0.82, 0.82)
local ARM_CURSOR_SCREEN_INFLUENCE = Vector2.new(0.07, 0.06)
local ARM_CAMERA_DEPTH = 1.55
local CAMERA_BINDING_NAME = "CleaningCameraAndArm"
local TOOL_SOUND_MAX_DISTANCE = 50

local VisibleArmParts = {
	["Right Arm"] = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}

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
	local IsApplicable = LocalPlayer:GetAttribute("IsFixing") == true and Tool ~= nil and ToolInfo ~= nil and ToolInfo.Id == RequiredToolId
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
end

local function StartToolEffects(Tool: Tool, ToolInfo)
	StopToolEffects()
	local StartObject = Tool:FindFirstChild(ToolInfo.VFXStartPartName, true)
	local BeamFolder = ReplicatedStorage.Assets.VFX:FindFirstChild(ToolInfo.VFXFolderName)
	local BeamTemplate = BeamFolder and BeamFolder:FindFirstChild(ToolInfo.VFXName)
	if not StartObject or not BeamTemplate or not BeamTemplate:IsA("Beam") then return end
	if StartObject:IsA("Attachment") then
		ToolStartAttachment = StartObject
	elseif StartObject:IsA("BasePart") then
		ToolStartAttachment = Instance.new("Attachment")
		ToolStartAttachment.Name = "ToolVFXStartAttachment"
		ToolStartAttachment.Parent = StartObject
		CreatedStartAttachment = true
	else
		return
	end
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
	ToolEmitter = StartObject:FindFirstChildWhichIsA("ParticleEmitter", true)
	if not ToolEmitter and StartObject.Parent then ToolEmitter = StartObject.Parent:FindFirstChildWhichIsA("ParticleEmitter", true) end
	if ToolEmitter then ToolEmitter.Enabled = true end
	local SoundTemplate = Sounds.Get(ToolInfo.LoopSoundName)
	if SoundTemplate then
		ToolLoop = SoundTemplate:Clone()
		ToolLoop.Looped = true
		ToolLoop.RollOffMaxDistance = TOOL_SOUND_MAX_DISTANCE
		ToolLoop.Parent = ToolStartAttachment.Parent
		ToolLoop:Play()
	end
end

local function Restore()
	UsingTool = false
	ActiveToolId = nil
	StopToolEffects()
	for Part, Transparency in HiddenParts do if Part.Parent then Part.LocalTransparencyModifier = Transparency end end
	HiddenParts = {}
	if Shoulder and Shoulder.Parent then Shoulder.Transform = ShoulderTransform end
	Shoulder = nil
	if CameraBound then RunService:UnbindFromRenderStep(CAMERA_BINDING_NAME); CameraBound = false end
	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Custom
	if OriginalFieldOfView then Camera.FieldOfView = OriginalFieldOfView; OriginalFieldOfView = nil end
	LocalPlayer:SetAttribute("CleaningRadiusVisible", false)
	LocalPlayer:SetAttribute("CleaningBrushRadius", nil)
end

local function GetArmTransform(): CFrame
	if not Shoulder or not Shoulder.Part0 or not Shoulder.Part1 then return ShoulderTransform end
	local Camera = Workspace.CurrentCamera
	local ViewportSize = Camera.ViewportSize
	local MousePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local Horizontal = math.clamp(MousePosition.X / math.max(ViewportSize.X, 1) * 2 - 1, -1, 1)
	local Vertical = math.clamp(MousePosition.Y / math.max(ViewportSize.Y, 1) * 2 - 1, -1, 1)
	local ScreenPosition = ARM_SCREEN_POSITION + Vector2.new(Horizontal * ARM_CURSOR_SCREEN_INFLUENCE.X, Vertical * ARM_CURSOR_SCREEN_INFLUENCE.Y)
	local HalfHeight = ARM_CAMERA_DEPTH * math.tan(math.rad(Camera.FieldOfView / 2))
	local HalfWidth = HalfHeight * ViewportSize.X / math.max(ViewportSize.Y, 1)
	local CameraPosition = Vector3.new((ScreenPosition.X * 2 - 1) * HalfWidth, (1 - ScreenPosition.Y * 2) * HalfHeight, -ARM_CAMERA_DEPTH)
	local DesiredArmCFrame = Camera.CFrame * CFrame.new(CameraPosition) * CFrame.Angles(math.rad(-20 - Vertical * 24), math.rad(-12 - Horizontal * 28), math.rad(18 + Horizontal * 14))
	return Shoulder.C0:Inverse() * Shoulder.Part0.CFrame:Inverse() * DesiredArmCFrame * Shoulder.C1
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
	Shoulder = (Character:FindFirstChild("Right Shoulder", true) or Character:FindFirstChild("RightShoulder", true)) :: Motor6D?
	if Shoulder and Shoulder:IsA("Motor6D") then ShoulderTransform = Shoulder.Transform else Shoulder = nil end
	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and not VisibleArmParts[Part.Name] and not IsFixingToolPart(Part) then
			HiddenParts[Part] = Part.LocalTransparencyModifier
			Part.LocalTransparencyModifier = 1
		end
	end
	local Camera = Workspace.CurrentCamera
	OriginalFieldOfView = Camera.FieldOfView
	Camera.FieldOfView = CleaningConfig.CameraFieldOfView
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CameraPart.CFrame
	if Shoulder then Shoulder.Transform = GetArmTransform() end
	RunService:BindToRenderStep(CAMERA_BINDING_NAME, Enum.RenderPriority.Last.Value, function()
		Camera.CFrame = CameraPart.CFrame
		if Shoulder and Shoulder.Parent then Shoulder.Transform = GetArmTransform() end
	end)
	CameraBound = true
	task.defer(UpdateToolInterface)
end

local function GetAimPosition(): Vector3?
	local Camera = Workspace.CurrentCamera
	local MousePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local Ray = Camera:ViewportPointToRay(MousePosition.X, MousePosition.Y)
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = if LocalPlayer.Character then { LocalPlayer.Character } else {}
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 30, Parameters)
	return if Result then Result.Position else nil
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
	LocalPlayer:GetAttributeChangedSignal("CleaningStepToolId"):Connect(UpdateToolInterface)
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
		if not Tool or not ToolInfo or ToolInfo.Id ~= ActiveToolId or ToolInfo.Id ~= LocalPlayer:GetAttribute("CleaningStepToolId") then
			UsingTool = false
			ActiveToolId = nil
			StopToolEffects()
			self.Networker:fire("StopUsingTool")
			return
		end
		local AimPosition = GetAimPosition()
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
		elseif ToolBeam then
			ToolBeam.Enabled = false
		end
		self.Networker:fire("ApplyTool", ToolInfo.Id, MousePosition, Camera.ViewportSize)
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and LocalPlayer:GetAttribute("IsFixing") == true and not UsingTool then
			local Tool, ToolInfo = GetEquippedCleaningTool()
			if Tool and ToolInfo and ToolInfo.Id == LocalPlayer:GetAttribute("CleaningStepToolId") then
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
