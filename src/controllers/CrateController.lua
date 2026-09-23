local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local CrateRuntime = require(ReplicatedStorage.Modules.Game.CrateRuntime)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local GuidanceController = require(ReplicatedStorage.Controllers.GuidanceController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
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
local HealthVisibilityIds = setmetatable({}, { __mode = "k" })
local ScreenEffectId = 0
local ActiveRollPresentation
local RandomGenerator = Random.new()
local LocalPlayer = Players.LocalPlayer
local FirstRollPreviewItems = {}

local STAR_BURST_COUNT = 24
local STAR_BURST_TARGET_SIZE = 0.08
local STAR_BURST_EDGE_MARGIN = Vector2.new(0.07, 0.09)
-- Crate-break stars must remain subtle enough that they never obscure the revealed item.
local STAR_BURST_MIN_TRANSPARENCY = 0.7
local STAR_BURST_MAX_TRANSPARENCY = 0.82

local FirstRollPreviewRarities = {
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythic = true,
	Secret = true,
}

for _, ItemInfo in ItemsInfo do
	if FirstRollPreviewRarities[ItemInfo.Rarity] then table.insert(FirstRollPreviewItems, ItemInfo) end
end

local PinwheelTemplates = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
	Secret = "Omniscient",
}

local ClaimFeedbackMessages = {
	AlreadyCarrying = function()
		return "Deliver Item First"
	end,
	Expired = function()
		return "Item Is Gone"
	end,
	Fixing = function()
		return "Finish Cleaning"
	end,
	NotReady = function()
		return "Item Still Opening"
	end,
	ClaimedByAnother = function()
		return "Item Already Taken"
	end,
	Success = function()
		return "Item Is Yours"
	end,
	Unavailable = function()
		return "Item Not Ready"
	end,
}

local function GetCrateInfo(CrateId)
	for _, Info in CrateInfo.Crates do
		if Info.Id == CrateId then return Info end
	end
end

local function GetHealthInterface(Model)
	local PrimaryPart = Model.PrimaryPart
	local Billboard = PrimaryPart and PrimaryPart:FindFirstChild("CrateHealth")
	local Group = Billboard and Billboard:FindFirstChild("Group")
	local Track = Group and Group:FindFirstChild("Track")
	local Fill = Track and Track:FindFirstChild("Fill")
	local HealthLabel = Track and Track:FindFirstChild("Health")
	if Group and Group:IsA("CanvasGroup") and Fill and Fill:IsA("Frame")
		and HealthLabel and HealthLabel:IsA("TextLabel")
	then
		return Group, Fill, HealthLabel
	end
	return nil, nil, nil
end

function CrateController.RenderCrateHealth(Model, Health, MaximumHealth, CrateId)
	if not Model.Parent or type(Health) ~= "number" or type(MaximumHealth) ~= "number" then return end
	local Group, Fill, HealthLabel = GetHealthInterface(Model)
	if not Group then return end
	local Info = GetCrateInfo(CrateId)
	local FillSize = UDim2.fromScale(math.clamp(Health / math.max(MaximumHealth, 1), 0, 1), 1)
	HealthLabel.Text = `{math.ceil(Health)}/{MaximumHealth}`
	if Health >= MaximumHealth then
		Fill.Size = FillSize
		return
	end
	HealthVisibilityIds[Model] = (HealthVisibilityIds[Model] or 0) + 1
	local VisibilityId = HealthVisibilityIds[Model]
	TweenService:Create(Group, TweenInfo.new(0.04), { GroupTransparency = 0 }):Play()
	TweenService:Create(Fill, TweenInfo.new(if Info then Info.HealthBarTweenTime else 0.12, Enum.EasingStyle.Quad), {
		Size = FillSize,
	}):Play()
	task.delay(if Info then Info.HealthBarHideDelay else 1.6, function()
		if Model.Parent and HealthVisibilityIds[Model] == VisibilityId then
			TweenService:Create(Group, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		end
	end)
end

function CrateController.HoldCrateHealth(Model, Health, MaximumHealth)
	if not Model.Parent or type(Health) ~= "number" or type(MaximumHealth) ~= "number" then return end
	local Group, Fill, HealthLabel = GetHealthInterface(Model)
	if not Group then return end
	Group.GroupTransparency = 0
	Fill.Size = UDim2.fromScale(math.clamp(Health / math.max(MaximumHealth, 1), 0, 1), 1)
	HealthLabel.Text = `{math.ceil(Health)}/{MaximumHealth}`
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

local function CreatePreview(ItemInfo, GroundCFrame, Parent, Scale: number?): Model?
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
	Model:ScaleTo(Scale or 1)
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

local function PulseModel(Model, Duration, Scale: number?)
	local BaseScale = Scale or 1
	local BasePivot = Model:GetPivot()
	local MotionValue = Instance.new("NumberValue")
	local SpinDirection = if RandomGenerator:NextInteger(0, 1) == 0 then -1 else 1
	local SpinDegrees = RandomGenerator:NextNumber(38, 62) * SpinDirection
	MotionValue.Value = 0
	local Connection = MotionValue.Changed:Connect(function(Value)
		if not Model.Parent then return end
		-- Each silhouette snaps in with a readable spin and overshooting scale instead of a flat size pulse.
		local RotationAlpha = 1 - math.clamp(Value, 0, 1)
		Model:ScaleTo(BaseScale * (0.72 + 0.28 * Value))
		Model:PivotTo(
			BasePivot
				* CFrame.Angles(
					math.rad(10 * RotationAlpha),
					math.rad(SpinDegrees * RotationAlpha),
					math.rad(-8 * SpinDirection * RotationAlpha)
				)
		)
	end)
	TweenService:Create(
		MotionValue,
		TweenInfo.new(math.max(Duration * 0.85, 0.05), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	):Play()
	task.delay(Duration, function()
		Connection:Disconnect()
		if Model.Parent then
			Model:ScaleTo(BaseScale)
			Model:PivotTo(BasePivot)
		end
		MotionValue:Destroy()
	end)
end

local function ShakeCamera(Strength: number, Duration: number)
	task.spawn(function()
		local StartedAt = os.clock()
		while os.clock() - StartedAt < Duration do
			RunService.RenderStepped:Wait()
			local Camera = Workspace.CurrentCamera
			if not Camera then continue end
			local Alpha = 1 - (os.clock() - StartedAt) / Duration
			local Offset = Vector3.new(
				RandomGenerator:NextNumber(-1, 1),
				RandomGenerator:NextNumber(-1, 1),
				0
			) * Strength * Alpha
			local Roll = math.rad(RandomGenerator:NextNumber(-1, 1) * Strength * 9 * Alpha)
			Camera.CFrame *= CFrame.new(Offset) * CFrame.Angles(0, 0, Roll)
		end
	end)
end

local function FinishRollPresentation(Reveal, Config)
	if Reveal.TickSound and Reveal.TickSound.Parent then Reveal.TickSound:Destroy() end
	Reveal.TickSound = nil
	local Presentation = Reveal.RollPresentation
	if not Presentation or Presentation.Finished then return end
	Presentation.Finished = true
	Reveal.RollPresentation = nil
	if ActiveRollPresentation == Presentation then ActiveRollPresentation = nil end
	if Presentation.FovTween then Presentation.FovTween:Cancel() end

	local Camera = Presentation.Camera
	if Camera and Camera.Parent then
		local RevealIntensity = if Config then math.clamp(Config.Intensity, 0.8, 2.5) else 1
		local Kick = if Config then CrateInfo.Effects.RevealFovKick * math.sqrt(RevealIntensity) else 0
		local KickTween = TweenService:Create(
			Camera,
			TweenInfo.new(if Config then 0.09 else 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = Presentation.BaseFieldOfView + Kick }
		)
		KickTween:Play()
		KickTween.Completed:Once(function()
			if not Camera.Parent or (ActiveRollPresentation and ActiveRollPresentation ~= Presentation) then return end
			TweenService:Create(
				Camera,
				TweenInfo.new(if Config then 0.38 else 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ FieldOfView = Presentation.BaseFieldOfView }
			):Play()
		end)
	end

	if Presentation.ColorEffect.Parent then
		if Config then
			-- The rolled reward gets stronger color, but restrained brightness prevents a white screen wash.
			Presentation.ColorEffect.TintColor = Color3.new(1, 1, 1):Lerp(Config.Color, 0.2)
			Presentation.ColorEffect.Brightness = CrateInfo.Effects.RevealLightingBrightness
			Presentation.ColorEffect.Contrast = 0.16
			Presentation.ColorEffect.Saturation = 0.24
		end
		TweenService:Create(Presentation.ColorEffect, TweenInfo.new(0.42), {
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}):Play()
		Debris:AddItem(Presentation.ColorEffect, 0.45)
	end
	if Presentation.BloomEffect.Parent then
		if Config then Presentation.BloomEffect.Intensity = CrateInfo.Effects.RevealBloomIntensity end
		TweenService:Create(Presentation.BloomEffect, TweenInfo.new(0.42), { Intensity = 0 }):Play()
		Debris:AddItem(Presentation.BloomEffect, 0.45)
	end
	if Config then ShakeCamera(0.075 * math.sqrt(math.clamp(Config.Intensity, 0.8, 2.5)), 0.22) end
end

local function StartRollPresentation(Reveal)
	if Reveal.Cancelled or Reveal.RevealingPlayer ~= LocalPlayer or Reveal.RollPresentation then return end
	if ActiveRollPresentation then
		FinishRollPresentation(ActiveRollPresentation.Reveal, nil)
	end
	local Camera = Workspace.CurrentCamera
	if not Camera then return end

	local ColorEffect = Instance.new("ColorCorrectionEffect")
	ColorEffect.Name = "LocalCrateRollColor"
	ColorEffect.Parent = Lighting
	local BloomEffect = Instance.new("BloomEffect")
	BloomEffect.Name = "LocalCrateRollBloom"
	BloomEffect.Intensity = 0
	BloomEffect.Size = 18
	BloomEffect.Threshold = 1.25
	BloomEffect.Parent = Lighting

	local Presentation = {
		BaseFieldOfView = Camera.FieldOfView,
		BloomEffect = BloomEffect,
		Camera = Camera,
		ColorEffect = ColorEffect,
		Finished = false,
		Reveal = Reveal,
	}
	Reveal.RollPresentation = Presentation
	ActiveRollPresentation = Presentation
	Presentation.FovTween = TweenService:Create(
		Camera,
		TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ FieldOfView = Presentation.BaseFieldOfView + CrateInfo.Effects.RollFovFocus }
	)
	Presentation.FovTween:Play()
	TweenService:Create(ColorEffect, TweenInfo.new(0.2), {
		-- Breaking begins the roll with a subdued grade; the payoff is reserved for the rolled item.
		Brightness = CrateInfo.Effects.RollLightingBrightness,
		Contrast = 0.045,
		Saturation = 0.08,
	}):Play()
	TweenService:Create(BloomEffect, TweenInfo.new(0.2), { Intensity = CrateInfo.Effects.RollBloomIntensity }):Play()
end

local function PulseRollPresentation(Reveal, Alpha: number)
	local Presentation = Reveal.RollPresentation
	if not Presentation or Presentation.Finished then return end
	local Camera = Presentation.Camera
	if Camera and Camera.Parent then
		if Presentation.FovTween then Presentation.FovTween:Cancel() end
		Camera.FieldOfView = Presentation.BaseFieldOfView
			+ CrateInfo.Effects.RollFovFocus
			+ CrateInfo.Effects.RollTickFovPulse * (0.45 + Alpha * 0.55)
		Presentation.FovTween = TweenService:Create(
			Camera,
			TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = Presentation.BaseFieldOfView + CrateInfo.Effects.RollFovFocus }
		)
		Presentation.FovTween:Play()
	end
	if Presentation.ColorEffect.Parent then
		Presentation.ColorEffect.Brightness = CrateInfo.Effects.RollLightingBrightness + Alpha * 0.008
		TweenService:Create(Presentation.ColorEffect, TweenInfo.new(0.1), {
			Brightness = CrateInfo.Effects.RollLightingBrightness,
		}):Play()
	end
end

local function PlayTick(Reveal, Index, SwitchCount: number?, Force: boolean?)
	if Reveal.RevealingPlayer ~= LocalPlayer then return end
	local Now = os.clock()
	if not Force and Now - (Reveal.LastTickAt or 0) < CrateInfo.Audio.RevealTickInterval then return end
	local Camera = Workspace.CurrentCamera
	if not Camera then return end
	-- Keep the short ItemRevealTick on the camera long enough to register, while replacing it before copies can stack.
	if Reveal.TickSound and Reveal.TickSound.Parent then Reveal.TickSound:Destroy() end
	Reveal.LastTickAt = Now
	local Sound = Sounds.Play(Reveal.Info.RevealTickSoundName, Camera)
	if Sound then
		local Alpha = math.clamp(Index / (SwitchCount or Reveal.Info.PreviewSwitchCount), 0, 1)
		Sound.PlaybackSpeed = 0.9 + Alpha * 0.45
		Sound.Volume = CrateInfo.Audio.RevealTickStartVolume
			+ (CrateInfo.Audio.RevealTickEndVolume - CrateInfo.Audio.RevealTickStartVolume) * Alpha
		Reveal.TickSound = Sound
	end
end

local function CreateRevealBurst(Position, Config)
	local BurstDuration = 0.45 + Config.RevealEffectDuration * 0.18
	local ParticleCount = math.max(1, math.round(Config.ParticleCount * CrateInfo.Effects.RolledEffectMultiplier))
	for Index = 1, ParticleCount do
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

local function CreateScreenStarBurst(Config)
	local StarLayer = Instance.new("Frame")
	StarLayer.Name = "RevealStarBurst"
	StarLayer.BackgroundTransparency = 1
	StarLayer.ClipsDescendants = true
	StarLayer.Size = UDim2.fromScale(1, 1)
	StarLayer.ZIndex = 3
	StarLayer.Parent = RevealGui

	local Center = Vector2.new(0.5, 0.5)
	local TravelDuration = math.clamp(0.55 + Config.RevealEffectDuration * 0.08, 0.6, 1)
	local HoldDuration = 0.08
	local FadeDuration = 0.3

	-- Keep the item information clear by revealing the stars as they leave the center and stop around the screen edges.
	for Index = 1, STAR_BURST_COUNT do
		local Angle = (Index - 1) / STAR_BURST_COUNT * math.pi * 2 + RandomGenerator:NextNumber(-0.09, 0.09)
		local Direction = Vector2.new(math.cos(Angle), math.sin(Angle))
		local HorizontalDistance = (0.5 - STAR_BURST_EDGE_MARGIN.X) / math.max(math.abs(Direction.X), 0.001)
		local VerticalDistance = (0.5 - STAR_BURST_EDGE_MARGIN.Y) / math.max(math.abs(Direction.Y), 0.001)
		local TargetDistance = math.min(HorizontalDistance, VerticalDistance) * RandomGenerator:NextNumber(0.88, 1)
		local Target = Center + Direction * TargetDistance
		local Start = Center + Direction * RandomGenerator:NextNumber(0.015, 0.04)

		local Star = Instance.new("ImageLabel")
		Star.Name = "RevealStar"
		Star.AnchorPoint = Vector2.new(0.5, 0.5)
		Star.BackgroundTransparency = 1
		Star.Image = Images.Sparkle
		Star.ImageColor3 = if Index % 3 == 0 then Color3.new(1, 1, 1) else Config.Color
		Star.ImageTransparency = 1
		Star.Position = UDim2.fromScale(Start.X, Start.Y)
		Star.Rotation = RandomGenerator:NextNumber(-180, 180)
		Star.Size = UDim2.fromScale(0.02, 0.02)
		Star.ZIndex = 3
		Star.Parent = StarLayer

		local AspectRatio = Instance.new("UIAspectRatioConstraint")
		AspectRatio.AspectRatio = 1
		AspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
		AspectRatio.Parent = Star

		local StarTravelDuration = TravelDuration * RandomGenerator:NextNumber(0.88, 1.08)
		TweenService:Create(
			Star,
			TweenInfo.new(StarTravelDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				ImageTransparency = RandomGenerator:NextNumber(
					STAR_BURST_MIN_TRANSPARENCY,
					STAR_BURST_MAX_TRANSPARENCY
				),
				Position = UDim2.fromScale(Target.X, Target.Y),
				Rotation = Star.Rotation + RandomGenerator:NextNumber(100, 220),
				Size = UDim2.fromScale(STAR_BURST_TARGET_SIZE, STAR_BURST_TARGET_SIZE),
			}
		):Play()

		task.delay(StarTravelDuration + HoldDuration, function()
			if not Star.Parent then return end
			TweenService:Create(
				Star,
				TweenInfo.new(FadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ ImageTransparency = 1 }
			):Play()
		end)
	end

	Debris:AddItem(StarLayer, TravelDuration + HoldDuration + FadeDuration + 0.05)
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
	local ScreenIntensity = math.min(Config.Intensity ^ 1.15 * 1.2, 3.5)
	-- Double the readable rolled-item accents while keeping the full-screen flash deliberately dim.
	local VignetteOpacity = math.clamp(
		(Config.VignetteOpacity * 1.35 + 0.04) * CrateInfo.Effects.RolledEffectMultiplier,
		0,
		0.92
	)
	local FlashStrength = math.clamp(Config.FlashStrength * 0.55 + 0.015, 0, 0.42)

	local Vignette = Instance.new("ImageLabel")
	-- Crate SFX are mixed down locally, so this vignette must not trigger the legacy 72% music duck.
	Vignette.Name = "RolledItemVignette"
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
	Flash.BackgroundTransparency = 1 - FlashStrength
	Flash.BorderSizePixel = 0
	Flash.Size = UDim2.fromScale(1, 1)
	Flash.ZIndex = 2
	Flash.Parent = RevealGui

	TweenService:Create(Vignette, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1 - VignetteOpacity,
	}):Play()
	TweenService:Create(Flash, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	CreateScreenStarBurst(Config)

	local SparkleCount = math.max(1, math.round(Config.SparkleCount * CrateInfo.Effects.RolledEffectMultiplier))
	for Index = 1, SparkleCount do
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

local function GetMinimumRevealDuration(Info, IsFirstRoll: boolean?): number
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

local function GetFirstRollPreviewItem()
	if #FirstRollPreviewItems == 0 then return nil end
	return FirstRollPreviewItems[RandomGenerator:NextInteger(1, #FirstRollPreviewItems)]
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
	if Sound then
		Sound.Volume = CrateInfo.Audio.BreakVolume
		Sound.PlaybackSpeed *= RandomGenerator:NextNumber(0.94, 1.04)
	end
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
	local FixingState = {
		Total = DirtCount,
		Remaining = DirtCount,
		Completed = false,
		RestorationSteps = Reveal.RestorationSteps,
	}
	RestorationVisuals.Apply(Model, Reveal.ActualItemInfo, FixingState)
	local AuthoritativeModel = Reveal.AuthoritativeModel
	local Prompt = AuthoritativeModel and AuthoritativeModel:FindFirstChild("ClaimPrompt", true)
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
		StartRollPresentation(Reveal)
		local Index = 0
		while not Reveal.Cancelled do
			Index += 1
			if Reveal.Model then Reveal.Model:Destroy() end
			local MinimumFinished = os.clock() - Reveal.StartedAt >= Reveal.MinimumDuration
			local IsFinalPreview = Reveal.ActualItemInfo ~= nil and MinimumFinished
			local IsFirstRollPreview = Reveal.IsFirstRoll and not IsFinalPreview
			local PreviewInfo = if IsFinalPreview
				then Reveal.ActualItemInfo
				elseif IsFirstRollPreview then GetFirstRollPreviewItem()
				else CrateInfo.GetRandomItem(ItemsInfo, Reveal.Info, RandomGenerator)
			local PreviewScale = if IsFirstRollPreview then Reveal.Info.FirstRollPreviewScale else 1
			Reveal.Model = PreviewInfo and CreatePreview(PreviewInfo, Reveal.GroundCFrame, RevealFolder, PreviewScale) or nil
			local SwitchCount = if IsFirstRollPreview then Reveal.Info.FirstRollPreviewSwitchCount else Reveal.Info.PreviewSwitchCount
			local StartDelay = if IsFirstRollPreview then Reveal.Info.FirstRollPreviewStartDelay else Reveal.Info.PreviewStartDelay
			local EndDelay = if IsFirstRollPreview then Reveal.Info.FirstRollPreviewEndDelay else Reveal.Info.PreviewEndDelay
			local DelayIndex = math.min(Index, SwitchCount)
			local Alpha = if SwitchCount > 1 then (DelayIndex - 1) / (SwitchCount - 1) else 1
			local Delay = StartDelay + (EndDelay - StartDelay) * Alpha * Alpha
			if Reveal.Model then
				PulseModel(Reveal.Model, Delay, PreviewScale)
				PlayTick(Reveal, Index, SwitchCount, IsFinalPreview)
				PulseRollPresentation(Reveal, Alpha)
			end
			task.wait(Delay)
			if IsFinalPreview then break end
		end
		if Reveal.Cancelled or not Reveal.ActualItemInfo then
			FinishRollPresentation(Reveal, nil)
			return
		end
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
			FinishRollPresentation(Reveal, Config)
			PlayScreenReveal(Position, Config)
			local Sound = Sounds.Play(Config.RevealSoundName or Reveal.Info.RevealCompleteSoundName, Workspace.CurrentCamera, 70)
			if Sound then
				Sound.Volume = CrateInfo.Audio.RevealCompleteVolume * Config.RevealSoundVolume
				Sound.PlaybackSpeed *= Config.RevealSoundPitch
			end
		end
		if Reveal.RewardId then Reveals[Reveal.RewardId] = nil end
	end)
end

function CrateController.BeginPredictedReveal(PredictionId, Model, CrateId)
	local Info = GetCrateInfo(CrateId)
	if type(PredictionId) ~= "string" or typeof(Model) ~= "Instance" or not Model:IsA("Model") or not Info then return end
	local IsFirstRoll = DataService:get("HasRolledCrate") ~= true and DataService:get("GuaranteedDropCount") == 0
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
		IsFirstRoll = IsFirstRoll,
		MinimumDuration = GetMinimumRevealDuration(Info, IsFirstRoll),
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
		FinishRollPresentation(Reveal, nil)
		RestorePredictedCrate(Reveal)
	end)
end

function CrateController.CancelPredictedReveal(PredictionId)
	local Reveal = PredictedReveals[PredictionId]
	if not Reveal then return end
	PredictedReveals[PredictionId] = nil
	Reveal.Cancelled = true
	if Reveal.Model then Reveal.Model:Destroy() end
	FinishRollPresentation(Reveal, nil)
	RestorePredictedCrate(Reveal)
end

function CrateController.CancelPredictedRevealsForCrate(Model)
	local PredictionIds = {}
	for PredictionId, Reveal in PredictedReveals do
		if Reveal.CrateModel == Model then table.insert(PredictionIds, PredictionId) end
	end
	for _, PredictionId in PredictionIds do CrateController.CancelPredictedReveal(PredictionId) end
end

function CrateController.StartReveal(_, RewardId, ActualItemId, GroundCFrame, CrateId, RevealingPlayer, PredictionId, AuthoritativeModel, DirtCount, RestorationSteps, IsFirstRoll)
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
		Reveal.RestorationSteps = if type(RestorationSteps) == "table" then RestorationSteps else nil
		Reveal.GroundCFrame = GroundCFrame
		Reveal.IsFirstRoll = IsFirstRoll == true
		Reveal.MinimumDuration = GetMinimumRevealDuration(Info, Reveal.IsFirstRoll)
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
		IsFirstRoll = IsFirstRoll == true,
		DirtCount = DirtCount,
		RestorationSteps = if type(RestorationSteps) == "table" then RestorationSteps else nil,
		MinimumDuration = GetMinimumRevealDuration(Info, IsFirstRoll == true),
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
	FinishRollPresentation(Reveal, nil)
	Reveals[RewardId] = nil
end

function CrateController.UpdateCrateHealth(_, Model, CrateId, Health, MaximumHealth)
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") then return end
	if type(CrateId) ~= "string" or type(Health) ~= "number" or type(MaximumHealth) ~= "number" then return end

	-- Render authoritative health locally before prediction reconciliation so delayed server updates cannot rewind the bar.
	CrateController.RenderCrateHealth(Model, Health, MaximumHealth, CrateId)
	CrateRuntime.Set(Model, CrateId, Health, MaximumHealth)
end

function CrateController.UpdateResetState(_, NextResetTime, IsResetting)
	if NextResetTime ~= nil and type(NextResetTime) ~= "number" then return end

	CrateRuntime.SetResetState(NextResetTime, IsResetting)
end

function CrateController.ClaimFeedback(_, Status, ItemName)
	local GetMessage = ClaimFeedbackMessages[Status]
	if type(Status) ~= "string" or type(ItemName) ~= "string" or not GetMessage then return end
	GuidanceController.ShowLocal(GetMessage(ItemName))
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
