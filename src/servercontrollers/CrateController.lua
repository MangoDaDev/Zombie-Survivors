local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryController = require(ServerStorage.Controllers.CarryController)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local FormatTime = require(ReplicatedStorage.Modules.Math.FormatTime)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
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

local function GetItemInfo(ItemId)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Id == ItemId then return ItemInfo end
	end
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
		local Z = RandomGenerator:NextNumber(-Area.Size.Z / 2 + Info.SpawnPadding, Area.Size.Z / 2 - Info.SpawnPadding)
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

local function CreateBreakShards(State)
	local Origin = State.Model:GetPivot().Position
	for Index = 1, 9 do
		local Shard = Instance.new("Part")
		Shard.Name = "CrateShard"
		Shard.Size = Vector3.new(0.18, 0.18, RandomGenerator:NextNumber(0.35, 0.7)) * State.Scale
		Shard.Color = Color3.fromRGB(111, 74, 47)
		Shard.Material = Enum.Material.Wood
		Shard.CanCollide = false
		Shard.CFrame = CFrame.new(Origin) * CFrame.Angles(RandomGenerator:NextNumber(0, 6), RandomGenerator:NextNumber(0, 6), RandomGenerator:NextNumber(0, 6))
		Shard.Parent = Workspace
		Shard.AssemblyLinearVelocity = Vector3.new(RandomGenerator:NextNumber(-13, 13), RandomGenerator:NextNumber(10, 20), RandomGenerator:NextNumber(-13, 13))
		Shard.AssemblyAngularVelocity = Vector3.new(RandomGenerator:NextNumber(-12, 12), RandomGenerator:NextNumber(-12, 12), RandomGenerator:NextNumber(-12, 12))
		Debris:AddItem(Shard, 1.4)
	end
end

local function RemoveReward(RewardId)
	local Reward = Rewards[RewardId]
	if not Reward then return end
	Rewards[RewardId] = nil
	if Reward.Connection then Reward.Connection:Disconnect() end
	if Reward.Model then Reward.Model:Destroy() end
	Network:fireAll("RemoveReveal", RewardId)
end

local function PurchaseReward(RewardId, Player)
	local Reward = Rewards[RewardId]
	if not Reward or Reward.Purchased or Workspace:GetServerTimeNow() < Reward.AvailableAt or not CarryController.CanCarry(Player) then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local ItemInfo = GetItemInfo(Reward.ItemId)
	local Cash = DataService:get(Player, "Cash")
	if not RootPart or not RootPart:IsA("BasePart") or not ItemInfo or type(Cash) ~= "number" or Cash < ItemInfo.Price then return end
	if (RootPart.Position - Reward.Model:GetPivot().Position).Magnitude > Reward.Info.PurchaseDistance then return end
	Reward.Purchased = true
	if not CarryController.StartCarrying(Player, Reward.ItemId, Reward.DirtCount) then Reward.Purchased = false; return end
	DataService:set(Player, "Cash", Cash - ItemInfo.Price)
	RemoveReward(RewardId)
end

local function CreateReward(State)
	local Info = State.Info
	local ItemInfo = GetRandomFromWeightedTable.GetRandomFromWeightedTable(ItemsInfo, "ChanceWeight", nil, Info.ActualLootLuck)
	if not ItemInfo then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	Model.Name = `CrateReward_{ItemInfo.Name}`
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			Part:SetAttribute("RevealTransparency", Part.Transparency)
			Part.Transparency = 1
		end
	end
	local GroundCFrame = State.GroundCFrame
	SetModelOnGround(Model, GroundCFrame)
	Model.Parent = RewardFolder
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "PurchasePrompt"
	Prompt.ActionText = `Buy ${ItemInfo.Price}`
	Prompt.ObjectText = ItemInfo.Name
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
		DirtCount = DirtRenderer.GetSuggestedCount(Template),
		Model = Model,
		Prompt = Prompt,
		AvailableAt = Workspace:GetServerTimeNow() + RevealDuration + Info.RevealFadeTime,
		Purchased = false,
	}
	Rewards[RewardId] = Reward
	Reward.Connection = Prompt.Triggered:Connect(function(Player) PurchaseReward(RewardId, Player) end)
	Network:fireAll("StartReveal", RewardId, ItemInfo.Id, GroundCFrame, Info.Id)
	task.delay(RevealDuration, function()
		if Rewards[RewardId] ~= Reward then return end
		for _, Part in Model:GetDescendants() do
			if Part:IsA("BasePart") then
				local RevealTransparency = Part:GetAttribute("RevealTransparency") or 0
				TweenService:Create(Part, TweenInfo.new(Info.RevealFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = RevealTransparency,
				}):Play()
			end
		end
		task.delay(Info.RevealFadeTime, function()
			if Rewards[RewardId] ~= Reward then return end
			for _, Part in Model:GetDescendants() do
				if Part:IsA("BasePart") then Part:SetAttribute("RevealTransparency", nil) end
			end
			local FixingState = { Total = Reward.DirtCount, Remaining = Reward.DirtCount, Completed = false }
			RestorationVisuals.Apply(Model, ItemInfo, FixingState)
			ItemInfoBillboard(ItemInfo, Box, FixingState)
			Prompt.Enabled = true
		end)
	end)
	task.delay(Info.RevealLifetime, function() if Rewards[RewardId] == Reward then RemoveReward(RewardId) end end)
end

local function BreakCrate(State)
	if Crates[State.Model] ~= State then return end
	local BreakGeneration = ResetGeneration
	Crates[State.Model] = nil
	local SoundName = State.Info.BreakSoundNames[RandomGenerator:NextInteger(1, #State.Info.BreakSoundNames)]
	local SoundAnchor = Instance.new("Part")
	SoundAnchor.Name = "CrateBreakSound"
	SoundAnchor.Anchored = true
	SoundAnchor.CanCollide = false
	SoundAnchor.CanQuery = false
	SoundAnchor.CanTouch = false
	SoundAnchor.CFrame = CFrame.new(State.BaseCFrame.Position)
	SoundAnchor.Size = Vector3.one * 0.1
	SoundAnchor.Transparency = 1
	SoundAnchor.Parent = Workspace
	Sounds.Play(SoundName, SoundAnchor, 90)
	Debris:AddItem(SoundAnchor, 5)
	CreateBreakShards(State)
	CreateReward(State)
	State.Model:Destroy()
	task.delay(State.Info.RespawnDelay, function()
		if State.Info.Respawns ~= false and ResetGeneration == BreakGeneration then CrateController.Spawn(State.Info) end
	end)
end

function CrateController.DamageCrate(Player, Model, Damage): boolean
	local State = Crates[Model]
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not State or not RootPart or not RootPart:IsA("BasePart") or type(Damage) ~= "number" then return false end
	State.Health = math.max(0, State.Health - math.clamp(Damage, 0, State.Info.Health))
	State.Model:SetAttribute("Health", State.Health)
	State.VisibilityId += 1
	local VisibilityId = State.VisibilityId
	TweenService:Create(State.HealthGroup, TweenInfo.new(0.08), { GroupTransparency = 0 }):Play()
	TweenService:Create(State.HealthFill, TweenInfo.new(State.Info.HealthBarTweenTime, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(State.Health / State.Info.Health, 1) }):Play()
	State.HealthLabel.Text = `{math.ceil(State.Health)}/{State.Info.Health}`
	Sounds.Play(State.Info.DamageSoundName, State.Model.PrimaryPart, 80)
	task.delay(State.Info.HealthBarHideDelay, function()
		if Crates[Model] == State and State.VisibilityId == VisibilityId then
			TweenService:Create(State.HealthGroup, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		end
	end)
	if State.Health <= 0 then BreakCrate(State) end
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
	Model:SetAttribute("CrateId", Info.Id)
	Model:SetAttribute("Health", Info.Health)
	Model:SetAttribute("MaxHealth", Info.Health)
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
	Workspace:SetAttribute("CratesResetting", true)
	SetResetWallVisible(true)
	local ResetStartedAt = Workspace:GetServerTimeNow()
	local Area = Workspace:FindFirstChild("CrateSpawnArea")
	if Area and Area:IsA("BasePart") then
		for _, Player in Players:GetPlayers() do
			if IsPlayerInCrateArea(Player, Area) then MuseumController.TeleportPlayerToMuseum(Player) end
		end
	end
	ClearCrateArea()
	SpawnAllCrates(BoundaryTime)
	local RemainingWallTime = CrateInfo.Reset.MinimumWallVisibleTime - (Workspace:GetServerTimeNow() - ResetStartedAt)
	if RemainingWallTime > 0 then task.wait(RemainingWallTime) end
	SetResetWallVisible(false)
	Workspace:SetAttribute("CratesResetting", false)
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
			local DisplayName = if Info.Id == "SecretCrate"
				then '<font color="#FFFFFF">S</font><font color="#25252B">E</font><font color="#FFFFFF">C</font><font color="#6F6F78">R</font><font color="#FFFFFF">E</font><font color="#151518">T</font>'
				else `<font color="#FF3041">MYTHICAL</font>`
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
	local NextResetTime = PreviousBoundary + Interval
	Workspace:SetAttribute("NextCrateResetTime", NextResetTime)
	Workspace:SetAttribute("CratesResetting", false)
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
		Workspace:SetAttribute("NextCrateResetTime", NextResetTime)
		ResetCrates(NextResetTime - Interval)
	end
end

function CrateController.SetDataService(Service) DataService = Service end
function CrateController:Init()
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
	Network = Networker.server.new("CrateController", self)
	CreatePityDisplay()
	task.spawn(function()
		while true do UpdatePityDisplay(); task.wait(1) end
	end)
	task.spawn(StartResetSchedule)
end

return CrateController
