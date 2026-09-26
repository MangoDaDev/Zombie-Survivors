local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local AbilityController = require(script.Parent.AbilityController)
local RunProgressionController = require(script.Parent.RunProgressionController)

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

local function isClassesPrompt(instance: Instance): boolean
	local promptPart = instance.Parent
	local structure = promptPart and promptPart.Parent
	return instance:IsA("ProximityPrompt")
		and instance.Name == "ClassesPrompt"
		and promptPart ~= nil
		and promptPart.Name == "PromptPart"
		and structure ~= nil
		and structure.Name == "Classes"
		and structure.Parent == Workspace
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

function ClassController.SetDataService(service)
	dataService = service
end

function ClassController.Init()
	classNetwork = Networker.client.new("ClassController", ClassController)
	dataService:getChangedSignal(ClassDefinitions.DataKey):Connect(function()
		stateChanged:Fire(ClassController.GetState())
	end)
	RunProgressionController.GetStateChangedSignal():Connect(function(runState)
		if runState.active then
			ClassController.SetOpen(false)
		end
	end)
	local structure = Workspace:FindFirstChild("Classes")
	local promptPart = structure and structure:FindFirstChild("PromptPart")
	local existingPrompt = promptPart and promptPart:FindFirstChild("ClassesPrompt")
	if existingPrompt then
		bindPrompt(existingPrompt)
	end
	-- The prompt can replicate after its parent or be recreated when Studio swaps maps.
	Workspace.DescendantAdded:Connect(bindPrompt)
end

function ClassController.GetState()
	local state = dataService and dataService:get(ClassDefinitions.DataKey)
	return if type(state) == "table" then state else {
		Owned = { [ClassDefinitions.DefaultId] = true },
		Equipped = ClassDefinitions.DefaultId,
	}
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
		-- Each visit starts on the equipped class; browsing locked classes is only a local preview.
		ClassController.SetPreviewClassId(ClassController.GetState().Equipped)
	end
	open = isOpen
	openChanged:Fire(open)
end

function ClassController.GetPreviewClassId(): string
	return previewClassId
end

function ClassController.SetPreviewClassId(classId: string)
	if not ClassDefinitions.ById[classId] or previewClassId == classId then
		return
	end
	previewClassId = classId
	previewChanged:Fire(classId)
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
	if classNetwork and ClassDefinitions.ById[classId] then
		classNetwork:fire("EquipClass", classId)
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
