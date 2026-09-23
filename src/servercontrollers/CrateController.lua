local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local CarryController = require(ServerStorage.Controllers.CarryController)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local FormatTime = require(ReplicatedStorage.Modules.Math.FormatTime)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemDespawnCountdown = require(ReplicatedStorage.Modules.UI.ItemDespawnCountdown)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local Networker = require(ReplicatedStorage.Packages.networker)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local MapAssets = ReplicatedStorage.Assets.Models.Map
local CrateController = {}
local DataService
local Network
local CrateFolder: Folder
local RewardFolder: Folder
local Crates = {}
local Rewards = {}
local ActiveOnboardingRewards: { [Player]: { [string]: boolean } } = {}
local PityLabels = {}
local RandomGenerator = Random.new()
local IsResetting = false
local NextResetTime
local ClaimFeedbackDistancePadding = 8

local function GetItemInfo(ItemId)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
end

local function GetRewardItemInfo(Player: Player, Info, Luck: number)
	local GuaranteedReward, RewardKind, GuaranteedIndex = GuidanceController.GetOnboardingReward(Player)
	if GuaranteedReward then
		local GuaranteedItemInfo = GuaranteedReward and GetItemInfo(GuaranteedReward.ItemId)
		if GuaranteedItemInfo then
			local RestorationSteps = GuaranteedReward.RestorationSteps
			return GuaranteedItemInfo, if RestorationSteps then table.clone(RestorationSteps) else nil,
				RewardKind, GuaranteedIndex
		end
	end
	return CrateInfo.GetRandomItem(ItemsInfo, Info, RandomGenerator, Luck)
end

local function GetRevealDuration(Info, IsFirstRoll: boolean?): number
	local SwitchCount = if IsFirstRoll then Info.FirstRollPreviewSwitchCount else Info.PreviewSwitchCount
	local StartDelay = if IsFirstRoll then Info.FirstRollPreviewStartDelay else Info.PreviewStartDelay
	local EndDelay = if IsFirstRoll then Info.FirstRollPreviewEndDelay else Info.PreviewEndDelay
	local Duration = 0
	for Index = 1, SwitchCount do
		local Alpha = if SwitchCount > 1 then (Index - 1) / (SwitchCount - 1) else 1
		Duration += StartDelay + (EndDelay - StartDelay) * Alpha * Alpha
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
	local Area = MapAssets:FindFirstChild("CrateSpawnArea")
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

local function SendClaimFeedback(Player, Status, ItemName)
	Network:fire(Player, "ClaimFeedback", Status, ItemName)
end

local function NotifyNearbyPlayers(Reward, Status, ExcludedPlayer)
	local ItemInfo = GetItemInfo(Reward.ItemId)
	if not ItemInfo or not Reward.Model or not Reward.Model.Parent then return end
	local Position = Reward.Model:GetPivot().Position
	local MaximumDistance = Reward.Info.ClaimDistance + ClaimFeedbackDistancePadding
	for _, Player in Players:GetPlayers() do
		if Player == ExcludedPlayer then continue end
		local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if RootPart and RootPart:IsA("BasePart") and (RootPart.Position - Position).Magnitude <= MaximumDistance then
			SendClaimFeedback(Player, Status, ItemInfo.Name)
		end
	end
end

local function RemoveReward(RewardId, Reason, ClaimingPlayer)
	local Reward = Rewards[RewardId]
	if not Reward then return end
	if Reward.Owner and Reward.Model then
		GuidanceController.MarkTutorialRewardRemoved(Reward.Owner, Reward.Model)
	end
	local OwnerRewards = Reward.Owner and ActiveOnboardingRewards[Reward.Owner]
	if OwnerRewards then
		OwnerRewards[RewardId] = nil
		if not next(OwnerRewards) then ActiveOnboardingRewards[Reward.Owner] = nil end
	end
	if Reason == "Claimed" then
		NotifyNearbyPlayers(Reward, "ClaimedByAnother", ClaimingPlayer)
	elseif Reason == "Expired" then
		NotifyNearbyPlayers(Reward, "Expired")
	end
	Rewards[RewardId] = nil
	if Reward.Connection then Reward.Connection:Disconnect() end
	if Reward.Model then Reward.Model:Destroy() end
	Network:fireAll("RemoveReveal", RewardId)
end

local function ClaimReward(RewardId, Player)
	local Reward = Rewards[RewardId]
	if not Reward then return end
	local ItemInfo = GetItemInfo(Reward.ItemId)
	if not ItemInfo then return end
	if Reward.Claimed then SendClaimFeedback(Player, "ClaimedByAnother", ItemInfo.Name); return end
	if Reward.OnboardingRewardKind and Reward.Owner ~= Player then
		SendClaimFeedback(Player, "Unavailable", ItemInfo.Name)
		return
	end
	if Workspace:GetServerTimeNow() < Reward.AvailableAt then SendClaimFeedback(Player, "NotReady", ItemInfo.Name); return end
	if PlayerStateController.Get(Player, "IsFixing", false) == true then SendClaimFeedback(Player, "Fixing", ItemInfo.Name); return end
	if PlayerStateController.Get(Player, "IsCarryingItem", false) == true then SendClaimFeedback(Player, "AlreadyCarrying", ItemInfo.Name); return end
	if not CarryController.CanCarry(Player) then SendClaimFeedback(Player, "Unavailable", ItemInfo.Name); return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local OnboardingRewardKind = if Reward.Owner == Player then Reward.OnboardingRewardKind else nil
	if not RootPart or not RootPart:IsA("BasePart") then SendClaimFeedback(Player, "Unavailable", ItemInfo.Name); return end
	if (RootPart.Position - Reward.Model:GetPivot().Position).Magnitude > Reward.Info.ClaimDistance then return end
	-- Revealed crate items are free; claiming is guarded only by ownership/state/range checks.
	Reward.Claimed = true
	-- Free crate claims must not play the cash/purchase pickup sound.
	if not CarryController.StartCarrying(Player, Reward.ItemId, Reward.DirtCount, nil, Reward.RestorationSteps, false) then
		Reward.Claimed = false
		SendClaimFeedback(Player, "Unavailable", ItemInfo.Name)
		return
	end
	GuidanceController.MarkOnboardingRewardReceived(Player, OnboardingRewardKind, Reward.GuaranteedIndex)
	AnalyticsController.TrackItemPurchased(Player, Reward.ItemId, "Crate", Reward.AnalyticsSessionId)
	SendClaimFeedback(Player, "Success", ItemInfo.Name)
	RemoveReward(RewardId, "Claimed", Player)
end

local function CreateReward(State, Player: Player, PredictionId, AnalyticsSessionId)
	local Info = State.Info
	local HasRolledCrate = DataService:get(Player, "HasRolledCrate") == true
	local IsFirstRoll = not HasRolledCrate and DataService:get(Player, "GuaranteedDropCount") == 0
	local ItemInfo, RestorationSteps, OnboardingRewardKind, GuaranteedIndex = GetRewardItemInfo(Player, Info, State.Luck)
	if not ItemInfo then return end
	-- Roll once per reward so cheaper restoration tools are more common while each physical copy keeps its own mix.
	if not RestorationSteps then RestorationSteps = CleaningConfig.RollRestorationSteps(ItemInfo, RandomGenerator) end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	Model.Name = `CrateReward_{ItemInfo.Name}`
	local DirtCount = DirtRenderer.GetSuggestedCount(Template)
	local FixingState = {
		Total = DirtCount,
		Remaining = DirtCount,
		Completed = false,
		RestorationSteps = RestorationSteps,
	}
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
	Prompt.Name = "ClaimPrompt"
	Prompt.ActionText = "Claim"
	Prompt.ObjectText = "???"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = Info.ClaimDistance - 3
	Prompt.RequiresLineOfSight = false
	Prompt.Enabled = false
	Prompt.Parent = Box
	local RewardId = HttpService:GenerateGUID(false)
	local RevealDuration = GetRevealDuration(Info, IsFirstRoll)
	-- Persist this before broadcasting so only the player's first crate uses the extended rare preview roll.
	if not HasRolledCrate then DataService:set(Player, "HasRolledCrate", true) end
	local Reward = {
		Id = RewardId,
		Owner = Player,
		Info = Info,
		ItemId = ItemInfo.Id,
		DirtCount = DirtCount,
		FixingState = FixingState,
		Model = Model,
		Prompt = Prompt,
		AvailableAt = math.huge,
		ExpiresAt = math.huge,
		Revealed = false,
		Claimed = false,
		AnalyticsSessionId = AnalyticsSessionId,
		RestorationSteps = RestorationSteps,
		OnboardingRewardKind = OnboardingRewardKind,
		GuaranteedIndex = GuaranteedIndex,
		RevealTransparencies = RevealTransparencies,
	}
	Rewards[RewardId] = Reward
	GuidanceController.MarkTutorialRewardCreated(Player, State.Model, Model)
	-- Breaking another crate must not despawn this reward; each drop keeps its own expiry.
	if OnboardingRewardKind then
		local OwnerRewards = ActiveOnboardingRewards[Player]
		if not OwnerRewards then
			OwnerRewards = {}
			ActiveOnboardingRewards[Player] = OwnerRewards
		end
		OwnerRewards[RewardId] = true
	end
	Reward.Connection = Prompt.Triggered:Connect(function(Player)
		if Rewards[RewardId] ~= Reward or Reward.Interacting then return end
		Reward.Interacting = true
		Prompt.Enabled = false
		ClaimReward(RewardId, Player)
		if Rewards[RewardId] == Reward then
			Reward.Interacting = false
			Prompt.Enabled = Workspace:GetServerTimeNow() >= Reward.AvailableAt
		end
	end)
	Network:fireAll("StartReveal", RewardId, ItemInfo.Id, GroundCFrame, Info.Id, Player, PredictionId, Model, DirtCount, RestorationSteps, IsFirstRoll)
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
			-- Start exactly one 30-second lifetime only after the authoritative reveal has finished.
			Reward.AvailableAt = Workspace:GetServerTimeNow()
			Reward.ExpiresAt = Reward.AvailableAt + ItemInteractionConfig.CrateRewardDespawnDuration
			Reward.Revealed = true
			Prompt.Enabled = true
			AnalyticsController.TrackItemRevealed(Player, ItemInfo.Id, Info, AnalyticsSessionId)
		end)
	end)
end

local function UpdateRewardDespawnTimers()
	local Now = Workspace:GetServerTimeNow()
	local ExpiredRewardIds = {}
	for RewardId, Reward in Rewards do
		if not Reward.Revealed or Reward.Claimed or Reward.Interacting then continue end
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
	local AnalyticsSessionId = AnalyticsController.TrackCrateBroken(Player, State.Model, State.Info)
	Crates[State.Model] = nil
	CreateReward(State, Player, PredictionId, AnalyticsSessionId)
	State.Model:Destroy()
end

function CrateController.DamageCrate(Player, Model, Damage, PredictionId): (boolean, boolean)
	local State = Crates[Model]
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not State or not RootPart or not RootPart:IsA("BasePart") or type(Damage) ~= "number" then return false, false end
	-- Every bat can damage every crate; higher-tier bats only reduce the hits needed.
	AnalyticsController.TrackCrateDiscovered(Player, State.Model, State.Info)
	State.Health = math.max(0, State.Health - math.clamp(Damage, 0, State.Info.Health))
	Network:fireAll("UpdateCrateHealth", State.Model, State.Info.Id, State.Health, State.Info.Health)
	if State.Health <= 0 then BreakCrate(State, Player, PredictionId) end
	return true, true
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
	local Scale = CrateInfo.RollScale(Info, RandomGenerator)
	local Luck = CrateInfo.GetScaleLuck(Info, Scale)
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
	CreateHealthBar(Model, Info)
	Crates[Model] = {
		Model = Model,
		Info = Info,
		Health = Info.Health,
		BaseCFrame = Model:GetPivot(),
		GroundCFrame = GroundCFrame,
		Luck = Luck,
		Scale = Scale,
		YRotation = YRotation,
	}
	Network:fireAll("UpdateCrateHealth", Model, Info.Id, Info.Health, Info.Health)
	return true
end

local function ClearCrates()
	-- Reset only crates; spawned rewards keep their existing despawn deadlines.
	local Models = {}
	for Model in Crates do table.insert(Models, Model) end
	for _, Model in Models do
		local State = Crates[Model]
		Crates[Model] = nil
		Model:Destroy()
	end
end

local function IsPityBoundary(Info, BoundaryTime): boolean
	return Info.PityOnly == true and type(Info.PityInterval) == "number" and BoundaryTime % Info.PityInterval == 0
end

local function SpawnConfiguredCrates(Infos)
	for _, Info in Infos do
		local Spawned = 0
		local Attempts = 0
		while Spawned < Info.MaximumActive and Attempts < Info.MaximumActive * 12 do
			Attempts += 1
			if CrateController.Spawn(Info, true) then Spawned += 1 end
			-- Generate small batches quickly while still yielding often enough to avoid a frame hitch.
			if Attempts % CrateInfo.Reset.SpawnBatchSize == 0 then task.wait(CrateInfo.Reset.SpawnInterval) end
		end
	end
end

local function SpawnPityCrate(Info)
	for Attempt = 1, 48 do
		if CrateController.Spawn(Info, true) then return end
		if Attempt % CrateInfo.Reset.SpawnBatchSize == 0 then task.wait(CrateInfo.Reset.SpawnInterval) end
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
	Network:fireAll("UpdateResetState", NextResetTime, true)
	-- Reset in place: players and already-revealed rewards remain untouched while only crates replenish.
	ClearCrates()
	GuidanceController.ResetTutorialCrates()
	SpawnAllCrates(BoundaryTime)
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
	local Now = os.time()
	for _, Info in CrateInfo.GetPityCrates() do
		local Label = PityLabels[Info.Id]
		if Label and Label.Parent then
			local Remaining = math.max(0, math.ceil(GetNextAlignedTime(Info.PityInterval, Now) - Now))
			local DisplayName = if Info.Id == "SecretCrate" then "SECRET" else `<font color="#FF3041">MYTHICAL</font>`
			Label.Text = `<b>{DisplayName}</b>: <b>{FormatTime(Remaining)}</b>`
		end
	end
end

local function GetNextResetTime(Now): number
	local Interval = CrateInfo.Reset.Interval
	return (math.floor(Now / Interval) + 1) * Interval
end

local function StartResetSchedule()
	local Now = os.time()
	local Interval = CrateInfo.Reset.Interval
	local PreviousBoundary = math.floor(Now / Interval) * Interval
	NextResetTime = PreviousBoundary + Interval
	Network:fireAll("UpdateResetState", NextResetTime, false)
	SpawnAllCrates(PreviousBoundary)
	while true do
		Now = os.time()
		while Now < NextResetTime do
			task.wait(math.min(1, NextResetTime - Now))
			Now = os.time()
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

function CrateController.OnPlayerRemoving(Player: Player)
	local OwnerRewards = ActiveOnboardingRewards[Player]
	if OwnerRewards then
		local RewardId = next(OwnerRewards)
		while RewardId do
			RemoveReward(RewardId, "PlayerLeft")
			RewardId = next(OwnerRewards)
		end
	end
	ActiveOnboardingRewards[Player] = nil
end

return CrateController
