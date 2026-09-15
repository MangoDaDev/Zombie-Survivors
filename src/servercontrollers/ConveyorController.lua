local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CarryController = require(ServerStorage.Controllers.CarryController)
local ConveyorItem = require(ServerStorage.Classes.ConveyorItem)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)

local CONFIG = {
	Luck = 1,
	SpawnInterval = 3,
	MaximumSegmentGap = 1,
	PurchaseDistanceBuffer = 3,
}

local ConveyorController = {
	Config = CONFIG,
}

local dataService

local function getPathLength(path: { CFrame }): number
	local length = 0
	for index = 1, #path - 1 do
		length += (path[index + 1].Position - path[index].Position).Magnitude
	end
	return length
end

local function getConveyorSegments(): { Model }
	local segments = {}
	for _, child in Workspace.Conveyors:GetChildren() do
		if
			child:IsA("Model")
			and child:FindFirstChild("StartPos")
			and child:FindFirstChild("EndPos")
		then
			table.insert(segments, child)
		end
	end
	return segments
end

local function buildPath(startSegment: Model, segments: { Model }): { CFrame }
	local currentSegment = startSegment
	local visited = { [startSegment] = true }
	local path = { (startSegment.StartPos :: BasePart).CFrame }

	while true do
		local endPos = currentSegment.EndPos :: BasePart
		table.insert(path, endPos.CFrame)
		if currentSegment.Name == "EndSegment" then
			break
		end

		local nextSegment: Model?
		local nearestDistance = math.huge
		for _, candidate in segments do
			if not visited[candidate] then
				local distance = (endPos.Position - (candidate.StartPos :: BasePart).Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nextSegment = candidate
				end
			end
		end

		assert(nextSegment and nearestDistance <= CONFIG.MaximumSegmentGap, "Conveyor path has a missing segment")
		currentSegment = nextSegment
		visited[currentSegment] = true
	end

	return path
end

local function getItemInfo(itemName: string)
	for _, itemInfo in ItemsInfo do
		if itemInfo.Name == itemName then
			return itemInfo
		end
	end
	return nil
end

local function purchaseItem(item, player: Player)
	if item.Purchased or item.UniqueId == nil or not CarryController.CanCarry(player) then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return
	end
	if (rootPart.Position - item:GetCurrentCFrame().Position).Magnitude > 10 + CONFIG.PurchaseDistanceBuffer then
		return
	end

	local itemInfo = getItemInfo(item.ItemName)
	local cash = dataService:get(player, "Cash")
	if itemInfo == nil or type(cash) ~= "number" or cash < itemInfo.Price then
		return
	end

	item.Purchased = true
	if not CarryController.StartCarrying(player, itemInfo.Id, item.DirtCount) then
		item.Purchased = nil
		return
	end

	dataService:set(player, "Cash", cash - itemInfo.Price)
	item:Destroy()
end

function ConveyorController.SetDataService(service)
	dataService = service
end

local function getConveyorPaths(): { { CFrame } }
	local segments = getConveyorSegments()
	local startSegments = {}
	for _, segment in segments do
		if segment.Name == "StartSegment" then
			table.insert(startSegments, segment)
		end
	end
	table.sort(startSegments, function(a, b)
		return (a.StartPos :: BasePart).Position.X < (b.StartPos :: BasePart).Position.X
	end)

	local paths = {}
	for _, startSegment in startSegments do
		table.insert(paths, buildPath(startSegment, segments))
	end
	return paths
end

local function spawnItem(path: { CFrame })
	local itemInfo = GetRandomFromWeightedTable.GetRandomFromWeightedTable(ItemsInfo, "ChanceWeight", nil, CONFIG.Luck)
	if itemInfo == nil then
		warn("ConveyorController could not select an item from ItemsInfo")
		return
	end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(itemInfo.AssetName)
	if Template == nil or not Template:IsA("Model") then
		warn(`ConveyorController could not find item model {itemInfo.AssetName}`)
		return
	end

	ConveyorItem.new({
		ItemName = itemInfo.Name,
		Path = path,
		MoveSpeed = itemInfo.MoveSpeed,
		StartedAt = Workspace:GetServerTimeNow(),
		Duration = getPathLength(path) / itemInfo.MoveSpeed,
		DirtCount = DirtRenderer.GetSuggestedCount(Template),
	})
end

function ConveyorController.Init()
	local paths = getConveyorPaths()
	assert(#paths == 2, `Expected two conveyor paths, found {#paths}`)
	ConveyorItem.SetPurchaseHandler(purchaseItem)

	task.spawn(function()
		while true do
			for _, path in paths do
				spawnItem(path)
			end
			task.wait(CONFIG.SpawnInterval)
		end
	end)
end

return ConveyorController
