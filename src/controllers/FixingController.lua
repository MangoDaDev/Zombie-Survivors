local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Networker = require(ReplicatedStorage.Packages.networker)
local player = Players.LocalPlayer
local FixingController = {}
local connection; local hidden = {}; local spraying = false
local prompt: ProximityPrompt?
local function updatePrompt()
	if not prompt then return end
	local Tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	prompt.Enabled = Tool ~= nil and Tool:GetAttribute("NeedsFixing") == true and player:GetAttribute("IsFixing") ~= true
end
local function restore() for part, value in hidden do if part.Parent then part.LocalTransparencyModifier = value end end; hidden = {}; if connection then connection:Disconnect(); connection = nil end; Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end
local function update()
	if player:GetAttribute("IsFixing") ~= true then restore(); return end
	local museum = Workspace:FindFirstChild("PlayerMuseums") and Workspace.PlayerMuseums:FindFirstChild(`Museum_{player.UserId}`); local tableModel = museum and museum:FindFirstChild("Table"); local cam = tableModel and tableModel:FindFirstChild("CamPart")
	if not cam or not cam:IsA("BasePart") then return end
	for _, part in player.Character:GetDescendants() do if part:IsA("BasePart") and part.Name ~= "RightUpperArm" and part.Name ~= "RightLowerArm" and part.Name ~= "RightHand" then hidden[part] = part.LocalTransparencyModifier; part.LocalTransparencyModifier = 1 end end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	connection = RunService.RenderStepped:Connect(function() Workspace.CurrentCamera.CFrame = cam.CFrame end)
end
function FixingController:Init()
	self.networker = Networker.client.new("FixingController", self)
	task.spawn(function()
		local Museums = Workspace:WaitForChild("PlayerMuseums")
		local Museum = Museums:WaitForChild(`Museum_{player.UserId}`)
		prompt = Museum:WaitForChild("Table"):WaitForChild("PromptPart"):WaitForChild("FixItemPrompt")
		prompt.Triggered:Connect(function() self.networker:fire("Start") end)
		updatePrompt()
	end)
	player:GetAttributeChangedSignal("IsFixing"):Connect(update); update()
	player:GetAttributeChangedSignal("IsFixing"):Connect(updatePrompt)
	RunService.RenderStepped:Connect(function() if spraying then local tool = player.Character and player.Character:FindFirstChild("SprayBottle"); if tool then local ray = Workspace.CurrentCamera:ViewportPointToRay(Workspace.CurrentCamera.ViewportSize.X/2, Workspace.CurrentCamera.ViewportSize.Y/2); local result = Workspace:Raycast(ray.Origin, ray.Direction * 30); if result then self.networker:fire("Spray", result.Position) end end end end)
	UserInputService.InputBegan:Connect(function(input, processed) if processed then return end; if input.UserInputType == Enum.UserInputType.MouseButton1 and player:GetAttribute("IsFixing") then spraying = true elseif input.KeyCode == Enum.KeyCode.Q and player:GetAttribute("IsFixing") then self.networker:fire("Exit") end end)
	UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then spraying = false end end)
end
function FixingController.OnCharacterAdded(Character) if player:GetAttribute("IsFixing") then restore() end; Character.ChildAdded:Connect(updatePrompt); Character.ChildRemoved:Connect(updatePrompt); updatePrompt() end
return FixingController
