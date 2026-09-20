local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local MuseumConfig = require(ReplicatedStorage.Modules.Game.MuseumConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local Networker = require(ReplicatedStorage.Packages.networker)

local MuseumAssets = ReplicatedStorage.Assets.Models.Museum
local BaseTemplate = MuseumAssets.Building.Base
local LevelTemplate = MuseumAssets.Building.Level
local RoofTemplate = MuseumAssets.Building.Roof
local TableTemplate = MuseumAssets.Table
local MuseumCFrames = MuseumAssets.MuseumCFrames
local DisplayTemplate = MuseumAssets.Display
local SFX_MAX_DISTANCE = 80
local SALE_CONFIRMATION_LIFETIME = 15

type DisplayState = {
	index: number, model: Model, itemCFrame: BasePart, viewPart: BasePart,
	prompt: ProximityPrompt, takePrompt: ProximityPrompt, sellPrompt: ProximityPrompt,
	levelNumber: number, Unlocked: boolean, itemId: number?, itemModel: Model?, Connections: { RBXScriptConnection },
}

type MuseumAssignment = {
	museum: Model, position: BasePart, levels: { [number]: Model },
	displays: { [number]: DisplayState }, occupiedDisplays: { DisplayState },
	occupiedDisplaysByLevel: { [number]: { DisplayState } }, museumAreas: { BasePart },
	base: Model?, roof: Model?, UpgradeConnection: RBXScriptConnection?,
}

local MuseumController = {}
local Assignments: { [Player]: MuseumAssignment } = {}
local OccupiedPositions: { [BasePart]: Player } = {}
local Positions: { BasePart } = {}
local PlayerMuseums: Folder
local DataService
local InventoryRefreshHandler
local CopyDisplays
local Network
local PendingSales: { [Player]: { SlotId: number, ItemId: number, ExpiresAt: number } } = {}

local function GetItemInfo(ItemId: number)
	for _, ItemInfo in ItemsInfo do if ItemInfo.Id == ItemId then return ItemInfo end end
	return nil
end

local function GetAvailablePosition(): BasePart?
	for _, Position in Positions do if OccupiedPositions[Position] == nil then return Position end end
	return nil
end

local function MoveModelToMarker(Model: Model, MarkerName: string, TargetCFrame: CFrame)
	local Marker = Model:FindFirstChild(MarkerName, true)
	assert(Marker and Marker:IsA("BasePart"), `{Model.Name} has no {MarkerName}`)
	Model:PivotTo(TargetCFrame * Marker.CFrame:ToObjectSpace(Model:GetPivot()))
end

local function TeleportCharacterToMuseum(Player: Player, Character: Model)
	local Assignment = Assignments[Player]
	if not Assignment then return end
	local RootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 5)
	if not RootPart or Assignments[Player] ~= Assignment or Player.Parent ~= Players then return end
	local Level = Assignment.levels[1]
	local SpawnCFrame = Level and Level:FindFirstChild("SpawnCFrame")
	if SpawnCFrame and SpawnCFrame:IsA("BasePart") then TeleportPlayer(Character, SpawnCFrame) end
end

local function CreateDisplayedItem(Player: Player, DisplayState: DisplayState, ItemId: number): Model?
	local ItemInfo = GetItemInfo(ItemId)
	local Template = ItemInfo and ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return nil end
	local ItemModel = Template:Clone()
	local BoundingBox = ItemModel:FindFirstChild("BoundingBox")
	if not BoundingBox or not BoundingBox:IsA("BasePart") then ItemModel:Destroy(); return nil end
	ItemModel.Name = `Displayed_{ItemInfo.Name}`
	ItemModel.PrimaryPart = BoundingBox
	for _, Descendant in ItemModel:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true; Descendant.CanCollide = false; Descendant.CanQuery = false; Descendant.CanTouch = false
		end
	end
	ItemModel:PivotTo(DisplayState.itemCFrame.CFrame * CFrame.new(0, BoundingBox.Size.Y / 2, 0))
	ItemModel.Parent = DisplayState.model
	local Fixing = DataService:get(Player, "Fixing") or {}
	ItemInfoBillboard(ItemInfo, BoundingBox, Fixing[tostring(ItemId)])
	return ItemModel
end

local function UpdateDisplayPrompts(DisplayState: DisplayState)
	DisplayState.prompt.ActionText = if DisplayState.itemId == nil then "Place Item" else "Occupied"
	DisplayState.prompt.ObjectText = "Display"
	DisplayState.prompt.Enabled = DisplayState.itemId == nil
	DisplayState.takePrompt.Enabled = DisplayState.itemId ~= nil
	DisplayState.sellPrompt.Enabled = DisplayState.itemId ~= nil
end

local function SetDisplayItem(Player: Player, DisplayState: DisplayState, ItemId: number): boolean
	if not DisplayState.Unlocked or DisplayState.itemId ~= nil or not GetItemInfo(ItemId) then return false end
	local ItemModel = CreateDisplayedItem(Player, DisplayState, ItemId)
	if not ItemModel then return false end
	DisplayState.itemId = ItemId; DisplayState.itemModel = ItemModel; UpdateDisplayPrompts(DisplayState)
	local Assignment = Assignments[Player]
	if Assignment then
		table.insert(Assignment.occupiedDisplays, DisplayState)
		local LevelDisplays = Assignment.occupiedDisplaysByLevel[DisplayState.levelNumber]
		if not LevelDisplays then LevelDisplays = {}; Assignment.occupiedDisplaysByLevel[DisplayState.levelNumber] = LevelDisplays end
		table.insert(LevelDisplays, DisplayState)
	end
	return true
end

CopyDisplays = function(Displays): { [string]: number }
	local Result = {}
	if type(Displays) == "table" then
		for Key, ItemId in Displays do
			local SlotId = tonumber(Key)
			if SlotId and SlotId % 1 == 0 and type(ItemId) == "number" then Result[tostring(SlotId)] = ItemId end
		end
	end
	return Result
end

local function ClearDisplay(Player: Player, DisplayState: DisplayState): number?
	local ItemId = DisplayState.itemId
	if not ItemId then return nil end
	DisplayState.itemId = nil
	local Assignment = Assignments[Player]
	if Assignment then
		local OccupiedIndex = table.find(Assignment.occupiedDisplays, DisplayState)
		if OccupiedIndex then table.remove(Assignment.occupiedDisplays, OccupiedIndex) end
		local LevelDisplays = Assignment.occupiedDisplaysByLevel[DisplayState.levelNumber]
		local LevelIndex = LevelDisplays and table.find(LevelDisplays, DisplayState)
		if LevelDisplays and LevelIndex then table.remove(LevelDisplays, LevelIndex) end
	end
	if DisplayState.itemModel then DisplayState.itemModel:Destroy(); DisplayState.itemModel = nil end
	UpdateDisplayPrompts(DisplayState)
	local Displays = CopyDisplays(DataService:get(Player, "Displays"))
	Displays[tostring(DisplayState.index)] = nil
	DataService:set(Player, "Displays", Displays)
	return ItemId
end

local function TakeDisplayedItem(Player: Player, DisplayState: DisplayState)
	local ItemId = ClearDisplay(Player, DisplayState)
	if not ItemId then return end
	DataService:arrayInsert(Player, "Inventory", ItemId)
	if InventoryRefreshHandler then InventoryRefreshHandler(Player) end
end

local function SellDisplayedItem(Player: Player, DisplayState: DisplayState)
	local ItemId = DisplayState.itemId
	local ItemInfo = ItemId and GetItemInfo(ItemId)
	if not ItemInfo or not ClearDisplay(Player, DisplayState) then return end
	DataService:update(Player, "Cash", function(Cash) return (if type(Cash) == "number" then Cash else 0) + ItemInfo.SaleValue end)
	AnalyticsController.TrackItemSold(Player, ItemId, DisplayState.levelNumber, ItemInfo.SaleValue)
	GuidanceController.Advance(Player, "EarnMoney")
	Sounds.Play("Kaching", DisplayState.itemCFrame, SFX_MAX_DISTANCE)
end

local function RequestSaleConfirmation(Player: Player, Assignment: MuseumAssignment, DisplayState: DisplayState)
	if Assignments[Player] ~= Assignment then return end
	local ItemId = DisplayState.itemId
	local ItemInfo = ItemId and GetItemInfo(ItemId)
	if not ItemInfo then return end
	-- Display sales stay pending until the owner accepts the named-item confirmation.
	PendingSales[Player] = {
		SlotId = DisplayState.index,
		ItemId = ItemId,
		ExpiresAt = os.clock() + SALE_CONFIRMATION_LIFETIME,
	}
	Network:fire(Player, "ShowSaleConfirmation", ItemInfo.Name, DisplayState.index, ItemId)
end

local function PlaceEquippedItem(Player: Player, Assignment: MuseumAssignment, DisplayState: DisplayState)
	if Assignments[Player] ~= Assignment or not DisplayState.Unlocked or DisplayState.itemId ~= nil then return end
	local Character = Player.Character
	local Tool
	local ItemId
	for _, Child in if Character then Character:GetChildren() else {} do
		local ItemInfo = ToolResolver.GetItemInfo(Child)
		if ItemInfo and Child:HasTag("satchelSlot") then Tool = Child; ItemId = ItemInfo.Id; break end
	end
	if not Tool or type(ItemId) ~= "number" or not GetItemInfo(ItemId) then GuidanceController.Show(Player, "Equip Fixed Item"); return end
	local Inventory = DataService:get(Player, "Inventory")
	if type(Inventory) ~= "table" then return end
	local InventoryPosition = table.find(Inventory, ItemId)
	local Fixing = DataService:get(Player, "Fixing") or {}
	local FixingState = Fixing[tostring(ItemId)]
	if not FixingState or FixingState.Completed ~= true then
		GuidanceController.Show(Player, "Finish Cleaning", Assignment.museum:FindFirstChild("PromptPart", true)); return
	end
	if not InventoryPosition or not SetDisplayItem(Player, DisplayState, ItemId) then return end
	local Displays = CopyDisplays(DataService:get(Player, "Displays"))
	Displays[tostring(DisplayState.index)] = ItemId
	DataService:set(Player, "Displays", Displays)
	DataService:arrayRemove(Player, "Inventory", InventoryPosition)
	AnalyticsController.TrackItemDisplayed(Player, ItemId, DisplayState.index, DisplayState.levelNumber)
	Tool:Destroy(); GuidanceController.Advance(Player, "DisplayItem"); Sounds.Play("Equip", DisplayState.itemCFrame, SFX_MAX_DISTANCE)
end

local function GetDisplayMarkers(Level: Model): { BasePart }
	local MarkerFolder = Level:FindFirstChild("DisplayCFrames")
	local Markers = {}
	if MarkerFolder then for _, Child in MarkerFolder:GetChildren() do if Child:IsA("BasePart") then table.insert(Markers, Child) end end end
	local LevelOrigin = Level:GetPivot()
	table.sort(Markers, function(A, B)
		local APosition = LevelOrigin:PointToObjectSpace(A.Position)
		local BPosition = LevelOrigin:PointToObjectSpace(B.Position)
		if math.abs(APosition.Z - BPosition.Z) > 0.01 then return APosition.Z < BPosition.Z end
		return APosition.X < BPosition.X
	end)
	return Markers
end

local function CreateLevel(Assignment: MuseumAssignment, LevelNumber: number): Model
	if Assignment.levels[LevelNumber] then return Assignment.levels[LevelNumber] end
	local TargetCFrame = Assignment.position.CFrame
	if LevelNumber > 1 then
		local PreviousLevel = CreateLevel(Assignment, LevelNumber - 1)
		local NextLevelMount = PreviousLevel:FindFirstChild("NextLevelMount")
		assert(NextLevelMount and NextLevelMount:IsA("BasePart"), "Museum level has no NextLevelMount")
		TargetCFrame = NextLevelMount.CFrame
	end
	local Level = LevelTemplate:Clone()
	Level.Name = `Level_{LevelNumber}`
	MoveModelToMarker(Level, "CFramePart", TargetCFrame)
	Level.Parent = Assignment.museum
	Assignment.levels[LevelNumber] = Level
	for _, Descendant in Level:GetDescendants() do
		if Descendant.Name == "MuseumArea" and Descendant:IsA("BasePart") then table.insert(Assignment.museumAreas, Descendant) end
	end
	return Level
end

local function CreateBase(Assignment: MuseumAssignment)
	if Assignment.base then return end
	-- The museum base is shared by the whole building and must not be cloned with each level.
	local Base = BaseTemplate:Clone()
	Base.Name = "Base"
	MoveModelToMarker(Base, "CFramePart", Assignment.position.CFrame)
	Base.Parent = Assignment.museum
	Assignment.base = Base
end

local function PositionRoof(Assignment: MuseumAssignment, LevelCount: number)
	local Level = Assignment.levels[LevelCount]
	local RoofMount = Level and Level:FindFirstChild("RoofMount")
	if not RoofMount or not RoofMount:IsA("BasePart") then return end
	local Roof = Assignment.roof
	if not Roof then Roof = RoofTemplate:Clone(); Roof.Name = "Roof"; Roof.Parent = Assignment.museum; Assignment.roof = Roof end
	MoveModelToMarker(Roof, "RoofMount", RoofMount.CFrame)
end

local function CreateTable(Assignment: MuseumAssignment)
	if Assignment.museum:FindFirstChild("Table") then return end
	local Level = Assignment.levels[1]
	local TableCFrame = Level and Level:FindFirstChild("TableCFrame")
	if not TableCFrame or not TableCFrame:IsA("BasePart") then return end
	local TableModel = TableTemplate:Clone()
	TableModel.Name = "Table"
	MoveModelToMarker(TableModel, "TableCFrame", TableCFrame.CFrame)
	TableModel.Parent = Assignment.museum
end

local function CreatePrompt(Name: string, ActionText: string, KeyCode: Enum.KeyCode, GamepadKeyCode: Enum.KeyCode, Offset: Vector2, Base: BasePart): ProximityPrompt
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = Name; Prompt.ActionText = ActionText; Prompt.ObjectText = "Display"; Prompt.HoldDuration = 0
	Prompt.KeyboardKeyCode = KeyCode; Prompt.GamepadKeyCode = GamepadKeyCode; Prompt.MaxActivationDistance = 10
	-- Keep the nearest display's actions available without exposing matching prompts from adjacent displays.
	Prompt.RequiresLineOfSight = false; Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton; Prompt.UIOffset = Offset; Prompt.Parent = Base
	return Prompt
end

local function CreateDisplay(Player: Player, Assignment: MuseumAssignment, SlotId: number, LevelNumber: number, Level: Model, Marker: BasePart, SavedDisplays)
	if Assignment.displays[SlotId] then return end
	local Display = DisplayTemplate:Clone()
	Display.Name = `Display_{SlotId}`
	MoveModelToMarker(Display, "CFramePart", Marker.CFrame)
	Display.Parent = Level
	local ItemCFrame = Display:FindFirstChild("ItemCFrame")
	local ViewPart = Display:FindFirstChild("ViewPart")
	local Base = Display:FindFirstChild("Base")
	assert(ItemCFrame and ItemCFrame:IsA("BasePart"), "Display has no ItemCFrame")
	assert(ViewPart and ViewPart:IsA("BasePart"), "Display has no ViewPart")
	assert(Base and Base:IsA("BasePart"), "Display has no Base")
	local Prompt = CreatePrompt("PlaceItemPrompt", "Place Item", Enum.KeyCode.E, Enum.KeyCode.ButtonX, Vector2.new(0, 55), Base)
	local TakePrompt = CreatePrompt("TakeItemPrompt", "Take Off Sale", Enum.KeyCode.E, Enum.KeyCode.ButtonX, Vector2.new(-85, -45), Base)
	local SellPrompt = CreatePrompt("SellItemPrompt", "Sell Item", Enum.KeyCode.F, Enum.KeyCode.ButtonY, Vector2.new(85, -45), Base)
	TakePrompt.Enabled = false; SellPrompt.Enabled = false
	local DisplayState: DisplayState = { index = SlotId, model = Display, itemCFrame = ItemCFrame, viewPart = ViewPart, prompt = Prompt,
		takePrompt = TakePrompt, sellPrompt = SellPrompt, levelNumber = LevelNumber, Unlocked = true, itemId = nil, itemModel = nil, Connections = {} }
	Assignment.displays[SlotId] = DisplayState
	UpdateDisplayPrompts(DisplayState)
	table.insert(DisplayState.Connections, Prompt.Triggered:Connect(function(TriggeringPlayer) if TriggeringPlayer == Player then PlaceEquippedItem(Player, Assignment, DisplayState) end end))
	table.insert(DisplayState.Connections, TakePrompt.Triggered:Connect(function(TriggeringPlayer) if TriggeringPlayer == Player then TakeDisplayedItem(Player, DisplayState) end end))
	table.insert(DisplayState.Connections, SellPrompt.Triggered:Connect(function(TriggeringPlayer) if TriggeringPlayer == Player then RequestSaleConfirmation(Player, Assignment, DisplayState) end end))
	local SavedItemId = SavedDisplays[tostring(SlotId)]
	if type(SavedItemId) == "number" then SetDisplayItem(Player, DisplayState, SavedItemId) end
end

local function RefreshMuseum(Player: Player)
	local Assignment = Assignments[Player]
	if not Assignment then return end
	local DisplayLimit = math.min(UpgradeLogic.GetDisplayLimit(DataService:get(Player, "Upgrades")), MuseumConfig.GetMaximumDisplayCount())
	local LevelCount = MuseumConfig.GetLevelCount(DisplayLimit)
	local SavedDisplays = CopyDisplays(DataService:get(Player, "Displays"))
	CreateBase(Assignment)
	for LevelNumber = 1, LevelCount do
		local Level = CreateLevel(Assignment, LevelNumber)
		local Markers = GetDisplayMarkers(Level)
		local LevelInfo = MuseumConfig.Levels[LevelNumber]
		for LocalIndex = 1, MuseumConfig.GetDisplayCount(LevelNumber, DisplayLimit) do
			local Marker = Markers[LocalIndex]
			if not Marker then warn(`Museum level {LevelNumber} is missing display marker {LocalIndex}`); break end
			CreateDisplay(Player, Assignment, LevelInfo.StartSlot + LocalIndex - 1, LevelNumber, Level, Marker, SavedDisplays)
		end
	end
	CreateTable(Assignment)
	PositionRoof(Assignment, LevelCount)
end

function MuseumController.SetDataService(Service) DataService = Service end
function MuseumController.SetInventoryRefreshHandler(Handler) InventoryRefreshHandler = Handler end
function MuseumController.GetMuseum(Player: Player): Model? local Assignment = Assignments[Player]; return if Assignment then Assignment.museum else nil end
function MuseumController.GetLevel(Player: Player, LevelNumber: number): Model?
	local Assignment = Assignments[Player]
	return if Assignment then Assignment.levels[LevelNumber] else nil
end
function MuseumController.GetMuseumArea(Player: Player): BasePart?
	local Assignment = Assignments[Player]
	return Assignment and Assignment.museumAreas[1] or nil
end
function MuseumController.GetMuseumAreas(Player: Player): { BasePart }
	local Assignment = Assignments[Player]
	return if Assignment then Assignment.museumAreas else {}
end
function MuseumController.TeleportPlayerToMuseum(Player: Player): boolean
	local Assignment = Assignments[Player]
	local Character = Player.Character
	local SpawnCFrame = Assignment and Assignment.levels[1] and Assignment.levels[1]:FindFirstChild("SpawnCFrame")
	if not Character or not SpawnCFrame or not SpawnCFrame:IsA("BasePart") then return false end
	return TeleportPlayer(Character, SpawnCFrame)
end
function MuseumController.GetOccupiedDisplays(Player: Player, LevelNumber: number?): { DisplayState }
	local Assignment = Assignments[Player]
	if not Assignment then return {} end
	return if LevelNumber == nil then Assignment.occupiedDisplays else Assignment.occupiedDisplaysByLevel[LevelNumber] or {}
end
function MuseumController.ConfirmSale(_, Player: Player, SlotId, ItemId)
	if type(SlotId) ~= "number" or SlotId % 1 ~= 0 or type(ItemId) ~= "number" or ItemId % 1 ~= 0 then return end
	local PendingSale = PendingSales[Player]
	PendingSales[Player] = nil
	if not PendingSale or PendingSale.ExpiresAt < os.clock() or PendingSale.SlotId ~= SlotId or PendingSale.ItemId ~= ItemId then return end
	local Assignment = Assignments[Player]
	local DisplayState = Assignment and Assignment.displays[SlotId]
	if not DisplayState or DisplayState.itemId ~= ItemId or not DisplayState.sellPrompt.Enabled then return end
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local PromptPart = DisplayState.sellPrompt.Parent
	if not RootPart or not RootPart:IsA("BasePart") or not PromptPart or not PromptPart:IsA("BasePart") then return end
	if (RootPart.Position - PromptPart.Position).Magnitude > DisplayState.sellPrompt.MaxActivationDistance + 3 then return end
	SellDisplayedItem(Player, DisplayState)
end
function MuseumController.Init()
	Network = Networker.server.new("MuseumController", MuseumController, { MuseumController.ConfirmSale })
	PlayerMuseums = Instance.new("Folder"); PlayerMuseums.Name = "PlayerMuseums"; PlayerMuseums.Parent = Workspace
	for _, Position in MuseumCFrames:GetChildren() do if Position:IsA("BasePart") then table.insert(Positions, Position) end end
	table.sort(Positions, function(A, B) return (tonumber(A.Name) or math.huge) < (tonumber(B.Name) or math.huge) end)
end
function MuseumController.OnPlayerAdded(Player: Player)
	if Assignments[Player] then return end
	local Position = GetAvailablePosition()
	if not Position then warn(`MuseumController could not assign a museum to {Player.Name}: no positions are available`); return end
	local Museum = Instance.new("Model"); Museum.Name = `Museum_{Player.UserId}`; Museum.Parent = PlayerMuseums
	local Assignment: MuseumAssignment = {
		museum = Museum, position = Position, levels = {}, displays = {}, occupiedDisplays = {},
		occupiedDisplaysByLevel = {}, museumAreas = {}, base = nil, roof = nil, UpgradeConnection = nil,
	}
	OccupiedPositions[Position] = Player; Assignments[Player] = Assignment
	RefreshMuseum(Player)
	Assignment.UpgradeConnection = DataService:getChangedSignal(Player, "Upgrades"):Connect(function() RefreshMuseum(Player) end)
end
function MuseumController.OnCharacterAdded(Player: Player, Character: Model) task.spawn(TeleportCharacterToMuseum, Player, Character) end
function MuseumController.OnPlayerRemoving(Player: Player)
	PendingSales[Player] = nil
	local Assignment = Assignments[Player]
	if not Assignment then return end
	Assignments[Player] = nil; OccupiedPositions[Assignment.position] = nil
	if Assignment.UpgradeConnection then Assignment.UpgradeConnection:Disconnect() end
	for _, DisplayState in Assignment.displays do for _, Connection in DisplayState.Connections do Connection:Disconnect() end end
	Assignment.museum:Destroy()
end

return MuseumController
