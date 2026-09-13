local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConveyorItem = require(ReplicatedStorage.Modules.Game.ConveyorItem)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)

local CONFIG = {
	Luck = 1,
	SpawnInterval = 3,
	MaximumSegmentGap = 1,
}

local ConveyorController = {
	Config = CONFIG,
}

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
		table.insert(path, (currentSegment.StartPos :: BasePart).CFrame)
	end

	return path
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

	ConveyorItem.new({
		ItemName = itemInfo.Name,
		Path = path,
		MoveSpeed = itemInfo.MoveSpeed,
		StartedAt = Workspace:GetServerTimeNow(),
		Duration = getPathLength(path) / itemInfo.MoveSpeed,
	})
end

function ConveyorController:Init()
	local paths = getConveyorPaths()
	assert(#paths == 2, `Expected two conveyor paths, found {#paths}`)

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
