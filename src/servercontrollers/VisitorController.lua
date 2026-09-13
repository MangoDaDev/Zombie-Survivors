local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumVisitor = require(ServerStorage.Classes.MuseumVisitor)
local MuseumController = require(ServerStorage.Controllers.MuseumController)

local CONFIG = {
	InitialSpawnDelay = 5,
	BetweenVisitorsMin = 8,
	BetweenVisitorsMax = 14,
	MoveSpeed = 8,
	ActivityCountMin = 4,
	ActivityCountMax = 7,
	InspectChance = 0.6,
	InspectDurationMin = 2,
	InspectDurationMax = 4,
	WanderPauseMin = 1,
	WanderPauseMax = 2,
	ViewPartMargin = 0.75,
	InspectMessageChance = 0.75,
	WanderMessageChance = 0.25,
	FloorMargin = 8,
	FadeDuration = 0.8,
}

local INSPECTION_MESSAGES = {
	"Now that's a lovely restoration.",
	"The details are incredible!",
	"You can tell a lot of care went into this.",
	"What a fascinating piece!",
	"I've never seen one quite like this.",
	"The finish turned out beautifully.",
	"That must have taken ages to restore.",
	"I wonder what story this piece has.",
	"This one really caught my eye.",
	"Impressive work!",
	"It looks almost brand new.",
	"I'd love to know where this was found.",
}

local WANDER_MESSAGES = {
	"What an interesting collection.",
	"There's so much to see here!",
	"I wonder what they'll restore next.",
	"This place has a lovely atmosphere.",
	"Every piece has its own story.",
	"I'm glad I stopped by today.",
	"I could spend hours looking around.",
	"The collection keeps getting better.",
}

local VisitorController = {
	Config = CONFIG,
}

local dataService
local visitTokens: { [Player]: {} } = {}
local activeVisitors: { [Player]: any } = {}

local function getItemInfo(itemId: number)
	for _, itemInfo in ItemsInfo do
		if itemInfo.Id == itemId then
			return itemInfo
		end
	end
	return nil
end

local function getRandomChildOfClass(folder: Instance, className: string)
	local choices = {}
	for _, child in folder:GetChildren() do
		if child:IsA(className) then
			table.insert(choices, child)
		end
	end
	return if #choices > 0 then choices[math.random(1, #choices)] else nil
end

local function getLargestFloor(museum: Model): BasePart?
	local largestFloor: BasePart?
	local largestArea = 0
	for _, child in museum:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Base" then
			local area = child.Size.X * child.Size.Z
			if area > largestArea then
				largestArea = area
				largestFloor = child
			end
		end
	end
	return largestFloor
end

local function getWanderCFrame(floor: BasePart, spawnHeight: number): CFrame
	local halfWidth = math.max(floor.Size.X / 2 - CONFIG.FloorMargin, 1)
	local halfDepth = math.max(floor.Size.Z / 2 - CONFIG.FloorMargin, 1)
	local localPosition = Vector3.new(
		(math.random() * 2 - 1) * halfWidth,
		0,
		(math.random() * 2 - 1) * halfDepth
	)
	local worldPosition = floor.CFrame:PointToWorldSpace(localPosition)
	worldPosition = Vector3.new(worldPosition.X, spawnHeight, worldPosition.Z)
	local direction = floor.CFrame.LookVector
	return CFrame.lookAt(worldPosition, worldPosition + Vector3.new(direction.X, 0, direction.Z))
end

local function getInspectionCFrame(viewPart: BasePart, itemCFrame: BasePart): CFrame
	local halfWidth = math.max(viewPart.Size.X / 2 - CONFIG.ViewPartMargin, 0)
	local halfDepth = math.max(viewPart.Size.Z / 2 - CONFIG.ViewPartMargin, 0)
	local localPosition = Vector3.new(
		(math.random() * 2 - 1) * halfWidth,
		0,
		(math.random() * 2 - 1) * halfDepth
	)
	local standPosition = viewPart.CFrame:PointToWorldSpace(localPosition)
	local itemPosition = itemCFrame.Position
	local lookPosition = Vector3.new(itemPosition.X, standPosition.Y, itemPosition.Z)
	return CFrame.lookAt(standPosition, lookPosition)
end

local function getRandomMessage(messages: { string }, previousMessage: string?): string
	if #messages == 1 then
		return messages[1]
	end

	local message = messages[math.random(1, #messages)]
	while message == previousMessage do
		message = messages[math.random(1, #messages)]
	end
	return message
end

local function isVisitActive(player: Player, token, visitor): boolean
	return player.Parent == Players and visitTokens[player] == token and activeVisitors[player] == visitor
end

local function runVisit(player: Player, token)
	local museum = MuseumController.GetMuseum(player)
	local spawnPart = museum and museum:FindFirstChild("SpawnCFrame")
	local floor = museum and getLargestFloor(museum)
	if spawnPart == nil or not spawnPart:IsA("BasePart") or floor == nil then
		return
	end

	local npcAssets = ReplicatedStorage.Assets.Models.NPCS
	local spawnCFrame = spawnPart.CFrame
	local visitor = MuseumVisitor.new({
		OwnerUserId = player.UserId,
		SpawnCFrame = spawnCFrame,
		CurrentCFrame = spawnCFrame,
		ShirtTemplate = getRandomChildOfClass(npcAssets.Shirts, "Shirt"),
		PantsTemplate = getRandomChildOfClass(npcAssets.Pants, "Pants"),
		HairTemplate = getRandomChildOfClass(npcAssets.Hair, "Accessory"),
	})
	activeVisitors[player] = visitor

	local currentCFrame = spawnCFrame
	local lastMessage: string?
	local function maybeSay(messages: { string }, chance: number)
		if math.random() <= chance then
			lastMessage = getRandomMessage(messages, lastMessage)
			visitor:Say(lastMessage)
		end
	end

	local function moveTo(targetCFrame: CFrame): boolean
		local duration = (targetCFrame.Position - currentCFrame.Position).Magnitude / CONFIG.MoveSpeed
		visitor:MoveTo(targetCFrame, duration)
		currentCFrame = targetCFrame
		task.wait(duration)
		return isVisitActive(player, token, visitor)
	end

	for _ = 1, math.random(CONFIG.ActivityCountMin, CONFIG.ActivityCountMax) do
		if not isVisitActive(player, token, visitor) then
			return
		end

		local occupiedDisplays = MuseumController.GetOccupiedDisplays(player)
		if #occupiedDisplays > 0 and math.random() <= CONFIG.InspectChance then
			local displayState = occupiedDisplays[math.random(1, #occupiedDisplays)]
			local itemId = displayState.itemId
			local itemInfo = itemId and getItemInfo(itemId)
			if itemInfo and moveTo(getInspectionCFrame(displayState.viewPart, displayState.itemCFrame)) then
				maybeSay(INSPECTION_MESSAGES, CONFIG.InspectMessageChance)
				task.wait(math.random(CONFIG.InspectDurationMin, CONFIG.InspectDurationMax))
				if isVisitActive(player, token, visitor) and displayState.itemId == itemId then
					dataService:update(player, "Cash", function(cash)
						return (if type(cash) == "number" then cash else 0) + itemInfo.GuestPay
					end)
					visitor:ShowCash(itemInfo.GuestPay)
				end
			end
		else
			if not moveTo(getWanderCFrame(floor, spawnCFrame.Position.Y)) then
				return
			end
			maybeSay(WANDER_MESSAGES, CONFIG.WanderMessageChance)
			task.wait(math.random(CONFIG.WanderPauseMin, CONFIG.WanderPauseMax))
		end
	end

	if isVisitActive(player, token, visitor) then
		moveTo(spawnCFrame)
	end
	if isVisitActive(player, token, visitor) then
		visitor:FadeOut(CONFIG.FadeDuration)
		task.wait(CONFIG.FadeDuration)
	end
	if isVisitActive(player, token, visitor) then
		activeVisitors[player] = nil
		visitor:Destroy()
	end
end

function VisitorController.SetDataService(service)
	dataService = service
end

function VisitorController.OnPlayerAdded(player: Player)
	local token = {}
	visitTokens[player] = token
	task.spawn(function()
		task.wait(CONFIG.InitialSpawnDelay)
		while player.Parent == Players and visitTokens[player] == token do
			runVisit(player, token)
			task.wait(math.random(CONFIG.BetweenVisitorsMin, CONFIG.BetweenVisitorsMax))
		end
	end)
end

function VisitorController.OnPlayerRemoving(player: Player)
	visitTokens[player] = nil
	local visitor = activeVisitors[player]
	activeVisitors[player] = nil
	if visitor then
		visitor:Destroy()
	end
end

return VisitorController
