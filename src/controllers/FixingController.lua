local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local Networker = require(ReplicatedStorage.Packages.networker)

local LocalPlayer = Players.LocalPlayer
local FixingController = {}
local CameraConnection: RBXScriptConnection?
local HiddenParts: { [BasePart]: number } = {}
local Shoulder: Motor6D?
local ShoulderTransform = CFrame.identity
local Spraying = false

local VisibleArmParts = {
	["Right Arm"] = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}

local function IsFixingToolPart(Part: BasePart): boolean
	local Tool = Part:FindFirstAncestorOfClass("Tool")
	return Tool ~= nil and type(Tool:GetAttribute("FixingTool")) == "string"
end

local function Restore()
	Spraying = false
	for Part, Transparency in HiddenParts do
		if Part.Parent then Part.LocalTransparencyModifier = Transparency end
	end
	HiddenParts = {}
	if Shoulder and Shoulder.Parent then Shoulder.Transform = ShoulderTransform end
	Shoulder = nil
	if CameraConnection then CameraConnection:Disconnect(); CameraConnection = nil end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function GetArmTransform(): CFrame
	local Camera = Workspace.CurrentCamera
	local ViewportSize = Camera.ViewportSize
	local MousePosition = UserInputService:GetMouseLocation()
	local Horizontal = math.clamp(MousePosition.X / math.max(ViewportSize.X, 1) * 2 - 1, -1, 1)
	local Vertical = math.clamp(MousePosition.Y / math.max(ViewportSize.Y, 1) * 2 - 1, -1, 1)
	return ShoulderTransform * CFrame.Angles(
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
		local Prompt = Museum:WaitForChild("Table"):WaitForChild("PromptPart"):WaitForChild("FixItemPrompt")
		Prompt.Triggered:Connect(function()
			local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
			local ItemId = Tool and Tool:GetAttribute("ItemId")
			if type(ItemId) == "number" then self.Networker:fire("Start", ItemId) end
		end)
	end)
	LocalPlayer:GetAttributeChangedSignal("IsFixing"):Connect(EnterFixingView)
	FixingInterface.ExitRequested:Connect(function()
		if LocalPlayer:GetAttribute("IsFixing") == true then self.Networker:fire("Exit") end
	end)
	RunService.RenderStepped:Connect(function()
		if not Spraying then return end
		local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("SprayBottle")
		local AimPosition = Tool and GetAimPosition()
		if AimPosition then self.Networker:fire("Spray", AimPosition) end
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and LocalPlayer:GetAttribute("IsFixing") == true then
			Spraying = true
			self.Networker:fire("StartSpraying")
		elseif Input.KeyCode == Enum.KeyCode.Q and LocalPlayer:GetAttribute("IsFixing") == true then
			self.Networker:fire("Exit")
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and Spraying then
			Spraying = false
			self.Networker:fire("StopSpraying")
		end
	end)
	EnterFixingView()
end

function FixingController.OnCharacterAdded(Character)
	if LocalPlayer:GetAttribute("IsFixing") == true then Restore() end
end

return FixingController
