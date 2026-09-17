local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryController = require(ServerStorage.Controllers.CarryController)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local EconomyConfig = require(ReplicatedStorage.Modules.Game.EconomyConfig)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local FormatTime = require(ReplicatedStorage.Modules.Math.FormatTime)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemDespawnCountdown = require(ReplicatedStorage.Modules.UI.ItemDespawnCountdown)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local CrateController = {}
local DataService
local Network
local CrateFolder: Folder
local RewardFolder: Folder
local ResetWall: BasePart?
local Crates = {}
local Rewards = {}
local PityLabels = {}
local RandomGenerator = Random.new()
local IsResetting = false
local ResetGeneration = 0
local NextResetTime
local PurchaseFeedbackDistancePadding = 8

local function GetItemInfo(ItemId)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
end

local function IsRecoveryEligible(Player: Player, Info): boolean
	if not Info or Info.Id ~= EconomyConfig.RecoveryCrateId then return false end
	local Cash = DataService:get(Player, "Cash")
	local Inventory = DataService:get(Player, "Inventory")
	local Displays = DataService:get(Player, "Displays")
	return type(Cash) == "number"
		and Cash < EconomyConfig.GetMinimumItemPrice()
		and (type(Inventory) ~= "table" or #Inventory == 0)
		and (type(Displays) ~= "table" or next(Displays) == nil)
end

local function GetRewardItemInfo(Player: Player, Info)
	-- A cash-poor player with no owned items always has a modest common-crate recovery loop.
	if IsRecoveryEligible(Player, Info) then return GetItemInfo(EconomyConfig.RecoveryItemId), true end
	local GuaranteedDropCount = DataService:get(Player, "GuaranteedDropCount")
	local IsNewPlayer = GuaranteedDropCount ~= 0
		or DataService:get(Player, "TutorialStep") == TutorialConfig.InitialStep
	if type(GuaranteedDropCount) == "number" and IsNewPlayer then
		local GuaranteedItemId = CrateInfo.NewPlayerDropSequence[GuaranteedDropCount + 1]
		local GuaranteedItemInfo = GuaranteedItemId and GetItemInfo(GuaranteedItemId)
		if GuaranteedItemInfo then
			DataService:set(Player, "GuaranteedDropCount", GuaranteedDropCount + 1)
			return GuaranteedItemInfo, false
		end
	end
	return CrateInfo.GetRandomItem(ItemsInfo, Info, RandomGenerator), false
end

local function GetRevealDuration(Info): number
	local Duration = 0
	for Index = 1, Info.PreviewSwitchCount do
		local Alpha = if Info.PreviewSwitchCount > 1 then (Index - 1) / (Info.PreviewSwitchCount - 1) else 1
		Duration += Info.PreviewStartDelay + (Info.PreviewEndDelay - Info.PreviewStartDelay) * Alpha * Alpha
	end
	return Duration
end

local function CreateHealthBar(Model, Info)
	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "CrateHealth"
	Billboard.Adornee = Model.PrimaryPart
	Billboard.AlwaysOnTop = true
	Billboard.MaxDistance = 100
	Billboard.Size = UDim2.fromScale(5, 0.75)
	Billboard.StudsOffsetWorldSpace = Vector3.new(0, Model:GetExtentsSize().Y / 2 + 1, 0)
	Billboard.Parent = Model.PrimaryPart
	local Group = Instance.new("CanvasGroup")
	Group.Name = "Group"
	Group.BackgroundTransparency = 1
	Group.BorderSizePixel = 0
	Group.GroupTransparency = 1
	Group.Size = UDim2.fromScale(1, 1)
	Group.Parent = Billboard
	local Track = Instance.new("Frame")
	Track.Name = "Track"
	Track.BackgroundColor3 = Color3.fromRGB(79, 18, 22)
	Track.BorderSizePixel = 0
	Track.Size = UDim2.fromScale(1, 1)
	Track.ClipsDescendants = true
	Track.Parent = Group
	local TrackCorner = Instance.new("UICorner")
	TrackCorner.CornerRadius = UDim.new(1, 0)
	TrackCorner.Parent = Track
	local TrackStroke = Instance.new("UIStroke")
	TrackStroke.Color = Color3.new(0, 0, 0)
	TrackStroke.Transparency = 0
	TrackStroke.Thickness = 2
	TrackStroke.Parent = Track
	local Fill = Instance.new("Frame")
	Fill.Name = "Fill"
	Fill.BackgroundColor3 = Color3.fromRGB(88, 225, 111)
	Fill.BorderSizePixel = 0
	Fill.Size = UDim2.fromScale(1, 1)
	Fill.Parent = Track
	local FillCorner = Instance.new("UICorner")
	FillCorner.CornerRadius = UDim.new(1, 0)
	FillCorner.Parent = Fill
	local HealthLabel = Instance.new("TextLabel")
	HealthLabel.Name = "Health"
	HealthLabel.BackgroundTransparency = 1
	HealthLabel.FontFace = UIStyle.Font
	HealthLabel.Size = UDim2.fromScale(1, 1)
	HealthLabel.Text = `{Info.Health}/{Info.Health}`
	HealthLabel.TextColor3 = Color3.new(1, 1, 1)
	HealthLabel.TextScaled = true
	HealthLabel.ZIndex = 2
	HealthLabel.Parent = Track
	local TextStroke = Instance.new("UIStroke")
	TextStroke.Color = Color3.new(0, 0, 0)
	TextStroke.Transparency = 0.2
	TextStroke.Thickness = 1.5
	TextStroke.Parent = HealthLabel
	return Group, Fill, HealthLabel
end

local function GetSpawnCFrame(Info): CFrame?
	local Area = Workspace:FindFirstChild("CrateSpawnArea")
	if not Area or not Area:IsA("BasePart") then return nil end
	for _ = 1, 12 do
		local X = RandomGenerator:NextNumber(-Area.Size.X / 2 + Info.SpawnPadding, Area.Size.X / 2 - Info.SpawnPadding)
		local MinimumZ = -Area.Size.Z / 2 + Info.SpawnPadding
		local MaximumZ = Area.Size.Z / 2 - Info.SpawnPadding
		local SpawnDepth = RandomGenerator:NextNumber()
		local SpawnDepthBias = math.clamp(Info.SpawnDepthBias or 0, -1, 1)
		local BiasPower = 1 + math.abs(SpawnDepthBias) * 3
		if SpawnDepthBias < 0 then
			SpawnDepth = SpawnDepth ^ BiasPower
		elseif SpawnDepthBias > 0 then
			SpawnDepth = 1 - (1 - SpawnDepth) ^ BiasPower
		end
		local Z = MaximumZ + (MinimumZ - MaximumZ) * SpawnDepth
		local Position = Area.CFrame:PointToWorldSpace(Vector3.new(X, Area.Size.Y / 2, Z))
		local IsClear = true
		for _, State in Crates do
			if (State.BaseCFrame.Position - Position).Magnitude < Info.MinimumSpawnSeparation then IsClear = false; break end
		end
		if IsClear then return CFrame.new(Position) end
	end
	return nil
end

local function SetModelOnGround(Model, GroundCFrame)
	Model:PivotTo(GroundCFrame)
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local BottomY = BoundingCFrame.Position.Y - BoundingSize.Y / 2
	Model:PivotTo(Model:GetPivot() + Vector3.new(0, GroundCFrame.Position.Y - BottomY, 0))
end

local function SendPurchaseFeedback(Player, Status, ItemName, Detail)
	Network:fire(Player, "PurchaseFeedback", Status, ItemName, Detail)
end

local function NotifyNearbyPlayers(Reward, Status, ExcludedPlayer)
	local ItemInfo = GetItemInfo(Reward.ItemId)
	if not ItemInfo or not Reward.Model or not Reward.Model.Parent then return end
	local Position = Reward.Model:GetPivot().Position
	local MaximumDistance = Reward.Info.PurchaseDistance + PurchaseFeedbackDistancePadding
	for _, Player in Players:GetPlayers() do
		if Player == ExcludedPlayer then continue end
		local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if RootPart and RootPart:IsA("BasePart") and (RootPart.Position - Position).Magnitude <= MaximumDistance then
			SendPurchaseFeedback(Player, Status, ItemInfo.Name)
		end
	end
end

local function RemoveReward(RewardId, Reason, PurchasingPlayer)
	local Reward = Rewards[RewardId]
	if not Reward then return end
	if Reason == "Purchased" then
		NotifyNearbyPlayers(Reward, "PurchasedByAnother", PurchasingPlayer)
	elseif Reason == "Expired" then
		NotifyNearbyPlayers(Reward, "Expired")
	end
	Rewards[RewardId] = nil
	if Reward.Connection then Reward.Connection:Disconnect() end
	if Reward.Model then Reward.Model:Destroy() end
	Network:fireAll("RemoveReveal", RewardId)
end

local function PurchaseReward(RewardId, Player)
	local Reward = Rewards[RewardId]
	if not Reward then return end
	local ItemInfo = GetItemInfo(Reward.ItemId)
	if not ItemInfo then return end
	if Reward.Purchased then SendPurchaseFeedback(Player, "PurchasedByAnother", ItemInfo.Name); return end
	if Workspace:GetServerTimeNow() < Reward.AvailableAt then SendPurchaseFeedback(Player, "NotReady", ItemInfo.Name); return end
	if PlayerStateController.Get(Player, "IsFixing", false) == true then SendPurchaseFeedback(Player, "Fixing", ItemInfo.Name); return end
	if PlayerStateController.Get(Player, "IsCarryingItem", false) == true then SendPurchaseFeedback(Player, "AlreadyCarrying", ItemInfo.Name); return end
	if not CarryController.CanCarry(Player) then SendPurchaseFeedback(Player, "Unavailable", ItemInfo.Name); return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Cash = DataService:get(Player, "Cash")
	if not RootPart or not RootPart:IsA("BasePart") or type(Cash) ~= "number" then SendPurchaseFeedback(Player, "Unavailable", ItemInfo.Name); return end
	if Cash < ItemInfo.Price and Reward.IsRecovery and IsRecoveryEligible(Player, Reward.Info) then
		Cash += EconomyConfig.GetRecoveryGrant(Cash, ItemInfo.Price)
	end
	if Cash < ItemInfo.Price then SendPurchaseFeedback(Player, "NotEnoughCash", ItemInfo.Name, ItemInfo.Price - Cash); return end
	if (RootPart.Position - Reward.Model:GetPivot().Position).Magnitude > Reward.Info.PurchaseDistance then return end
	Reward.Purchased = true
	if not CarryController.StartCarrying(Player, Reward.ItemId, Reward.DirtCount) then
		Reward.Purchased = false
		SendPurchaseFeedback(Player, "Unavailable", ItemInfo.Name)
		return
	end
	DataService:set(Player, "Cash", Cash - ItemInfo.Price)
	SendPurchaseFeedback(Player, "Success", ItemInfo.Name, ItemInfo.Price)
	RemoveReward(RewardId, "Purchased", Player)
end

local function CreateReward(State, Player: Player, PredictionId)
	local Info = State.Info
	local ItemInfo, IsRecovery = GetRewardItemInfo(Player, Info)
	if not ItemInfo then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	Model.Name = `CrateReward_{ItemInfo.Name}`
	local DirtCount = DirtRenderer.GetSuggestedCount(Template)
	local FixingState = { Total = DirtCount, Remaining = DirtCount, Completed = false }
	local GroundCFrame = State.GroundCFrame
	SetModelOnGround(Model, GroundCFrame)
	-- Apply restoration damage before hiding the reward so no pristine frame can reveal the item.
	RestorationVisuals.Apply(Model, ItemInfo, FixingState)
	local RevealTransparencies = {}
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			RevealTransparencies[Part] = Part.Transparency
			Part.Transparency = 1
		end
	end
	Model.Parent = RewardFolder
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "PurchasePrompt"
	Prompt.ActionText = `Buy ${FormatNumber(ItemInfo.Price) or "0"}`
	Prompt.ObjectText = "???"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = Info.PurchaseDistance - 3
	Prompt.RequiresLineOfSight = false
	Prompt.Enabled = false
	Prompt.Parent = Box
	local RewardId = HttpService:GenerateGUID(false)
	local RevealDuration = GetRevealDuration(Info)
	local Reward = {
		Id = RewardId,
		Info = Info,
		ItemId = ItemInfo.Id,
		DirtCount = DirtCount,
		FixingState = FixingState,
		Model = Model,
		Prompt = Prompt,
		AvailableAt = Workspace:GetServerTimeNow() + RevealDuration + Info.RevealFadeTime,
		ExpiresAt = Workspace:GetServerTimeNow() + RevealDuration + Info.RevealFadeTime + ItemInteractionConfig.WorldItemDespawnDuration,
		Purchased = false,
		IsRecovery = IsRecovery,
		RevealTransparencies = RevealTransparencies,
	}
	Rewards[RewardId] = Reward
	Reward.Connection = Prompt.Triggered:Connect(function(Player)
		if Rewards[RewardId] ~= Reward or Reward.Interacting then return end
		Reward.Interacting = true
		Reward.InteractionStartedAt = Workspace:GetServerTimeNow()
		Prompt.Enabled = false
		PurchaseReward(RewardId, Player)
		if Rewards[RewardId] == Reward then
			Reward.ExpiresAt += Workspace:GetServerTimeNow() - Reward.InteractionStartedAt
			Reward.Interacting = false
			Reward.InteractionStartedAt = nil
			Prompt.Enabled = Workspace:GetServerTimeNow() >= Reward.AvailableAt
		end
	end)
	Network:fireAll("StartReveal", RewardId, ItemInfo.Id, GroundCFrame, Info.Id, Player, PredictionId, Model, DirtCount)
	task.delay(RevealDuration, function()
		if Rewards[RewardId] ~= Reward then return end
		for _, Part in Model:GetDescendants() do
			if Part:IsA("BasePart") then
				local RevealTransparency = Reward.RevealTransparencies[Part] or 0
				TweenService:Create(Part, TweenInfo.new(Info.RevealFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = RevealTransparency,
				}):Play()
			end
		end
		task.delay(Info.RevealFadeTime, function()
			if Rewards[RewardId] ~= Reward then return end
			Reward.RevealTransparencies = nil
			local Billboard = ItemInfoBillboard(ItemInfo, Box, Reward.FixingState)
			Reward.FixingState = nil
			Reward.CountdownRow = ItemDespawnCountdown.Create(Billboard)
			Prompt.Enabled = true
		end)
	end)
end

local function UpdateRewardDespawnTimers()
	local Now = Workspace:GetServerTimeNow()
	local ExpiredRewardIds = {}
	for RewardId, Reward in Rewards do
		if Reward.Purchased or Reward.Interacting or Now < Reward.AvailableAt then continue end
		local Remaining = Reward.ExpiresAt - Now
		if Remaining <= 0 then
			table.insert(ExpiredRewardIds, RewardId)
		else
			ItemDespawnCountdown.Update(Reward.CountdownRow, Remaining)
		end
	end
	for _, RewardId in ExpiredRewardIds do RemoveReward(RewardId, "Expired") end
end

local function BreakCrate(State, Player: Player, PredictionId)
	if Crates[State.Model] ~= State then return end
	local BreakGeneration = ResetGeneration
	Crates[State.Model] = nil
	CreateReward(State, Player, PredictionId)
	State.Model:Destroy()
	task.delay(State.Info.RespawnDelay, function()
		if State.Info.Respawns ~= false and ResetGeneration == BreakGeneration then CrateController.Spawn(State.Info) end
	end)
end

function CrateController.DamageCrate(Player, Model, Damage, PredictionId): boolean
	local State = Crates[Model]
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not State or not RootPart or not RootPart:IsA("BasePart") or type(Damage) ~= "number" then return false end
	State.Health = math.max(0, State.Health - math.clamp(Damage, 0, State.Info.Health))
	Network:fireAll("UpdateCrateHealth", State.Model, State.Info.Id, State.Health, State.Info.Health)
	State.VisibilityId += 1
	local VisibilityId = State.VisibilityId
	TweenService:Create(State.HealthGroup, TweenInfo.new(0.08), { GroupTransparency = 0 }):Play()
	TweenService:Create(State.HealthFill, TweenInfo.new(State.Info.HealthBarTweenTime, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(State.Health / State.Info.Health, 1) }):Play()
	State.HealthLabel.Text = `{math.ceil(State.Health)}/{State.Info.Health}`
	task.delay(State.Info.HealthBarHideDelay, function()
		if Crates[Model] == State and State.VisibilityId == VisibilityId then
			TweenService:Create(State.HealthGroup, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		end
	end)
	if State.Health <= 0 then BreakCrate(State, Player, PredictionId) end
	return true
end

local function GetActiveCrateCount(CrateId): number
	local Count = 0
	for _, State in Crates do
		if State.Info.Id == CrateId then Count += 1 end
	end
	return Count
end

function CrateController.Spawn(Info, AllowDuringReset): boolean
	if not CrateFolder or (IsResetting and AllowDuringReset ~= true) or GetActiveCrateCount(Info.Id) >= Info.MaximumActive then return false end
	local SpawnCFrame = GetSpawnCFrame(Info)
	local TemplateFolder = ReplicatedStorage.Assets.Models:FindFirstChild(Info.TemplateFolderName)
	local Template = TemplateFolder and TemplateFolder:FindFirstChild(Info.TemplateName)
	if not SpawnCFrame or not Template or not Template:IsA("Model") then return false end
	local Model = Template:Clone()
	local Scale = RandomGenerator:NextNumber(Info.ScaleMinimum, Info.ScaleMaximum)
	local YRotation = RandomGenerator:NextNumber(0, math.pi * 2)
	Model:ScaleTo(Scale)
	Model.Name = Info.Id
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then Part.Anchored = true; Part.CanCollide = true end
	end
	local GroundCFrame = CFrame.new(SpawnCFrame.Position) * CFrame.Angles(0, YRotation, 0)
	SetModelOnGround(Model, GroundCFrame)
	Model.Parent = CrateFolder
	CollectionService:AddTag(Model, "Crate")
	local HealthGroup, HealthFill, HealthLabel = CreateHealthBar(Model, Info)
	Crates[Model] = {
		Model = Model,
		Info = Info,
		Health = Info.Health,
		HealthGroup = HealthGroup,
		HealthFill = HealthFill,
		HealthLabel = HealthLabel,
		BaseCFrame = Model:GetPivot(),
		GroundCFrame = GroundCFrame,
		Scale = Scale,
		YRotation = YRotation,
		VisibilityId = 0,
	}
	Network:fireAll("UpdateCrateHealth", Model, Info.Id, Info.Health, Info.Health)
	return true
end

local function IsPlayerInCrateArea(Player, Area): boolean
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return false end
	local LocalPosition = Area.CFrame:PointToObjectSpace(RootPart.Position)
	return math.abs(LocalPosition.X) <= Area.Size.X / 2 and math.abs(LocalPosition.Z) <= Area.Size.Z / 2
end

local function SetResetWallVisible(IsVisible)
	if not ResetWall then return end
	ResetWall.Transparency = if IsVisible then 0 else 1
	ResetWall.CanCollide = IsVisible
	ResetWall.CanQuery = IsVisible
	ResetWall.CanTouch = IsVisible
end

local function ClearCrateArea()
	local RewardIds = {}
	for RewardId in Rewards do table.insert(RewardIds, RewardId) end
	for _, RewardId in RewardIds do RemoveReward(RewardId) end
	local Models = {}
	for Model in Crates do table.insert(Models, Model) end
	for _, Model in Models do
		local State = Crates[Model]
		Crates[Model] = nil
		Model:Destroy()
	end
end

local function IsPityBoundary(Info, BoundaryTime): boolean
	return Info.PityOnly == true and type(Info.PityInterval) == "number" and math.round(BoundaryTime) % Info.PityInterval == 0
end

local function SpawnConfiguredCrates(Infos)
	for _, Info in Infos do
		local Spawned = 0
		local Attempts = 0
		while Spawned < Info.MaximumActive and Attempts < Info.MaximumActive * 12 do
			Attempts += 1
			if CrateController.Spawn(Info, true) then Spawned += 1 end
			task.wait(CrateInfo.Reset.SpawnInterval)
		end
	end
end

local function SpawnPityCrate(Info)
	for _ = 1, 48 do
		if CrateController.Spawn(Info, true) then return end
		task.wait(CrateInfo.Reset.SpawnInterval)
	end
end

local function SpawnAllCrates(BoundaryTime)
	for _, Info in CrateInfo.GetPityCrates() do
		if IsPityBoundary(Info, BoundaryTime) then SpawnPityCrate(Info) end
	end
	SpawnConfiguredCrates(CrateInfo.GetRegularCrates())
end

local function ResetCrates(BoundaryTime)
	if IsResetting then return end
	IsResetting = true
	ResetGeneration += 1
	Network:fireAll("UpdateResetState", NextResetTime, true)
	SetResetWallVisible(true)
	local ResetStartedAt = Workspace:GetServerTimeNow()
	local Area = Workspace:FindFirstChild("CrateSpawnArea")
	if Area and Area:IsA("BasePart") then
		for _, Player in Players:GetPlayers() do
			if IsPlayerInCrateArea(Player, Area) then MuseumController.TeleportPlayerToMuseum(Player) end
		end
	end
	ClearCrateArea()
	GuidanceController.ResetTutorialCrates()
	SpawnAllCrates(BoundaryTime)
	local RemainingWallTime = CrateInfo.Reset.MinimumWallVisibleTime - (Workspace:GetServerTimeNow() - ResetStartedAt)
	if RemainingWallTime > 0 then task.wait(RemainingWallTime) end
	SetResetWallVisible(false)
	Network:fireAll("UpdateResetState", NextResetTime, false)
	IsResetting = false
end

local function GetNextAlignedTime(Interval, Now): number
	return (math.floor(Now / Interval) + 1) * Interval
end

local function CreatePityDisplay()
	local DisplayPart = Workspace:FindFirstChild(CrateInfo.PityDisplay.PartName)
	if not DisplayPart or not DisplayPart:IsA("BasePart") then return end
	local Existing = DisplayPart:FindFirstChild("CratePitySurface")
	if Existing then Existing:Destroy() end
	local Surface = Instance.new("SurfaceGui")
	Surface.Name = "CratePitySurface"
	Surface.Face = Enum.NormalId.Front
	Surface.LightInfluence = 0
	Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	Surface.PixelsPerStud = CrateInfo.PityDisplay.PixelsPerStud
	Surface.Parent = DisplayPart
	local Container = Instance.new("Frame")
	Container.Name = "Container"
	Container.BackgroundTransparency = 1
	Container.Position = UDim2.fromScale(0.06, 0.08)
	Container.Size = UDim2.fromScale(0.88, 0.84)
	Container.Parent = Surface
	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Vertical
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.Padding = UDim.new(0.025, 0)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Parent = Container
	for Index, Info in CrateInfo.GetPityCrates() do
		local Label = Instance.new("TextLabel")
		Label.Name = Info.Id
		Label.BackgroundTransparency = 1
		Label.FontFace = UIStyle.Font
		Label.LayoutOrder = Index
		Label.RichText = true
		Label.Size = UDim2.fromScale(1, 0.4)
		Label.TextColor3 = Info.DisplayColor or Color3.new(1, 1, 1)
		Label.TextScaled = true
		Label.Parent = Container
		local Stroke = Instance.new("UIStroke")
		Stroke.Color = Color3.new(0, 0, 0)
		Stroke.Thickness = 3
		Stroke.Parent = Label
		PityLabels[Info.Id] = Label
	end
end

local function UpdatePityDisplay()
	local Now = Workspace:GetServerTimeNow()
	for _, Info in CrateInfo.GetPityCrates() do
		local Label = PityLabels[Info.Id]
		if Label and Label.Parent then
			local Remaining = math.max(0, math.ceil(GetNextAlignedTime(Info.PityInterval, Now) - Now))
			local DisplayName = if Info.Id == "SecretCrate" then "SECRET" else `<font color="#FF3041">MYTHICAL</font>`
			Label.Text = `<b>{DisplayName}</b> Crate in <b>{FormatTime(Remaining)}</b>`
		end
	end
end

local function GetNextResetTime(Now): number
	local Interval = CrateInfo.Reset.Interval
	return (math.floor(Now / Interval) + 1) * Interval
end

local function StartResetSchedule()
	local Now = Workspace:GetServerTimeNow()
	local Interval = CrateInfo.Reset.Interval
	local PreviousBoundary = math.floor(Now / Interval) * Interval
	NextResetTime = PreviousBoundary + Interval
	Network:fireAll("UpdateResetState", NextResetTime, false)
	if Now - PreviousBoundary < CrateInfo.Reset.MinimumWallVisibleTime then
		ResetCrates(PreviousBoundary)
	else
		SpawnAllCrates(PreviousBoundary)
	end
	while true do
		Now = Workspace:GetServerTimeNow()
		while Now < NextResetTime do
			task.wait(math.min(1, NextResetTime - Now))
			Now = Workspace:GetServerTimeNow()
		end
		NextResetTime = GetNextResetTime(Now)
		Network:fireAll("UpdateResetState", NextResetTime, false)
		ResetCrates(NextResetTime - Interval)
	end
end

function CrateController.SetDataService(Service) DataService = Service end

function CrateController.GetRuntimeState(_, Player)
	local CrateStates = {}

	for Model, State in Crates do
		table.insert(CrateStates, {
			Model = Model,
			CrateId = State.Info.Id,
			Health = State.Health,
			MaximumHealth = State.Info.Health,
		})
	end

	return {
		Crates = CrateStates,
		IsResetting = IsResetting,
		NextResetTime = NextResetTime,
	}
end

function CrateController.Init()
	CrateFolder = Instance.new("Folder")
	CrateFolder.Name = "Crates"
	CrateFolder.Parent = Workspace
	RewardFolder = Instance.new("Folder")
	RewardFolder.Name = "CrateRewards"
	RewardFolder.Parent = Workspace
	local WallTemplate = ReplicatedStorage.Assets.Models.Map:FindFirstChild(CrateInfo.Reset.WallTemplateName)
	if WallTemplate and WallTemplate:IsA("BasePart") then
		ResetWall = WallTemplate:Clone()
		ResetWall.Name = "CrateResetWall"
		ResetWall.Anchored = true
		ResetWall.Parent = Workspace
		SetResetWallVisible(false)
	end
	Network = Networker.server.new("CrateController", CrateController, {
		CrateController.GetRuntimeState,
	})
	CreatePityDisplay()
	task.spawn(function()
		while RewardFolder.Parent do
			UpdateRewardDespawnTimers()
			task.wait(ItemInteractionConfig.WorldItemTimerUpdateInterval)
		end
	end)
	task.spawn(function()
		while true do UpdatePityDisplay(); task.wait(1) end
	end)
	task.spawn(StartResetSchedule)
end

return CrateController
