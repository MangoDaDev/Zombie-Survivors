local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)

local DEFAULT_CARRY_OFFSET = CFrame.new(0, 0, -3) * CFrame.Angles(0, math.rad(90), 0)
local SFX_MAX_DISTANCE = 80

type CarryState = {
	itemId: number,
	model: Model?,
}

local CarryController = {}

local carryStates: { [Player]: CarryState } = {}
local museumAreaConnections: { [Player]: RBXScriptConnection } = {}
local dataService

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
		state.model:Destroy()
	end

	local model = template:Clone()
	local boundingBox = model:FindFirstChild("BoundingBox")
	if boundingBox == nil or not boundingBox:IsA("BasePart") then
		model:Destroy()
		return false
	end

	model.Name = `Carried_{itemInfo.Name}`
	model.PrimaryPart = boundingBox
	model:PivotTo(humanoidRootPart.CFrame * (itemInfo.CarryOffset or DEFAULT_CARRY_OFFSET))
	prepareParts(model, boundingBox)

	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = humanoidRootPart
	carryWeld.Part1 = boundingBox
	carryWeld.Parent = boundingBox
	model.Parent = character
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingState = fixing[tostring(state.itemId)]
	RestorationVisuals.Apply(model, itemInfo, fixingState)
	ItemInfoBillboard(itemInfo, boundingBox, fixingState)
	state.model = model
	return true
end

local function createTool(player: Player, itemId: number, inventoryPosition: number): Tool?
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

	local tool = Instance.new("Tool")
	tool.Name = itemInfo.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", itemId)
	tool:SetAttribute("InitialToolOrder", inventoryPosition)
	tool:AddTag("satchelSlot")

	handle.Name = "Handle"
	handle.Transparency = 1
	prepareParts(model, handle)
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingState = fixing[tostring(itemId)]
	tool:SetAttribute("NeedsFixing", fixingState ~= nil and fixingState.Completed ~= true)
	RestorationVisuals.Apply(model, itemInfo, fixingState)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	ItemInfoBillboard(itemInfo, handle, fixingState)
	return tool
end

local function removeManagedTools(container: Instance)
	for _, child in container:GetChildren() do
		if
			child:IsA("Tool")
			and (
				type(child:GetAttribute("ItemId")) == "number"
				or type(child:GetAttribute("FixingTool")) == "string"
			)
		then
			child:Destroy()
		end
	end
end

local function restoreInventory(player: Player, character: Model)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack == nil or player.Parent ~= Players or player.Character ~= character then
		return
	end

	removeManagedTools(backpack)
	removeManagedTools(character)

	local inventory = dataService:get(player, "Inventory")
	if type(inventory) ~= "table" then
		return
	end
	local fixing = dataService:get(player, "Fixing") or {}
	local fixingChanged = false
	for _, itemId in inventory do
		if type(itemId) == "number" and fixing[tostring(itemId)] == nil then
			local DirtCount = GetSuggestedDirtCount(itemId)
			fixing[tostring(itemId)] = { Total = DirtCount, Remaining = DirtCount, Completed = false }
			fixingChanged = true
		end
	end
	if fixingChanged then dataService:set(player, "Fixing", fixing) end

	for inventoryPosition, itemId in inventory do
		if type(itemId) == "number" then
			local tool = createTool(player, itemId, inventoryPosition)
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

	local inventoryPosition = #inventory + 1
	local tool = createTool(player, state.itemId, inventoryPosition)
	if tool == nil then
		return
	end
	dataService:arrayInsert(player, "Inventory", state.itemId)

	carryStates[player] = nil
	if state.model then
		state.model:Destroy()
	end
	tool.Parent = backpack
	player:SetAttribute("IsCarryingItem", false)
	task.delay(0.1, function()
		local character = player.Character
		if character and tool.Parent == backpack then tool.Parent = character end
	end)
	PlaySound(player, "Reward1")
end

function CarryController.CanCarry(player: Player): boolean
	return player.Parent == Players and carryStates[player] == nil and player.Character ~= nil and player:GetAttribute("IsFixing") ~= true
end

function CarryController.MoveCarriedItemToInventory(player: Player): number?
	local state = carryStates[player]
	if state == nil then return nil end
	dataService:arrayInsert(player, "Inventory", state.itemId)
	if state.model then state.model:Destroy() end
	carryStates[player] = nil
	player:SetAttribute("IsCarryingItem", false)
	return state.itemId
end

function CarryController.GetEquippedItemId(player: Player): number?
	local Character = player.Character
	if not Character then return nil end
	for _, Tool in Character:GetChildren() do
		local ItemId = Tool:GetAttribute("ItemId")
		if Tool:IsA("Tool") and type(ItemId) == "number" and Tool:HasTag("satchelSlot") then return ItemId end
	end
	return nil
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
					Tool:SetAttribute("FixingTool", ToolInfo.TemplateName)
					Tool:SetAttribute("CleaningToolId", ToolInfo.Id)
					Tool:SetAttribute("InitialToolOrder", 1)
					Tool:AddTag("satchelSlot")
					for _, Descendant in Tool:GetDescendants() do
						if Descendant:IsA("BasePart") then
							Descendant:SetAttribute("ViewmodelTransparency", Descendant.Transparency)
							Descendant.Transparency = 1
							Descendant.CanCollide = false
							Descendant.CanQuery = false
							Descendant.CanTouch = false
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
		restoreInventory(player, character)
	end
end

function CarryController.EquipCleaningTool(Player: Player, ToolId: string)
	local Character = Player.Character
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	local Ownership = dataService:get(Player, "Upgrades")
	if not Character or not Backpack or not UpgradeLogic.IsToolUnlocked(Ownership, ToolId) then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid:UnequipTools() end
	for _, Tool in Backpack:GetChildren() do
		if Tool:IsA("Tool") and Tool:GetAttribute("CleaningToolId") == ToolId then
			Tool.Parent = Character
			return
		end
	end
end

function CarryController.StartCarrying(player: Player, itemId: number, DirtCount: number?): boolean
	if not CarryController.CanCarry(player) or getItemInfo(itemId) == nil then
		return false
	end

	local fixing = dataService:get(player, "Fixing") or {}
	local ResolvedDirtCount = if type(DirtCount) == "number" then math.max(1, math.round(DirtCount)) else GetSuggestedDirtCount(itemId)
	fixing[tostring(itemId)] = {
		Total = ResolvedDirtCount,
		Remaining = ResolvedDirtCount,
		Completed = false,
	}
	dataService:set(player, "Fixing", fixing)

	local state: CarryState = {
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
	player:SetAttribute("IsCarryingItem", true)
	PlaySound(player, "Buy")
	return true
end

function CarryController.OnPlayerAdded(player: Player)
	player:SetAttribute("IsCarryingItem", false)
	local museum = MuseumController.GetMuseum(player)
	local museumArea = museum and museum:FindFirstChild("MuseumArea")
	if museumArea == nil or not museumArea:IsA("BasePart") then
		return
	end

	museumAreaConnections[player] = museumArea.Touched:Connect(function(hit)
		local character = player.Character
		if character and hit:IsDescendantOf(character) then
			deliverItem(player)
		end
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
			attachCarriedModel(player, state)
		end
	end)
end

function CarryController.SetDataService(service)
	dataService = service
end

function CarryController:SaveInventoryOrder(player: Player, itemIds)
	if player.Parent ~= Players or type(itemIds) ~= "table" then
		return
	end

	local currentInventory = dataService:get(player, "Inventory")
	if type(currentInventory) ~= "table" or #itemIds ~= #currentInventory then
		return
	end

	for key in itemIds do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #itemIds then
			return
		end
	end

	local currentCounts = {}
	for _, itemId in currentInventory do
		if type(itemId) ~= "number" or getItemInfo(itemId) == nil then
			return
		end
		currentCounts[itemId] = (currentCounts[itemId] or 0) + 1
	end

	local orderedInventory = table.create(#itemIds)
	local requestedCounts = {}
	for position = 1, #itemIds do
		local itemId = itemIds[position]
		if type(itemId) ~= "number" or itemId % 1 ~= 0 or getItemInfo(itemId) == nil then
			return
		end
		orderedInventory[position] = itemId
		requestedCounts[itemId] = (requestedCounts[itemId] or 0) + 1
	end

	for itemId, count in currentCounts do
		if requestedCounts[itemId] ~= count then
			return
		end
	end

	dataService:set(player, "Inventory", orderedInventory)
end

function CarryController:Init()
	MuseumController.SetInventoryRefreshHandler(CarryController.RefreshInventory)
	Networker.server.new("InventoryController", self, {
		CarryController.SaveInventoryOrder,
	})
end

function CarryController.OnPlayerRemoving(player: Player)
	local connection = museumAreaConnections[player]
	if connection then
		connection:Disconnect()
		museumAreaConnections[player] = nil
	end

	local state = carryStates[player]
	if state and state.model then
		state.model:Destroy()
	end
	carryStates[player] = nil
end

return CarryController
