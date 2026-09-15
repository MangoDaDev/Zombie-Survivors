local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumVisitor = require(ServerStorage.Classes.MuseumVisitor)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)

local CONFIG = {
	InitialSpawnDelay = 1,
	BetweenVisitorsMin = 4,
	BetweenVisitorsMax = 7,
	MoveSpeed = 8,
	ActivityCountMin = 4,
	ActivityCountMax = 7,
	InspectChance = 0.9,
	InspectDurationMin = 1,
	InspectDurationMax = 2,
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
local activeVisitors: { [Player]: { [any]: boolean } } = {}
local DisplayReservations: { [Player]: { [any]: number } } = {}

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

local function GetGroundedCFrame(Museum: Model, TargetCFrame: CFrame): CFrame
	local RaycastParameters = RaycastParams.new()
	RaycastParameters.FilterType = Enum.RaycastFilterType.Include
	RaycastParameters.FilterDescendantsInstances = { Museum }
	RaycastParameters.RespectCanCollide = true

	local RayOrigin = TargetCFrame.Position + Vector3.new(0, 4, 0)
	local RayResult = Workspace:Raycast(RayOrigin, Vector3.new(0, -12, 0), RaycastParameters)
	if RayResult == nil then
		return TargetCFrame
	end
	return CFrame.new(RayResult.Position) * TargetCFrame.Rotation
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
	local ActiveForPlayer = activeVisitors[player]
	return player.Parent == Players
		and visitTokens[player] == token
		and ActiveForPlayer ~= nil
		and ActiveForPlayer[visitor] == true
end

local function GetAvailableDisplays(Player: Player): { any }
	local AvailableDisplays = {}
	local Reservations = DisplayReservations[Player]
	if not Reservations then return AvailableDisplays end
	local VisitorsPerDisplay = UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	for _, DisplayState in MuseumController.GetOccupiedDisplays(Player) do
		if (Reservations[DisplayState] or 0) < VisitorsPerDisplay then
			table.insert(AvailableDisplays, DisplayState)
		end
	end
	return AvailableDisplays
end

local function GetActiveVisitorLimit(Player: Player): number
	local OccupiedDisplayCount = #MuseumController.GetOccupiedDisplays(Player)
	local VisitorsPerDisplay = UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	return OccupiedDisplayCount * VisitorsPerDisplay
end

local function ReserveDisplay(Player: Player, DisplayState): boolean
	local Reservations = DisplayReservations[Player]
	if not Reservations then return false end
	local VisitorsPerDisplay = UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	local CurrentCount = Reservations[DisplayState] or 0
	if CurrentCount >= VisitorsPerDisplay then return false end
	Reservations[DisplayState] = CurrentCount + 1
	return true
end

local function ReleaseDisplay(Player: Player, DisplayState)
	local Reservations = DisplayReservations[Player]
	if not Reservations then return end
	local CurrentCount = Reservations[DisplayState] or 0
	Reservations[DisplayState] = if CurrentCount > 1 then CurrentCount - 1 else nil
end

local function runVisit(player: Player, token)
	if #MuseumController.GetOccupiedDisplays(player) == 0 then return end

	local museum = MuseumController.GetMuseum(player)
	local spawnPart = museum and museum:FindFirstChild("SpawnCFrame")
	local floor = museum and getLargestFloor(museum)
	if spawnPart == nil or not spawnPart:IsA("BasePart") or floor == nil then
		return
	end

	local npcAssets = ReplicatedStorage.Assets.Models.NPCS
	local spawnCFrame = GetGroundedCFrame(museum, spawnPart.CFrame)
	local visitor = MuseumVisitor.new({
		OwnerUserId = player.UserId,
		SpawnCFrame = spawnCFrame,
		CurrentCFrame = spawnCFrame,
		ShirtTemplate = getRandomChildOfClass(npcAssets.Shirts, "Shirt"),
		PantsTemplate = getRandomChildOfClass(npcAssets.Pants, "Pants"),
		HairTemplate = getRandomChildOfClass(npcAssets.Hair, "Accessory"),
	})
	local ActiveForPlayer = activeVisitors[player]
	if ActiveForPlayer == nil or visitTokens[player] ~= token then
		visitor:Destroy()
		return
	end
	ActiveForPlayer[visitor] = true

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

		local AvailableDisplays = GetAvailableDisplays(player)
		if #AvailableDisplays > 0 and math.random() <= CONFIG.InspectChance then
			local displayState = AvailableDisplays[math.random(1, #AvailableDisplays)]
			if not ReserveDisplay(player, displayState) then continue end
			local itemId = displayState.itemId
			local itemInfo = itemId and getItemInfo(itemId)
			local InspectionCFrame = GetGroundedCFrame(
				museum,
				getInspectionCFrame(displayState.viewPart, displayState.itemCFrame)
			)
			if itemInfo and moveTo(InspectionCFrame) then
				maybeSay(INSPECTION_MESSAGES, CONFIG.InspectMessageChance)
				task.wait(math.random(CONFIG.InspectDurationMin, CONFIG.InspectDurationMax))
				if isVisitActive(player, token, visitor) and displayState.itemId == itemId then
					dataService:update(player, "Cash", function(cash)
						return (if type(cash) == "number" then cash else 0) + itemInfo.GuestPay
					end)
					GuidanceController.Advance(player, "EarnMoney")
					visitor:ShowCash(itemInfo.GuestPay)
				end
			end
			ReleaseDisplay(player, displayState)
		else
			local WanderCFrame = GetGroundedCFrame(museum, getWanderCFrame(floor, spawnCFrame.Position.Y))
			if not moveTo(WanderCFrame) then
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
		activeVisitors[player][visitor] = nil
		visitor:Destroy()
	end
end

function VisitorController.SetDataService(service)
	dataService = service
end

function VisitorController.OnPlayerAdded(player: Player)
	local token = {}
	visitTokens[player] = token
	activeVisitors[player] = {}
	DisplayReservations[player] = {}
	task.spawn(function()
		task.wait(CONFIG.InitialSpawnDelay)
		while player.Parent == Players and visitTokens[player] == token do
			local ActiveForPlayer = activeVisitors[player]
			local ActiveCount = 0
			if ActiveForPlayer then
				for _ in ActiveForPlayer do
					ActiveCount += 1
				end
			end
			if ActiveCount < GetActiveVisitorLimit(player) and #MuseumController.GetOccupiedDisplays(player) > 0 then
				task.spawn(runVisit, player, token)
			end
			task.wait(math.random(CONFIG.BetweenVisitorsMin, CONFIG.BetweenVisitorsMax))
		end
	end)
end

function VisitorController.OnPlayerRemoving(player: Player)
	visitTokens[player] = nil
	local Visitors = activeVisitors[player]
	activeVisitors[player] = nil
	DisplayReservations[player] = nil
	if Visitors then
		for Visitor in Visitors do
			Visitor:Destroy()
		end
	end
end

return VisitorController
