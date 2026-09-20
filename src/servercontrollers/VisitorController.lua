local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local ServerStorage = game:GetService "ServerStorage"
local Workspace = game:GetService "Workspace"

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumVisitor = require(ServerStorage.Classes.MuseumVisitor)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local MuseumConfig = require(ReplicatedStorage.Modules.Game.MuseumConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local Networker = require(ReplicatedStorage.Packages.networker)

local CONFIG = {
	InitialSpawnDelay = 2,
	VisitorSpawnInterval = 0.5,
	MoveSpeed = 8,
	ActivityCountMin = 2,
	ActivityCountMax = 7,
	InspectChance = 0.9,
	InspectDurationMin = 1,
	InspectDurationMax = 2,
	WanderPauseMin = 1,
	WanderPauseMax = 2,
	ViewPartMargin = 0.75,
	InspectMessageChance = 0.15,
	WanderMessageChance = 0.15,
	FloorMargin = 8,
	FadeDuration = 0.8,
	HitRagdollDuration = 1.6,
	HitFadeDuration = 0.45,
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
	"The craftsmanship is remarkable.",
	"This has been restored wonderfully.",
	"What an unusual find!",
	"I can't believe how good this looks.",
	"The restoration really brought it back to life.",
	"This must be worth a fair bit.",
	"I wonder how old this is.",
	"They did an excellent job with this one.",
	"Look at all those little details!",
	"This is definitely one of my favorites.",
	"I'd love something like this at home.",
	"What a beautiful piece of history.",
	"You'd never guess this was damaged before.",
	"The condition is incredible now.",
	"I wonder who originally owned this.",
	"This looks professionally restored.",
	"Such an interesting design.",
	"I didn't expect to see one of these here.",
	"This is in amazing shape.",
	"What a transformation!",
	"They really cleaned this up nicely.",
	"I wonder how they managed to restore this.",
	"The colors look fantastic.",
	"This piece really stands out.",
	"I could look at this for ages.",
	"There's something special about this one.",
	"The attention to detail is impressive.",
	"That restoration must have been difficult.",
	"This looks like it belongs in a proper museum.",
	"I'd love to see what it looked like before.",
	"The original design is still so clear.",
	"It's amazing what a good restoration can do.",
	"This must have an interesting history.",
	"What a rare-looking piece.",
	"The surface looks incredibly clean.",
	"This was definitely worth restoring.",
	"Someone clearly put a lot of effort into this.",
	"I wonder how much this is worth.",
	"This has been preserved beautifully.",
	"You don't see craftsmanship like this often.",
	"This looks better every time I look at it.",
	"I wonder how long this was lost for.",
	"The restoration really shows off the original details.",
	"This one has so much character.",
	"I can see why they decided to display this.",
	"This is such a satisfying restoration.",
	"The before-and-after must have been incredible.",
	"I hope they find more pieces like this.",
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
	"This museum is bigger than I expected.",
	"I wonder what's upstairs.",
	"There are so many interesting things here.",
	"I should tell my friends about this place.",
	"I wonder what the rarest item here is.",
	"This is a nice way to spend the day.",
	"They've really put together a great collection.",
	"I wonder how they find all these items.",
	"I hope they add even more displays.",
	"This place feels different every time I visit.",
	"There's always something new to look at.",
	"I wonder which piece is the oldest.",
	"I could definitely come back here again.",
	"The displays are arranged really nicely.",
	"This collection must have taken ages to build.",
	"I wonder how much everything here is worth.",
	"It's surprisingly peaceful in here.",
	"I wasn't expecting such a large collection.",
	"There are some really unusual pieces here.",
	"I wonder where they store everything.",
	"This museum has come a long way.",
	"I wonder what their next big discovery will be.",
	"I like how every display feels different.",
	"There must be some rare treasures hidden around here.",
	"It's nice seeing old things given a second life.",
	"I wonder who restores all of this.",
	"There's something interesting around every corner.",
	"I should take another look around.",
	"This place is full of surprises.",
	"I wonder how many items they've restored.",
	"Some of these pieces must be incredibly rare.",
	"The collection has a lot of variety.",
	"I'd like to see how the restoration process works.",
	"I wonder which item took the longest to restore.",
	"This place must get new items all the time.",
	"I've already spotted a few favorites.",
	"There's still so much I haven't seen.",
	"It's amazing how much history is in one place.",
	"I wonder if anything here was recently discovered.",
	"The museum is really starting to fill up.",
	"I hope there's another floor to explore.",
	"I wonder what the most valuable exhibit is.",
	"The collection feels really well cared for.",
	"I could easily lose track of time in here.",
	"I wonder how many more displays they can fit.",
	"This would be a great place to visit again.",
	"Every section has something worth seeing.",
	"I wonder what condition these were in originally.",
	"The restorations make everything look so impressive.",
	"I wasn't expecting to enjoy this place this much.",
	"I wonder what they'll put on display next.",
	"There's always another interesting piece nearby.",
}

local HIT_MESSAGES = {
	"Ow! What was that for?!",
	"Hey! I'm a paying guest!",
	"I'm leaving a terrible review!",
	"Security!",
	"This museum is dangerous!",
}

local VisitorController = {
	Config = CONFIG,
}

local SKIN_COLORS = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(241, 194, 125),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 51, 23),
}

local dataService
local visitTokens: { [Player]: {} } = {}
local activeVisitors: { [Player]: { [any]: number } } = {}
local DisplayReservations: { [Player]: { [any]: number } } = {}
local ActiveCounts: { [Player]: { [number]: number } } = {}
local VisitorsPerDisplay: { [Player]: number } = {}
local UpgradeConnections: { [Player]: RBXScriptConnection } = {}
local LevelRuntime: { [Player]: { [number]: any } } = {}
local ReadyPlayers: { [Player]: boolean } = {}
local SubscribersByOwner: { [Player]: { [Player]: boolean } } = {}
local ViewedOwnerByPlayer: { [Player]: Player } = {}
local LastViewRequestAt: { [Player]: number } = {}
local ItemsById = {}
local ShirtChoices = {}
local PantsChoices = {}
local HairChoices = {}
local Network

local function getItemInfo(itemId: number)
	return ItemsById[itemId]
end

local function GetRandomChoice(Choices)
	return if #Choices > 0 then Choices[math.random(1, #Choices)] else nil
end

local function getLargestFloor(museum: Model): BasePart?
	local largestFloor: BasePart?
	local largestArea = 0
	for _, child in museum:GetDescendants() do
		if child:IsA "BasePart" and child.Name == "Base" then
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
	local localPosition = Vector3.new((math.random() * 2 - 1) * halfWidth, 0, (math.random() * 2 - 1) * halfDepth)
	local worldPosition = floor.CFrame:PointToWorldSpace(localPosition)
	worldPosition = Vector3.new(worldPosition.X, spawnHeight, worldPosition.Z)
	local direction = floor.CFrame.LookVector
	return CFrame.lookAt(worldPosition, worldPosition + Vector3.new(direction.X, 0, direction.Z))
end

local function getInspectionCFrame(viewPart: BasePart, itemCFrame: BasePart): CFrame
	local halfWidth = math.max(viewPart.Size.X / 2 - CONFIG.ViewPartMargin, 0)
	local halfDepth = math.max(viewPart.Size.Z / 2 - CONFIG.ViewPartMargin, 0)
	local localPosition = Vector3.new((math.random() * 2 - 1) * halfWidth, 0, (math.random() * 2 - 1) * halfDepth)
	local standPosition = viewPart.CFrame:PointToWorldSpace(localPosition)
	local itemPosition = itemCFrame.Position
	local lookPosition = Vector3.new(itemPosition.X, standPosition.Y, itemPosition.Z)
	return CFrame.lookAt(standPosition, lookPosition)
end

local function GetGroundedCFrame(RaycastParameters: RaycastParams, TargetCFrame: CFrame): CFrame
	local RayOrigin = TargetCFrame.Position + Vector3.new(0, 4, 0)
	local RayResult = Workspace:Raycast(RayOrigin, Vector3.new(0, -12, 0), RaycastParameters)
	if RayResult == nil then
		return TargetCFrame
	end
	return CFrame.new(RayResult.Position) * TargetCFrame.Rotation
end

local function GetLevelRuntime(Player: Player, LevelNumber: number)
	local PlayerRuntime = LevelRuntime[Player]
	if not PlayerRuntime then return nil end
	local Cached = PlayerRuntime[LevelNumber]
	local Level = MuseumController.GetLevel(Player, LevelNumber)
	if Cached and Cached.Level == Level and Level and Level.Parent then return Cached end
	if not Level then return nil end
	local SpawnPart = Level:FindFirstChild("SpawnCFrame")
	local Floor = getLargestFloor(Level)
	if not SpawnPart or not SpawnPart:IsA("BasePart") or not Floor then return nil end
	local RaycastParameters = RaycastParams.new()
	RaycastParameters.FilterType = Enum.RaycastFilterType.Include
	RaycastParameters.FilterDescendantsInstances = { Level }
	RaycastParameters.RespectCanCollide = true
	Cached = {
		Level = Level,
		Floor = Floor,
		RaycastParameters = RaycastParameters,
		SpawnCFrame = GetGroundedCFrame(RaycastParameters, SpawnPart.CFrame),
	}
	PlayerRuntime[LevelNumber] = Cached
	return Cached
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
		and ActiveForPlayer[visitor] ~= nil
end

function VisitorController.GetOwnedVisitor(Player: Player, UniqueId: string)
	if type(UniqueId) ~= "string" then return nil end
	local ActiveForPlayer = activeVisitors[Player]
	if not ActiveForPlayer then return nil end
	for Visitor in ActiveForPlayer do
		if Visitor.UniqueId == UniqueId then return Visitor end
	end
	return nil
end

function VisitorController.HitVisitor(Player: Player, Visitor, Knockback: Vector3): boolean
	local ActiveForPlayer = activeVisitors[Player]
	local Counts = ActiveCounts[Player]
	-- Bat hits must only ever remove a guest owned by the attacking player.
	if not ActiveForPlayer or not Counts or ActiveForPlayer[Visitor] == nil or Visitor.OwnerPlayer ~= Player then return false end
	local LevelNumber = ActiveForPlayer[Visitor]
	ActiveForPlayer[Visitor] = nil
	Counts[LevelNumber] = math.max((Counts[LevelNumber] or 1) - 1, 0)
	Visitor:Say(HIT_MESSAGES[math.random(1, #HIT_MESSAGES)])
	Visitor:Ragdoll(Knockback)
	task.delay(CONFIG.HitRagdollDuration, function()
		if Visitor.UniqueId == nil then return end
		Visitor:FadeOut(CONFIG.HitFadeDuration)
		task.delay(CONFIG.HitFadeDuration, function()
			Visitor:Destroy()
		end)
	end)
	return true
end

local function IsPointInsidePart(Point: Vector3, Part: BasePart): boolean
	local LocalPoint = Part.CFrame:PointToObjectSpace(Point)
	local HalfSize = Part.Size / 2
	return math.abs(LocalPoint.X) <= HalfSize.X and math.abs(LocalPoint.Y) <= HalfSize.Y and math.abs(LocalPoint.Z) <= HalfSize.Z
end

local function CanObserve(Subscriber: Player, Owner: Player): boolean
	if Subscriber == Owner then return true end
	local Character = Subscriber.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return false end
	for _, MuseumArea in MuseumController.GetMuseumAreas(Owner) do
		if MuseumArea.Parent and IsPointInsidePart(RootPart.Position, MuseumArea) then return true end
	end
	return false
end

local function SendOwnerSnapshot(Subscriber: Player, Owner: Player)
	local Visitors = activeVisitors[Owner]
	if not Visitors or not Network then return end
	for Visitor in Visitors do Network:fire(Subscriber, "CreateVisitor", Visitor:GetSnapshot()) end
end

local function AddSubscriber(Subscriber: Player, Owner: Player)
	if not ReadyPlayers[Subscriber] or not CanObserve(Subscriber, Owner) then return end
	local Subscribers = SubscribersByOwner[Owner]
	if not Subscribers then Subscribers = {}; SubscribersByOwner[Owner] = Subscribers end
	if Subscribers[Subscriber] then return end
	Subscribers[Subscriber] = true
	SendOwnerSnapshot(Subscriber, Owner)
end

local function RemoveSubscriber(Subscriber: Player, Owner: Player)
	local Subscribers = SubscribersByOwner[Owner]
	if not Subscribers or not Subscribers[Subscriber] then return end
	Subscribers[Subscriber] = nil
	if Network and Subscriber.Parent == Players then Network:fire(Subscriber, "ClearOwner", Owner.UserId) end
end

local function BroadcastVisitor(Visitor, Method: string, ...)
	local Owner = Visitor.OwnerPlayer
	local Subscribers = Owner and SubscribersByOwner[Owner]
	if not Subscribers or not Network then return end
	for Subscriber in Subscribers do
		if Subscriber.Parent ~= Players or not ReadyPlayers[Subscriber] or not CanObserve(Subscriber, Owner) then
			Subscribers[Subscriber] = nil
			if Subscriber.Parent == Players then Network:fire(Subscriber, "ClearOwner", Owner.UserId) end
		else
			Network:fire(Subscriber, Method, ...)
		end
	end
end

local function GetAvailableDisplays(Player: Player, LevelNumber: number): { any }
	local AvailableDisplays = {}
	local Reservations = DisplayReservations[Player]
	if not Reservations then
		return AvailableDisplays
	end
	local VisitorLimit = VisitorsPerDisplay[Player] or UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	for _, DisplayState in MuseumController.GetOccupiedDisplays(Player, LevelNumber) do
		if (Reservations[DisplayState] or 0) < VisitorLimit then
			table.insert(AvailableDisplays, DisplayState)
		end
	end
	return AvailableDisplays
end

local function GetActiveVisitorLimit(Player: Player, LevelNumber: number): number
	local OccupiedDisplayCount = #MuseumController.GetOccupiedDisplays(Player, LevelNumber)
	local VisitorLimit = VisitorsPerDisplay[Player] or UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	-- Each level's visitor population is based only on the items displayed on that level.
	return OccupiedDisplayCount * VisitorLimit
end

local function ReserveDisplay(Player: Player, DisplayState): boolean
	local Reservations = DisplayReservations[Player]
	if not Reservations then
		return false
	end
	local VisitorLimit = VisitorsPerDisplay[Player] or UpgradeLogic.GetVisitorsPerDisplay(dataService:get(Player, "Upgrades"))
	local CurrentCount = Reservations[DisplayState] or 0
	if CurrentCount >= VisitorLimit then
		return false
	end
	Reservations[DisplayState] = CurrentCount + 1
	return true
end

local function ReleaseDisplay(Player: Player, DisplayState)
	local Reservations = DisplayReservations[Player]
	if not Reservations then
		return
	end
	local CurrentCount = Reservations[DisplayState] or 0
	Reservations[DisplayState] = if CurrentCount > 1 then CurrentCount - 1 else nil
end

local function runVisit(player: Player, token, levelNumber: number)
	if #MuseumController.GetOccupiedDisplays(player, levelNumber) == 0 then
		return
	end

	local Runtime = GetLevelRuntime(player, levelNumber)
	if not Runtime then return end
	local level = Runtime.Level
	local floor = Runtime.Floor
	local RaycastParameters = Runtime.RaycastParameters
	local spawnCFrame = Runtime.SpawnCFrame
	local ShirtTemplate = GetRandomChoice(ShirtChoices)
	local PantsTemplate = GetRandomChoice(PantsChoices)
	local HairTemplate = GetRandomChoice(HairChoices)
	local visitor = MuseumVisitor.new({
		OwnerPlayer = player,
		OwnerUserId = player.UserId,
		SpawnCFrame = spawnCFrame,
		CurrentCFrame = spawnCFrame,
		ShirtTemplate = ShirtTemplate,
		PantsTemplate = PantsTemplate,
		HairTemplate = HairTemplate,
		SkinColor = SKIN_COLORS[math.random(1, #SKIN_COLORS)],
	}, BroadcastVisitor)
	local ActiveForPlayer = activeVisitors[player]
	if ActiveForPlayer == nil or visitTokens[player] ~= token then
		visitor:Destroy()
		return
	end
	ActiveForPlayer[visitor] = levelNumber
	ActiveCounts[player][levelNumber] = (ActiveCounts[player][levelNumber] or 0) + 1
	visitor:StartReplication()

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

		local AvailableDisplays = GetAvailableDisplays(player, levelNumber)
		if #AvailableDisplays > 0 and math.random() <= CONFIG.InspectChance then
			local displayState = AvailableDisplays[math.random(1, #AvailableDisplays)]
			if not ReserveDisplay(player, displayState) then
				continue
			end
			local itemId = displayState.itemId
			local itemInfo = itemId and getItemInfo(itemId)
			local InspectionCFrame =
				GetGroundedCFrame(RaycastParameters, getInspectionCFrame(displayState.viewPart, displayState.itemCFrame))
			if itemInfo and moveTo(InspectionCFrame) then
				maybeSay(INSPECTION_MESSAGES, CONFIG.InspectMessageChance)
				task.wait(math.random(CONFIG.InspectDurationMin, CONFIG.InspectDurationMax))
				if isVisitActive(player, token, visitor) and displayState.itemId == itemId then
					dataService:update(player, "Cash", function(cash)
						return (if type(cash) == "number" then cash else 0) + itemInfo.GuestPay
					end)
					AnalyticsController.TrackFirstVisitorIncome(player, itemId, levelNumber, itemInfo.GuestPay)
					GuidanceController.Advance(player, "EarnMoney")
					visitor:ShowCash(itemInfo.GuestPay)
				end
			end
			ReleaseDisplay(player, displayState)
		else
			local WanderCFrame = GetGroundedCFrame(RaycastParameters, getWanderCFrame(floor, spawnCFrame.Position.Y))
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
		ActiveCounts[player][levelNumber] = math.max((ActiveCounts[player][levelNumber] or 1) - 1, 0)
		visitor:Destroy()
	end
end

function VisitorController.SetDataService(service)
	dataService = service
end

function VisitorController.Ready(_, Player: Player)
	if ReadyPlayers[Player] or Player.Parent ~= Players then return end
	ReadyPlayers[Player] = true
	AddSubscriber(Player, Player)
end

function VisitorController.SetViewedMuseum(_, Player: Player, OwnerUserId)
	if not ReadyPlayers[Player] or type(OwnerUserId) ~= "number" or OwnerUserId % 1 ~= 0 then return end
	local Now = os.clock()
	if Now - (LastViewRequestAt[Player] or 0) < 0.1 then return end
	LastViewRequestAt[Player] = Now
	local Owner = Players:GetPlayerByUserId(OwnerUserId)
	if not Owner or not CanObserve(Player, Owner) then return end
	local PreviousOwner = ViewedOwnerByPlayer[Player]
	if PreviousOwner == Owner then return end
	if PreviousOwner and PreviousOwner ~= Player then RemoveSubscriber(Player, PreviousOwner) end
	ViewedOwnerByPlayer[Player] = if Owner ~= Player then Owner else nil
	if Owner ~= Player then AddSubscriber(Player, Owner) end
end

function VisitorController.Init()
	for _, ItemInfo in ItemsInfo do ItemsById[ItemInfo.Id] = ItemInfo end
	local Assets = ReplicatedStorage.Assets.Models.NPCS
	for _, Child in Assets.Shirts:GetChildren() do if Child:IsA("Shirt") then table.insert(ShirtChoices, Child) end end
	for _, Child in Assets.Pants:GetChildren() do if Child:IsA("Pants") then table.insert(PantsChoices, Child) end end
	for _, Child in Assets.Hair:GetChildren() do if Child:IsA("Accessory") then table.insert(HairChoices, Child) end end
	Network = Networker.server.new("MuseumVisitorController", VisitorController, {
		VisitorController.Ready,
		VisitorController.SetViewedMuseum,
	})
end

function VisitorController.OnPlayerAdded(player: Player)
	local token = {}
	visitTokens[player] = token
	activeVisitors[player] = {}
	DisplayReservations[player] = {}
	ActiveCounts[player] = {}
	LevelRuntime[player] = {}
	SubscribersByOwner[player] = {}
	VisitorsPerDisplay[player] = UpgradeLogic.GetVisitorsPerDisplay(dataService:get(player, "Upgrades"))
	UpgradeConnections[player] = dataService:getChangedSignal(player, "Upgrades"):Connect(function()
		VisitorsPerDisplay[player] = UpgradeLogic.GetVisitorsPerDisplay(dataService:get(player, "Upgrades"))
	end)
	if ReadyPlayers[player] then AddSubscriber(player, player) end
	task.spawn(function()
		task.wait(CONFIG.InitialSpawnDelay)
		while player.Parent == Players and visitTokens[player] == token do
			for LevelNumber = 1, #MuseumConfig.Levels do
				local ActiveCount = ActiveCounts[player] and (ActiveCounts[player][LevelNumber] or 0) or 0
				if ActiveCount < GetActiveVisitorLimit(player, LevelNumber) then
					task.spawn(runVisit, player, token, LevelNumber)
				end
			end
			task.wait(CONFIG.VisitorSpawnInterval)
		end
	end)
end

function VisitorController.OnPlayerRemoving(player: Player)
	visitTokens[player] = nil
	local Visitors = activeVisitors[player]
	activeVisitors[player] = nil
	DisplayReservations[player] = nil
	ActiveCounts[player] = nil
	VisitorsPerDisplay[player] = nil
	LevelRuntime[player] = nil
	ReadyPlayers[player] = nil
	LastViewRequestAt[player] = nil
	local UpgradeConnection = UpgradeConnections[player]
	if UpgradeConnection then UpgradeConnection:Disconnect(); UpgradeConnections[player] = nil end
	local ViewedOwner = ViewedOwnerByPlayer[player]
	if ViewedOwner then RemoveSubscriber(player, ViewedOwner) end
	ViewedOwnerByPlayer[player] = nil
	for Owner, Subscribers in SubscribersByOwner do Subscribers[player] = nil end
	if Visitors then
		for Visitor in Visitors do
			Visitor:Destroy()
		end
	end
	local Subscribers = SubscribersByOwner[player]
	if Subscribers and Network then
		for Subscriber in Subscribers do
			if Subscriber ~= player and Subscriber.Parent == Players then Network:fire(Subscriber, "ClearOwner", player.UserId) end
		end
	end
	SubscribersByOwner[player] = nil
end

return VisitorController
