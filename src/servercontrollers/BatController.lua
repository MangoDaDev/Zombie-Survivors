local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local CrateController = require(ServerStorage.Controllers.CrateController)
local CarryController = require(ServerStorage.Controllers.CarryController)
local GuidanceController = require(ServerStorage.Controllers.GuidanceController)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local Networker = require(ReplicatedStorage.Packages.networker)
local PlayerStateController = require(ServerStorage.Controllers.PlayerStateController)
local ToolResolver = require(ReplicatedStorage.Modules.Game.ToolResolver)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)

local BatController = {}
local DataService
local Network
local PlayerConnections: { [Player]: RBXScriptConnection } = {}
local UpgradeConnections: { [Player]: RBXScriptConnection } = {}
local LastSwings: { [Player]: number } = {}
local PositionHistory: { [Player]: { { Time: number, CFrame: CFrame } } } = {}
local LastPositionSamples: { [Player]: number } = {}
local LastPlayerHits: { [Player]: { [Player]: number } } = {}
local ProtectedUntil: { [Player]: number } = {}
local StunStates: { [Player]: any } = {}
local MaximumValidationHistoryWindow = 0
local MinimumValidationSampleInterval = math.huge

for _, Info in BatInfo do
	MaximumValidationHistoryWindow = math.max(MaximumValidationHistoryWindow, Info.ValidationHistoryWindow)
	MinimumValidationSampleInterval = math.min(MinimumValidationSampleInterval, Info.ValidationSampleInterval)
end

local function GetBatInfo(BatId)
	for _, Info in BatInfo do
		if Info.Id == BatId then return Info end
	end
end

local function RemoveBats(Player)
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if not Container then continue end
		for _, Child in Container:GetChildren() do
			if ToolResolver.GetBatInfo(Child) then Child:Destroy() end
		end
	end
end

local function EnsureBat(Player)
	if Player.Parent ~= Players or PlayerStateController.Get(Player, "IsFixing", false) == true then return end
	local Ownership = DataService:get(Player, "Upgrades")
	local Info = GetBatInfo(UpgradeLogic.GetBatId(Ownership)) or BatInfo[1]
	local CooldownMultiplier = UpgradeLogic.GetBatCooldownMultiplier(Ownership)
	local MatchingBat
	for _, Container in { Player.Character, Player:FindFirstChildOfClass("Backpack") } do
		if Container then
			for _, Child in Container:GetChildren() do
				local ChildInfo = ToolResolver.GetBatInfo(Child)
				if ChildInfo then
					if ChildInfo.Id == Info.Id and not MatchingBat then
						MatchingBat = Child
					else
						Child:Destroy()
					end
				end
			end
		end
	end
	if MatchingBat then
		MatchingBat.TextureId = Images[Info.Icon] or ""
		return
	end
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	local Template = ReplicatedStorage.Assets.Tools:FindFirstChild(Info.TemplateName)
	if not Backpack or not Template or not Template:IsA("Tool") then return end
	local Tool = Template:Clone()
	Tool.Name = Info.DisplayName
	Tool.CanBeDropped = false
	Tool.TextureId = Images[Info.Icon] or ""
	Tool:AddTag("satchelSlot")
	Tool.Parent = Backpack
end

local function IsCFrameInRange(OriginCFrame, TargetPosition, Info): boolean
	local Offset = TargetPosition - OriginCFrame.Position
	local Distance = Offset.Magnitude
	if Distance > Info.Range + Info.ValidationDistanceBuffer then return false end
	if Distance <= 0.01 then return true end
	return OriginCFrame.LookVector:Dot(Offset.Unit) >= Info.MinimumFacingDot
end

local function IsTargetInRange(Player, RootPart, TargetPosition, Info, Now): boolean
	if IsCFrameInRange(RootPart.CFrame, TargetPosition, Info) then return true end
	for _, Snapshot in PositionHistory[Player] or {} do
		if Now - Snapshot.Time <= Info.ValidationHistoryWindow and IsCFrameInRange(Snapshot.CFrame, TargetPosition, Info) then
			return true
		end
	end
	return false
end

local function RecordPositions(Now)
	for _, Player in Players:GetPlayers() do
		if Now - (LastPositionSamples[Player] or 0) < MinimumValidationSampleInterval then continue end
		LastPositionSamples[Player] = Now
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not RootPart or not RootPart:IsA("BasePart") then
			PositionHistory[Player] = nil
			continue
		end
		local History = PositionHistory[Player] or {}
		PositionHistory[Player] = History
		table.insert(History, { Time = Now, CFrame = RootPart.CFrame })
		while History[1] and Now - History[1].Time > MaximumValidationHistoryWindow do
			table.remove(History, 1)
		end
	end
end

local function ClearStun(Player: Player, RestoreCharacter: boolean, UpdatePlayerState: boolean?)
	local State = StunStates[Player]
	if UpdatePlayerState ~= false then PlayerStateController.Set(Player, "IsPvpStunned", false) end
	if not State then return end
	StunStates[Player] = nil
	if not RestoreCharacter or Player.Character ~= State.Character then return end
	if State.Humanoid.Parent and State.Humanoid.Health > 0 then
		State.Humanoid.PlatformStand = State.PlatformStand
		State.Humanoid.AutoRotate = State.AutoRotate
		State.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if State.RootPart.Parent then State.RootPart:SetNetworkOwnershipAuto() end
end

local function HasClearHitPath(AttackerCharacter: Model, TargetCharacter: Model, Origin: Vector3, Target: Vector3): boolean
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = { AttackerCharacter, TargetCharacter }
	Parameters.IgnoreWater = true
	return Workspace:Raycast(Origin, Target - Origin, Parameters) == nil
end

local function GetCrateImpact(Model: Model, Origin: Vector3)
	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Include
	Parameters.FilterDescendantsInstances = { Model }
	Parameters.IgnoreWater = true
	local TargetPosition = Model:GetPivot().Position
	local Direction = TargetPosition - Origin
	local Result = if Direction.Magnitude > 0.01 then Workspace:Raycast(Origin, Direction.Unit * (Direction.Magnitude + 8), Parameters) else nil
	if Result then
		return TargetPosition, Result.Normal, Result.Instance.Color, Result.Instance.Material
	end
	local Part = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
	if not Part then return TargetPosition, Vector3.yAxis, Color3.fromRGB(125, 90, 62), Enum.Material.Wood end
	local Normal = Origin - Part.Position
	return TargetPosition, if Normal.Magnitude > 0.01 then Normal.Unit else Vector3.yAxis, Part.Color, Part.Material
end

local function HitPlayer(Attacker: Player, TargetPlayer: Player, AttackerRoot: BasePart, Info, Now: number)
	if Attacker == TargetPlayer or Now < (ProtectedUntil[TargetPlayer] or 0) then return end
	local AttackerCharacter = Attacker.Character
	local TargetCharacter = TargetPlayer.Character
	local TargetRoot = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart")
	local TargetHumanoid = TargetCharacter and TargetCharacter:FindFirstChildOfClass("Humanoid")
	if not AttackerCharacter or not TargetCharacter or not TargetRoot or not TargetRoot:IsA("BasePart") or not TargetHumanoid or TargetHumanoid.Health <= 0 then return end
	if TargetRoot.Anchored or PlayerStateController.Get(TargetPlayer, "IsFixing", false) == true then return end
	if (TargetRoot.Position - AttackerRoot.Position).Magnitude > ItemInteractionConfig.PvpMaximumHitDistance then return end
	if not IsTargetInRange(Attacker, AttackerRoot, TargetRoot.Position, Info, Now) then return end
	if not HasClearHitPath(AttackerCharacter, TargetCharacter, AttackerRoot.Position, TargetRoot.Position) then return end

	local Hits = LastPlayerHits[Attacker] or {}
	LastPlayerHits[Attacker] = Hits
	if Now - (Hits[TargetPlayer] or 0) < ItemInteractionConfig.PvpHitCooldown then return end
	Hits[TargetPlayer] = Now
	ProtectedUntil[TargetPlayer] = Now + ItemInteractionConfig.PvpProtectionDuration
	CarryController.DropCarriedItem(TargetPlayer)

	ClearStun(TargetPlayer, true)
	local State = {
		AutoRotate = TargetHumanoid.AutoRotate,
		Character = TargetCharacter,
		Humanoid = TargetHumanoid,
		PlatformStand = TargetHumanoid.PlatformStand,
		RootPart = TargetRoot,
	}
	StunStates[TargetPlayer] = State
	PlayerStateController.Set(TargetPlayer, "IsPvpStunned", true)
	-- PvP is displacement-only: the server applies a temporary physics stun and never damages health.
	TargetHumanoid.AutoRotate = false
	TargetHumanoid.PlatformStand = true
	TargetHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
	TargetRoot:SetNetworkOwner(nil)
	local Direction = TargetRoot.Position - AttackerRoot.Position
	local FlatDirection = Vector3.new(Direction.X, 0, Direction.Z)
	if FlatDirection.Magnitude <= 0.01 then FlatDirection = AttackerRoot.CFrame.LookVector end
	local Knockback = FlatDirection.Unit * ItemInteractionConfig.BatKnockbackSpeed
		+ Vector3.new(0, ItemInteractionConfig.BatKnockbackUpwardSpeed, 0)
	if Knockback.Magnitude > ItemInteractionConfig.MaximumKnockbackSpeed then
		Knockback = Knockback.Unit * ItemInteractionConfig.MaximumKnockbackSpeed
	end
	TargetRoot.AssemblyLinearVelocity = Knockback
	task.delay(ItemInteractionConfig.RagdollDuration, function()
		if StunStates[TargetPlayer] == State then ClearStun(TargetPlayer, true) end
	end)
end

function BatController.Swing(_, Player, Targets)
	if type(Targets) ~= "table" or #Targets > 16
		or PlayerStateController.Get(Player, "IsFixing", false) == true
		or PlayerStateController.Get(Player, "IsPvpStunned", false) == true
	then return end
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local Tool = Character and Character:FindFirstChildOfClass("Tool")
	local Info = ToolResolver.GetBatInfo(Tool)
	local BatId = Info and Info.Id
	local Ownership = DataService:get(Player, "Upgrades")
	local OwnedBatId = UpgradeLogic.GetBatId(Ownership)
	local CooldownMultiplier = UpgradeLogic.GetBatCooldownMultiplier(Ownership)
	if not RootPart or not RootPart:IsA("BasePart") or not Info or BatId ~= OwnedBatId then return end
	local Now = os.clock()
	local MinimumServerCooldown = math.max(
		0,
		Info.SwingCooldown * CooldownMultiplier * Info.ServerCooldownFactor - Info.ServerCooldownLeeway
	)
	if Now - (LastSwings[Player] or 0) < MinimumServerCooldown then return end
	LastSwings[Player] = Now
	local HitTargets = {}
	for _, TargetData in Targets do
		local Target = if type(TargetData) == "table" then TargetData.Model else TargetData
		local PredictionId = if type(TargetData) == "table" then TargetData.PredictionId else nil
		if typeof(Target) ~= "Instance" or HitTargets[Target] then continue end
		if PredictionId ~= nil and (type(PredictionId) ~= "string" or #PredictionId > 64) then continue end
		HitTargets[Target] = true
		if Target:IsA("Model") and Target:HasTag("Crate") then
			if DataService:get(Player, "TutorialStep") == "PickUpItem" then
				local TutorialCrate = GuidanceController.GetTutorialCrateForPlayer(Player)
				if Target ~= TutorialCrate then
					if TutorialCrate then GuidanceController.Show(Player, "Break Highlighted Crate", TutorialCrate) end
					continue
				end
			end
			if IsTargetInRange(Player, RootPart, Target:GetPivot().Position, Info, Now) then
				local ImpactPosition, ImpactNormal, ImpactColor, ImpactMaterial = GetCrateImpact(Target, RootPart.Position)
				local Damaged = CrateController.DamageCrate(Player, Target, Info.CrateDamage, PredictionId)
				local IsFinalHit = Damaged and not Target.Parent
				if IsFinalHit then GuidanceController.MarkTutorialCrateBroken(Player, Target) end
				if Damaged then
					Network:fire(Player, "CrateHitConfirmed", ImpactPosition, ImpactNormal, ImpactColor, ImpactMaterial, IsFinalHit, Info.Id, PredictionId)
				end
				if Damaged and Target.Parent then
					Network:fireAllExcept(Player, "ReactToCrate", Target, RootPart.Position, Info.Id)
				end
			end
			continue
		end
		if Target:IsA("Model") then
			local TargetPlayer = Players:GetPlayerFromCharacter(Target)
			if TargetPlayer then HitPlayer(Player, TargetPlayer, RootPart, Info, Now) end
		end
	end
end

function BatController.Init()
	Network = Networker.server.new("BatController", BatController, { BatController.Swing })
	RunService.Heartbeat:Connect(function()
		RecordPositions(os.clock())
	end)
end

function BatController.SetDataService(Service)
	DataService = Service
end

function BatController.OnPlayerAdded(Player)
	PlayerConnections[Player] = PlayerStateController.GetChangedSignal(Player, "IsFixing"):Connect(function(IsFixing)
		if IsFixing == true then RemoveBats(Player) else task.defer(EnsureBat, Player) end
	end)
	UpgradeConnections[Player] = DataService:getChangedSignal(Player, "Upgrades"):Connect(function()
		task.defer(EnsureBat, Player)
	end)
	task.defer(EnsureBat, Player)
end

function BatController.OnCharacterAdded(Player)
	ClearStun(Player, false)
	ProtectedUntil[Player] = nil
	task.defer(EnsureBat, Player)
end

function BatController.OnPlayerRemoving(Player)
	local Connection = PlayerConnections[Player]
	if Connection then Connection:Disconnect(); PlayerConnections[Player] = nil end
	local UpgradeConnection = UpgradeConnections[Player]
	if UpgradeConnection then UpgradeConnection:Disconnect(); UpgradeConnections[Player] = nil end
	LastSwings[Player] = nil
	PositionHistory[Player] = nil
	LastPositionSamples[Player] = nil
	LastPlayerHits[Player] = nil
	ProtectedUntil[Player] = nil
	ClearStun(Player, false, false)
	for _, Hits in LastPlayerHits do Hits[Player] = nil end
end

return BatController
