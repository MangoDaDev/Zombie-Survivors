local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local AbilityController = require(script.Parent.AbilityController)
local RunProgressionController = require(script.Parent.RunProgressionController)
local AdditionalWeaponEffects = require(script.Parent.Ability.AdditionalWeaponEffects)
local AnalyticsController = require(script.Parent.AnalyticsController)
local ClassesAbilitiesTutorialController = require(script.Parent.ClassesAbilitiesTutorialController)

local ClassController = {}

local dataService
local classNetwork
local open = false
local previewClassId = ClassDefinitions.DefaultId
local promptConnection: RBXScriptConnection?
local prompt: ProximityPrompt?
local stateChanged = Signal.new()
local openChanged = Signal.new()
local previewChanged = Signal.new()
local actionResult = Signal.new()
local nextEquipRequestId = 0
local equipRequest
local confirmedEquipped: string? = nil

local function isClassesPrompt(instance: Instance): boolean
	local promptPart = instance.Parent
	local structure = promptPart and promptPart.Parent
	return instance:IsA("ProximityPrompt")
		and promptPart ~= nil
		and promptPart.Name == "PromptPart"
		and structure ~= nil
		and structure.Name == "Classes"
		and structure:IsDescendantOf(Workspace)
end

local function bindPrompt(candidate: Instance)
	if not isClassesPrompt(candidate) or candidate == prompt then
		return
	end
	if promptConnection then
		promptConnection:Disconnect()
	end
	prompt = candidate :: ProximityPrompt
	promptConnection = prompt.Triggered:Connect(function()
		ClassController.SetOpen(true)
	end)
end

function ClassController.ActionResult(_, success, message)
	if type(success) ~= "boolean" or type(message) ~= "string" then
		return
	end
	actionResult:Fire(success, message)
	NotificationManager.Notify(message, 2.5, if success then UIStyle.Colors.Green else UIStyle.Colors.Red)
end

function ClassController.EquipResolved(_, requestId, equippedClassId)
	if not equipRequest or requestId ~= equipRequest.id or not ClassDefinitions.ById[equippedClassId] then
		return
	end
	equipRequest = nil
	local authoritative = dataService and dataService:get(ClassDefinitions.DataKey)
	confirmedEquipped = if authoritative and authoritative.Equipped == equippedClassId then nil else equippedClassId
	stateChanged:Fire(ClassController.GetState())
	task.delay(8, function()
		if nextEquipRequestId == requestId and confirmedEquipped then
			confirmedEquipped = nil
			stateChanged:Fire(ClassController.GetState())
		end
	end)
end

function ClassController.KillEffect(_, kind, position, radius)
	if (kind ~= "Star" and kind ~= "Void")
		or typeof(position) ~= "Vector3"
		or type(radius) ~= "number"
		or radius <= 0
		or radius > 35
	then
		return
	end
	if kind == "Star" then
		AdditionalWeaponEffects.MeteorImpacted({
			id = 0,
			position = position,
			radius = radius,
			shockwave = true,
			fragments = true,
		})
	else
		AdditionalWeaponEffects.VortexCollapsed({ position = position, radius = radius })
	end
end

function ClassController.SetDataService(service)
	dataService = service
end

function ClassController.Init()
	classNetwork = Networker.client.new("ClassController", ClassController)
	dataService:getChangedSignal(ClassDefinitions.DataKey):Connect(function()
		-- Keep an acknowledged selection visible until DataService catches up with the response.
		local authoritative = dataService:get(ClassDefinitions.DataKey)
		if authoritative and authoritative.Equipped == confirmedEquipped then
			confirmedEquipped = nil
		end
		stateChanged:Fire(ClassController.GetState())
	end)
	RunProgressionController.GetStateChangedSignal():Connect(function(runState)
		if runState.active then
			ClassController.SetOpen(false)
		end
	end)
	ClassesAbilitiesTutorialController.GetStateChangedSignal():Connect(function(tutorialState)
		if tutorialState.active and open then
			ClassController.SetPreviewClassId(tutorialState.targetClassId)
		end
	end)
	for _, descendant in Workspace:GetDescendants() do
		if isClassesPrompt(descendant) then
			bindPrompt(descendant)
			break
		end
	end
	-- The lobby is parented as a complete map beneath Workspace, and the authored prompt's display
	-- name may change. Bind by the stable Classes > PromptPart hierarchy instead of a root/name guess.
	Workspace.DescendantAdded:Connect(bindPrompt)
end

function ClassController.GetState()
	local state = dataService and dataService:get(ClassDefinitions.DataKey)
	local current = if type(state) == "table" then state else {
		Owned = { [ClassDefinitions.DefaultId] = true },
		Equipped = ClassDefinitions.DefaultId,
	}
	if equipRequest or confirmedEquipped then
		current = table.clone(current)
		current.Equipped = if equipRequest then equipRequest.classId else confirmedEquipped
		current.PendingEquip = equipRequest and equipRequest.classId or nil
	end
	return current
end

function ClassController.IsOpen(): boolean
	return open
end

function ClassController.SetOpen(isOpen: boolean)
	if type(isOpen) ~= "boolean" or open == isOpen then
		return
	end
	if isOpen and RunProgressionController.GetState().active then
		return
	end
	if isOpen then
		AbilityController.SetInventoryOpen(false)
		local tutorialState = ClassesAbilitiesTutorialController.GetState()
		-- The returning-player tutorial owns selection until its free claim succeeds; ordinary visits
		-- continue to start on the equipped class and keep other browsing purely local.
		ClassController.SetPreviewClassId(if tutorialState.active then tutorialState.targetClassId else ClassController.GetState().Equipped)
	end
	open = isOpen
	openChanged:Fire(open)
	if open then
		AnalyticsController.OpenShop("Class")
	end
end

function ClassController.GetPreviewClassId(): string
	return previewClassId
end

function ClassController.SetPreviewClassId(classId: string)
	if not ClassDefinitions.ById[classId] or previewClassId == classId then
		return
	end
	local tutorialState = ClassesAbilitiesTutorialController.GetState()
	if tutorialState.active and classId ~= tutorialState.targetClassId then
		return
	end
	previewClassId = classId
	previewChanged:Fire(classId)
	if open then
		AnalyticsController.SelectShopItem("Class", classId)
	end
end

function ClassController.GetPreviewChangedSignal()
	return previewChanged
end

function ClassController.UnlockClass(classId: string)
	if classNetwork and ClassDefinitions.ById[classId] then
		classNetwork:fire("UnlockClass", classId)
	end
end

function ClassController.EquipClass(classId: string)
	local current = ClassController.GetState()
	if classNetwork and ClassDefinitions.ById[classId] and current.Owned[classId]
		and not equipRequest and current.Equipped ~= classId and not RunProgressionController.GetState().active then
		nextEquipRequestId += 1
		local requestId = nextEquipRequestId
		-- Predict menu selection only. Character gear, class stats and persistence remain server-owned.
		equipRequest = { id = requestId, classId = classId }
		stateChanged:Fire(ClassController.GetState())
		classNetwork:fire("RequestEquipClass", requestId, classId)
		task.delay(8, function()
			if equipRequest and equipRequest.id == requestId then
				equipRequest = nil
				stateChanged:Fire(ClassController.GetState())
			end
		end)
	end
end

function ClassController.GetStateChangedSignal()
	return stateChanged
end

function ClassController.GetOpenChangedSignal()
	return openChanged
end

function ClassController.GetActionResultSignal()
	return actionResult
end

return ClassController
