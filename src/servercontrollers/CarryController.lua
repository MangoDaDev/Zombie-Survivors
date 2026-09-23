local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local InventoryItemKey = require(ReplicatedStorage.Modules.Game.InventoryItemKey)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)

local DEFAULT_CARRY_OFFSET = CFrame.new(0, 0, -3) * CFrame.Angles(0, math.rad(90), 0)
local SFX_MAX_DISTANCE = 80
local MapAssets = ReplicatedStorage.Assets.Models.Map

export type OwnershipState = {
	BasePrice: number,
	CurrentPrice: number,
	OwnerUserId: number,
	OwnershipId: string,
	TransferCount: number,
}

type CarryState = {
	DeathConnection: RBXScriptConnection?,
	DirtCount: number,
	Ownership: OwnershipState,
	RestorationSteps: { string }?,
	ItemKey: string,
	itemId: number,
	model: Model?,
	ModelConnection: RBXScriptConnection?,
}

type MovementState = {
	AppliedWalkSpeed: number,
	BaseWalkSpeed: number,
	Connection: RBXScriptConnection,
	Humanoid: Humanoid,
	Updating: boolean,
}

local CarryController = {}

local carryStates: { [Player]: CarryState } = {}
local characterRemovingConnections: { [Player]: RBXScriptConnection } = {}
local MovementStates: { [Player]: MovementState } = {}
local dataService
local StopCarrying
local DropHandler

local function ClearCarryMovement(Player: Player)
	local State = MovementStates[Player]
	if not State then return end
	MovementStates[Player] = nil
	State.Connection:Disconnect()
	local Humanoid = State.Humanoid
	if Humanoid.Parent and math.abs(Humanoid.WalkSpeed - State.AppliedWalkSpeed) < 0.001 then
		State.Updating = true
		Humanoid.WalkSpeed = State.BaseWalkSpeed
		State.Updating = false
	end
end

local function ApplyCarryMovement(Player: Player)
	ClearCarryMovement(Player)
	local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	local State = {
		AppliedWalkSpeed = math.max(0, Humanoid.WalkSpeed * ItemInteractionConfig.CarryWalkSpeedMultiplier),
		BaseWalkSpeed = Humanoid.WalkSpeed,
		Humanoid = Humanoid,
		Updating = false,
	}
	State.Connection = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if State.Updating or MovementStates[Player] ~= State then return end
		if math.abs(Humanoid.WalkSpeed - State.AppliedWalkSpeed) < 0.001 then return end
		State.BaseWalkSpeed = Humanoid.WalkSpeed
		State.AppliedWalkSpeed = math.max(0, State.BaseWalkSpeed * ItemInteractionConfig.CarryWalkSpeedMultiplier)
		State.Updating = true
		Humanoid.WalkSpeed = State.AppliedWalkSpeed
		State.Updating = false
	end)
	MovementStates[Player] = State
	State.Updating = true
	Humanoid.WalkSpeed = State.AppliedWalkSpeed
	State.Updating = false
end

local function PlaySound(Player: Player, SoundName: string)
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if RootPart == nil then
		return
	end
	Sounds.Play(SoundName, RootPart, SFX_MAX_DISTANCE)
end

local function getItemInfo(itemId: number)
	for _, itemInfo in ItemsInfo do
		if itemInfo.Id == itemId then
			return itemInfo
		end
	end
	return nil
end

local function GetSuggestedDirtCount(ItemId: number): number
	local ItemInfo = getItemInfo(ItemId)
	local Template = ItemInfo and ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	return if Template and Template:IsA("Model") then DirtRenderer.GetSuggestedCount(Template) else 1
end

local function prepareParts(model: Model, rootPart: BasePart)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true

			if descendant ~= rootPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootPart
				weld.Part1 = descendant
				weld.Parent = rootPart
			end
		end
	end
end

local function attachCarriedModel(player: Player, state: CarryState): boolean
	local itemInfo = getItemInfo(state.itemId)
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	local template = itemInfo and ReplicatedStorage.Assets.Models.Items:FindFirstChild(itemInfo.AssetName)
	if humanoidRootPart == nil or template == nil or not template:IsA("Model") then
		return false
	end

	if state.model then
		if state.ModelConnection then state.ModelConnection:Disconnect(); state.ModelConnection = nil end
		state.model:Destroy()
	end
	if state.DeathConnection then state.DeathConnection:Disconnect(); state.DeathConnection = nil end

	local model = template:Clone()
	local boundingBox = model:FindFirstChild("BoundingBox")
	if boundingBox == nil or not boundingBox:IsA("BasePart") then
		model:Destroy()
		return false
	end

	model.Name = `Carried_{itemInfo.Name}`
	model.PrimaryPart = boundingBox
	model:PivotTo(
		humanoidRootPart.CFrame
			* (itemInfo.CarryOffset or DEFAULT_CARRY_OFFSET)
			* CFrame.Angles(0, math.rad(180), 0)
	)
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingState = fixing[state.ItemKey]
	-- Generate every restoration layer before the weld pass so dust and debris move with the carried item.
	RestorationVisuals.Apply(model, itemInfo, fixingState)
	prepareParts(model, boundingBox)

	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = humanoidRootPart
	carryWeld.Part1 = boundingBox
	carryWeld.Parent = boundingBox
	model.Parent = character
	local DisplayInfo = table.clone(itemInfo)
	DisplayInfo.Price = state.Ownership.CurrentPrice
	ItemInfoBillboard(DisplayInfo, boundingBox, fixingState)
	state.model = model
	local Humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		state.DeathConnection = Humanoid.Died:Connect(function()
			task.defer(CarryController.DropCarriedItem, player)
		end)
	end
	state.ModelConnection = model.Destroying:Connect(function()
		task.defer(function()
			if carryStates[player] == state and state.model == model then
				if not CarryController.DropCarriedItem(player) then StopCarrying(player) end
			end
		end)
	end)
	return true
end

StopCarrying = function(Player: Player, UpdatePlayerState: boolean?): number?
	local State = carryStates[Player]
	if not State then
		ClearCarryMovement(Player)
		if UpdatePlayerState ~= false then PlayerStateController.Set(Player, "IsCarryingItem", false) end
		return nil
	end
	carryStates[Player] = nil
	if State.DeathConnection then State.DeathConnection:Disconnect(); State.DeathConnection = nil end
	if State.ModelConnection then State.ModelConnection:Disconnect(); State.ModelConnection = nil end
	if State.model then State.model:Destroy(); State.model = nil end
	ClearCarryMovement(Player)
	if UpdatePlayerState ~= false then PlayerStateController.Set(Player, "IsCarryingItem", false) end
	return State.itemId
end

local function createTool(player: Player, itemId: number, itemKey: string): Tool?
	local itemInfo = getItemInfo(itemId)
	local template = itemInfo and ReplicatedStorage.Assets.Models.Items:FindFirstChild(itemInfo.AssetName)
	if template == nil or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	local handle = model:FindFirstChild("BoundingBox")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	local fixing = dataService:get(player, "Fixing") or {}
	local fixingState = fixing[itemKey]
	local tool = Instance.new("Tool")
	tool.Name = if CleaningConfig.IsCleaningComplete(fixingState, itemInfo) then itemInfo.Name else "???"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = tool.Grip * CFrame.Angles(0, math.rad(180), 0)
	tool:AddTag("satchelSlot")
	tool:AddTag(`Item_{itemInfo.Id}`)
	InventoryItemKey.Set(tool, itemKey)

	handle.Name = "Handle"
	handle.Transparency = 1
	RestorationVisuals.Apply(model, itemInfo, fixingState)
	prepareParts(model, handle)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	ItemInfoBillboard(itemInfo, handle, fixingState)
	return tool
end

local function EnsureInventoryKeys(Player: Player, Inventory): { string }
	local ExistingKeys = dataService:get(Player, "InventoryKeys")
	local InventoryKeys = {}
	local UsedKeys = {}
	local Fixing = dataService:get(Player, "Fixing") or {}
	local LegacyStatesUsed = {}
	local KeysChanged = type(ExistingKeys) ~= "table" or #ExistingKeys ~= #Inventory
	local FixingChanged = false
	for Position, ItemId in Inventory do
		local ItemKey = type(ExistingKeys) == "table" and ExistingKeys[Position] or nil
		if type(ItemKey) ~= "string" or ItemKey == "" or UsedKeys[ItemKey] then
			ItemKey = HttpService:GenerateGUID(false)
			KeysChanged = true
		end
		InventoryKeys[Position] = ItemKey
		UsedKeys[ItemKey] = true
		if type(ItemId) == "number" and type(Fixing[ItemKey]) == "table" then
			LegacyStatesUsed[ItemId] = true
		elseif Fixing[ItemKey] == nil and type(ItemId) == "number" then
			local LegacyKey = tostring(ItemId)
			local LegacyState = Fixing[LegacyKey]
			if type(LegacyState) == "table" and not LegacyStatesUsed[ItemId] then
				Fixing[ItemKey] = LegacyState
				LegacyStatesUsed[ItemId] = true
				FixingChanged = true
			end
		end
	end
	if KeysChanged then dataService:set(Player, "InventoryKeys", InventoryKeys) end
	if FixingChanged then dataService:set(Player, "Fixing", Fixing) end
	return InventoryKeys
end

local function removeManagedTools(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and (ToolResolver.GetItemInfo(child) or ToolResolver.GetCleaningToolInfo(child)) then
			child:Destroy()
		end
	end
end

local function restoreInventory(player: Player, character: Model, exitingFixing: boolean?)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	-- A delayed character inventory rebuild must never replace the cleaning tools for an active fixing session.
	if backpack == nil or player.Parent ~= Players or player.Character ~= character
		or (not exitingFixing and PlayerStateController.Get(player, "IsFixing", false) == true)
	then
		return
	end

	removeManagedTools(backpack)
	removeManagedTools(character)

	local inventory = dataService:get(player, "Inventory")
	if type(inventory) ~= "table" then
		return
	end
	local InventoryKeys = EnsureInventoryKeys(player, inventory)
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingChanged = false
	for Position, itemId in inventory do
		local ItemKey = InventoryKeys[Position]
		if type(itemId) == "number" and fixing[ItemKey] == nil then
			local DirtCount = GetSuggestedDirtCount(itemId)
			fixing[ItemKey] = { Total = DirtCount, Remaining = DirtCount, Completed = false }
			fixingChanged = true
		end
	end
	if fixingChanged then dataService:set(player, "Fixing", fixing) end

	for Position, itemId in inventory do
		if type(itemId) == "number" then
			local tool = createTool(player, itemId, InventoryKeys[Position])
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

local function deliverItem(player: Player)
	local state = carryStates[player]
	if state == nil then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	local inventory = dataService:get(player, "Inventory")
	if type(inventory) ~= "table" then
		return
	end

	local tool = createTool(player, state.itemId, state.ItemKey)
	if tool == nil then
		return
	end
	dataService:arrayInsert(player, "Inventory", state.itemId)
	dataService:arrayInsert(player, "InventoryKeys", state.ItemKey)

	StopCarrying(player)
	tool.Parent = backpack
	AnalyticsController.TrackItemBroughtToMuseum(player, state.itemId)
	GuidanceController.Advance(player, "BringItemHome")
	task.delay(0.1, function()
		local character = player.Character
		if character and tool.Parent == backpack then tool.Parent = character end
	end)
	PlaySound(player, "Reward1")
end

function CarryController.CanCarry(player: Player): boolean
	return player.Parent == Players
		and carryStates[player] == nil
		and player.Character ~= nil
		and PlayerStateController.Get(player, "IsFixing", false) ~= true
		and PlayerStateController.Get(player, "IsPvpStunned", false) ~= true
end

function CarryController.MoveCarriedItemToInventory(player: Player): number?
	local state = carryStates[player]
	if state == nil then return nil end
	dataService:arrayInsert(player, "Inventory", state.itemId)
	dataService:arrayInsert(player, "InventoryKeys", state.ItemKey)
	return StopCarrying(player)
end

function CarryController.SetDropHandler(Handler)
	DropHandler = Handler
end

function CarryController.DropCarriedItem(Player: Player, UpdatePlayerState: boolean?): boolean
	local State = carryStates[Player]
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not State or not DropHandler or not RootPart or not RootPart:IsA("BasePart") then return false end

	local FlatLook = Vector3.new(RootPart.CFrame.LookVector.X, 0, RootPart.CFrame.LookVector.Z)
	if FlatLook.Magnitude <= 0.01 then FlatLook = Vector3.zAxis end
	local DropPosition = RootPart.Position + FlatLook.Unit * ItemInteractionConfig.DropForwardDistance
	local DropCFrame = CFrame.lookAt(DropPosition, DropPosition + FlatLook.Unit)
	local DropData = {
		DirtCount = State.DirtCount,
		ItemId = State.itemId,
		Ownership = table.clone(State.Ownership),
		RestorationSteps = if State.RestorationSteps then table.clone(State.RestorationSteps) else nil,
	}
	if DropHandler(Player, DropData, DropCFrame) ~= true then return false end

	StopCarrying(Player, UpdatePlayerState)
	return true
end

function CarryController.RequestDrop(_, Player: Player)
	if Player.Parent ~= Players or PlayerStateController.Get(Player, "IsFixing", false) == true then return false end
	return CarryController.DropCarriedItem(Player)
end

function CarryController.GetEquippedItem(player: Player, ExpectedItemKey: string?): (number?, string?)
	local Character = player.Character
	if not Character then return nil end
	local EquippedItemId
	local EquippedItemKey
	for _, Tool in Character:GetChildren() do
		local ItemInfo = ToolResolver.GetItemInfo(Tool)
		local ItemKey = ItemInfo and Tool:HasTag("satchelSlot") and InventoryItemKey.Get(Tool) or nil
		if not ItemKey then continue end
		if ExpectedItemKey then
			if ItemKey == ExpectedItemKey then return ItemInfo.Id, ItemKey end
			continue
		end
		-- Equip replication may briefly expose both sides of an item switch. Do not guess which item is held.
		if EquippedItemKey then return nil end
		EquippedItemId = ItemInfo.Id
		EquippedItemKey = ItemKey
	end
	return EquippedItemId, EquippedItemKey
end

function CarryController.RefreshInventory(player: Player)
	if player.Character then restoreInventory(player, player.Character) end
end

function CarryController.SetFixingMode(player: Player, enabled: boolean, InitialToolId: string?)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if backpack then removeManagedTools(backpack) end
	if character then removeManagedTools(character) end
	if enabled then
		local InitialTool: Tool?
		local Ownership = dataService:get(player, "Upgrades")
		InitialToolId = InitialToolId or (CleaningConfig.Steps[1] and CleaningConfig.Steps[1].ToolId)
		if backpack then
			for _, ToolInfo in CleaningConfig.Tools do
				if not UpgradeLogic.IsToolUnlocked(Ownership, ToolInfo.Id) then continue end
				local Template = ReplicatedStorage.Assets.Tools:FindFirstChild(ToolInfo.TemplateName)
				if Template and Template:IsA("Tool") then
					local Tool = Template:Clone()
					Tool.Name = ToolInfo.DisplayName
					Tool.CanBeDropped = false
					Tool:AddTag("satchelSlot")
					for _, Descendant in Tool:GetDescendants() do
						if Descendant:IsA("BasePart") then
							-- Studio tool templates may be anchored; equipping one must never anchor or move the character assembly.
							Descendant.Anchored = false
							Descendant.Transparency = 1
							Descendant.CanCollide = false
							Descendant.CanQuery = false
							Descendant.CanTouch = false
							Descendant.Massless = true
							Descendant.CastShadow = false
						elseif Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") or Descendant:IsA("Trail") then
							Descendant.Enabled = false
						end
					end
					Tool.Parent = backpack
					if ToolInfo.Id == InitialToolId then InitialTool = Tool end
				end
			end
			if character and InitialTool then InitialTool.Parent = character end
		end
	elseif character then
		-- Restore inventory tools while IsFixing is still true so the completed item is present before release.
		restoreInventory(player, character, true)
	end
end

function CarryController.EquipCleaningTool(Player: Player, ToolId: string)
	local Character = Player.Character
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	local Ownership = dataService:get(Player, "Upgrades")
	if not Character or not Backpack or not UpgradeLogic.IsToolUnlocked(Ownership, ToolId) then return end
	for _, Tool in Character:GetChildren() do
		local ToolInfo = ToolResolver.GetCleaningToolInfo(Tool)
		if ToolInfo and ToolInfo.Id == ToolId then return end
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid:UnequipTools() end
	for _, Tool in Backpack:GetChildren() do
		local ToolInfo = ToolResolver.GetCleaningToolInfo(Tool)
		if ToolInfo and ToolInfo.Id == ToolId then
			Tool.Parent = Character
			return
		end
	end
end

function CarryController.StartCarrying(
	player: Player,
	itemId: number,
	DirtCount: number?,
	Ownership: OwnershipState?,
	RestorationSteps,
	playPickupSound: boolean?
): boolean
	local ItemInfo = getItemInfo(itemId)
	if not CarryController.CanCarry(player) or not ItemInfo then
		return false
	end

	local fixing = dataService:get(player, "Fixing") or {}
	local ResolvedDirtCount = if type(DirtCount) == "number" then math.max(1, math.round(DirtCount)) else GetSuggestedDirtCount(itemId)
	local ResolvedRestorationSteps
	if type(RestorationSteps) == "table" then
		ResolvedRestorationSteps = {}
		for _, StepId in RestorationSteps do
			if type(StepId) == "string" and CleaningConfig.GetStep(StepId) and not table.find(ResolvedRestorationSteps, StepId) then
				table.insert(ResolvedRestorationSteps, StepId)
			end
		end
		if #ResolvedRestorationSteps == 0 then ResolvedRestorationSteps = nil end
	end
	-- Conveyor and legacy items without an authored mix receive the same price-weighted restoration selection.
	if not ResolvedRestorationSteps then ResolvedRestorationSteps = CleaningConfig.RollRestorationSteps(ItemInfo) end
	local ResolvedOwnershipId = if Ownership and type(Ownership.OwnershipId) == "string" and Ownership.OwnershipId ~= ""
		then Ownership.OwnershipId
		else HttpService:GenerateGUID(false)
	local FixingState = {
		Total = ResolvedDirtCount,
		Remaining = ResolvedDirtCount,
		Completed = false,
	}
	if ResolvedRestorationSteps then FixingState.RestorationSteps = table.clone(ResolvedRestorationSteps) end
	-- Restoration state belongs to this physical copy, not every copy with the same catalog item id.
	fixing[ResolvedOwnershipId] = FixingState
	dataService:set(player, "Fixing", fixing)

	local state: CarryState = {
		DirtCount = ResolvedDirtCount,
		RestorationSteps = ResolvedRestorationSteps,
		ItemKey = ResolvedOwnershipId,
		Ownership = {
			BasePrice = ItemInfo.Price,
			CurrentPrice = if Ownership and type(Ownership.CurrentPrice) == "number"
				then math.clamp(
					math.round(Ownership.CurrentPrice),
					ItemInfo.Price,
					ItemInfo.Price * ItemInteractionConfig.MaximumPurchasePriceMultiplier
				)
				else ItemInfo.Price,
			OwnerUserId = player.UserId,
			OwnershipId = ResolvedOwnershipId,
			TransferCount = if Ownership and type(Ownership.TransferCount) == "number"
				then math.max(0, math.floor(Ownership.TransferCount))
				else 0,
		},
		itemId = itemId,
		model = nil,
	}
	carryStates[player] = state
	if not attachCarriedModel(player, state) then
		carryStates[player] = nil
		return false
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	PlayerStateController.Set(player, "IsCarryingItem", true)
	ApplyCarryMovement(player)
	GuidanceController.Advance(player, "PickUpItem")
	if playPickupSound ~= false then PlaySound(player, "Buy") end
	return true
end

function CarryController.OnPlayerAdded(player: Player)
	PlayerStateController.Set(player, "IsCarryingItem", false)
	characterRemovingConnections[player] = player.CharacterRemoving:Connect(function()
		if not CarryController.DropCarriedItem(player) then StopCarrying(player) end
	end)
end

function CarryController.OnCharacterAdded(player: Player, character: Model)
	local state = carryStates[player]
	task.spawn(function()
		restoreInventory(player, character)
		if state == nil then
			return
		end
		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
		if rootPart and carryStates[player] == state then
			if attachCarriedModel(player, state) then ApplyCarryMovement(player) else StopCarrying(player) end
		end
	end)
end

function CarryController.SetDataService(service)
	dataService = service
end

function CarryController.SaveInventoryOrder(_, player: Player, ItemKeys)
	-- Slot removal events race with fixing-mode replication, so reject their reorder requests authoritatively.
	if player.Parent ~= Players or PlayerStateController.Get(player, "IsFixing", false) == true or type(ItemKeys) ~= "table" then
		return
	end

	local currentInventory = dataService:get(player, "Inventory")
	if type(currentInventory) ~= "table" or #ItemKeys ~= #currentInventory then
		return
	end
	local CurrentKeys = EnsureInventoryKeys(player, currentInventory)
	local ItemsByKey = {}
	for Position, ItemKey in CurrentKeys do ItemsByKey[ItemKey] = currentInventory[Position] end
	local OrderedInventory = table.create(#ItemKeys)
	local OrderedKeys = table.create(#ItemKeys)
	local SeenKeys = {}
	for Position, ItemKey in ItemKeys do
		local ItemId = type(ItemKey) == "string" and ItemsByKey[ItemKey] or nil
		if not ItemId or SeenKeys[ItemKey] then return end
		SeenKeys[ItemKey] = true
		OrderedInventory[Position] = ItemId
		OrderedKeys[Position] = ItemKey
	end
	dataService:set(player, "Inventory", OrderedInventory)
	dataService:set(player, "InventoryKeys", OrderedKeys)
end

function CarryController.Init()
	MuseumController.SetInventoryRefreshHandler(CarryController.RefreshInventory)
	local BasesAreaTemplate = MapAssets:FindFirstChild("BasesArea")
	if BasesAreaTemplate and BasesAreaTemplate:IsA("BasePart") then
		local BasesArea = BasesAreaTemplate:Clone()
		BasesArea.Name = "BasesArea"
		BasesArea.Anchored = true
		BasesArea.CanCollide = false
		BasesArea.CanTouch = true
		BasesArea.Transparency = 1
		BasesArea.Parent = Workspace
		-- Any player carrying an item can deliver it through the shared bases area.
		BasesArea.Touched:Connect(function(Hit)
			local Character = Hit:FindFirstAncestorOfClass("Model")
			local Player = Character and Players:GetPlayerFromCharacter(Character)
			if Player then deliverItem(Player) end
		end)
	end
	Networker.server.new("InventoryController", CarryController, {
		CarryController.RequestDrop,
		CarryController.SaveInventoryOrder,
	})
end

function CarryController.OnPlayerRemoving(player: Player)
	local CharacterConnection = characterRemovingConnections[player]
	if CharacterConnection then
		CharacterConnection:Disconnect()
		characterRemovingConnections[player] = nil
	end

	if not CarryController.DropCarriedItem(player, false) then StopCarrying(player, false) end
end

return CarryController
