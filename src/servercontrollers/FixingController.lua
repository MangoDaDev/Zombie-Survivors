local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CarryController = require(ServerStorage.Controllers.CarryController)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local EconomyConfig = require(ReplicatedStorage.Modules.Game.EconomyConfig)
local DirtRenderer = require(ReplicatedStorage.Modules.Game.DirtRenderer)
local GreaseRenderer = require(ReplicatedStorage.Modules.Game.GreaseRenderer)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local ItemInfoBillboard = require(ReplicatedStorage.Modules.UI.ItemInfoBillboard)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local MuseumController = require(ServerStorage.Controllers.MuseumController)
local Networker = require(ReplicatedStorage.Packages.networker)
local PaintRenderer = require(ReplicatedStorage.Modules.Game.PaintRenderer)
local RestorationTargetRenderer = require(ReplicatedStorage.Modules.Game.RestorationTargetRenderer)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local CONFIG = {
	RotationSpeed = math.rad(ItemInteractionConfig.FixingRotationSpeedDegrees),
	RotationResponsiveness = 5,
	FeedbackSoundMaxDistance = 50,
}
local FixingController = {}
local DataService
local Network
local Sessions = {}
local PromptConnections: { [Player]: RBXScriptConnection } = {}
local CompleteCurrentStep

local function GetInfo(ItemId)
	for _, Info in ItemsInfo do if Info.Id == ItemId then return Info end end
end

local function GetToolInfo(ToolId)
	return CleaningConfig.GetTool(ToolId)
end

local function PlaceItemOnTable(Model: Model, Box: BasePart, TableSurface: BasePart)
	local BoxOffset = Model:GetPivot():ToObjectSpace(Box.CFrame)
	local BoxRotation = TableSurface.CFrame.Rotation
		* CFrame.Angles(0, math.rad(CleaningConfig.ItemPresentationRotationDegrees), 0)
	local SurfaceNormal = TableSurface.CFrame.UpVector
	local HalfSize = Box.Size / 2
	local SupportHeight = math.abs(BoxRotation.RightVector:Dot(SurfaceNormal)) * HalfSize.X
		+ math.abs(BoxRotation.UpVector:Dot(SurfaceNormal)) * HalfSize.Y
		+ math.abs(BoxRotation.LookVector:Dot(SurfaceNormal)) * HalfSize.Z
	local SurfacePosition = TableSurface.CFrame:PointToWorldSpace(Vector3.new(0, TableSurface.Size.Y / 2, 0))
	local BoxCFrame = CFrame.fromMatrix(
		SurfacePosition + SurfaceNormal * (SupportHeight + CleaningConfig.ItemSurfaceOffset),
		BoxRotation.RightVector,
		BoxRotation.UpVector,
		-BoxRotation.LookVector
	)
	Model:PivotTo(BoxCFrame * BoxOffset:Inverse())
end

local function RotateItemAroundBoundingBox(Model: Model, Box: BasePart, SurfaceNormal: Vector3, Rotation: number)
	local BoxCenter = Box.Position
	local RotationCFrame = CFrame.fromAxisAngle(SurfaceNormal, Rotation)
	Model:PivotTo(CFrame.new(BoxCenter) * RotationCFrame * CFrame.new(-BoxCenter) * Model:GetPivot())
end

local function IsToolUnlocked(Player, ToolId): boolean
	return UpgradeLogic.IsToolUnlocked(DataService:get(Player, "Upgrades"), ToolId)
end

local function ShowToolRequirement(Player, ToolId)
	local ToolInfo = GetToolInfo(ToolId)
	local Upgrade = UpgradeLogic.GetToolUnlockUpgrade(ToolId)
	local DisplayName = if ToolInfo then ToolInfo.DisplayName else ToolId
	GuidanceController.Show(Player, `Use {DisplayName}`, nil, if Upgrade then `Upgrade:{Upgrade.Id}` else nil)
end

local function SaveState(Player, ItemId, State)
	local Fixing = DataService:get(Player, "Fixing") or {}
	Fixing[tostring(ItemId)] = State
	DataService:set(Player, "Fixing", Fixing)
end

local function CompleteRestorationState(Player, ItemId, ItemInfo, State)
	State.Completed = true
	if State.CompletionRewardClaimed == true then
		SaveState(Player, ItemId, State)
		return
	end
	State.CompletionRewardClaimed = true
	SaveState(Player, ItemId, State)
	local Reward = EconomyConfig.GetRestorationReward(ItemInfo.Rarity, ItemInfo.Price)
	DataService:update(Player, "Cash", function(Cash)
		return (if type(Cash) == "number" then Cash else 0) + Reward
	end)
end

local function GetCleaningTool(Player, ToolId): Tool?
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if not Container then continue end
		for _, Child in Container:GetChildren() do
			local ToolInfo = ToolResolver.GetCleaningToolInfo(Child)
			if ToolInfo and ToolInfo.Id == ToolId then return Child end
		end
	end
	return nil
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
	if Step and Step.Type == "Paint" then return Session.PaintTargets or {} end
	return if Step then Session.RestorationTargets[Step.Id] or {} else {}
end

local function GetTargetHP(Target, Step): number
	if Step.Type == "Paint" then
		return PaintRenderer.GetHealth(Target)
	elseif Step.Type == "Grease" then
		return GreaseRenderer.GetHealth(Target)
	elseif Step.Type ~= "Dirt" then
		return RestorationTargetRenderer.GetHealth(Target)
	end

	return DirtRenderer.GetHealth(Target)
end

local function GetTargetMaxHP(Target, Step): number
	local _, MaximumHealth

	if Step.Type == "Paint" then
		_, MaximumHealth = PaintRenderer.GetHealth(Target)
	elseif Step.Type == "Grease" then
		_, MaximumHealth = GreaseRenderer.GetHealth(Target)
	elseif Step.Type ~= "Dirt" then
		_, MaximumHealth = RestorationTargetRenderer.GetHealth(Target)
	else
		_, MaximumHealth = DirtRenderer.GetHealth(Target)
	end

	return MaximumHealth
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
		PlayerStateController.Set(Player, "CleaningProgress", Progress)
	end
	return Progress
end

local function ClearTargets(Session)
	if Session.Dirt then Session.Dirt:Destroy(); Session.Dirt = nil end
	if Session.Grease then Session.Grease:Destroy(); Session.Grease = nil end
	if Session.PaintTargets then PaintRenderer.Clear(Session.PaintTargets); Session.PaintTargets = nil end
	Session.RestorationTargets = {}
end

local function PrepareAllTargets(Session)
	ClearTargets(Session)
	Session.RestorationTargets = {}
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
			local RenderedCount = if Session.Grease then #Session.Grease:GetChildren() else 0
			local CompletedCount = math.max(0, StepState.Total - StepState.Remaining)
			StepState.Total = CompletedCount + RenderedCount
			StepState.Remaining = RenderedCount
		end
	end
	for _, Step in Session.Steps do
		local StepState = Session.State.Steps[Step.Id]
		if Step.Type == "Dirt" and StepState.Completed ~= true then
			Session.Dirt = DirtRenderer.Add(Session.Model, StepState.Remaining, Session.ItemInfo.DirtHP)
			local RenderedCount = if Session.Dirt then #Session.Dirt:GetChildren() else 0
			local CompletedCount = math.max(0, StepState.Total - StepState.Remaining)
			StepState.Total = CompletedCount + RenderedCount
			StepState.Remaining = RenderedCount
		end
	end
	for _, Step in Session.Steps do
		if Step.Type == "Dirt" or Step.Type == "Grease" or Step.Type == "Paint" or Step.Type == "Polish" then continue end
		local StepState = Session.State.Steps[Step.Id]
		if StepState.Completed == true then continue end
		local Targets = RestorationTargetRenderer.Add(Session.Model, Step.Type, StepState.Remaining, Step.TargetHP, Step)
		Session.RestorationTargets[Step.Id] = Targets
		local CompletedCount = math.max(0, StepState.Total - StepState.Remaining)
		StepState.Total = CompletedCount + #Targets
		StepState.Remaining = #Targets
	end
end

local function RestoreCompletedBentTargets(Session)
	for _, Target in Session.RestoredBentTargets do
		RestorationTargetRenderer.Restore(Session.Model, Target)
	end
end

local function PrepareCurrentPolishTargets(Session, Step, StepState)
	if Step.Type ~= "Polish" or Session.RestorationTargets[Step.Id] then return end
	local Targets = RestorationTargetRenderer.Add(Session.Model, Step.Type, StepState.Remaining, Step.TargetHP, Step)
	Session.RestorationTargets[Step.Id] = Targets
	local CompletedCount = math.max(0, StepState.Total - StepState.Remaining)
	StepState.Total = CompletedCount + #Targets
	StepState.Remaining = #Targets
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
	elseif Session.RestorationTargets and Session.RestorationTargets[Step.Id] then
		for _, Target in Session.RestorationTargets[Step.Id] do
			if not Target.Parent then continue end
			if Step.Type == "Bent" then
				RestorationTargetRenderer.Restore(Session.Model, Target)
				table.insert(Session.RestoredBentTargets, Target)
			elseif Step.Type == "Polish" then
				RestorationTargetRenderer.Restore(Session.Model, Target)
			elseif Step.Type == "LightDust" or Step.Type == "LooseDebris" or Step.Type == "Metal" then
				Target:Destroy()
			end
		end
		Session.RestorationTargets[Step.Id] = nil
	end
end

local function PrepareCurrentStep(Player, Session)
	local Step = Session.Steps[Session.StepIndex]
	local StepState = GetStepState(Session)
	if not Step or not StepState then return end
	-- Completed Hammer work must remain aligned through every later stage.
	RestoreCompletedBentTargets(Session)
	-- Prepare the dull finish before equipping the Polisher; input only improves it.
	PrepareCurrentPolishTargets(Session, Step, StepState)
	Session.LastProgress = -1
	PlayerStateController.Set(Player, "CleaningStepName", Step.DisplayName)
	PlayerStateController.Set(Player, "CleaningStepTotal", StepState.Total)
	PlayerStateController.Set(Player, "CleaningStepRemaining", StepState.Remaining)
	PlayerStateController.Set(Player, "CleaningStepToolId", Step.ToolId)
	PlayerStateController.Set(Player, "CleaningStepComplete", StepState.Completed == true)
	UpdateProgress(Player, Session, true)
	CarryController.EquipCleaningTool(Player, Step.ToolId)
end

local function ClearSession(Player)
	local Session = Sessions[Player]
	if not Session then return end
	SaveState(Player, Session.ItemId, Session.State)
	if Session.Connection then Session.Connection:Disconnect() end
	if Session.CharacterConnection then Session.CharacterConnection:Disconnect() end
	if Session.HumanoidDiedConnection then Session.HumanoidDiedConnection:Disconnect() end
	ClearTargets(Session)
	if Session.Model then Session.Model:Destroy() end
	if Session.RootPart and Session.RootPart.Parent then Session.RootPart.Anchored = Session.RootWasAnchored end
	if Session.Humanoid and Session.Humanoid.Parent then
		Session.Humanoid.AutoRotate = Session.HumanoidAutoRotate
		Session.Humanoid.WalkSpeed = Session.HumanoidWalkSpeed
		Session.Humanoid.JumpPower = Session.HumanoidJumpPower
		Session.Humanoid.JumpHeight = Session.HumanoidJumpHeight
	end
	Sessions[Player] = nil
	PlayerStateController.Set(Player, "IsFixing", false)
	PlayerStateController.Set(Player, "CleaningStepName", nil)
	PlayerStateController.Set(Player, "CleaningStepToolId", nil)
	PlayerStateController.Set(Player, "CleaningProgress", nil)
	PlayerStateController.Set(Player, "CleaningStepComplete", nil)
	PlayerStateController.Set(Player, "CleaningItemId", nil)
	PlayerStateController.Set(Player, "CleaningStepTotal", nil)
	PlayerStateController.Set(Player, "CleaningStepRemaining", nil)
	PlayerStateController.Set(Player, "CleaningRestorationComplete", nil)
	CarryController.SetFixingMode(Player, false)
	if Session.Prompt and Session.Prompt.Parent then Session.Prompt.Enabled = true end
end

local function NormalizeState(State, Model, Steps)
	State.Steps = if type(State.Steps) == "table" then State.Steps else {}
	local DirtTotal = DirtRenderer.GetSuggestedCount(Model)
	local PreviousDirtTotal = if type(State.Total) == "number" and State.Total >= 1 then math.round(State.Total) else DirtTotal
	local PreviousDirtRemaining = if type(State.Remaining) == "number" then math.clamp(State.Remaining, 0, PreviousDirtTotal) else PreviousDirtTotal
	local DirtRemaining = math.round(DirtTotal * PreviousDirtRemaining / math.max(PreviousDirtTotal, 1))
	local DirtState
	for _, Step in Steps do
		local Existing = State.Steps[Step.Id]
		local Total = if Step.Type == "Dirt"
			then DirtTotal
			elseif Step.Type == "Grease" then GreaseRenderer.GetSuggestedCount(Model)
			elseif Step.Type == "Paint" then PaintRenderer.GetSuggestedCount(Model)
			else RestorationTargetRenderer.GetSuggestedCount(Model, Step.Type)
		if type(Existing) ~= "table" then
			Existing = {
				Total = Total,
				Remaining = if Step.Type == "Dirt" then DirtRemaining else Total,
				Completed = false,
			}
			State.Steps[Step.Id] = Existing
		end
		if type(Existing.Total) == "number" and Existing.Total >= 1 and Existing.Total ~= Total then
			local PreviousRemaining = if type(Existing.Remaining) == "number" then math.clamp(Existing.Remaining, 0, Existing.Total) else Existing.Total
			Existing.Remaining = math.round(Total * PreviousRemaining / Existing.Total)
			Existing.Total = Total
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

local function GetFirstMissingToolStep(Player, State, Steps)
	for _, Step in Steps do
		if State.Steps[Step.Id].Completed ~= true and not IsToolUnlocked(Player, Step.ToolId) then return Step end
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
	if not ItemId or not Info then
		GuidanceController.Show(Player, "Equip An Item")
		return
	end
	if not PromptPart or not PromptPart:IsA("BasePart") then return end
	local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Inventory = DataService:get(Player, "Inventory")
	if not RootPart or not RootPart:IsA("BasePart") or (RootPart.Position - PromptPart.Position).Magnitude > 13 or type(Inventory) ~= "table" or table.find(Inventory, ItemId) == nil then return end
	local Template = ReplicatedStorage.Assets.Models.Items:FindFirstChild(Info.AssetName)
	if not Template or not Template:IsA("Model") then return end
	local Fixing = DataService:get(Player, "Fixing") or {}
	local State = Fixing[tostring(ItemId)] or { Completed = false }
	if State.Completed == true then
		GuidanceController.Show(Player, "Ready To Display")
		return
	end
	local Steps = CleaningConfig.GetStepsForItem(Info)
	if #Steps == 0 then return end
	local Model = Template:Clone()
	local Box = Model:FindFirstChild("BoundingBox")
	if not Box or not Box:IsA("BasePart") then Model:Destroy(); return end
	Model.PrimaryPart = Box
	Model.Name = `FixingItem_{Player.UserId}`
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = Part ~= Box
		end
	end
	NormalizeState(State, Model, Steps)
	local StepIndex = GetFirstIncompleteStep(State, Steps)
	if not StepIndex then
		CompleteRestorationState(Player, ItemId, Info, State)
		Model:Destroy()
		GuidanceController.Advance(Player, "CleanThis")
		GuidanceController.Show(Player, "Ready To Display")
		return
	end
	-- Require every remaining tool before entering fixing so the player cannot get stuck midway.
	local MissingToolStep = GetFirstMissingToolStep(Player, State, Steps)
	if MissingToolStep then
		Model:Destroy()
		ShowToolRequirement(Player, MissingToolStep.ToolId)
		return
	end
	local CameraPart = TableModel and TableModel:FindFirstChild("CamPart")
	if not CameraPart or not CameraPart:IsA("BasePart") then Model:Destroy(); return end
	PlaceItemOnTable(Model, Box, PromptPart)
	Model.Parent = Museum
	-- Keep the standard item billboard hidden while the player is actively fixing the item.
	local RootWasAnchored = RootPart.Anchored
	local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then Model:Destroy(); return end
	local HumanoidAutoRotate = Humanoid.AutoRotate
	local HumanoidWalkSpeed = Humanoid.WalkSpeed
	local HumanoidJumpPower = Humanoid.JumpPower
	local HumanoidJumpHeight = Humanoid.JumpHeight
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.Anchored = true
	Humanoid.AutoRotate = false
	Humanoid.WalkSpeed = 0
	Humanoid.JumpPower = 0
	Humanoid.JumpHeight = 0
	PlayerStateController.Set(Player, "CleaningItemId", ItemId)
	PlayerStateController.Set(Player, "IsFixing", true)
	CarryController.SetFixingMode(Player, true, Steps[StepIndex].ToolId)
	local Session = {
		ItemId = ItemId,
		ItemInfo = Info,
		State = State,
		Steps = Steps,
		Model = Model,
		RootPart = RootPart,
		RootWasAnchored = RootWasAnchored,
		Humanoid = Humanoid,
		HumanoidAutoRotate = HumanoidAutoRotate,
		HumanoidWalkSpeed = HumanoidWalkSpeed,
		HumanoidJumpPower = HumanoidJumpPower,
		HumanoidJumpHeight = HumanoidJumpHeight,
		Prompt = if Prompt and Prompt:IsA("ProximityPrompt") then Prompt else nil,
		IsUsingTool = false,
		ActiveToolId = nil,
		CurrentRotationSpeed = CONFIG.RotationSpeed,
		StepIndex = StepIndex,
		Completing = false,
		TransitionId = 0,
		LastProgress = -1,
		RestoredBentTargets = {},
	}
	Session.Connection = RunService.Heartbeat:Connect(function(DeltaTime)
		if not Model.Parent or not RootPart.Parent or Humanoid.Health <= 0 then task.defer(ClearSession, Player); return end
		local TargetRotationSpeed = if Session.IsUsingTool then 0 else CONFIG.RotationSpeed
		local Blend = 1 - math.exp(-CONFIG.RotationResponsiveness * DeltaTime)
		Session.CurrentRotationSpeed += (TargetRotationSpeed - Session.CurrentRotationSpeed) * Blend
		if math.abs(TargetRotationSpeed - Session.CurrentRotationSpeed) < math.rad(0.05) then Session.CurrentRotationSpeed = TargetRotationSpeed end
		RotateItemAroundBoundingBox(Model, Box, PromptPart.CFrame.UpVector, Session.CurrentRotationSpeed * DeltaTime)
	end)
	Session.CharacterConnection = Player.CharacterRemoving:Connect(function(RemovingCharacter)
		if RemovingCharacter == RootPart.Parent then task.defer(ClearSession, Player) end
	end)
	Session.HumanoidDiedConnection = Humanoid.Died:Connect(function() task.defer(ClearSession, Player) end)
	Sessions[Player] = Session
	if Session.Prompt then Session.Prompt.Enabled = false end
	PrepareAllTargets(Session)
	SaveState(Player, ItemId, State)
	PrepareCurrentStep(Player, Session)
	GuidanceController.Advance(Player, "StartCleaning")
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

local function PlayNameRevealFeedback(Session)
	local PrimaryPart = Session.Model.PrimaryPart
	if not PrimaryPart then
		return
	end

	local Billboard = ItemInfoBillboard(Session.ItemInfo, PrimaryPart, Session.State)
	local NameLabel = Billboard:FindFirstChild("ItemName")
	local RarityLabel
	if NameLabel and NameLabel:IsA("TextLabel") then
		RarityLabel = NameLabel:Clone()
		RarityLabel.Name = "Rarity"
		RarityLabel.Position = UDim2.fromScale(0, 0.28)
		RarityLabel.Size = UDim2.fromScale(1, 0.12)
		RarityLabel.Text = Session.ItemInfo.Rarity
		RarityLabel.Parent = Billboard
	end
	local RevealOrder = { NameLabel, RarityLabel }
	local GuestIncomeRow
	local ValueRow
	for _, Child in Billboard:GetChildren() do
		if Child:IsA("Frame") then
			Child.Visible = false
			if Child.Position.Y.Scale < 0.5 then
				GuestIncomeRow = Child
				Child.Position = UDim2.fromScale(0, 0.4)
			else
				ValueRow = Child
				Child.Position = UDim2.fromScale(0, 0.75)
			end
		end
	end
	table.insert(RevealOrder, ValueRow)
	table.insert(RevealOrder, GuestIncomeRow)
	for Index, GuiObject in RevealOrder do
		if not GuiObject then continue end
		GuiObject.Visible = false
		task.delay((Index - 1) * 0.2, function()
			if GuiObject.Parent then GuiObject.Visible = true end
		end)
	end
	if NameLabel and NameLabel:IsA("TextLabel") then
		local Scale = Instance.new("UIScale")
		Scale.Scale = 0.2
		Scale.Parent = NameLabel
		NameLabel.Rotation = -7
		NameLabel.TextTransparency = 1
		local Stroke = NameLabel:FindFirstChildOfClass("UIStroke")
		if Stroke then
			Stroke.Transparency = 1
			TweenService:Create(Stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 }):Play()
		end
		TweenService:Create(NameLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0,
			TextTransparency = 0,
		}):Play()
		TweenService:Create(Scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	local RarityTemplates = { Secret = "Omniscient" }
	local RarityConfig = RarityInfo.Get(Session.ItemInfo.Rarity)
	local RevealSoundName = if RarityConfig.Intensity >= 1.65 then "Reward5" elseif RarityConfig.Intensity >= 1.2 then "Reward4" elseif RarityConfig.Intensity >= 1.05 then "Reward3" else "Reward2"
	Sounds.Play(RevealSoundName, Session.RootPart, CONFIG.FeedbackSoundMaxDistance)

	local PinwheelFolder = ReplicatedStorage.Assets.VFX:FindFirstChild("RarityPinwheels")
	local TemplateName = RarityTemplates[Session.ItemInfo.Rarity] or Session.ItemInfo.Rarity
	local Template = PinwheelFolder and PinwheelFolder:FindFirstChild(TemplateName)
	if Template and Template:IsA("Attachment") then
		local Effect = Template:Clone()
		Effect.Name = "NameRevealEffect"
		Effect.Parent = PrimaryPart
		local MaximumLifetime = 0
		for _, Emitter in Effect:GetDescendants() do
			if Emitter:IsA("ParticleEmitter") then
				Emitter.Enabled = false
				Emitter:Emit(if RarityConfig.Intensity >= 1.4 then 2 else 1)
				MaximumLifetime = math.max(MaximumLifetime, Emitter.Lifetime.Max)
			end
		end
		Debris:AddItem(Effect, MaximumLifetime + 0.5)
	end

	local Highlight = Instance.new("Highlight")
	Highlight.Name = "NameRevealHighlight"
	Highlight.FillColor = RarityConfig.Color
	Highlight.FillTransparency = 0.05
	Highlight.OutlineColor = Color3.new(1, 1, 1)
	Highlight.OutlineTransparency = 0
	Highlight.Parent = Session.Model
	TweenService:Create(Highlight, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(Highlight, 0.85)
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
	PlayerStateController.Set(Player, "CleaningProgress", 1)
	PlayerStateController.Set(Player, "CleaningStepComplete", true)
	Sounds.Play(Step.CompletionSoundName, Session.RootPart, CONFIG.FeedbackSoundMaxDistance)
	if GetFirstIncompleteStep(Session.State, Session.Steps) then
		Session.TransitionId += 1
		local TransitionId = Session.TransitionId
		task.delay(CleaningConfig.StepTransitionDelay, function()
			if Sessions[Player] ~= Session or Session.TransitionId ~= TransitionId then return end
			local NextStepIndex = GetFirstAvailableIncompleteStep(Player, Session.State, Session.Steps)
			if not NextStepIndex then
				local RequiredStepIndex = GetFirstIncompleteStep(Session.State, Session.Steps)
				local RequiredStep = RequiredStepIndex and Session.Steps[RequiredStepIndex]
				ClearSession(Player)
				if RequiredStep then ShowToolRequirement(Player, RequiredStep.ToolId) end
				return
			end
			Session.StepIndex = NextStepIndex
			Session.Completing = false
			PrepareCurrentStep(Player, Session)
		end)
		return
	end
	CompleteRestorationState(Player, Session.ItemId, Session.ItemInfo, Session.State)
	PlayerStateController.Set(Player, "CleaningRestorationComplete", true)
	GuidanceController.Advance(Player, "CleanThis")
	GuidanceController.Show(Player, "Ready To Display")
	PlayFullCompletionFeedback(Session)
	PlayNameRevealFeedback(Session)
	task.delay(CleaningConfig.FullCompletionDelay, function() if Sessions[Player] == Session then ClearSession(Player) end end)
end

function FixingController.SelectTool(_, Player, ToolId)
	local Session = Sessions[Player]
	local ToolInfo = if type(ToolId) == "string" then GetToolInfo(ToolId) else nil
	if not Session or not ToolInfo then return end
	if not IsToolUnlocked(Player, ToolId) then ShowToolRequirement(Player, ToolId); return end
	local Tool = GetCleaningTool(Player, ToolId)
	if not Tool then return end
	for Index, Step in Session.Steps do
		if Step.ToolId ~= ToolId then continue end
		if Session.StepIndex == Index then
			CarryController.EquipCleaningTool(Player, ToolId)
			return
		end
		Session.TransitionId += 1
		Session.Completing = false
		Session.IsUsingTool = false
		Session.ActiveToolId = nil
		Session.StepIndex = Index
		PrepareCurrentStep(Player, Session)
		return
	end
	CarryController.EquipCleaningTool(Player, ToolId)
	Session.TransitionId += 1
	Session.Completing = false
	Session.IsUsingTool = false
	Session.ActiveToolId = nil
	Session.StepIndex = nil
	PlayerStateController.Set(Player, "CleaningStepName", `{ToolInfo.DisplayName} Not Needed`)
	PlayerStateController.Set(Player, "CleaningStepToolId", ToolId)
	PlayerStateController.Set(Player, "CleaningProgress", 1)
	PlayerStateController.Set(Player, "CleaningStepComplete", true)
end

function FixingController.ReportProgress(_, Player, ToolId, Remaining)
	local Session = Sessions[Player]
	local Step = Session and Session.Steps[Session.StepIndex]
	local StepState = Session and GetStepState(Session)
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if not Session or Session.Completing or not Step or not StepState or Step.ToolId ~= ToolId or not Tool
		or not IsToolUnlocked(Player, ToolId)
		or Tool.Parent ~= Player.Character
		or type(Remaining) ~= "number"
		or Remaining ~= Remaining
		or math.abs(Remaining) == math.huge
	then return end
	local ResolvedRemaining = math.clamp(math.round(Remaining), 0, StepState.Remaining)
	if ResolvedRemaining == StepState.Remaining then return end
	StepState.Remaining = ResolvedRemaining
	if Step.Type == "Dirt" then Session.State.Remaining = ResolvedRemaining end
	PlayerStateController.Set(Player, "CleaningStepRemaining", ResolvedRemaining)
	SaveState(Player, Session.ItemId, Session.State)
end

function FixingController.CompleteStep(_, Player, ToolId)
	-- Assisted completion happens after input use ends at the configured threshold, so equipped-tool validation is sufficient here.
	local Session = Sessions[Player]
	local Step = Session and Session.Steps[Session.StepIndex]
	local StepState = Session and GetStepState(Session)
	local Tool = Step and GetCleaningTool(Player, Step.ToolId)
	if not Session or Session.Completing or not Step or not StepState or Step.ToolId ~= ToolId
		or not IsToolUnlocked(Player, ToolId)
		or not Tool or Tool.Parent ~= Player.Character
	then return end
	CompleteCurrentStep(Player, Session)
end

function FixingController.StartUsingTool(_, Player, ToolId)
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
	GuidanceController.Advance(Player, "UseTool")
end

function FixingController.StopUsingTool(_, Player)
	local Session = Sessions[Player]
	if Session then Session.IsUsingTool = false; Session.ActiveToolId = nil end
end

function FixingController.Exit(_, Player)
	ClearSession(Player)
end

function FixingController.SetDataService(Service) DataService = Service end

function FixingController.Init()
	Network = Networker.server.new("FixingController", FixingController, {
		FixingController.SelectTool,
		FixingController.StartUsingTool,
		FixingController.ReportProgress,
		FixingController.CompleteStep,
		FixingController.StopUsingTool,
		FixingController.Exit,
	})
end

function FixingController.OnPlayerAdded(Player)
	PlayerStateController.Set(Player, "IsFixing", false)
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

function FixingController.OnCharacterAdded(Player)
	if Sessions[Player] then ClearSession(Player) end
end

return FixingController
