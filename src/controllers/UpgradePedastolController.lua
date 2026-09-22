local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.signal)

local UpgradePedastolController = {}
UpgradePedastolController.OpenRequested = Signal.new()

local localPlayer = Players.LocalPlayer
local arrows: { [Model]: CFrame } = {}
local promptConnections: { [ProximityPrompt]: RBXScriptConnection } = {}
local pedestalHighlights: { [Model]: { highlight: Highlight, tween: Tween } } = {}
local renderConnection: RBXScriptConnection?
local phase = 0
local museums: Instance?
local upgradeAvailable = false

local function setHighlightFlashing(entry, flashing: boolean)
	if flashing then
		entry.highlight.Enabled = true
		entry.tween:Play()
	else
		entry.tween:Cancel()
		entry.highlight.Enabled = false
		entry.highlight.FillTransparency = 0.88
		entry.highlight.OutlineTransparency = 0.8
	end
end

local function registerPedastol(descendant: Instance)
	local pedestal = if descendant:IsA("Model") and descendant.Name == "UpgradePedastol"
		then descendant
		else descendant:FindFirstAncestor("UpgradePedastol")
	if not pedestal or not pedestal:IsA("Model") or pedestalHighlights[pedestal] then return end
	if not pedestal.Parent or pedestal.Parent.Name ~= `Museum_{localPlayer.UserId}` then return end

	-- Flash only this player's runtime pedestal; the shared asset template stays untouched.
	local highlight = Instance.new("Highlight")
	highlight.Name = "AvailableUpgradeHighlight"
	highlight.Adornee = pedestal
	highlight.FillColor = Color3.fromRGB(255, 45, 45)
	highlight.OutlineColor = Color3.fromRGB(255, 45, 45)
	highlight.FillTransparency = 0.88
	highlight.OutlineTransparency = 0.8
	highlight.Enabled = false
	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = 0.4, OutlineTransparency = 0.1 }
	)
	local entry = { highlight = highlight, tween = tween }
	pedestalHighlights[pedestal] = entry
	highlight.Parent = pedestal
	if upgradeAvailable then setHighlightFlashing(entry, true) end
end

local function animateArrows(deltaTime: number)
	phase += deltaTime
	for arrow, origin in arrows do
		local bob = math.sin(phase * 2.2) * 0.35
		arrow:PivotTo(CFrame.new(origin.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, phase * 1.3, 0) * origin.Rotation)
	end
end

local function registerDescendant(descendant: Instance)
	registerPedastol(descendant)
	local arrow = if descendant.Name == "Arrow" then descendant else descendant:FindFirstAncestor("Arrow")
	if arrow and arrow:IsA("Model") and arrow.Parent and arrow.Parent.Name == "UpgradePedastol" then
		if arrows[arrow] then return end
		-- The arrow's two colour models contain six parts; wait for all of them to replicate.
		local partCount = 0
		for _, part in arrow:GetDescendants() do
			if part:IsA("BasePart") then partCount += 1 end
		end
		if partCount < 6 then return end
		arrows[arrow] = arrow:GetPivot()
		if not renderConnection then renderConnection = RunService.RenderStepped:Connect(animateArrows) end
	elseif descendant.Name == "UpgradePrompt" and descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "PromptPart" then
		promptConnections[descendant] = descendant.Triggered:Connect(function()
			UpgradePedastolController.OpenRequested:Fire()
		end)
	end
end

local function unregisterDescendant(descendant: Instance)
	local entry = pedestalHighlights[descendant]
	if entry then
		entry.tween:Cancel()
		entry.highlight:Destroy()
		pedestalHighlights[descendant] = nil
	end
	if arrows[descendant] then
		arrows[descendant] = nil
		if not next(arrows) and renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
	end
	local connection = promptConnections[descendant]
	if connection then
		connection:Disconnect()
		promptConnections[descendant] = nil
	end
end

function UpgradePedastolController.SetUpgradeAvailable(available: boolean)
	if upgradeAvailable == available then return end
	upgradeAvailable = available
	for _, entry in pedestalHighlights do
		setHighlightFlashing(entry, available)
	end
end

function UpgradePedastolController.Init()
	museums = Workspace:WaitForChild("PlayerMuseums", 10)
	if not museums then return end
	for _, descendant in museums:GetDescendants() do registerDescendant(descendant) end
	museums.DescendantAdded:Connect(registerDescendant)
	museums.DescendantRemoving:Connect(unregisterDescendant)
end

return UpgradePedastolController
