local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ItemsInfo = require(script.Parent.ItemsInfo)
local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)

local CLASS_INFO = {
	Name = "ConveyorItem",
}

local isServer = RunService:IsServer()
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
		if distance <= segmentLength then
			return from:Lerp(to, if segmentLength > 0 then distance / segmentLength else 1)
		end
		distance -= segmentLength
	end
	return path[#path]
end

function ConveyorItem.new(data)
	local self = setmetatable(data, ConveyorItem)
	self:Link(CLASS_INFO)

	if isServer then
		task.delay(self.Duration, function()
			if self.UniqueId then
				self:Destroy()
			end
		end)
	else
		self:Render()
	end

	return self
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

	self.renderConnection = RunService.RenderStepped:Connect(function()
		local elapsed = Workspace:GetServerTimeNow() - self.StartedAt
		local pathCFrame = getPathCFrame(self.Path, math.max(elapsed, 0) * self.MoveSpeed)
		model:PivotTo(pathCFrame * CFrame.new(0, itemInfo.HeightOffset, 0))
	end)
end

function ConveyorItem:Destroy()
	if isServer then
		if self.UniqueId == nil then
			return
		end
		self:FireAllClients("Destroy")
		self:Unlink()
		return
	end

	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

SharedClass:Link(ConveyorItem, CLASS_INFO)

return ConveyorItem
