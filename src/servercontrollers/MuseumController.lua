local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local PlayVFX = require(ReplicatedStorage.Modules.UI.PlayVFX)
local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)

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
	itemId: number?,
	itemModel: Model?,
	connection: RBXScriptConnection?,
}

type MuseumAssignment = {
	museum: Model,
	position: BasePart,
	displays: { DisplayState },
}

local MuseumController = {}

local assignments: { [Player]: MuseumAssignment } = {}
local occupiedPositions: { [BasePart]: Player } = {}
local positions: { BasePart } = {}
local playerMuseums: Folder
local dataService

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

local function setDisplayItem(player: Player, displayState: DisplayState, itemId: number): boolean
	if displayState.itemId ~= nil or getItemInfo(itemId) == nil then
		return false
	end

	local itemModel = createDisplayedItem(player, displayState, itemId)
	if itemModel == nil then
		return false
	end

	displayState.itemId = itemId
	displayState.itemModel = itemModel
	displayState.prompt.ActionText = "Occupied"
	displayState.prompt.Enabled = false
	displayState.model:SetAttribute("ItemId", itemId)
	return true
end

local function copyDisplays(displays): { [string]: number }
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
	if assignments[player] ~= assignment or displayState.itemId ~= nil then
		return
	end

	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local itemId = tool and tool:GetAttribute("ItemId")
	if tool == nil or type(itemId) ~= "number" or not tool:HasTag("satchelSlot") or getItemInfo(itemId) == nil then
		return
	end

	local inventory = dataService:get(player, "Inventory")
	if type(inventory) ~= "table" then
		return
	end
	local inventoryPosition = table.find(inventory, itemId)
	if inventoryPosition == nil or not setDisplayItem(player, displayState, itemId) then
		return
	end

	local displays = copyDisplays(dataService:get(player, "Displays"))
	displays[tostring(displayState.index)] = itemId
	dataService:set(player, "Displays", displays)
	dataService:arrayRemove(player, "Inventory", inventoryPosition)
	tool:Destroy()

	local equipSound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Equip")
	if equipSound and equipSound:IsA("Sound") then
		local sounds = PlayVFX(equipSound, displayState.itemCFrame)
		local sound = sounds[1]
		if sound and sound:IsA("Sound") then
			sound.RollOffMaxDistance = SFX_MAX_DISTANCE
		end
	end
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

local function createDisplays(player: Player, assignment: MuseumAssignment)
	local savedDisplays = copyDisplays(dataService:get(player, "Displays"))
	for index, marker in getDisplayMarkers(assignment.museum) do
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
		prompt.Parent = base

		local displayState: DisplayState = {
			index = index,
			model = display,
			itemCFrame = itemCFrame,
			viewPart = viewPart,
			prompt = prompt,
			itemId = nil,
			itemModel = nil,
			connection = nil,
		}
		table.insert(assignment.displays, displayState)
		displayState.connection = prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then
				placeEquippedItem(player, assignment, displayState)
			end
		end)

		local savedItemId = savedDisplays[tostring(index)]
		if type(savedItemId) == "number" then
			setDisplayItem(player, displayState, savedItemId)
		end
	end
end

function MuseumController.SetDataService(service)
	dataService = service
end

function MuseumController.GetMuseum(player: Player): Model?
	local assignment = assignments[player]
	return if assignment then assignment.museum else nil
end

function MuseumController.GetOccupiedDisplays(player: Player): { DisplayState }
	local assignment = assignments[player]
	local occupiedDisplays = {}
	if assignment then
		for _, displayState in assignment.displays do
			if displayState.itemId ~= nil and displayState.itemModel ~= nil then
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
	}
	occupiedPositions[position] = player
	assignments[player] = assignment
	createDisplays(player, assignment)
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
	for _, displayState in assignment.displays do
		if displayState.connection then
			displayState.connection:Disconnect()
		end
	end
	assignment.museum:Destroy()
end

return MuseumController
