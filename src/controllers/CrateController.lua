local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local CrateRuntime = require(ReplicatedStorage.Modules.Game.CrateRuntime)
local GuidanceController = require(ReplicatedStorage.Controllers.GuidanceController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local MultiplyNumberSequence = require(ReplicatedStorage.Modules.Math.MultiplyNumberSequence)
local Networker = require(ReplicatedStorage.Packages.networker)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local RestorationVisuals = require(ReplicatedStorage.Modules.Game.RestorationVisuals)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local CrateController = {}
local RevealFolder: Folder
local RevealGui: ScreenGui
local Reveals = {}
local PredictedReveals = {}
local ScreenEffectId = 0
local RandomGenerator = Random.new()
local LocalPlayer = Players.LocalPlayer

local PinwheelTemplates = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
	Secret = "Omniscient",
}

local PurchaseFeedbackMessages = {
	AlreadyCarrying = function()
		return "Deliver Item First"
	end,
	Expired = function()
		return "Reward Expired"
	end,
	Fixing = function()
		return "Finish Cleaning"
	end,
	NotEnoughCash = function(_, Detail)
		return `Need {FormatNumber(math.max(0, math.ceil(Detail or 0))) or "0"} More`
	end,
	NotReady = function()
		return "Reveal In Progress"
	end,
	PurchasedByAnother = function()
		return "Already Purchased"
	end,
	Success = function()
		return "Item Purchased"
	end,
	Unavailable = function()
		return "Item Unavailable"
	end,
}

local function GetCrateInfo(CrateId)
	for _, Info in CrateInfo.Crates do
		if Info.Id == CrateId then return Info end
	end
end

local function GetItemInfo(ItemId)
	for _, Info in ItemsInfo do
		if Info.Id == ItemId then return Info end
	end
end

local function SetModelOnGround(Model, GroundCFrame)
	Model:PivotTo(GroundCFrame)
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local BottomY = BoundingCFrame.Position.Y - BoundingSize.Y / 2
	Model:PivotTo(Model:GetPivot() + Vector3.new(0, GroundCFrame.Position.Y - BottomY, 0))
end

local function CreatePreview(ItemInfo, GroundCFrame, Parent): Model?
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(ItemInfo.AssetName)
	if not Template or not Template:IsA("Model") then return nil end
	local Model = Template:Clone()
	Model.Name = `Preview_{ItemInfo.Name}`
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
		end
	end
	SetModelOnGround(Model, GroundCFrame)
	Model.Parent = Parent
	local Silhouette = Instance.new("Highlight")
	Silhouette.Name = "Silhouette"
	Silhouette.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Silhouette.FillColor = Color3.new(0, 0, 0)
	Silhouette.FillTransparency = 0
	Silhouette.OutlineColor = Color3.new(1, 1, 1)
	Silhouette.OutlineTransparency = 0
	Silhouette.Parent = Model
	return Model
end

local function PulseModel(Model, Duration)
	local ScaleValue = Instance.new("NumberValue")
	ScaleValue.Value = 0.9
	local Connection = ScaleValue.Changed:Connect(function(Value)
		if Model.Parent then Model:ScaleTo(Value) end
	end)
	TweenService:Create(
		ScaleValue,
		TweenInfo.new(math.max(Duration * 0.8, 0.04), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1.08 }
	):Play()
	task.delay(Duration, function()
		Connection:Disconnect()
		ScaleValue:Destroy()
	end)
end

local function PlayTick(Info, Model, Index)
	local Parent = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
	if not Parent then return end
	local Sound = Sounds.Play(Info.RevealTickSoundName, Parent, 70)
	if Sound then
		local Alpha = Index / Info.PreviewSwitchCount
		Sound.PlaybackSpeed = 0.9 + Alpha * 0.45
		Sound.Volume *= 0.65 + Alpha * 0.35
	end
end

local function CreateRevealBurst(Position, Config)
	local BurstDuration = 0.45 + Config.RevealEffectDuration * 0.18
	for Index = 1, Config.ParticleCount do
		local Particle = Instance.new("Part")
		Particle.Name = "RevealParticle"
		Particle.Anchored = true
		Particle.CanCollide = false
		Particle.CanQuery = false
		Particle.CanTouch = false
		Particle.Material = Enum.Material.Neon
		Particle.Color = if Index % 3 == 0 then Color3.new(1, 1, 1) else Config.Color
		Particle.Size = Vector3.one * RandomGenerator:NextNumber(0.07, 0.14) * Config.Intensity
		Particle.Position = Position
		Particle.Parent = RevealFolder
		local Direction = Vector3.new(RandomGenerator:NextNumber(-1, 1), RandomGenerator:NextNumber(0.2, 1), RandomGenerator:NextNumber(-1, 1)).Unit
		TweenService:Create(
			Particle,
			TweenInfo.new(BurstDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = Position + Direction * RandomGenerator:NextNumber(2, 4) * Config.Intensity, Transparency = 1, Size = Vector3.zero }
		):Play()
		Debris:AddItem(Particle, BurstDuration + 0.1)
	end
end

local function PlayScreenReveal(Position, Config)
	ScreenEffectId += 1
	local EffectId = ScreenEffectId
	RevealGui:ClearAllChildren()

	local Camera = Workspace.CurrentCamera
	local ViewportPosition, IsVisible = Camera:WorldToViewportPoint(Position)
	local Origin = if IsVisible
		then Vector2.new(ViewportPosition.X, ViewportPosition.Y)
		else Camera.ViewportSize / 2
	local SparkleDuration = 0.35 + Config.RevealEffectDuration * 0.22
	local ScreenIntensity = Config.Intensity ^ 1.15

	local Vignette = Instance.new("ImageLabel")
	Vignette.Name = "RarityVignette"
	Vignette.BackgroundTransparency = 1
	Vignette.Image = Images.Vignette
	Vignette.ImageColor3 = Config.Color
	Vignette.ImageTransparency = 1
	Vignette.Size = UDim2.fromScale(1, 1)
	Vignette.ZIndex = 1
	Vignette.Parent = RevealGui

	local Flash = Instance.new("Frame")
	Flash.Name = "RevealFlash"
	Flash.BackgroundColor3 = Config.Color
	Flash.BackgroundTransparency = 1 - Config.FlashStrength
	Flash.BorderSizePixel = 0
	Flash.Size = UDim2.fromScale(1, 1)
	Flash.ZIndex = 2
	Flash.Parent = RevealGui

	TweenService:Create(Vignette, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1 - Config.VignetteOpacity,
	}):Play()
	TweenService:Create(Flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	for Index = 1, Config.SparkleCount do
		local Sparkle = Instance.new("ImageLabel")
		Sparkle.Name = "RevealSparkle"
		Sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		Sparkle.BackgroundTransparency = 1
		Sparkle.Image = Images.Sparkle
		Sparkle.ImageColor3 = if Index % 4 == 0 then Color3.new(1, 1, 1) else Config.Color
		Sparkle.ImageTransparency = RandomGenerator:NextNumber(0, 0.15)
		Sparkle.Position = UDim2.fromOffset(Origin.X, Origin.Y)
		Sparkle.Rotation = RandomGenerator:NextNumber(-180, 180)
		local Size = RandomGenerator:NextNumber(12, 25) * ScreenIntensity
		Sparkle.Size = UDim2.fromOffset(Size, Size)
		Sparkle.ZIndex = 3
		Sparkle.Parent = RevealGui
		local Angle = RandomGenerator:NextNumber(0, math.pi * 2)
		local Distance = RandomGenerator:NextNumber(55, 145) * ScreenIntensity
		local Target = Origin + Vector2.new(math.cos(Angle), math.sin(Angle)) * Distance
		TweenService:Create(
			Sparkle,
			TweenInfo.new(SparkleDuration * RandomGenerator:NextNumber(0.8, 1.2), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				ImageTransparency = 1,
				Position = UDim2.fromOffset(Target.X, Target.Y),
				Rotation = Sparkle.Rotation + RandomGenerator:NextNumber(-100, 100),
				Size = UDim2.fromOffset(Size * 0.35, Size * 0.35),
			}
		):Play()
		Debris:AddItem(Sparkle, SparkleDuration * 1.25)
	end

	task.delay(Config.RevealEffectDuration * 0.8, function()
		if EffectId ~= ScreenEffectId or not Vignette.Parent then return end
		local FadeDuration = math.max(0.3, Config.RevealEffectDuration * 0.2)
		TweenService:Create(Vignette, TweenInfo.new(FadeDuration, Enum.EasingStyle.Quad), { ImageTransparency = 1 }):Play()
		Debris:AddItem(Vignette, FadeDuration + 0.05)
		Debris:AddItem(Flash, FadeDuration + 0.05)
	end)
end

local function CreateRarityEffect(Model: Model, Rarity: string)
	local Config = RarityInfo.Get(Rarity)
	local PinwheelFolder = ReplicatedStorage.Assets.VFX:FindFirstChild("RarityPinwheels")
	local TemplateName = PinwheelTemplates[Rarity]
	local Template = PinwheelFolder and TemplateName and PinwheelFolder:FindFirstChild(TemplateName)
	if not Template or not Template:IsA("Attachment") then return end
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local Camera = Workspace.CurrentCamera
	local CameraOffset = Camera.CFrame.Position - BoundingCFrame.Position
	local BehindDirection = if CameraOffset.Magnitude > 0.01 then -CameraOffset.Unit else Camera.CFrame.LookVector
	local MaximumSize = math.max(BoundingSize.X, BoundingSize.Y, BoundingSize.Z)
	local Anchor = Instance.new("Part")
	Anchor.Name = `RarityEffect_{Rarity}`
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanQuery = false
	Anchor.CanTouch = false
	Anchor.Size = Vector3.one * 0.05
	Anchor.Transparency = 1
	Anchor.Position = BoundingCFrame.Position + BehindDirection * (math.max(BoundingSize.X, BoundingSize.Z) * 0.35 + 0.35)
	Anchor.Parent = RevealFolder
	local Effect = Template:Clone()
	Effect.Parent = Anchor
	local SizeScale = math.clamp(MaximumSize / 3, 1, 3) * Config.PinwheelIntensity
	local MaximumLifetime = 0
	for _, Emitter in Effect:GetDescendants() do
		if not Emitter:IsA("ParticleEmitter") then continue end
		Emitter.Size = MultiplyNumberSequence(Emitter.Size, SizeScale)
		Emitter.Color = ColorSequence.new(Config.Color)
		Emitter.LightEmission = math.clamp(Emitter.LightEmission * Config.PinwheelIntensity, 0, 1)
		Emitter.Rate *= Config.PinwheelIntensity
		Emitter.Enabled = true
		Emitter:Emit(math.max(1, math.floor(Config.PinwheelIntensity + 0.5)))
		MaximumLifetime = math.max(MaximumLifetime, Emitter.Lifetime.Max)
	end
	local Duration = Config.RevealEffectDuration or 1
	task.delay(Duration, function()
		if not Effect.Parent then return end
		for _, Emitter in Effect:GetDescendants() do
			if Emitter:IsA("ParticleEmitter") then Emitter.Enabled = false end
		end
	end)
	Debris:AddItem(Anchor, Duration + MaximumLifetime + 0.25)
end

local function GetMinimumRevealDuration(Info): number
	local Duration = 0
	for Index = 1, Info.PreviewSwitchCount do
		local Alpha = if Info.PreviewSwitchCount > 1 then (Index - 1) / (Info.PreviewSwitchCount - 1) else 1
		Duration += Info.PreviewStartDelay + (Info.PreviewEndDelay - Info.PreviewStartDelay) * Alpha * Alpha
	end
	return Duration
end

local function PlayBreakSound(GroundCFrame, Info)
	local Anchor = Instance.new("Part")
	Anchor.Name = "LocalCrateBreakSound"
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanQuery = false
	Anchor.CanTouch = false
	Anchor.Size = Vector3.one * 0.05
	Anchor.Transparency = 1
	Anchor.CFrame = GroundCFrame
	Anchor.Parent = RevealFolder
	local SoundName = Info.BreakSoundNames[RandomGenerator:NextInteger(1, #Info.BreakSoundNames)]
	local Sound = Sounds.Play(SoundName, Anchor, 75)
	if Sound then Sound.Volume *= 0.65 end
	Debris:AddItem(Anchor, 3)
end

local function RestorePredictedCrate(Reveal)
	if not Reveal.CrateModel or not Reveal.CrateModel.Parent then return end
	for Part, CanQuery in Reveal.CrateParts do
		if Part.Parent then
			Part.LocalTransparencyModifier = 0
			Part.CanQuery = CanQuery
		end
	end
	if Reveal.HealthBillboard and Reveal.HealthBillboard.Parent then Reveal.HealthBillboard.Enabled = true end
end

local function HandOffLocalReward(Model, Reveal)
	local Silhouette = Model:FindFirstChild("Silhouette")
	if Silhouette then Silhouette:Destroy() end
	Model.Name = `LocalRevealedReward_{Reveal.ActualItemInfo.Name}`
	local DirtCount = math.max(1, math.round(Reveal.DirtCount or 1))
	local FixingState = { Total = DirtCount, Remaining = DirtCount, Completed = false }
	RestorationVisuals.Apply(Model, Reveal.ActualItemInfo, FixingState)
	local AuthoritativeModel = Reveal.AuthoritativeModel
	local Prompt = AuthoritativeModel and AuthoritativeModel:FindFirstChild("PurchasePrompt", true)
	if not Prompt or not Prompt:IsA("ProximityPrompt") then
		Debris:AddItem(Model, 3)
		return
	end
	if Prompt.Enabled then
		Model:Destroy()
		return
	end
	local Connection
	Connection = Prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not Prompt.Enabled then return end
		Connection:Disconnect()
		if Model.Parent then Model:Destroy() end
	end)
	Model.Destroying:Once(function()
		if Connection.Connected then Connection:Disconnect() end
	end)
	Debris:AddItem(Model, 5)
end

local function RunReveal(Reveal)
	task.spawn(function()
		local Index = 0
		while not Reveal.Cancelled do
			Index += 1
			if Reveal.Model then Reveal.Model:Destroy() end
			local MinimumFinished = os.clock() - Reveal.StartedAt >= Reveal.MinimumDuration
			local IsFinalPreview = Reveal.ActualItemInfo ~= nil and MinimumFinished
			local PreviewInfo = if IsFinalPreview
				then Reveal.ActualItemInfo
				else CrateInfo.GetRandomItem(ItemsInfo, Reveal.Info, RandomGenerator)
			Reveal.Model = PreviewInfo and CreatePreview(PreviewInfo, Reveal.GroundCFrame, RevealFolder) or nil
			local DelayIndex = math.min(Index, Reveal.Info.PreviewSwitchCount)
			local Alpha = if Reveal.Info.PreviewSwitchCount > 1 then (DelayIndex - 1) / (Reveal.Info.PreviewSwitchCount - 1) else 1
			local Delay = Reveal.Info.PreviewStartDelay + (Reveal.Info.PreviewEndDelay - Reveal.Info.PreviewStartDelay) * Alpha * Alpha
			if Reveal.Model then PulseModel(Reveal.Model, Delay); PlayTick(Reveal.Info, Reveal.Model, DelayIndex) end
			task.wait(Delay)
			if IsFinalPreview then break end
		end
		if Reveal.Cancelled or not Reveal.ActualItemInfo then return end
		local Position = if Reveal.Model then Reveal.Model:GetPivot().Position else Reveal.GroundCFrame.Position
		local Config = RarityInfo.Get(Reveal.ActualItemInfo.Rarity)
		if Reveal.Model then
			CreateRarityEffect(Reveal.Model, Reveal.ActualItemInfo.Rarity)
			-- Keep a dirty local stand-in visible until the authoritative reward has fully appeared.
			HandOffLocalReward(Reveal.Model, Reveal)
			Reveal.Model = nil
		end
		CreateRevealBurst(Position, Config)
		if Reveal.RevealingPlayer == LocalPlayer then
			PlayScreenReveal(Position, Config)
			local Sound = Sounds.Play(Config.RevealSoundName or Reveal.Info.RevealCompleteSoundName, Workspace.CurrentCamera, 70)
			if Sound then
				Sound.Volume *= Config.RevealSoundVolume
				Sound.PlaybackSpeed *= Config.RevealSoundPitch
			end
		end
		if Reveal.RewardId then Reveals[Reveal.RewardId] = nil end
	end)
end

function CrateController.BeginPredictedReveal(PredictionId, Model, CrateId)
	local Info = GetCrateInfo(CrateId)
	if type(PredictionId) ~= "string" or typeof(Model) ~= "Instance" or not Model:IsA("Model") or not Info then return end
	local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
	local Pivot = Model:GetPivot()
	local GroundCFrame = CFrame.new(Pivot.X, BoundingCFrame.Position.Y - BoundingSize.Y / 2, Pivot.Z) * Pivot.Rotation
	local Reveal = {
		ActualItemInfo = nil,
		Cancelled = false,
		CrateModel = Model,
		CrateParts = {},
		GroundCFrame = GroundCFrame,
		Info = Info,
		MinimumDuration = GetMinimumRevealDuration(Info),
		Model = nil,
		RevealingPlayer = LocalPlayer,
		StartedAt = os.clock(),
	}
	PredictedReveals[PredictionId] = Reveal
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Reveal.CrateParts[Descendant] = Descendant.CanQuery
			Descendant.LocalTransparencyModifier = 1
			Descendant.CanQuery = false
		end
	end
	local PrimaryPart = Model.PrimaryPart
	Reveal.HealthBillboard = PrimaryPart and PrimaryPart:FindFirstChild("CrateHealth")
	if Reveal.HealthBillboard and Reveal.HealthBillboard:IsA("BillboardGui") then Reveal.HealthBillboard.Enabled = false end
	RunReveal(Reveal)
	task.delay(8, function()
		if PredictedReveals[PredictionId] ~= Reveal or Reveal.ActualItemInfo then return end
		PredictedReveals[PredictionId] = nil
		Reveal.Cancelled = true
		if Reveal.Model then Reveal.Model:Destroy() end
		RestorePredictedCrate(Reveal)
	end)
end

function CrateController.CancelPredictedReveal(PredictionId)
	local Reveal = PredictedReveals[PredictionId]
	if not Reveal then return end
	PredictedReveals[PredictionId] = nil
	Reveal.Cancelled = true
	if Reveal.Model then Reveal.Model:Destroy() end
	RestorePredictedCrate(Reveal)
end

function CrateController.CancelPredictedRevealsForCrate(Model)
	local PredictionIds = {}
	for PredictionId, Reveal in PredictedReveals do
		if Reveal.CrateModel == Model then table.insert(PredictionIds, PredictionId) end
	end
	for _, PredictionId in PredictionIds do CrateController.CancelPredictedReveal(PredictionId) end
end

function CrateController.StartReveal(_, RewardId, ActualItemId, GroundCFrame, CrateId, RevealingPlayer, PredictionId, AuthoritativeModel, DirtCount)
	local Info = GetCrateInfo(CrateId)
	local ActualItemInfo = GetItemInfo(ActualItemId)
	if type(RewardId) ~= "string" or not Info or not ActualItemInfo or typeof(GroundCFrame) ~= "CFrame"
		or typeof(AuthoritativeModel) ~= "Instance" or not AuthoritativeModel:IsA("Model") or type(DirtCount) ~= "number"
	then return end
	local Reveal = if RevealingPlayer == LocalPlayer and type(PredictionId) == "string" then PredictedReveals[PredictionId] else nil
	if Reveal then
		PredictedReveals[PredictionId] = nil
		Reveal.ActualItemInfo = ActualItemInfo
		Reveal.AuthoritativeModel = AuthoritativeModel
		Reveal.DirtCount = DirtCount
		Reveal.GroundCFrame = GroundCFrame
		Reveal.RewardId = RewardId
		Reveals[RewardId] = Reveal
		return
	end
	Reveal = {
		ActualItemInfo = ActualItemInfo,
		AuthoritativeModel = AuthoritativeModel,
		Cancelled = false,
		GroundCFrame = GroundCFrame,
		Info = Info,
		DirtCount = DirtCount,
		MinimumDuration = GetMinimumRevealDuration(Info),
		Model = nil,
		RevealingPlayer = RevealingPlayer,
		RewardId = RewardId,
		StartedAt = os.clock(),
	}
	Reveals[RewardId] = Reveal
	PlayBreakSound(GroundCFrame, Info)
	RunReveal(Reveal)
end

function CrateController.RemoveReveal(_, RewardId)
	local Reveal = Reveals[RewardId]
	if not Reveal then return end
	Reveal.Cancelled = true
	if Reveal.Model then Reveal.Model:Destroy() end
	Reveals[RewardId] = nil
end

function CrateController.UpdateCrateHealth(_, Model, CrateId, Health, MaximumHealth)
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") then return end
	if type(CrateId) ~= "string" or type(Health) ~= "number" or type(MaximumHealth) ~= "number" then return end

	CrateRuntime.Set(Model, CrateId, Health, MaximumHealth)
end

function CrateController.UpdateResetState(_, NextResetTime, IsResetting)
	if NextResetTime ~= nil and type(NextResetTime) ~= "number" then return end

	CrateRuntime.SetResetState(NextResetTime, IsResetting)
end

function CrateController.PurchaseFeedback(_, Status, ItemName, Detail)
	local GetMessage = PurchaseFeedbackMessages[Status]
	if type(Status) ~= "string" or type(ItemName) ~= "string" or not GetMessage then return end
	if Detail ~= nil and type(Detail) ~= "number" then return end
	GuidanceController.ShowLocal(GetMessage(ItemName, Detail))
end

function CrateController.Init()
	RevealFolder = Instance.new("Folder")
	RevealFolder.Name = "LocalCrateReveals"
	RevealFolder.Parent = Workspace
	RevealGui = Instance.new("ScreenGui")
	RevealGui.Name = "LocalRevealVFX"
	RevealGui.DisplayOrder = 80
	RevealGui.IgnoreGuiInset = true
	RevealGui.ResetOnSpawn = false
	RevealGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local CrateNetwork = Networker.client.new("CrateController", CrateController)
	local Snapshot = CrateNetwork:fetch("GetRuntimeState")

	if type(Snapshot) == "table" then
		CrateRuntime.SetResetState(Snapshot.NextResetTime, Snapshot.IsResetting)

		for _, State in Snapshot.Crates or {} do
			CrateController.UpdateCrateHealth(nil, State.Model, State.CrateId, State.Health, State.MaximumHealth)
		end
	end
end

return CrateController
