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
local CameraConnection: RBXScriptConnection?
local HiddenParts: { [BasePart]: number } = {}
local Shoulder: Motor6D?
local ShoulderTransform = CFrame.identity
local Spraying = false
local FixPrompt: ProximityPrompt?
local CharacterConnections: { RBXScriptConnection } = {}
local SprayLoop: Sound?
local SprayBeam: Beam?
local SprayEndPart: Part?
local SprayStartAttachment: Attachment?
local SprayEndAttachment: Attachment?
local SprayEmitter: ParticleEmitter?
local SmoothedSprayPosition: Vector3?
local OriginalFieldOfView: number?

local ARM_OFFSET = CFrame.new(0.35, 0, 0)
local SPRAY_SOUND_MAX_DISTANCE = 50

local VisibleArmParts = {
	["Right Arm"] = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}

local function UpdateFixPrompt()
	if not FixPrompt then return end
	local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
	local ItemId = Tool and Tool:GetAttribute("ItemId")
	local Fixing = DataService:get("Fixing") or {}
	local State = if type(ItemId) == "number" then Fixing[tostring(ItemId)] else nil
	FixPrompt.Enabled = LocalPlayer:GetAttribute("IsFixing") ~= true
		and type(ItemId) == "number"
		and (type(State) ~= "table" or State.Completed ~= true)
end

local function WatchCharacter(Character: Model)
	for _, Connection in CharacterConnections do Connection:Disconnect() end
	CharacterConnections = {
		Character.ChildAdded:Connect(function() task.defer(UpdateFixPrompt) end),
		Character.ChildRemoved:Connect(function() task.defer(UpdateFixPrompt) end),
	}
	task.defer(UpdateFixPrompt)
end

local function IsFixingToolPart(Part: BasePart): boolean
	local Tool = Part:FindFirstAncestorOfClass("Tool")
	return Tool ~= nil and type(Tool:GetAttribute("FixingTool")) == "string"
end

local function GetToolInfo(ToolId: string)
	for _, ToolInfo in CleaningConfig.Tools do
		if ToolInfo.Id == ToolId then return ToolInfo end
	end
end

local function GetCleaningTool(ToolId: string): Tool?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	for _, Child in Character:GetChildren() do
		if Child:IsA("Tool") and Child:GetAttribute("CleaningToolId") == ToolId then return Child end
	end
	return nil
end

local function StopSprayEffects()
	if SprayLoop then
		SprayLoop:Stop()
		SprayLoop:Destroy()
		SprayLoop = nil
	end
	if SprayEmitter then SprayEmitter.Enabled = false; SprayEmitter = nil end
	if SprayBeam then SprayBeam:Destroy(); SprayBeam = nil end
	if SprayStartAttachment then SprayStartAttachment:Destroy(); SprayStartAttachment = nil end
	if SprayEndAttachment then SprayEndAttachment:Destroy(); SprayEndAttachment = nil end
	if SprayEndPart then SprayEndPart:Destroy(); SprayEndPart = nil end
	SmoothedSprayPosition = nil
end

local function StartSprayEffects()
	StopSprayEffects()
	local ToolInfo = GetToolInfo("Spray")
	local Tool = GetCleaningTool("Spray")
	if not ToolInfo or not Tool then return end
	local StartPart = Tool:FindFirstChild(ToolInfo.VFXStartPartName, true)
	local BeamFolder = ReplicatedStorage.Assets.VFX:FindFirstChild(ToolInfo.VFXFolderName)
	local BeamTemplate = BeamFolder and BeamFolder:FindFirstChild(ToolInfo.VFXName)
	local SoundTemplate = Sounds.Get(ToolInfo.LoopSoundName)
	if not StartPart or not StartPart:IsA("BasePart") or not BeamTemplate or not BeamTemplate:IsA("Beam") then return end

	SprayEndPart = Instance.new("Part")
	SprayEndPart.Name = "SprayEndpoint"
	SprayEndPart.Anchored = true
	SprayEndPart.CanCollide = false
	SprayEndPart.CanQuery = false
	SprayEndPart.CanTouch = false
	SprayEndPart.Size = Vector3.one * 0.05
	SprayEndPart.Transparency = 1
	SprayEndPart.Parent = Workspace
	SprayStartAttachment = Instance.new("Attachment")
	SprayStartAttachment.Name = "SprayStartAttachment"
	SprayStartAttachment.Parent = StartPart
	SprayEndAttachment = Instance.new("Attachment")
	SprayEndAttachment.Name = "SprayEndAttachment"
	SprayEndAttachment.Parent = SprayEndPart
	SprayBeam = BeamTemplate:Clone()
	SprayBeam.Attachment0 = SprayStartAttachment
	SprayBeam.Attachment1 = SprayEndAttachment
	SprayBeam.Enabled = true
	SprayBeam.Parent = StartPart
	SprayEmitter = StartPart:FindFirstChildOfClass("ParticleEmitter")
	if SprayEmitter then SprayEmitter.Enabled = true end

	if not SoundTemplate then return end
	SprayLoop = SoundTemplate:Clone()
	SprayLoop.Looped = true
	SprayLoop.RollOffMaxDistance = SPRAY_SOUND_MAX_DISTANCE
	SprayLoop.Parent = StartPart
	SprayLoop:Play()
end

local function Restore()
	Spraying = false
	StopSprayEffects()
	for Part, Transparency in HiddenParts do
		if Part.Parent then Part.LocalTransparencyModifier = Transparency end
	end
	HiddenParts = {}
	if Shoulder and Shoulder.Parent then Shoulder.Transform = ShoulderTransform end
	Shoulder = nil
	if CameraConnection then CameraConnection:Disconnect(); CameraConnection = nil end
	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Custom
	if OriginalFieldOfView then Camera.FieldOfView = OriginalFieldOfView; OriginalFieldOfView = nil end
end

local function GetArmTransform(): CFrame
	local Camera = Workspace.CurrentCamera
	local ViewportSize = Camera.ViewportSize
	local MousePosition = UserInputService:GetMouseLocation()
	local Horizontal = math.clamp(MousePosition.X / math.max(ViewportSize.X, 1) * 2 - 1, -1, 1)
	local Vertical = math.clamp(MousePosition.Y / math.max(ViewportSize.Y, 1) * 2 - 1, -1, 1)
	return ShoulderTransform * ARM_OFFSET * CFrame.Angles(
		math.rad(-15 - Vertical * 30),
		math.rad(-Horizontal * 35),
		math.rad(10 + Horizontal * 12)
	)
end

local function EnterFixingView()
	Restore()
	if LocalPlayer:GetAttribute("IsFixing") ~= true then return end
	local Character = LocalPlayer.Character
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local CamPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not Character or not CamPart or not CamPart:IsA("BasePart") then return end

	Shoulder = Character:FindFirstChild("RightShoulder", true) :: Motor6D?
	if Shoulder and Shoulder:IsA("Motor6D") then
		ShoulderTransform = Shoulder.Transform
	else
		Shoulder = nil
	end
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
	CameraConnection = RunService.RenderStepped:Connect(function()
		Camera.CFrame = CamPart.CFrame
		if Shoulder and Shoulder.Parent then Shoulder.Transform = GetArmTransform() end
	end)
end

local function GetAimPosition(): Vector3?
	local Camera = Workspace.CurrentCamera
	local MousePosition = UserInputService:GetMouseLocation()
	local Ray = Camera:ScreenPointToRay(MousePosition.X, MousePosition.Y)
	local RaycastParameters = RaycastParams.new()
	RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParameters.FilterDescendantsInstances = if LocalPlayer.Character then { LocalPlayer.Character } else {}
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 30, RaycastParameters)
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
	LocalPlayer:GetAttributeChangedSignal("IsFixing"):Connect(function()
		EnterFixingView()
		UpdateFixPrompt()
	end)
	DataService:getChangedSignal("Fixing"):Connect(UpdateFixPrompt)
	FixingInterface.ExitRequested:Connect(function()
		if LocalPlayer:GetAttribute("IsFixing") == true then self.Networker:fire("Exit") end
	end)
	RunService.RenderStepped:Connect(function(DeltaTime)
		if not Spraying then return end
		local Tool = GetCleaningTool("Spray")
		local AimPosition = Tool and GetAimPosition()
		if not AimPosition then return end
		local Camera = Workspace.CurrentCamera
		local MousePosition = UserInputService:GetMouseLocation()
		if SprayEndPart and SprayBeam then
			local Blend = 1 - math.exp(-CleaningConfig.SprayEndpointResponsiveness * DeltaTime)
			SmoothedSprayPosition = if SmoothedSprayPosition then SmoothedSprayPosition:Lerp(AimPosition, Blend) else AimPosition
			SprayEndPart.Position = SmoothedSprayPosition
			local CameraPosition = Camera.CFrame:PointToObjectSpace(SmoothedSprayPosition)
			local Depth = math.max(-CameraPosition.Z, 0.1)
			local WorldUnitsPerPixel = 2 * Depth * math.tan(math.rad(Camera.FieldOfView / 2)) / math.max(Camera.ViewportSize.Y, 1)
			SprayBeam.Width1 = CleaningConfig.BrushRadiusPixels * 2 * WorldUnitsPerPixel * CleaningConfig.SprayVFXWidthScale
		end
		self.Networker:fire("Spray", MousePosition, Camera.ViewportSize)
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1
			and LocalPlayer:GetAttribute("IsFixing") == true
			and not Spraying
		then
			Spraying = true
			StartSprayEffects()
			self.Networker:fire("StartSpraying")
		elseif Input.KeyCode == Enum.KeyCode.Q and LocalPlayer:GetAttribute("IsFixing") == true then
			self.Networker:fire("Exit")
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and Spraying then
			Spraying = false
			StopSprayEffects()
			self.Networker:fire("StopSpraying")
		end
	end)
	EnterFixingView()
end

function FixingController.OnCharacterAdded(Character)
	if LocalPlayer:GetAttribute("IsFixing") == true then Restore() end
	WatchCharacter(Character)
end

return FixingController
