local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(ReplicatedStorage.Packages.dataservice).client
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)
local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local TutorialConfig = require(ReplicatedStorage.Modules.Game.TutorialConfig)

local LocalPlayer = Players.LocalPlayer
local GuidanceController = {}
local Network
local Highlight: Highlight?
local OverrideId = 0
local OverrideText: string?
local OverrideTarget: Instance?
local OverrideTargetKind: string?

local function GetMuseum(): Model?
	local Museums = Workspace:FindFirstChild("PlayerMuseums")
	local Museum = Museums and Museums:FindFirstChild(`Museum_{LocalPlayer.UserId}`)
	return if Museum and Museum:IsA("Model") then Museum else nil
end

local function GetItemInfo(ItemName: string)
	for _, ItemInfo in ItemsInfo do
		if ItemInfo.Name == ItemName then return ItemInfo end
	end
end

local function GetNearestModel(Folder: Instance?, IsAllowed): Model?
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local Closest: Model?
	local ClosestDistance = math.huge
	if not Folder then return nil end
	for _, Model in Folder:GetChildren() do
		if not Model:IsA("Model") or not IsAllowed(Model) then continue end
		local Distance = if RootPart then (Model:GetPivot().Position - RootPart.Position).Magnitude else 0
		if Distance < ClosestDistance then
			Closest = Model
			ClosestDistance = Distance
		end
	end
	return Closest
end

local function GetStarterTarget(): Model?
	local Cash = DataService:get("Cash") or 0
	local Reward = GetNearestModel(Workspace:FindFirstChild("CrateRewards"), function(Model)
		local ItemName = string.match(Model.Name, "^CrateReward_(.+)$")
		local ItemInfo = ItemName and GetItemInfo(ItemName)
		return ItemInfo
			and ItemInfo.Price <= Cash
			and #ItemInfo.RestorationSteps == 1
			and ItemInfo.RestorationSteps[1] == "Spray"
	end)
	if Reward then return Reward end
	return GetNearestModel(Workspace:FindFirstChild("Crates"), function(Model)
		return Model.Name == "CommonCrate"
	end)
end

local function GetDisplay(Occupied: boolean): Model?
	local Museum = GetMuseum()
	if not Museum then return nil end
	for _, Child in Museum:GetChildren() do
		if not Child:IsA("Model") or not string.match(Child.Name, "^Display_%d+$") then continue end
		local Prompt = Child:FindFirstChild("PlaceItemPrompt", true)
		if Prompt and Prompt:IsA("ProximityPrompt") and Prompt.Enabled == (not Occupied) then return Child end
	end
end

local function GetGuiTarget(Name: string): GuiObject?
	local App = LocalPlayer.PlayerGui:FindFirstChild("App")
	local Target = App and App:FindFirstChild(Name, true)
	return if Target and Target:IsA("GuiObject") then Target else nil
end

local function GetUpgradeTarget(UpgradeId: string): GuiObject?
	local Panel = GetGuiTarget("UpgradeTree")
	return if Panel and Panel.Visible then GetGuiTarget(UpgradeId) else GetGuiTarget("OpenButton")
end

local function ResolveTarget(StepId: string, TargetKind: string?): Instance?
	if TargetKind then
		local UpgradeId = string.match(TargetKind, "^Upgrade:(.+)$")
		if UpgradeId then return GetUpgradeTarget(UpgradeId) end
	end
	if StepId == "PickUpItem" then return GetStarterTarget() end
	local Museum = GetMuseum()
	if StepId == "BringItemHome" or StepId == "StartCleaning" then
		return Museum and Museum:FindFirstChild("PromptPart", true)
	elseif StepId == "UseTool" or StepId == "CleanThis" then
		return Museum and (Museum:FindFirstChild(`FixingItem_{LocalPlayer.UserId}`) or Museum:FindFirstChild("PromptPart", true))
	elseif StepId == "DisplayItem" then
		return GetDisplay(false)
	elseif StepId == "EarnMoney" then
		return GetDisplay(true)
	elseif StepId == "OpenUpgrades" then
		return GetGuiTarget("OpenButton")
	elseif StepId == "BuySponge" then
		return GetUpgradeTarget("UnlockSponge")
	end
end

local function SetGuidance(Text: string?, Target: Instance?)
	RuntimeState.Set(LocalPlayer, "GuidanceText", Text)
	RuntimeState.Set(LocalPlayer, "GuidanceTarget", Target)
	if Highlight then
		Highlight.Adornee = if Target and (Target:IsA("Model") or Target:IsA("BasePart")) then Target else nil
		Highlight.Enabled = Highlight.Adornee ~= nil
	end
end

local function RefreshTutorial()
	if OverrideId > 0 then return end
	local StepId = DataService:get("TutorialStep")
	local Step = type(StepId) == "string" and TutorialConfig.GetStep(StepId) or nil
	local Text = Step and Step.Text
	if StepId == "PickUpItem" then
		local Target = GetStarterTarget()
		if Target and Target.Parent and Target.Parent.Name == "Crates" then Text = "Break A Crate" end
	elseif StepId == "UseTool" then
		local ToolId = RuntimeState.Get(LocalPlayer, "CleaningStepToolId")
		local ToolInfo = type(ToolId) == "string" and CleaningConfig.GetTool(ToolId) or nil
		if ToolInfo then Text = `Use {ToolInfo.DisplayName}` end
	end
	SetGuidance(Text, if Step then ResolveTarget(StepId) else nil)
end

function GuidanceController.ShowLocal(Text: string, Target: Instance?, TargetKind: string?)
	OverrideId += 1
	local CurrentId = OverrideId
	local StepId = DataService:get("TutorialStep")
	OverrideText = Text
	OverrideTarget = Target
	OverrideTargetKind = TargetKind
	SetGuidance(Text, Target or ResolveTarget(type(StepId) == "string" and StepId or "", TargetKind))
	task.delay(2.5, function()
		if OverrideId ~= CurrentId then return end
		OverrideId = 0
		OverrideText = nil
		OverrideTarget = nil
		OverrideTargetKind = nil
		RefreshTutorial()
	end)
end

function GuidanceController.ShowMessage(_, Text, Target, TargetKind)
	if type(Text) ~= "string" or #Text > 40 then return end
	GuidanceController.ShowLocal(Text, if typeof(Target) == "Instance" then Target else nil, if type(TargetKind) == "string" then TargetKind else nil)
end

function GuidanceController.OpenedUpgradeTree()
	if Network then Network:fire("OpenedUpgrades") end
	if OverrideId > 0 and OverrideText and OverrideTargetKind then
		task.defer(function()
			local StepId = DataService:get("TutorialStep")
			SetGuidance(OverrideText, OverrideTarget or ResolveTarget(type(StepId) == "string" and StepId or "", OverrideTargetKind))
		end)
	end
end

function GuidanceController.Init()
	Network = Networker.client.new("GuidanceController", GuidanceController)
	Highlight = Instance.new("Highlight")
	Highlight.Name = "LocalGuidanceHighlight"
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillColor = Color3.fromRGB(72, 209, 238)
	Highlight.FillTransparency = 0.72
	Highlight.OutlineColor = Color3.new(1, 1, 1)
	Highlight.OutlineTransparency = 0
	Highlight.Enabled = false
	Highlight.Parent = Workspace
	DataService:getChangedSignal("TutorialStep"):Connect(RefreshTutorial)
	DataService:getChangedSignal("Cash"):Connect(RefreshTutorial)
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepToolId"):Connect(RefreshTutorial)
	Workspace.DescendantAdded:Connect(function(Descendant)
		local StepId = DataService:get("TutorialStep")
		if type(StepId) ~= "string" or not TutorialConfig.GetStep(StepId) then return end
		local IsNewReward = StepId == "PickUpItem" and Descendant:IsA("Model") and Descendant.Parent and Descendant.Parent.Name == "CrateRewards"
		if OverrideId == 0 and (IsNewReward or RuntimeState.Get(LocalPlayer, "GuidanceTarget") == nil) then task.defer(RefreshTutorial) end
	end)
	Workspace.DescendantRemoving:Connect(function(Descendant)
		if RuntimeState.Get(LocalPlayer, "GuidanceTarget") == Descendant then task.defer(RefreshTutorial) end
	end)
	RefreshTutorial()
end

return GuidanceController
