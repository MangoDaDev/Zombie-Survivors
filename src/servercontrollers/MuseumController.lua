local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local museumAssets = ReplicatedStorage.Assets.Models.Museum
local museumTemplate = museumAssets.Museum
local museumCFrames = museumAssets.MuseumCFrames
local displayTemplate = museumAssets.Display
local SFX_MAX_DISTANCE = 80

type DisplayState = {
	index: number,
	model: Model,
	itemCFrame: BasePart,
	viewPart: BasePart,
	prompt: ProximityPrompt,
	takePrompt: ProximityPrompt,
	sellPrompt: ProximityPrompt,
	Unlocked: boolean,
	itemId: number?,
	itemModel: Model?,
	Connections: { RBXScriptConnection },
}

type MuseumAssignment = {
	museum: Model,
	position: BasePart,
	displays: { DisplayState },
	UpgradeConnection: RBXScriptConnection?,
}

local MuseumController = {}

local assignments: { [Player]: MuseumAssignment } = {}
local occupiedPositions: { [BasePart]: Player } = {}
local positions: { BasePart } = {}
local playerMuseums: Folder
local dataService
local inventoryRefreshHandler
local copyDisplays

local function getItemInfo(itemId: number)
	for _, itemInfo in ItemsInfo do
		if itemInfo.Id == itemId then
			return itemInfo
		end
	end
	return nil
end

local function getAvailablePosition(): BasePart?
	for _, position in positions do
		if occupiedPositions[position] == nil then
			return position
		end
	end
	return nil
end

local function moveModelToCFrame(model: Model, cFrame: CFrame)
	local cFramePart = model:FindFirstChild("CFramePart")
	assert(cFramePart and cFramePart:IsA("BasePart"), `{model.Name} has no CFramePart`)
	local pivotOffset = cFramePart.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(cFrame * pivotOffset)
end

local function teleportCharacterToMuseum(player: Player, character: Model)
	local assignment = assignments[player]
	if assignment == nil then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if rootPart == nil or assignments[player] ~= assignment or player.Parent ~= Players then
		return
	end

	local spawnCFrame = assignment.museum:FindFirstChild("SpawnCFrame") :: BasePart
	TeleportPlayer(character, spawnCFrame)
end

local function createDisplayedItem(player: Player, displayState: DisplayState, itemId: number): Model?
	local itemInfo = getItemInfo(itemId)
	local template = itemInfo and ReplicatedStorage.Assets.Models.Items:FindFirstChild(itemInfo.AssetName)
	if template == nil or not template:IsA("Model") then
		return nil
	end

	local itemModel = template:Clone()
	local boundingBox = itemModel:FindFirstChild("BoundingBox")
	if boundingBox == nil or not boundingBox:IsA("BasePart") then
		itemModel:Destroy()
		return nil
	end

	itemModel.Name = `Displayed_{itemInfo.Name}`
	itemModel.PrimaryPart = boundingBox
	for _, descendant in itemModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	itemModel:SetAttribute("OwnerUserId", player.UserId)
	itemModel:SetAttribute("ItemId", itemId)
	itemModel:SetAttribute("DisplayIndex", displayState.index)
	itemModel:PivotTo(displayState.itemCFrame.CFrame * CFrame.new(0, boundingBox.Size.Y / 2, 0))
	itemModel.Parent = displayState.model
	ItemInfoBillboard(itemInfo, boundingBox)
	return itemModel
end

local function UpdateDisplayPrompts(DisplayState: DisplayState)
	DisplayState.model:SetAttribute("Unlocked", true)
	DisplayState.prompt.ActionText = if DisplayState.itemId == nil then "Place Item" else "Occupied"
	DisplayState.prompt.ObjectText = "Display"
	DisplayState.prompt.Enabled = DisplayState.itemId == nil
	DisplayState.takePrompt.Enabled = DisplayState.itemId ~= nil
	DisplayState.sellPrompt.Enabled = DisplayState.itemId ~= nil
end

local function setDisplayItem(player: Player, displayState: DisplayState, itemId: number): boolean
	if not displayState.Unlocked or displayState.itemId ~= nil or getItemInfo(itemId) == nil then
		return false
	end

	local itemModel = createDisplayedItem(player, displayState, itemId)
	if itemModel == nil then
		return false
	end

	displayState.itemId = itemId
	displayState.itemModel = itemModel
	displayState.model:SetAttribute("ItemId", itemId)
	UpdateDisplayPrompts(displayState)
	return true
end

local function clearDisplay(player: Player, displayState: DisplayState): number?
	local itemId = displayState.itemId
	if itemId == nil then return nil end
	displayState.itemId = nil
	if displayState.itemModel then displayState.itemModel:Destroy(); displayState.itemModel = nil end
	displayState.model:SetAttribute("ItemId", nil)
	UpdateDisplayPrompts(displayState)
	local displays = copyDisplays(dataService:get(player, "Displays"))
	displays[tostring(displayState.index)] = nil
	dataService:set(player, "Displays", displays)
	return itemId
end

local function takeDisplayedItem(player: Player, displayState: DisplayState)
	local itemId = clearDisplay(player, displayState)
	if itemId == nil then return end
	dataService:arrayInsert(player, "Inventory", itemId)
	if inventoryRefreshHandler then inventoryRefreshHandler(player) end
end

local function sellDisplayedItem(player: Player, displayState: DisplayState)
	local itemId = displayState.itemId
	local itemInfo = itemId and getItemInfo(itemId)
	if not itemInfo or clearDisplay(player, displayState) == nil then return end
	dataService:update(player, "Cash", function(cash) return (if type(cash) == "number" then cash else 0) + itemInfo.Price end)
	Sounds.Play("Kaching", displayState.itemCFrame, SFX_MAX_DISTANCE)
end

copyDisplays = function(displays): { [string]: number }
	local result = {}
	if type(displays) == "table" then
		for key, itemId in displays do
			if type(key) == "string" and type(itemId) == "number" then
				result[key] = itemId
			end
		end
	end
	return result
end

local function placeEquippedItem(player: Player, assignment: MuseumAssignment, displayState: DisplayState)
	if assignments[player] ~= assignment or not displayState.Unlocked or displayState.itemId ~= nil then
		return
	end

	local Character = player.Character
	local Tool
	local ItemId
	local CharacterChildren = if Character then Character:GetChildren() else {}
	for _, Child in CharacterChildren do
		local ChildItemId = Child:GetAttribute("ItemId")
		if Child:IsA("Tool") and type(ChildItemId) == "number" and Child:HasTag("satchelSlot") then
			Tool = Child
			ItemId = ChildItemId
			break
		end
	end
	if Tool == nil or type(ItemId) ~= "number" or getItemInfo(ItemId) == nil then
		return
	end

	local inventory = dataService:get(player, "Inventory")
	if type(inventory) ~= "table" then
		return
	end
	local inventoryPosition = table.find(inventory, ItemId)
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingState = fixing[tostring(ItemId)]
	if fixingState == nil or fixingState.Completed ~= true then
		return
	end
	if inventoryPosition == nil or not setDisplayItem(player, displayState, ItemId) then
		return
	end

	local displays = copyDisplays(dataService:get(player, "Displays"))
	displays[tostring(displayState.index)] = ItemId
	dataService:set(player, "Displays", displays)
	dataService:arrayRemove(player, "Inventory", inventoryPosition)
	Tool:Destroy()

	Sounds.Play("Equip", displayState.itemCFrame, SFX_MAX_DISTANCE)
end

local function getDisplayMarkers(museum: Model): { BasePart }
	local markerFolder = museum:FindFirstChild("DisplayCFrames")
	local markers = {}
	if markerFolder then
		for _, child in markerFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(markers, child)
			end
		end
	end

	local museumOrigin = museum:GetPivot()
	table.sort(markers, function(a, b)
		local aPosition = museumOrigin:PointToObjectSpace(a.Position)
		local bPosition = museumOrigin:PointToObjectSpace(b.Position)
		if math.abs(aPosition.Z - bPosition.Z) > 0.01 then
			return aPosition.Z < bPosition.Z
		end
		return aPosition.X < bPosition.X
	end)
	return markers
end

local function CreateDisplays(player: Player, assignment: MuseumAssignment)
	local savedDisplays = copyDisplays(dataService:get(player, "Displays"))
	local DisplayLimit = UpgradeLogic.GetDisplayLimit(dataService:get(player, "Upgrades"))
	local DisplaysChanged = false
	for index, marker in getDisplayMarkers(assignment.museum) do
		if index > DisplayLimit then break end
		if assignment.displays[index] then continue end
		local display = displayTemplate:Clone()
		display.Name = `Display_{index}`
		moveModelToCFrame(display, marker.CFrame)
		display:SetAttribute("OwnerUserId", player.UserId)
		display:SetAttribute("DisplayIndex", index)
		display.Parent = assignment.museum

		local itemCFrame = display:FindFirstChild("ItemCFrame")
		local viewPart = display:FindFirstChild("ViewPart")
		local base = display:FindFirstChild("Base")
		assert(itemCFrame and itemCFrame:IsA("BasePart"), "Display has no ItemCFrame")
		assert(viewPart and viewPart:IsA("BasePart"), "Display has no ViewPart")
		assert(base and base:IsA("BasePart"), "Display has no Base")

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PlaceItemPrompt"
		prompt.ActionText = "Place Item"
		prompt.ObjectText = "Display"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		prompt.UIOffset = Vector2.new(0, 55)
		prompt.Parent = base

		local takePrompt = Instance.new("ProximityPrompt")
		takePrompt.Name = "TakeItemPrompt"
		takePrompt.ActionText = "Take Off Sale"
		takePrompt.ObjectText = "Display"
		takePrompt.HoldDuration = 0
		takePrompt.KeyboardKeyCode = Enum.KeyCode.E
		takePrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		takePrompt.MaxActivationDistance = 10
		takePrompt.RequiresLineOfSight = false
		takePrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		takePrompt.UIOffset = Vector2.new(-85, -45)
		takePrompt.Enabled = false
		takePrompt.Parent = base

		local sellPrompt = Instance.new("ProximityPrompt")
		sellPrompt.Name = "SellItemPrompt"
		sellPrompt.ActionText = "Sell Item"
		sellPrompt.ObjectText = "Display"
		sellPrompt.HoldDuration = 0
		sellPrompt.KeyboardKeyCode = Enum.KeyCode.F
		sellPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		sellPrompt.MaxActivationDistance = 10
		sellPrompt.RequiresLineOfSight = false
		sellPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		sellPrompt.UIOffset = Vector2.new(85, -45)
		sellPrompt.Enabled = false
		sellPrompt.Parent = base

		local displayState: DisplayState = {
			index = index,
			model = display,
			itemCFrame = itemCFrame,
			viewPart = viewPart,
			prompt = prompt,
			takePrompt = takePrompt,
			sellPrompt = sellPrompt,
			Unlocked = true,
			itemId = nil,
			itemModel = nil,
			Connections = {},
		}
		table.insert(assignment.displays, displayState)
		UpdateDisplayPrompts(displayState)
		table.insert(displayState.Connections, prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then
				placeEquippedItem(player, assignment, displayState)
			end
		end))
		table.insert(displayState.Connections, takePrompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then takeDisplayedItem(player, displayState) end
		end))
		table.insert(displayState.Connections, sellPrompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then sellDisplayedItem(player, displayState) end
		end))

		local savedItemId = savedDisplays[tostring(index)]
		if type(savedItemId) == "number" then
			setDisplayItem(player, displayState, savedItemId)
		end
	end
	for DisplayKey, SavedItemId in savedDisplays do
		local DisplayIndex = tonumber(DisplayKey)
		if type(SavedItemId) == "number" and DisplayIndex and DisplayIndex > DisplayLimit then
			dataService:arrayInsert(player, "Inventory", SavedItemId)
			savedDisplays[DisplayKey] = nil
			DisplaysChanged = true
		end
	end
	if DisplaysChanged then
		dataService:set(player, "Displays", savedDisplays)
		if inventoryRefreshHandler then inventoryRefreshHandler(player) end
	end
end

local function RefreshDisplays(Player: Player)
	local Assignment = assignments[Player]
	if not Assignment then return end
	CreateDisplays(Player, Assignment)
end

function MuseumController.SetDataService(service)
	dataService = service
end

function MuseumController.SetInventoryRefreshHandler(handler)
	inventoryRefreshHandler = handler
end

function MuseumController.GetMuseum(player: Player): Model?
	local assignment = assignments[player]
	return if assignment then assignment.museum else nil
end

function MuseumController.TeleportPlayerToMuseum(Player: Player): boolean
	local Assignment = assignments[Player]
	local Character = Player.Character
	if not Assignment or not Character then return false end
	local SpawnCFrame = Assignment.museum:FindFirstChild("SpawnCFrame")
	if not SpawnCFrame or not SpawnCFrame:IsA("BasePart") then return false end
	return TeleportPlayer(Character, SpawnCFrame)
end

function MuseumController.GetOccupiedDisplays(player: Player): { DisplayState }
	local assignment = assignments[player]
	local occupiedDisplays = {}
	if assignment then
		for _, displayState in assignment.displays do
			if displayState.Unlocked and displayState.itemId ~= nil and displayState.itemModel ~= nil then
				table.insert(occupiedDisplays, displayState)
			end
		end
	end
	return occupiedDisplays
end

function MuseumController:Init()
	playerMuseums = Instance.new("Folder")
	playerMuseums.Name = "PlayerMuseums"
	playerMuseums.Parent = Workspace

	for _, position in museumCFrames:GetChildren() do
		if position:IsA("BasePart") then
			table.insert(positions, position)
		end
	end

	table.sort(positions, function(a, b)
		return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
	end)
end

function MuseumController.OnPlayerAdded(player: Player)
	if assignments[player] then
		return
	end

	local position = getAvailablePosition()
	if position == nil then
		warn(`MuseumController could not assign a museum to {player.Name}: no positions are available`)
		return
	end

	local museum = museumTemplate:Clone()
	museum.Name = `Museum_{player.UserId}`
	moveModelToCFrame(museum, position.CFrame)
	museum:SetAttribute("OwnerUserId", player.UserId)
	museum.Parent = playerMuseums

	local assignment: MuseumAssignment = {
		museum = museum,
		position = position,
		displays = {},
		UpgradeConnection = nil,
	}
	occupiedPositions[position] = player
	assignments[player] = assignment
	CreateDisplays(player, assignment)
	assignment.UpgradeConnection = dataService:getChangedSignal(player, "Upgrades"):Connect(function()
		RefreshDisplays(player)
	end)
end

function MuseumController.OnCharacterAdded(player: Player, character: Model)
	task.spawn(teleportCharacterToMuseum, player, character)
end

function MuseumController.OnPlayerRemoving(player: Player)
	local assignment = assignments[player]
	if assignment == nil then
		return
	end

	assignments[player] = nil
	occupiedPositions[assignment.position] = nil
	if assignment.UpgradeConnection then assignment.UpgradeConnection:Disconnect() end
	for _, displayState in assignment.displays do
		for _, Connection in displayState.Connections do Connection:Disconnect() end
	end
	assignment.museum:Destroy()
end

return MuseumController
