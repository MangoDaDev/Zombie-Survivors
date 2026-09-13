local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)

local CLASS_INFO = {
	Name = "ConveyorItem",
	AllowedMethods = { "Purchase" },
}

local purchaseHandler: ((any, Player) -> ())?

local ConveyorItem = {}
ConveyorItem.__index = ConveyorItem

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

	task.delay(self.Duration, function()
		if self.UniqueId then
			self:Destroy()
		end
	end)

	return self
end

function ConveyorItem.SetPurchaseHandler(handler: (any, Player) -> ())
	purchaseHandler = handler
end

function ConveyorItem:GetCurrentCFrame(): CFrame
	local elapsed = Workspace:GetServerTimeNow() - self.StartedAt
	return getPathCFrame(self.Path, math.max(elapsed, 0) * self.MoveSpeed)
end

function ConveyorItem:Purchase(player: Player)
	if purchaseHandler then
		purchaseHandler(self, player)
	end
end

function ConveyorItem:Destroy()
	if self.UniqueId == nil then
		return
	end
	self:FireAllClients("Destroy")
	self:Unlink()
end

SharedClass:Link(ConveyorItem, CLASS_INFO)

return ConveyorItem
