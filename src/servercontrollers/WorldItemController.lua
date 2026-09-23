local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local CarryController = require(ServerStorage.Controllers.CarryController)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemDespawnCountdown = require(ReplicatedStorage.Modules.UI.ItemDespawnCountdown)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)

type WorldItemState = {
	AncestryConnection: RBXScriptConnection?,
	DestroyingConnection: RBXScriptConnection?,
	DirtCount: number,
	CountdownRow: Frame,
	ExpiresAt: number,
	InteractionStartedAt: number?,
	ItemId: number,
	Locked: boolean,
	Model: Model,
	MoveConnection: RBXScriptConnection?,
	Ownership: CarryController.OwnershipState,
	PromptConnection: RBXScriptConnection?,
	RestorationSteps: { string }?,
	SafeCFrame: CFrame,
}

local WorldItemController = {}
local WorldItemFolder: Folder
local WorldItems: { [Model]: WorldItemState } = {}
local PickupLocks: { [Player]: boolean } = {}

local function GetItemInfo(ItemId: number)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
end

local function DisconnectState(State: WorldItemState)
	if State.AncestryConnection then State.AncestryConnection:Disconnect(); State.AncestryConnection = nil end
	if State.DestroyingConnection then State.DestroyingConnection:Disconnect(); State.DestroyingConnection = nil end
	if State.MoveConnection then State.MoveConnection:Disconnect(); State.MoveConnection = nil end
	if State.PromptConnection then State.PromptConnection:Disconnect(); State.PromptConnection = nil end
end

local function RemoveWorldItem(State: WorldItemState)
	if WorldItems[State.Model] ~= State then return end
	WorldItems[State.Model] = nil
	DisconnectState(State)
	if State.Model.Parent then State.Model:Destroy() end
end

local function GetGroundCFrame(Player: Player, DropCFrame: CFrame): CFrame
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = { Player.Character, WorldItemFolder }
	Parameters.IgnoreWater = false
	local Origin = DropCFrame.Position + Vector3.new(0, 6, 0)
	local Result = Workspace:Raycast(Origin, Vector3.new(0, -30, 0), Parameters)
	local Position = if Result then Result.Position else DropCFrame.Position
	return CFrame.new(Position) * DropCFrame.Rotation
end

local function SetModelOnGround(Model: Model, GroundCFrame: CFrame): CFrame
	Model:PivotTo(GroundCFrame)
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local BottomY = BoundingCFrame.Position.Y - BoundingSize.Y / 2
	local GroundedCFrame = Model:GetPivot() + Vector3.new(0, GroundCFrame.Position.Y - BottomY, 0)
	Model:PivotTo(GroundedCFrame)
	return GroundedCFrame
end

local function GetTransferredOwnership(State: WorldItemState, Player: Player): CarryController.OwnershipState
	local Ownership = table.clone(State.Ownership)
	Ownership.OwnerUserId = Player.UserId
	Ownership.TransferCount += 1
	return Ownership
end

local function PickUpWorldItem(State: WorldItemState, Player: Player)
	if WorldItems[State.Model] ~= State or State.Locked or PickupLocks[Player] then return end
	if Player.Parent ~= Players or not CarryController.CanCarry(Player) then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return end
	if (RootPart.Position - State.Model:GetPivot().Position).Magnitude > ItemInteractionConfig.DroppedItemPickupDistance then return end

	State.Locked = true
	PickupLocks[Player] = true
	local IsOwner = State.Ownership.OwnerUserId == Player.UserId
	local Ownership = if IsOwner then table.clone(State.Ownership) else GetTransferredOwnership(State, Player)
	-- Dropped items are always free to pick up; only a successful pickup transfers server-owned copy metadata.
	if not CarryController.StartCarrying(Player, State.ItemId, State.DirtCount, Ownership, State.RestorationSteps, false) then
		State.Locked = false
		PickupLocks[Player] = nil
		return
	end
	if not IsOwner then
		AnalyticsController.TrackItemPurchased(Player, State.ItemId, "WorldItem")
	end
	PickupLocks[Player] = nil
	RemoveWorldItem(State)
end

local function CreateDroppedItem(Player: Player, DropData, DropCFrame: CFrame): boolean
	if type(DropData) ~= "table" or typeof(DropCFrame) ~= "CFrame" then return false end
	local ItemInfo = if type(DropData.ItemId) == "number" then GetItemInfo(DropData.ItemId) else nil
	local Ownership = DropData.Ownership
	if not ItemInfo or type(Ownership) ~= "table" or Ownership.OwnerUserId ~= Player.UserId then return false end
	if type(Ownership.OwnershipId) ~= "string" then return false end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return false end

	local Model = Template:Clone()
	local BoundingBox = Model:FindFirstChild("BoundingBox")
	if not BoundingBox or not BoundingBox:IsA("BasePart") then Model:Destroy(); return false end
	Model.Name = `Dropped_{ItemInfo.Name}`
	Model.PrimaryPart = BoundingBox
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
			Descendant.CanCollide = false
			Descendant.CanQuery = true
			Descendant.CanTouch = false
		end
	end
	local GroundCFrame = GetGroundCFrame(Player, DropCFrame)
	Model.Parent = WorldItemFolder
	local SafeCFrame = SetModelOnGround(Model, GroundCFrame)
	local DirtCount = if type(DropData.DirtCount) == "number" then math.max(1, math.round(DropData.DirtCount)) else 1
	local RestorationSteps = if type(DropData.RestorationSteps) == "table" then table.clone(DropData.RestorationSteps) else nil
	local FixingState = {
		Total = DirtCount,
		Remaining = DirtCount,
		Completed = false,
		RestorationSteps = RestorationSteps,
	}
	RestorationVisuals.Apply(Model, ItemInfo, FixingState)
	local Billboard = ItemInfoBillboard(ItemInfo, BoundingBox, FixingState)

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "WorldItemPrompt"
	Prompt.ActionText = "Pick Up"
	Prompt.ObjectText = "Free Item"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = ItemInteractionConfig.DroppedItemPickupDistance
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = BoundingBox

	local CountdownRow = ItemDespawnCountdown.Create(Billboard)
	local State: WorldItemState = {
		CountdownRow = CountdownRow,
		DirtCount = DirtCount,
		ExpiresAt = Workspace:GetServerTimeNow() + ItemInteractionConfig.WorldItemDespawnDuration,
		ItemId = ItemInfo.Id,
		Locked = false,
		Model = Model,
		Ownership = table.clone(Ownership),
		RestorationSteps = RestorationSteps,
		SafeCFrame = SafeCFrame,
	}
	WorldItems[Model] = State
	CollectionService:AddTag(Model, "WorldItem")
	State.PromptConnection = Prompt.Triggered:Connect(function(TriggeringPlayer)
		if WorldItems[Model] ~= State or State.Locked then return end
		State.InteractionStartedAt = Workspace:GetServerTimeNow()
		State.CountdownRow.Visible = false
		PickUpWorldItem(State, TriggeringPlayer)
		if WorldItems[Model] == State and State.InteractionStartedAt then
			State.ExpiresAt += Workspace:GetServerTimeNow() - State.InteractionStartedAt
			State.InteractionStartedAt = nil
		end
	end)
	State.MoveConnection = BoundingBox:GetPropertyChangedSignal("CFrame"):Connect(function()
		if WorldItems[Model] ~= State or State.Locked then return end
		if (Model:GetPivot().Position - State.SafeCFrame.Position).Magnitude > ItemInteractionConfig.UnexpectedMoveDistance then
			Model:PivotTo(State.SafeCFrame)
		end
	end)
	State.AncestryConnection = Model.AncestryChanged:Connect(function()
		if WorldItems[Model] == State and Model.Parent ~= WorldItemFolder then RemoveWorldItem(State) end
	end)
	State.DestroyingConnection = Model.Destroying:Connect(function()
		if WorldItems[Model] == State then
			WorldItems[Model] = nil
			DisconnectState(State)
		end
	end)
	return true
end

local function UpdateDespawnTimers()
	local Now = Workspace:GetServerTimeNow()
	local ExpiredStates = {}
	for _, State in WorldItems do
		if State.Locked or State.InteractionStartedAt then continue end
		local Remaining = State.ExpiresAt - Now
		if Remaining <= 0 then
			table.insert(ExpiredStates, State)
		else
			ItemDespawnCountdown.Update(State.CountdownRow, Remaining)
		end
	end
	for _, State in ExpiredStates do RemoveWorldItem(State) end
end

function WorldItemController.SetDataService(_Service) end

function WorldItemController.Init()
	WorldItemFolder = Instance.new("Folder")
	WorldItemFolder.Name = "WorldItems"
	WorldItemFolder.Parent = Workspace
	CarryController.SetDropHandler(CreateDroppedItem)
	task.spawn(function()
		while WorldItemFolder.Parent do
			UpdateDespawnTimers()
			task.wait(ItemInteractionConfig.WorldItemTimerUpdateInterval)
		end
	end)
end

function WorldItemController.OnPlayerRemoving(Player: Player)
	PickupLocks[Player] = nil
end

return WorldItemController
