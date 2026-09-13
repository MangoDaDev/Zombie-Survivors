local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)

local CLASS_INFO = {
	Name = "ConveyorItem",
	AllowedMethods = { "Purchase" },
}

local PROMPT_DISTANCE = 10

local renderFolder: Folder?

local ConveyorItem = {}
ConveyorItem.__index = ConveyorItem

local function getItemInfo(itemName: string)
	for _, itemInfo in ItemsInfo do
		if itemInfo.Name == itemName then
			return itemInfo
		end
	end
	return nil
end

local function getRenderFolder(): Folder
	if renderFolder then
		return renderFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "RenderedConveyorItems"
	folder.Parent = Workspace
	renderFolder = folder
	return folder
end

local function getPathCFrame(path: { CFrame }, distance: number): CFrame
	for index = 1, #path - 1 do
		local from = path[index]
		local to = path[index + 1]
		local segmentLength = (to.Position - from.Position).Magnitude
		if segmentLength > 0 and distance <= segmentLength then
			return from:Lerp(to, distance / segmentLength)
		end
		distance -= segmentLength
	end
	return path[#path]
end

function ConveyorItem.new(data)
	local self = setmetatable(data, ConveyorItem)
	self:Link(CLASS_INFO)
	self:Render()
	return self
end

function ConveyorItem:GetCurrentCFrame(): CFrame
	local elapsed = Workspace:GetServerTimeNow() - self.StartedAt
	return getPathCFrame(self.Path, math.max(elapsed, 0) * self.MoveSpeed)
end

function ConveyorItem:Render()
	local itemInfo = getItemInfo(self.ItemName)
	if itemInfo == nil then
		warn(`ConveyorItem has no ItemsInfo entry named {self.ItemName}`)
		return
	end

	local template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(itemInfo.AssetName)
	if template == nil or not template:IsA("Model") then
		warn(`ConveyorItem could not find item model {itemInfo.AssetName}`)
		return
	end

	local model = template:Clone()
	local primaryPart = model.PrimaryPart
	if primaryPart == nil then
		model:Destroy()
		warn(`ConveyorItem model {itemInfo.AssetName} has no PrimaryPart`)
		return
	end
	local heightOffset = primaryPart.Size.Y / 2

	model.Name = self.ItemName
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	model.Parent = getRenderFolder()
	self.model = model
	ItemInfoBillboard(itemInfo, primaryPart)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy ${itemInfo.Price}`
	prompt.ObjectText = self.ItemName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = primaryPart
	self.prompt = prompt
	self.promptConnection = prompt.Triggered:Connect(function()
		self:FireServer("Purchase")
	end)

	self.renderConnection = RunService.RenderStepped:Connect(function()
		local pathCFrame = self:GetCurrentCFrame()
		model:PivotTo(pathCFrame * CFrame.new(0, heightOffset, 0))
	end)
end

function ConveyorItem:Destroy()
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
	if self.promptConnection then
		self.promptConnection:Disconnect()
		self.promptConnection = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

SharedClass:Link(ConveyorItem, CLASS_INFO)

return ConveyorItem
