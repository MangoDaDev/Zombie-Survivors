local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryController = require(ServerStorage.Controllers.CarryController)
local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local CrateController = {}
local DataService
local Network
local CrateFolder: Folder
local RewardFolder: Folder
local Crates = {}
local Rewards = {}
local RandomGenerator = Random.new()

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
	Track.BackgroundColor3 = Color3.fromRGB(35, 39, 47)
	Track.BorderSizePixel = 0
	Track.Size = UDim2.fromScale(1, 1)
	Track.ClipsDescendants = true
	Track.Parent = Group
	local TrackCorner = Instance.new("UICorner")
	TrackCorner.CornerRadius = UDim.new(1, 0)
	TrackCorner.Parent = Track
	local TrackStroke = Instance.new("UIStroke")
	TrackStroke.Color = Color3.new(1, 1, 1)
	TrackStroke.Transparency = 0.15
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
	HealthLabel.Font = Enum.Font.GothamBold
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
			DirtRenderer.Add(Model, Reward.DirtCount, ItemInfo.DirtHP)
			ItemInfoBillboard(ItemInfo, Box, { Total = Reward.DirtCount, Remaining = Reward.DirtCount, Completed = false })
			Prompt.Enabled = true
		end)
	end)
	task.delay(Info.RevealLifetime, function() if Rewards[RewardId] == Reward then RemoveReward(RewardId) end end)
end

local function BreakCrate(State)
	if Crates[State.Model] ~= State then return end
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
	task.delay(State.Info.RespawnDelay, function() CrateController.Spawn(State.Info) end)
end

local function ReactToDamage(State, AttackerPosition)
	State.ReactionId += 1
	local ReactionId = State.ReactionId
	local Direction = State.BaseCFrame.Position - AttackerPosition
	local LocalDirection = State.BaseCFrame:VectorToObjectSpace(if Direction.Magnitude > 0 then Direction.Unit else Vector3.zAxis)
	local Kick = CFrame.Angles(math.rad(-LocalDirection.Z * 5), 0, math.rad(LocalDirection.X * 5))
	task.spawn(function()
		for Index = 1, 6 do
			if Crates[State.Model] ~= State or State.ReactionId ~= ReactionId then return end
			local Alpha = Index / 6
			local Weight = math.sin(Alpha * math.pi)
			State.Model:PivotTo(State.BaseCFrame:Lerp(State.BaseCFrame * Kick, Weight))
			task.wait()
		end
		if Crates[State.Model] == State then State.Model:PivotTo(State.BaseCFrame) end
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
	ReactToDamage(State, RootPart.Position)
	task.delay(State.Info.HealthBarHideDelay, function()
		if Crates[Model] == State and State.VisibilityId == VisibilityId then
			TweenService:Create(State.HealthGroup, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		end
	end)
	if State.Health <= 0 then BreakCrate(State) end
	return true
end

function CrateController.Spawn(Info)
	if not CrateFolder or #CrateFolder:GetChildren() >= Info.MaximumActive then return end
	local SpawnCFrame = GetSpawnCFrame(Info)
	local TemplateFolder = ReplicatedStorage.Assets.Models:FindFirstChild(Info.TemplateFolderName)
	local Template = TemplateFolder and TemplateFolder:FindFirstChild(Info.TemplateName)
	if not SpawnCFrame or not Template or not Template:IsA("Model") then return end
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
		ReactionId = 0,
	}
end

function CrateController.SetDataService(Service) DataService = Service end
function CrateController:Init()
	CrateFolder = Instance.new("Folder")
	CrateFolder.Name = "Crates"
	CrateFolder.Parent = Workspace
	RewardFolder = Instance.new("Folder")
	RewardFolder.Name = "CrateRewards"
	RewardFolder.Parent = Workspace
	Network = Networker.server.new("CrateController", self)
	for _, Info in CrateInfo do
		for Index = 1, Info.MaximumActive do
			task.delay((Index - 1) * 0.08, function() CrateController.Spawn(Info) end)
		end
	end
end

return CrateController
