local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CrateInfo = require(ReplicatedStorage.Modules.Game.CrateInfo)
local CrateRuntime = require(ReplicatedStorage.Modules.Game.CrateRuntime)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
local GuidanceController = require(ReplicatedStorage.Controllers.GuidanceController)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MultiplyNumberSequence = require(ReplicatedStorage.Modules.Math.MultiplyNumberSequence)
local Networker = require(ReplicatedStorage.Packages.networker)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local CrateController = {}
local RevealFolder: Folder
local Reveals = {}
local RandomGenerator = Random.new()

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
		return `Need ${math.max(0, math.ceil(Detail or 0))} More`
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

local function CreateRevealBurst(Position)
	for Index = 1, 14 do
		local Particle = Instance.new("Part")
		Particle.Name = "RevealParticle"
		Particle.Anchored = true
		Particle.CanCollide = false
		Particle.CanQuery = false
		Particle.CanTouch = false
		Particle.Material = Enum.Material.Neon
		Particle.Color = if Index % 2 == 0 then Color3.fromRGB(255, 232, 111) else Color3.new(1, 1, 1)
		Particle.Size = Vector3.one * RandomGenerator:NextNumber(0.09, 0.18)
		Particle.Position = Position
		Particle.Parent = RevealFolder
		local Direction = Vector3.new(RandomGenerator:NextNumber(-1, 1), RandomGenerator:NextNumber(0.2, 1), RandomGenerator:NextNumber(-1, 1)).Unit
		TweenService:Create(
			Particle,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = Position + Direction * RandomGenerator:NextNumber(2, 4), Transparency = 1, Size = Vector3.zero }
		):Play()
		Debris:AddItem(Particle, 0.6)
	end
end

local function CreateRarityEffect(Model: Model, Rarity: string)
	local PinwheelFolder = ReplicatedStorage.Assets.VFX:FindFirstChild("RarityPinwheels")
	local Template = PinwheelFolder and PinwheelFolder:FindFirstChild(Rarity)
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
	local SizeScale = math.clamp(MaximumSize / 3, 1, 3)
	local MaximumLifetime = 0
	for _, Emitter in Effect:GetChildren() do
		if not Emitter:IsA("ParticleEmitter") then continue end
		Emitter.Size = MultiplyNumberSequence(Emitter.Size, SizeScale)
		Emitter.Enabled = true
		Emitter:Emit(1)
		MaximumLifetime = math.max(MaximumLifetime, Emitter.Lifetime.Max)
	end
	local Duration = RarityInfo.Get(Rarity).RevealEffectDuration or 1
	task.delay(Duration, function()
		if not Effect.Parent then return end
		for _, Emitter in Effect:GetChildren() do
			if Emitter:IsA("ParticleEmitter") then Emitter.Enabled = false end
		end
	end)
	Debris:AddItem(Anchor, Duration + MaximumLifetime + 0.25)
end

function CrateController.StartReveal(_, RewardId, ActualItemId, GroundCFrame, CrateId)
	local Info = GetCrateInfo(CrateId)
	local ActualItemInfo = GetItemInfo(ActualItemId)
	if type(RewardId) ~= "string" or not Info or not ActualItemInfo or typeof(GroundCFrame) ~= "CFrame" then return end
	local Reveal = { Cancelled = false, Model = nil }
	Reveals[RewardId] = Reveal
	task.spawn(function()
		for Index = 1, Info.PreviewSwitchCount do
			if Reveals[RewardId] ~= Reveal or Reveal.Cancelled then return end
			if Reveal.Model then Reveal.Model:Destroy() end
			local PreviewInfo = if Index == Info.PreviewSwitchCount
				then ActualItemInfo
				else GetRandomFromWeightedTable.GetRandomFromWeightedTable(ItemsInfo, "ChanceWeight", nil, Info.PreviewLootLuck)
			Reveal.Model = PreviewInfo and CreatePreview(PreviewInfo, GroundCFrame, RevealFolder) or nil
			local Alpha = if Info.PreviewSwitchCount > 1 then (Index - 1) / (Info.PreviewSwitchCount - 1) else 1
			local Delay = Info.PreviewStartDelay + (Info.PreviewEndDelay - Info.PreviewStartDelay) * Alpha * Alpha
			if Reveal.Model then PulseModel(Reveal.Model, Delay); PlayTick(Info, Reveal.Model, Index) end
			task.wait(Delay)
		end
		if Reveals[RewardId] ~= Reveal or Reveal.Cancelled then return end
		local Position = if Reveal.Model then Reveal.Model:GetPivot().Position else GroundCFrame.Position
		if Reveal.Model then
			CreateRarityEffect(Reveal.Model, ActualItemInfo.Rarity)
			Reveal.Model:Destroy()
			Reveal.Model = nil
		end
		Sounds.Play(Info.RevealCompleteSoundName, Workspace.CurrentCamera, 70)
		CreateRevealBurst(Position)
		Reveals[RewardId] = nil
	end)
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
