local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)

local RollController = {}

local rollNetwork: Networker.Client?
local ready = false
local latestRollId = 0
local latestStartedSequenceId = 0
local autoRollEnabled = false
local presentationHidden = false

local rollStarted = Signal.new()
local rollFinished = Signal.new()
local autoRollChanged = Signal.new()
local presentationHiddenChanged = Signal.new()

local function setAutoRollEnabled(enabled: any)
	if type(enabled) ~= "boolean" or autoRollEnabled == enabled then
		return
	end
	autoRollEnabled = enabled
	autoRollChanged:Fire(enabled)
end

local function setPresentationHidden(hidden: any)
	if type(hidden) ~= "boolean" or presentationHidden == hidden then
		return
	end
	presentationHidden = hidden
	presentationHiddenChanged:Fire(hidden)
end

local function isValidInteger(value: any, minimum: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum
end

function RollController.RollStarted(_, packet)
	if type(packet) ~= "table"
		or not isValidInteger(packet.rollId, 1)
		or not isValidInteger(packet.sequenceId, 1)
		or not isValidInteger(packet.reelIndex, 1)
		or (packet.kind ~= "Item" and packet.kind ~= "Clover")
		or not isValidInteger(packet.luckMultiplier, 1)
		or (packet.kind == "Item" and (type(packet.itemId) ~= "string" or RollDefinitions.ById[packet.itemId] == nil))
		or (packet.kind == "Item" and type(packet.isNewAbility) ~= "boolean")
		or (packet.kind == "Clover" and (packet.itemId ~= nil or packet.isNewAbility ~= nil))
	then
		return
	end

	if packet.rollId < latestRollId
		or (packet.rollId == latestRollId and packet.sequenceId <= latestStartedSequenceId)
	then
		return
	end
	if packet.rollId > latestRollId then
		latestStartedSequenceId = 0
	end
	latestRollId = packet.rollId
	latestStartedSequenceId = packet.sequenceId
	rollStarted:Fire(packet)
end

function RollController.RollFinished(_, rollId, willAutoRoll)
	if rollId ~= latestRollId or type(willAutoRoll) ~= "boolean" then
		return
	end
	rollFinished:Fire(rollId, willAutoRoll)
end

function RollController.AutoRollChanged(_, enabled)
	setAutoRollEnabled(enabled)
end

function RollController.PresentationHiddenChanged(_, hidden)
	setPresentationHidden(hidden)
end

function RollController.Init()
	rollNetwork = Networker.client.new("RollController", RollController)
	local settings = (rollNetwork :: Networker.Client):fetch("GetSettings")
	if type(settings) == "table" then
		setAutoRollEnabled(settings.autoRollEnabled)
		setPresentationHidden(settings.presentationHidden)
	end
	ready = true
end

function RollController.RequestRoll()
	if ready then
		(rollNetwork :: Networker.Client):fire("RequestRoll")
	end
end

function RollController.SetAutoRoll(enabled: boolean)
	if ready and type(enabled) == "boolean" then
		(rollNetwork :: Networker.Client):fire("SetAutoRoll", enabled)
	end
end

function RollController.IsAutoRollEnabled(): boolean
	return autoRollEnabled
end

function RollController.SetPresentationHidden(hidden: boolean)
	if ready and type(hidden) == "boolean" and presentationHidden ~= hidden then
		(rollNetwork :: Networker.Client):fire("SetPresentationHidden", hidden)
	end
end

function RollController.IsPresentationHidden(): boolean
	return presentationHidden
end

function RollController.GetRollStartedSignal()
	return rollStarted
end

function RollController.GetRollFinishedSignal()
	return rollFinished
end

function RollController.GetAutoRollChangedSignal()
	return autoRollChanged
end

function RollController.GetPresentationHiddenChangedSignal()
	return presentationHiddenChanged
end

return RollController
