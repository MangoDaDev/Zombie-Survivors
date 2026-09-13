local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local PlayVFX = require(ReplicatedStorage.Modules.UI.PlayVFX)
local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)

local CLASS_INFO = {
	Name = "MuseumVisitor",
	AllowedMethods = {},
}

local FADE_DURATION = 0.8
local CASH_EFFECT_DURATION = 1.2
local COMIC_FONT = Font.fromName("ComicNeueAngular")

local renderFolder: Folder?

local MuseumVisitor = {}
MuseumVisitor.__index = MuseumVisitor

local function getRenderFolder(): Folder
	if renderFolder and renderFolder.Parent then
		return renderFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "RenderedMuseumVisitors"
	folder.Parent = Workspace
	renderFolder = folder
	return folder
end

local function prepareModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = true
	end
end

local function applyAppearance(model: Model, shirtTemplate, pantsTemplate, hairTemplate)
	if shirtTemplate and shirtTemplate:IsA("Shirt") then
		shirtTemplate:Clone().Parent = model
	end
	if pantsTemplate and pantsTemplate:IsA("Pants") then
		pantsTemplate:Clone().Parent = model
	end
	if hairTemplate and hairTemplate:IsA("Accessory") then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:AddAccessory(hairTemplate:Clone())
		end
	end
end

local function getFadeInstances(model: Model)
	local instances = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
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
	local template = ReplicatedStorage.Assets.Models.NPCS:FindFirstChild("NPC")
	if template == nil or not template:IsA("Model") then
		warn("MuseumVisitor could not find the NPC template")
		return
	end

	local model = template:Clone()
	model.Name = `MuseumVisitor_{self.OwnerUserId}`
	applyAppearance(model, self.ShirtTemplate, self.PantsTemplate, self.HairTemplate)
	prepareModel(model)
	model.Parent = getRenderFolder()
	model:PivotTo(self.CurrentCFrame or self.SpawnCFrame)

	self.model = model
	self.fadeInstances = getFadeInstances(model)
	self.fadeAlpha = 1
	self.fadeStartAlpha = 1
	self.fadeTargetAlpha = 0
	self.fadeStartedAt = Workspace:GetServerTimeNow()
	self.fadeDuration = FADE_DURATION
	self.renderConnection = RunService.RenderStepped:Connect(function()
		self:Update()
	end)
end

function MuseumVisitor:Update()
	local model = self.model
	if model == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if self.moveTarget then
		local alpha = math.clamp((now - self.moveStartedAt) / self.moveDuration, 0, 1)
		model:PivotTo(self.moveStart:Lerp(self.moveTarget, alpha))
		if alpha >= 1 then
			self.moveTarget = nil
		end
	end

	if self.fadeTargetAlpha ~= nil then
		local alpha = math.clamp((now - self.fadeStartedAt) / self.fadeDuration, 0, 1)
		self.fadeAlpha = self.fadeStartAlpha + (self.fadeTargetAlpha - self.fadeStartAlpha) * alpha
		for _, fadeInfo in self.fadeInstances do
			fadeInfo.instance.Transparency = fadeInfo.transparency
				+ (1 - fadeInfo.transparency) * self.fadeAlpha
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
	self.moveStart = self.model:GetPivot()
	self.moveTarget = targetCFrame
	self.moveStartedAt = Workspace:GetServerTimeNow()
	self.moveDuration = math.max(duration, 0.01)
end

function MuseumVisitor:ShowCash(amount: number)
	local model = self.model
	local rootPart = model and model:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CashEffect"
	billboard.Adornee = rootPart
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Size = UDim2.fromScale(4, 1.3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	billboard.Parent = rootPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = COMIC_FONT
	label.Size = UDim2.fromScale(1, 1)
	label.Text = `+{amount}`
	label.TextColor3 = Color3.fromRGB(72, 232, 91)
	label.TextScaled = true
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
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

	local coinSound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Coin")
	if coinSound and coinSound:IsA("Sound") then
		PlayVFX(coinSound, rootPart)
	end
end

function MuseumVisitor:Say(message: string)
	local model = self.model
	local head = model and model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and message ~= "" then
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
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

SharedClass:Link(MuseumVisitor, CLASS_INFO)

return MuseumVisitor
