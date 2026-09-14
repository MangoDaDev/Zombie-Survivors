local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CarryController = require(ServerStorage.Controllers.CarryController)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local CONFIG = {
	SprayDamagePerSecond = 4,
	RotationSpeed = math.rad(12),
	RotationResponsiveness = 5,
	DirtFeedbackInterval = 0.16,
	DirtFeedbackInTime = 0.06,
	DirtFeedbackOutTime = 0.1,
	DirtSoundMaxDistance = 50,
}
local FixingController = {}
local DataService
local Sessions = {}
local PromptConnections: { [Player]: RBXScriptConnection } = {}
local CompleteCurrentStep

local function GetInfo(ItemId)
	for _, Info in ItemsInfo do if Info.Id == ItemId then return Info end end
end
local function SaveState(Player, ItemId, State)
	local Fixing = DataService:get(Player, "Fixing") or {}
	Fixing[tostring(ItemId)] = State
	DataService:set(Player, "Fixing", Fixing)
end
local function GetCleaningTool(Player, ToolId): Tool?
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if not Container then continue end
		for _, Child in Container:GetChildren() do
			if Child:IsA("Tool") and Child:GetAttribute("CleaningToolId") == ToolId then return Child end
		end
	end
	return nil
end
local function GetScreenPosition(WorldPosition, CameraCFrame, ViewportSize): Vector2?
	local CameraPosition = CameraCFrame:PointToObjectSpace(WorldPosition)
	local Depth = -CameraPosition.Z
	if Depth <= 0.1 then return nil end
	local HalfHeight = Depth * math.tan(math.rad(CleaningConfig.CameraFieldOfView / 2))
	local HalfWidth = HalfHeight * ViewportSize.X / ViewportSize.Y
	return Vector2.new(
		(CameraPosition.X / HalfWidth + 1) * ViewportSize.X / 2,
		(1 - CameraPosition.Y / HalfHeight) * ViewportSize.Y / 2
	)
end
local function GetDirtProgress(Session): number
	local RemovedCount = Session.State.Total - Session.State.Remaining
	local PartialProgress = 0
	if Session.Dirt then
		for _, Dirt in Session.Dirt:GetChildren() do
			if Dirt:IsA("BasePart") then
				PartialProgress += 1 - math.clamp((Dirt:GetAttribute("HP") or 0) / Session.MaxDirtHP, 0, 1)
			end
		end
	end
	return math.clamp((RemovedCount + PartialProgress) / math.max(Session.State.Total, 1), 0, 1)
end
local function UpdateProgress(Player, Session, Force)
	local Progress = GetDirtProgress(Session)
	if Force or math.abs(Progress - Session.LastProgress) >= 0.005 then
		Session.LastProgress = Progress
		Player:SetAttribute("CleaningProgress", Progress)
	end
end
local function PlayDirtFeedback(Session, Dirt, Now)
	local LastFeedback = Session.DirtFeedbackTimes[Dirt] or 0
	if Now - LastFeedback < CONFIG.DirtFeedbackInterval then return end
	Session.DirtFeedbackTimes[Dirt] = Now

	local OriginalSize = Dirt.Size
	local OriginalColor = Dirt.Color
	local HitSize = OriginalSize * Vector3.new(1.18, 0.82, 1.12)
	local HitColor = OriginalColor:Lerp(Color3.new(1, 1, 1), 0.7)
	local HitTween = TweenService:Create(
		Dirt,
		TweenInfo.new(CONFIG.DirtFeedbackInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = HitSize, Color = HitColor }
	)
	HitTween.Completed:Once(function()
		if not Dirt.Parent then return end
		TweenService:Create(
			Dirt,
			TweenInfo.new(CONFIG.DirtFeedbackOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = OriginalSize, Color = OriginalColor }
		):Play()
	end)
	HitTween:Play()

	if Now - Session.LastDirtSound >= CONFIG.DirtFeedbackInterval then
		Session.LastDirtSound = Now
		local Sound = Sounds.Play(CleaningConfig.DirtDamageSoundName, Session.Model.PrimaryPart or Session.Model, CONFIG.DirtSoundMaxDistance)
		if Sound then
			Sound.Volume *= 0.45
			Sound.PlaybackSpeed = Random.new():NextNumber(0.92, 1.08)
		end
	end
end
local function ClearSession(Player)
	local Session = Sessions[Player]
	if not Session then return end
	SaveState(Player, Session.ItemId, Session.State)
	if Session.Connection then Session.Connection:Disconnect() end
	if Session.Model then Session.Model:Destroy() end
	if Session.RootPart and Session.RootPart.Parent then
		Session.RootPart.Anchored = Session.RootWasAnchored
	end
	Sessions[Player] = nil
	Player:SetAttribute("IsFixing", false)
	Player:SetAttribute("CleaningStepName", nil)
	Player:SetAttribute("CleaningProgress", nil)
	Player:SetAttribute("CleaningStepComplete", nil)
	CarryController.SetFixingMode(Player, false)
	if Session.Prompt and Session.Prompt.Parent then Session.Prompt.Enabled = true end
end
local function StartFixing(Player)
	if Sessions[Player] then return end
	local ItemId = CarryController.GetEquippedItemId(Player)
	local Info = ItemId and GetInfo(ItemId)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local PromptPart = TableModel and TableModel:FindFirstChild("PromptPart")
	local Prompt = PromptPart and PromptPart:FindFirstChild("FixItemPrompt")
	if not ItemId or not Info or not PromptPart or not PromptPart:IsA("BasePart") then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Inventory = DataService:get(Player, "Inventory")
	if not RootPart or not RootPart:IsA("BasePart") or (RootPart.Position - PromptPart.Position).Magnitude > 13 or type(Inventory) ~= "table" or table.find(Inventory, ItemId) == nil then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(Info.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Fixing = DataService:get(Player, "Fixing") or {}
	local DirtCount = DirtRenderer.GetSuggestedCount(Template)
	local State = Fixing[tostring(ItemId)] or { Total = DirtCount, Remaining = DirtCount, Completed = false }
	if State.Completed == true then return end
	if type(State.Total) ~= "number" or State.Total < 1 then State.Total = DirtCount end
	if type(State.Remaining) ~= "number" then State.Remaining = State.Total end
	State.Remaining = math.clamp(math.round(State.Remaining), 0, State.Total)
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	for _, Part in Model:GetDescendants() do if Part:IsA("BasePart") then Part.Anchored = true; Part.CanCollide = false end end
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not CameraPart or not CameraPart:IsA("BasePart") then Model:Destroy(); return end
	local ItemDistance = CleaningConfig.MinimumItemCameraDistance
		+ math.max(Box.Size.X, Box.Size.Y, Box.Size.Z) * CleaningConfig.ItemCameraDistancePerStud
	local ItemPosition = CameraPart.CFrame:PointToWorldSpace(Vector3.new(0, CleaningConfig.ItemVerticalOffset, -ItemDistance))
	Model:PivotTo(
		CFrame.new(ItemPosition)
			* PromptPart.CFrame.Rotation
			* CFrame.Angles(math.rad(CleaningConfig.ItemTiltDegrees), 0, 0)
	)
	Model.Parent = Museum
	local Dirt = if State.Completed then nil else DirtRenderer.Add(Model, State.Remaining, Info.DirtHP)
	local RootWasAnchored = RootPart.Anchored
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.Anchored = true
	Player:SetAttribute("IsFixing", true)
	CarryController.SetFixingMode(Player, true)
	local Session = {
		ItemId = ItemId,
		State = State,
		Model = Model,
		Dirt = Dirt,
		LastSpray = os.clock(),
		RootPart = RootPart,
		RootWasAnchored = RootWasAnchored,
		Prompt = if Prompt and Prompt:IsA("ProximityPrompt") then Prompt else nil,
		IsSpraying = false,
		CurrentRotationSpeed = CONFIG.RotationSpeed,
		DirtFeedbackTimes = {},
		LastDirtSound = 0,
		MaxDirtHP = Info.DirtHP,
		StepIndex = 1,
		Completing = false,
		LastProgress = -1,
	}
	Session.Connection = RunService.Heartbeat:Connect(function(DeltaTime)
		if not Model.Parent then return end
		local TargetRotationSpeed = if Session.IsSpraying then 0 else CONFIG.RotationSpeed
		local Blend = 1 - math.exp(-CONFIG.RotationResponsiveness * DeltaTime)
		Session.CurrentRotationSpeed += (TargetRotationSpeed - Session.CurrentRotationSpeed) * Blend
		if math.abs(TargetRotationSpeed - Session.CurrentRotationSpeed) < math.rad(0.05) then
			Session.CurrentRotationSpeed = TargetRotationSpeed
		end
		Model:PivotTo(Model:GetPivot() * CFrame.Angles(0, Session.CurrentRotationSpeed * DeltaTime, 0))
	end)
	Sessions[Player] = Session
	if Session.Prompt then Session.Prompt.Enabled = false end
	SaveState(Player, ItemId, State)
	local Step = CleaningConfig.Steps[Session.StepIndex]
	Player:SetAttribute("CleaningStepName", Step.DisplayName)
	Player:SetAttribute("CleaningStepComplete", false)
	UpdateProgress(Player, Session, true)
	local RemovedProgress = (State.Total - State.Remaining) / State.Total
	if RemovedProgress >= CleaningConfig.AutoCompletionThreshold then task.defer(CompleteCurrentStep, Player, Session) end
end

local function PlayFullCompletionFeedback(Session)
	for _, SoundName in CleaningConfig.FullCompletion.SoundNames do
		Sounds.Play(SoundName, Session.RootPart, CONFIG.DirtSoundMaxDistance)
	end
	local ToolTemplate = ReplicatedStorage.Assets.Tools:FindFirstChild(CleaningConfig.FullCompletion.ParticleToolTemplateName)
	local ParticlePart = ToolTemplate and ToolTemplate:FindFirstChild(CleaningConfig.FullCompletion.ParticlePartName, true)
	local ParticleTemplate = ParticlePart and ParticlePart:FindFirstChildOfClass("ParticleEmitter")
	local EffectParent = Session.Model.PrimaryPart
	if ParticleTemplate and EffectParent then
		local Particle = ParticleTemplate:Clone()
		Particle.Enabled = false
		Particle.Parent = EffectParent
		Particle:Emit(CleaningConfig.FullCompletion.ParticleCount)
		Debris:AddItem(Particle, Particle.Lifetime.Max + 0.5)
	end
	local Highlight = Instance.new("Highlight")
	Highlight.FillColor = Color3.fromRGB(118, 220, 255)
	Highlight.FillTransparency = 0.25
	Highlight.OutlineColor = Color3.new(1, 1, 1)
	Highlight.OutlineTransparency = 0
	Highlight.Parent = Session.Model
	TweenService:Create(
		Highlight,
		TweenInfo.new(CleaningConfig.FullCompletionDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
	Debris:AddItem(Highlight, CleaningConfig.FullCompletionDelay)
end

CompleteCurrentStep = function(Player, Session)
	if Sessions[Player] ~= Session or Session.Completing then return end
	Session.Completing = true
	Session.IsSpraying = false
	Session.State.Remaining = 0
	Session.State.Completed = true
	if Session.Dirt then Session.Dirt:Destroy(); Session.Dirt = nil end
	SaveState(Player, Session.ItemId, Session.State)
	Player:SetAttribute("CleaningProgress", 1)
	Player:SetAttribute("CleaningStepComplete", true)
	local Step = CleaningConfig.Steps[Session.StepIndex]
	Sounds.Play(Step.CompletionSoundName, Session.RootPart, CONFIG.DirtSoundMaxDistance)

	local NextStep = CleaningConfig.Steps[Session.StepIndex + 1]
	if NextStep then
		task.delay(CleaningConfig.StepTransitionDelay, function()
			if Sessions[Player] ~= Session then return end
			Session.StepIndex += 1
			Session.Completing = false
			Player:SetAttribute("CleaningStepName", NextStep.DisplayName)
			Player:SetAttribute("CleaningStepComplete", false)
			Player:SetAttribute("CleaningProgress", 0)
		end)
		return
	end

	PlayFullCompletionFeedback(Session)
	task.delay(CleaningConfig.FullCompletionDelay, function()
		if Sessions[Player] == Session then ClearSession(Player) end
	end)
end

function FixingController:Spray(Player, BrushPosition, ViewportSize)
	local Session = Sessions[Player]
	local Step = Session and CleaningConfig.Steps[Session.StepIndex]
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if not Session or Session.Completing or not Session.IsSpraying or not Tool or typeof(BrushPosition) ~= "Vector2" or typeof(ViewportSize) ~= "Vector2" or not Session.Dirt then return end
	if ViewportSize.X < 200 or ViewportSize.Y < 200 or ViewportSize.X > 10000 or ViewportSize.Y > 10000 then return end
	if BrushPosition.X < 0 or BrushPosition.Y < 0 or BrushPosition.X > ViewportSize.X or BrushPosition.Y > ViewportSize.Y then return end
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not CameraPart or not CameraPart:IsA("BasePart") then return end
	local Now = os.clock()
	local Damage = CONFIG.SprayDamagePerSecond * math.clamp(Now - Session.LastSpray, 0, 0.2)
	Session.LastSpray = Now
	local ProgressChanged = false
	for _, Dirt in Session.Dirt:GetChildren() do
		local ScreenPosition = if Dirt:IsA("BasePart") then GetScreenPosition(Dirt.Position, CameraPart.CFrame, ViewportSize) else nil
		if Dirt:IsA("BasePart") and ScreenPosition and (ScreenPosition - BrushPosition).Magnitude <= CleaningConfig.BrushRadiusPixels then
			PlayDirtFeedback(Session, Dirt, Now)
			local HP = (Dirt:GetAttribute("HP") or 0) - Damage
			Dirt:SetAttribute("HP", HP)
			if HP <= 0 then Dirt:Destroy(); Session.State.Remaining -= 1; ProgressChanged = true end
		end
	end
	if ProgressChanged then SaveState(Player, Session.ItemId, Session.State) end
	UpdateProgress(Player, Session, false)
	local RemovedProgress = (Session.State.Total - Session.State.Remaining) / math.max(Session.State.Total, 1)
	if Session.State.Remaining <= 0 or RemovedProgress >= CleaningConfig.AutoCompletionThreshold then
		CompleteCurrentStep(Player, Session)
	end
end
function FixingController:StartSpraying(Player)
	local Session = Sessions[Player]
	local Step = Session and CleaningConfig.Steps[Session.StepIndex]
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if not Session or Session.Completing or not Tool then return end
	Session.IsSpraying = true
	Session.LastSpray = os.clock()
end
function FixingController:StopSpraying(Player)
	local Session = Sessions[Player]
	if Session then Session.IsSpraying = false end
end
function FixingController:Exit(Player) ClearSession(Player) end
function FixingController.SetDataService(Service) DataService = Service end
function FixingController:Init()
	self.Networker = Networker.server.new("FixingController", self, {
		FixingController.StartSpraying,
		FixingController.Spray,
		FixingController.StopSpraying,
		FixingController.Exit,
	})
end
function FixingController.OnPlayerAdded(Player)
	Player:SetAttribute("IsFixing", false)
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local Part = TableModel and TableModel:FindFirstChild("PromptPart")
	if Part and Part:IsA("BasePart") then
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "FixItemPrompt"; Prompt.ActionText = "Fix Item"; Prompt.ObjectText = "Fixing Table"
		Prompt.HoldDuration = 0; Prompt.MaxActivationDistance = 10; Prompt.RequiresLineOfSight = false
		Prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		Prompt.Enabled = true; Prompt.UIOffset = Vector2.new(0, -55); Prompt.Parent = Part
		PromptConnections[Player] = Prompt.Triggered:Connect(function(TriggeringPlayer)
			if TriggeringPlayer == Player then StartFixing(Player) end
		end)
	end
end
function FixingController.OnPlayerRemoving(Player)
	ClearSession(Player)
	local PromptConnection = PromptConnections[Player]
	if PromptConnection then PromptConnection:Disconnect(); PromptConnections[Player] = nil end
end
return FixingController
