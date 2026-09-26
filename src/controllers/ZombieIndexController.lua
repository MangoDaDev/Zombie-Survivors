local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ZombieIndexConfig = require(ReplicatedStorage.Modules.Game.Zombies.ZombieIndexConfig)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local AbilityController = require(script.Parent.AbilityController)
local ClassController = require(script.Parent.ClassController)
local RunProgressionController = require(script.Parent.RunProgressionController)

local ZombieIndexController = {}

local dataService
local indexNetwork
local open = false
local stateChanged = Signal.new()
local openChanged = Signal.new()
local actionResult = Signal.new()

function ZombieIndexController.ActionResult(_, success, message)
	if type(success) ~= "boolean" or type(message) ~= "string" then
		return
	end
	actionResult:Fire(success, message)
	NotificationManager.Notify(message, 3, if success then UIStyle.Colors.Green else UIStyle.Colors.Red)
end

function ZombieIndexController.SetDataService(service)
	dataService = service
end

function ZombieIndexController.Init()
	indexNetwork = Networker.client.new("ZombieIndexController", ZombieIndexController)
	dataService:getChangedSignal(ZombieIndexConfig.DataKey):Connect(function()
		stateChanged:Fire(ZombieIndexController.GetState())
	end)
	RunProgressionController.GetStateChangedSignal():Connect(function(runState)
		if runState.active then
			ZombieIndexController.SetOpen(false)
		end
	end)
end

function ZombieIndexController.GetState()
	local state = dataService and dataService:get(ZombieIndexConfig.DataKey)
	return if type(state) == "table" then state else {}
end

function ZombieIndexController.IsOpen(): boolean
	return open
end

function ZombieIndexController.SetOpen(isOpen: boolean)
	if type(isOpen) ~= "boolean" or open == isOpen then
		return
	end
	if isOpen and RunProgressionController.GetState().active then
		return
	end
	if isOpen then
		AbilityController.SetInventoryOpen(false)
		ClassController.SetOpen(false)
	end
	open = isOpen
	openChanged:Fire(open)
end

function ZombieIndexController.ClaimDiscoveryReward(zombieId: string)
	if indexNetwork and ZombieIndexConfig.ById[zombieId] then
		indexNetwork:fire("ClaimDiscoveryReward", zombieId)
	end
end

function ZombieIndexController.GetStateChangedSignal()
	return stateChanged
end

function ZombieIndexController.GetOpenChangedSignal()
	return openChanged
end

function ZombieIndexController.GetActionResultSignal()
	return actionResult
end

return ZombieIndexController
