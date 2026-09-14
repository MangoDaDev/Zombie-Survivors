local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CarryController = require(ServerStorage.Controllers.CarryController)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local GreaseRenderer = require(ReplicatedStorage.Modules.Game.GreaseRenderer)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local PaintRenderer = require(ReplicatedStorage.Modules.Game.PaintRenderer)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local CONFIG = {
	RotationSpeed = math.rad(12),
	RotationResponsiveness = 5,
	DirtFeedbackInterval = 0.16,
	DirtFeedbackInTime = 0.06,
	DirtFeedbackOutTime = 0.1,
	FeedbackSoundMaxDistance = 50,
}
local FixingController = {}
local DataService
local Sessions = {}
local PromptConnections: { [Player]: RBXScriptConnection } = {}
local CompleteCurrentStep

local function GetInfo(ItemId)
	for _, Info in ItemsInfo do if Info.Id == ItemId then return Info end end
end

local function GetToolInfo(ToolId)
	return CleaningConfig.GetTool(ToolId)
end

local function IsToolUnlocked(Player, ToolId): boolean
	return UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), ToolId)
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

local function GetStepState(Session)
	local Step = Session.Steps[Session.StepIndex]
	return Step and Session.State.Steps[Step.Id]
end

local function GetTargets(Session): { BasePart }
	local Step = Session.Steps[Session.StepIndex]
	if Step and Step.Type == "Dirt" and Session.Dirt then
		local Targets = {}
		for _, Target in Session.Dirt:GetChildren() do if Target:IsA("BasePart") then table.insert(Targets, Target) end end
		return Targets
	end
	if Step and Step.Type == "Grease" and Session.Grease then
		local Targets = {}
		for _, Target in Session.Grease:GetChildren() do if Target:IsA("BasePart") then table.insert(Targets, Target) end end
		return Targets
	end
	return if Step and Step.Type == "Paint" then Session.PaintTargets or {} else {}
end

local function GetTargetHP(Target, Step): number
	return Target:GetAttribute(if Step.Type == "Paint" then "PaintHP" else "HP") or 0
end

local function GetTargetMaxHP(Target, Step): number
	return Target:GetAttribute(if Step.Type == "Paint" then "PaintMaxHP" else "MaxHP") or 1
end

local function GetStepProgress(Session): number
	local Step = Session.Steps[Session.StepIndex]
	local StepState = GetStepState(Session)
	if not Step or not StepState then return 0 end
	local RemovedCount = StepState.Total - StepState.Remaining
	local PartialProgress = 0
	for _, Target in GetTargets(Session) do
		local MaximumHP = GetTargetMaxHP(Target, Step)
		local CurrentHP = GetTargetHP(Target, Step)
		if MaximumHP > 0 and CurrentHP > 0 then PartialProgress += 1 - math.clamp(CurrentHP / MaximumHP, 0, 1) end
	end
	return math.clamp((RemovedCount + PartialProgress) / math.max(StepState.Total, 1), 0, 1)
end

local function UpdateProgress(Player, Session, Force)
	local Progress = GetStepProgress(Session)
	if Force or math.abs(Progress - Session.LastProgress) >= 0.005 then
		Session.LastProgress = Progress
		Player:SetAttribute("CleaningProgress", Progress)
	end
	return Progress
end

local function ClearTargets(Session)
	if Session.Dirt then Session.Dirt:Destroy(); Session.Dirt = nil end
	if Session.Grease then Session.Grease:Destroy(); Session.Grease = nil end
	if Session.PaintTargets then PaintRenderer.Clear(Session.PaintTargets); Session.PaintTargets = nil end
end

local function PrepareAllTargets(Session)
	ClearTargets(Session)
	for _, Step in Session.Steps do
		local StepState = Session.State.Steps[Step.Id]
		if Step.Type == "Paint" and StepState.Completed ~= true then
			Session.PaintTargets = PaintRenderer.Add(
				Session.Model,
				StepState.Remaining,
				Step.TargetHP,
				Step.DirtColor,
				Step.DirtAmountMinimum,
				Step.DirtAmountMaximum
			)
		end
	end
	for _, Step in Session.Steps do
		local StepState = Session.State.Steps[Step.Id]
		if Step.Type == "Grease" and StepState.Completed ~= true then
			Session.Grease = GreaseRenderer.Add(
				Session.Model,
				StepState.Remaining,
				Step.TargetHP,
				Step.PatchColor,
				Step.PatchTransparency
			)
		end
	end
	for _, Step in Session.Steps do
		local StepState = Session.State.Steps[Step.Id]
		if Step.Type == "Dirt" and StepState.Completed ~= true then
			Session.Dirt = DirtRenderer.Add(Session.Model, StepState.Remaining, Session.ItemInfo.DirtHP)
			if Session.Dirt then
				for _, Dirt in Session.Dirt:GetChildren() do
					if Dirt:IsA("BasePart") then Dirt:SetAttribute("MaxHP", Session.ItemInfo.DirtHP) end
				end
			end
		end
	end
end

local function ClearCurrentTargets(Session)
	local Step = Session.Steps[Session.StepIndex]
	if not Step then return end
	if Step.Type == "Dirt" and Session.Dirt then
		Session.Dirt:Destroy()
		Session.Dirt = nil
	elseif Step.Type == "Grease" and Session.Grease then
		Session.Grease:Destroy()
		Session.Grease = nil
	elseif Step.Type == "Paint" and Session.PaintTargets then
		PaintRenderer.Clear(Session.PaintTargets)
		Session.PaintTargets = nil
	end
end

local function PrepareCurrentStep(Player, Session)
	local Step = Session.Steps[Session.StepIndex]
	local StepState = GetStepState(Session)
	if not Step or not StepState then return end
	Session.LastProgress = -1
	Player:SetAttribute("CleaningStepName", Step.DisplayName)
	Player:SetAttribute("CleaningStepToolId", Step.ToolId)
	Player:SetAttribute("CleaningStepComplete", StepState.Completed == true)
	UpdateProgress(Player, Session, true)
	CarryController.EquipCleaningTool(Player, Step.ToolId)
end

local function PlayDirtFeedback(Session, Dirt, Now)
	local LastFeedback = Session.DirtFeedbackTimes[Dirt] or 0
	if Now - LastFeedback < CONFIG.DirtFeedbackInterval then return end
	Session.DirtFeedbackTimes[Dirt] = Now
	local OriginalSize = Dirt.Size
	local OriginalColor = Dirt.Color
	local HitSize = OriginalSize * Vector3.new(1.18, 0.82, 1.12)
	local HitColor = OriginalColor:Lerp(Color3.new(1, 1, 1), 0.7)
	local HitTween = TweenService:Create(Dirt, TweenInfo.new(CONFIG.DirtFeedbackInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = HitSize,
		Color = HitColor,
	})
	HitTween.Completed:Once(function()
		if Dirt.Parent then
			TweenService:Create(Dirt, TweenInfo.new(CONFIG.DirtFeedbackOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = OriginalSize,
				Color = OriginalColor,
			}):Play()
		end
	end)
	HitTween:Play()
	if Now - Session.LastFeedbackSound >= CONFIG.DirtFeedbackInterval then
		Session.LastFeedbackSound = Now
		local Sound = Sounds.Play(CleaningConfig.DirtDamageSoundName, Session.Model.PrimaryPart or Session.Model, CONFIG.FeedbackSoundMaxDistance)
		if Sound then Sound.Volume *= 0.45; Sound.PlaybackSpeed = Random.new():NextNumber(0.92, 1.08) end
	end
end

local function ClearSession(Player)
	local Session = Sessions[Player]
	if not Session then return end
	SaveState(Player, Session.ItemId, Session.State)
	if Session.Connection then Session.Connection:Disconnect() end
	ClearTargets(Session)
	if Session.Model then Session.Model:Destroy() end
	if Session.RootPart and Session.RootPart.Parent then Session.RootPart.Anchored = Session.RootWasAnchored end
	Sessions[Player] = nil
	Player:SetAttribute("IsFixing", false)
	Player:SetAttribute("CleaningStepName", nil)
	Player:SetAttribute("CleaningStepToolId", nil)
	Player:SetAttribute("CleaningProgress", nil)
	Player:SetAttribute("CleaningStepComplete", nil)
	CarryController.SetFixingMode(Player, false)
	if Session.Prompt and Session.Prompt.Parent then Session.Prompt.Enabled = true end
end

local function NormalizeState(State, Model, Steps)
	State.Steps = if type(State.Steps) == "table" then State.Steps else {}
	local DirtTotal = if type(State.Total) == "number" and State.Total >= 1 then math.round(State.Total) else DirtRenderer.GetSuggestedCount(Model)
	local DirtRemaining = if type(State.Remaining) == "number" then math.clamp(math.round(State.Remaining), 0, DirtTotal) else DirtTotal
	local DirtState
	for _, Step in Steps do
		local Existing = State.Steps[Step.Id]
		local Total = if Step.Type == "Dirt"
			then DirtTotal
			elseif Step.Type == "Grease" then GreaseRenderer.GetSuggestedCount(Model)
			else PaintRenderer.GetSuggestedCount(Model)
		if type(Existing) ~= "table" then
			Existing = {
				Total = Total,
				Remaining = if Step.Type == "Dirt" then DirtRemaining else Total,
				Completed = false,
			}
			State.Steps[Step.Id] = Existing
		end
		if type(Existing.Total) ~= "number" or Existing.Total < 1 then Existing.Total = Total end
		if type(Existing.Remaining) ~= "number" then Existing.Remaining = Existing.Total end
		Existing.Remaining = math.clamp(math.round(Existing.Remaining), 0, Existing.Total)
		Existing.Completed = Existing.Completed == true or Existing.Remaining <= 0
		if Step.Type == "Dirt" then DirtState = Existing end
	end
	if DirtState then
		State.Total = DirtState.Total
		State.Remaining = DirtState.Remaining
	end
	State.Completed = false
end

local function GetFirstIncompleteStep(State, Steps): number?
	for Index, Step in Steps do
		if State.Steps[Step.Id].Completed ~= true then return Index end
	end
	return nil
end

local function GetFirstAvailableIncompleteStep(Player, State, Steps): number?
	for Index, Step in Steps do
		if State.Steps[Step.Id].Completed ~= true and IsToolUnlocked(Player, Step.ToolId) then return Index end
	end
	return nil
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
	local State = Fixing[tostring(ItemId)] or { Completed = false }
	if State.Completed == true then return end
	local Steps = CleaningConfig.GetStepsForItem(Info)
	if #Steps == 0 then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	Model:SetAttribute("FixingItemOwnerUserId", Player.UserId)
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = Part ~= Box
		end
	end
	NormalizeState(State, Model, Steps)
	local StepIndex = GetFirstAvailableIncompleteStep(Player, State, Steps)
	if not GetFirstIncompleteStep(State, Steps) then State.Completed = true; SaveState(Player, ItemId, State); Model:Destroy(); return end
	if not StepIndex then Model:Destroy(); return end
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not CameraPart or not CameraPart:IsA("BasePart") then Model:Destroy(); return end
	local ItemDistance = CleaningConfig.MinimumItemCameraDistance + math.max(Box.Size.X, Box.Size.Y, Box.Size.Z) * CleaningConfig.ItemCameraDistancePerStud
	local ItemPosition = CameraPart.CFrame:PointToWorldSpace(Vector3.new(0, CleaningConfig.ItemVerticalOffset, -ItemDistance))
	Model:PivotTo(CFrame.new(ItemPosition) * PromptPart.CFrame.Rotation * CFrame.Angles(math.rad(CleaningConfig.ItemTiltDegrees), 0, 0))
	Model.Parent = Museum
	local RootWasAnchored = RootPart.Anchored
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.Anchored = true
	Player:SetAttribute("IsFixing", true)
	CarryController.SetFixingMode(Player, true, Steps[StepIndex].ToolId)
	local Session = {
		ItemId = ItemId,
		ItemInfo = Info,
		State = State,
		Steps = Steps,
		Model = Model,
		RootPart = RootPart,
		RootWasAnchored = RootWasAnchored,
		Prompt = if Prompt and Prompt:IsA("ProximityPrompt") then Prompt else nil,
		IsUsingTool = false,
		ActiveToolId = nil,
		LastApplication = os.clock(),
		CurrentRotationSpeed = CONFIG.RotationSpeed,
		DirtFeedbackTimes = {},
		LastFeedbackSound = 0,
		StepIndex = StepIndex,
		Completing = false,
		TransitionId = 0,
		LastProgress = -1,
	}
	Session.Connection = RunService.Heartbeat:Connect(function(DeltaTime)
		if not Model.Parent then return end
		local TargetRotationSpeed = if Session.IsUsingTool then 0 else CONFIG.RotationSpeed
		local Blend = 1 - math.exp(-CONFIG.RotationResponsiveness * DeltaTime)
		Session.CurrentRotationSpeed += (TargetRotationSpeed - Session.CurrentRotationSpeed) * Blend
		if math.abs(TargetRotationSpeed - Session.CurrentRotationSpeed) < math.rad(0.05) then Session.CurrentRotationSpeed = TargetRotationSpeed end
		Model:PivotTo(Model:GetPivot() * CFrame.Angles(0, Session.CurrentRotationSpeed * DeltaTime, 0))
	end)
	Sessions[Player] = Session
	if Session.Prompt then Session.Prompt.Enabled = false end
	SaveState(Player, ItemId, State)
	PrepareAllTargets(Session)
	PrepareCurrentStep(Player, Session)
	if GetStepProgress(Session) >= CleaningConfig.AutoCompletionThreshold then task.defer(CompleteCurrentStep, Player, Session) end
end

local function PlayFullCompletionFeedback(Session)
	for _, SoundName in CleaningConfig.FullCompletion.SoundNames do Sounds.Play(SoundName, Session.RootPart, CONFIG.FeedbackSoundMaxDistance) end
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
	TweenService:Create(Highlight, TweenInfo.new(CleaningConfig.FullCompletionDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(Highlight, CleaningConfig.FullCompletionDelay)
end

CompleteCurrentStep = function(Player, Session)
	if Sessions[Player] ~= Session or Session.Completing then return end
	Session.Completing = true
	Session.IsUsingTool = false
	Session.ActiveToolId = nil
	local Step = Session.Steps[Session.StepIndex]
	local StepState = GetStepState(Session)
	StepState.Remaining = 0
	StepState.Completed = true
	if Step.Type == "Dirt" then Session.State.Remaining = 0 end
	ClearCurrentTargets(Session)
	SaveState(Player, Session.ItemId, Session.State)
	Player:SetAttribute("CleaningProgress", 1)
	Player:SetAttribute("CleaningStepComplete", true)
	Sounds.Play(Step.CompletionSoundName, Session.RootPart, CONFIG.FeedbackSoundMaxDistance)
	if GetFirstIncompleteStep(Session.State, Session.Steps) then
		Session.TransitionId += 1
		local TransitionId = Session.TransitionId
		task.delay(CleaningConfig.StepTransitionDelay, function()
			if Sessions[Player] ~= Session or Session.TransitionId ~= TransitionId then return end
			local NextStepIndex = GetFirstAvailableIncompleteStep(Player, Session.State, Session.Steps)
			if not NextStepIndex then
				ClearSession(Player)
				return
			end
			Session.StepIndex = NextStepIndex
			Session.Completing = false
			PrepareCurrentStep(Player, Session)
		end)
		return
	end
	Session.State.Completed = true
	SaveState(Player, Session.ItemId, Session.State)
	PlayFullCompletionFeedback(Session)
	task.delay(CleaningConfig.FullCompletionDelay, function() if Sessions[Player] == Session then ClearSession(Player) end end)
end

function FixingController:SelectTool(Player, ToolId)
	local Session = Sessions[Player]
	local ToolInfo = if type(ToolId) == "string" then GetToolInfo(ToolId) else nil
	if not Session or not ToolInfo or not IsToolUnlocked(Player, ToolId) then return end
	local Tool = GetCleaningTool(Player, ToolId)
	if not Tool then return end
	for Index, Step in Session.Steps do
		if Step.ToolId ~= ToolId then continue end
		Session.TransitionId += 1
		Session.Completing = false
		Session.IsUsingTool = false
		Session.ActiveToolId = nil
		Session.StepIndex = Index
		Session.LastApplication = os.clock()
		PrepareCurrentStep(Player, Session)
		return
	end
	CarryController.EquipCleaningTool(Player, ToolId)
	Session.TransitionId += 1
	Session.Completing = false
	Session.IsUsingTool = false
	Session.ActiveToolId = nil
	Session.StepIndex = nil
	Player:SetAttribute("CleaningStepName", `{ToolInfo.DisplayName} Not Needed`)
	Player:SetAttribute("CleaningStepToolId", ToolId)
	Player:SetAttribute("CleaningProgress", 1)
	Player:SetAttribute("CleaningStepComplete", true)
end

function FixingController:ApplyTool(Player, ToolId, BrushPosition, ViewportSize)
	local Session = Sessions[Player]
	local Step = Session and Session.Steps[Session.StepIndex]
	local ToolInfo = if type(ToolId) == "string" then GetToolInfo(ToolId) else nil
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if not Session or Session.Completing or not Session.IsUsingTool or Session.ActiveToolId ~= ToolId or not Step or Step.ToolId ~= ToolId or not ToolInfo or not Tool
		or not IsToolUnlocked(Player, ToolId)
		or Tool.Parent ~= Player.Character
		or typeof(BrushPosition) ~= "Vector2" or typeof(ViewportSize) ~= "Vector2"
	then return end
	if ViewportSize.X < 200 or ViewportSize.Y < 200 or ViewportSize.X > 10000 or ViewportSize.Y > 10000 then return end
	if BrushPosition.X < 0 or BrushPosition.Y < 0 or BrushPosition.X > ViewportSize.X or BrushPosition.Y > ViewportSize.Y then return end
	local Museum = MuseumController.GetMuseum(Player)
	local TableModel = Museum and Museum:FindFirstChild("Table")
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not CameraPart or not CameraPart:IsA("BasePart") then return end
	local Now = os.clock()
	local StrengthMultiplier = UpgradeLogic.GetToolStrengthMultiplier(DataService:get(Player, "Upgrades"), ToolId)
	local Damage = ToolInfo.StrengthPerSecond * StrengthMultiplier * math.clamp(Now - Session.LastApplication, 0, 0.2)
	Session.LastApplication = Now
	local StepState = GetStepState(Session)
	local ProgressChanged = false
	for _, Target in GetTargets(Session) do
		local ScreenPosition = GetScreenPosition(Target.Position, CameraPart.CFrame, ViewportSize)
		if ScreenPosition and (ScreenPosition - BrushPosition).Magnitude <= ToolInfo.RadiusPixels then
			if Step.Type == "Dirt" then
				PlayDirtFeedback(Session, Target, Now)
				local HP = GetTargetHP(Target, Step) - Damage
				Target:SetAttribute("HP", HP)
				if HP <= 0 then Target:Destroy(); StepState.Remaining -= 1; Session.State.Remaining = StepState.Remaining; ProgressChanged = true end
			elseif Step.Type == "Paint" and PaintRenderer.Damage(Target, Damage, Step.DirtColor) then
				StepState.Remaining -= 1
				ProgressChanged = true
			elseif Step.Type == "Grease" and GreaseRenderer.Damage(Target, Damage) then
				StepState.Remaining -= 1
				ProgressChanged = true
			end
		end
	end
	if ProgressChanged then SaveState(Player, Session.ItemId, Session.State) end
	local Progress = UpdateProgress(Player, Session, false)
	if StepState.Remaining <= 0 or Progress >= CleaningConfig.AutoCompletionThreshold then CompleteCurrentStep(Player, Session) end
end

function FixingController:StartUsingTool(Player, ToolId)
	local Session = Sessions[Player]
	local Step = Session and Session.Steps[Session.StepIndex]
	local StepState = Session and GetStepState(Session)
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if
		not Session
		or Session.Completing
		or type(ToolId) ~= "string"
		or not Step
		or not StepState
		or StepState.Completed == true
		or Step.ToolId ~= ToolId
		or not IsToolUnlocked(Player, ToolId)
		or not Tool
		or Tool.Parent ~= Player.Character
	then
		return
	end
	Session.IsUsingTool = true
	Session.ActiveToolId = ToolId
	Session.LastApplication = os.clock()
end

function FixingController:StopUsingTool(Player)
	local Session = Sessions[Player]
	if Session then Session.IsUsingTool = false; Session.ActiveToolId = nil end
end

function FixingController:Exit(Player) ClearSession(Player) end
function FixingController.SetDataService(Service) DataService = Service end
function FixingController:Init()
	self.Networker = Networker.server.new("FixingController", self, {
		FixingController.SelectTool,
		FixingController.StartUsingTool,
		FixingController.ApplyTool,
		FixingController.StopUsingTool,
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
