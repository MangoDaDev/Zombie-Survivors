local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)

local RollController = {}

local rollNetwork: Networker.Client?
local ready = false
local latestRollId = 0
local latestStartedSequenceId = 0
local latestBonusSequenceId = 1
local autoRollEnabled = false

local rollStarted = Signal.new()
local bonusActivated = Signal.new()
local rollFinished = Signal.new()
local autoRollChanged = Signal.new()

local function isValidInteger(value: any, minimum: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum
end

function RollController.RollStarted(_, packet)
	if type(packet) ~= "table"
		or not isValidInteger(packet.rollId, 1)
		or not isValidInteger(packet.sequenceId, 1)
		or not isValidInteger(packet.reelIndex, 1)
		or not isValidInteger(packet.multiplier, 1)
		or type(packet.itemId) ~= "string"
		or RollDefinitions.ById[packet.itemId] == nil
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
		latestBonusSequenceId = 1
	end
	latestRollId = packet.rollId
	latestStartedSequenceId = packet.sequenceId
	rollStarted:Fire(packet)
end

function RollController.BonusActivated(_, packet)
	if type(packet) ~= "table"
		or packet.rollId ~= latestRollId
		or not isValidInteger(packet.sequenceId, 2)
		or not isValidInteger(packet.reelIndex, 2)
		or not isValidInteger(packet.multiplier, 2)
		or packet.sequenceId ~= latestStartedSequenceId + 1
		or packet.sequenceId <= latestBonusSequenceId
	then
		return
	end

	latestBonusSequenceId = packet.sequenceId
	bonusActivated:Fire(packet)
end

function RollController.RollFinished(_, rollId, willAutoRoll)
	if rollId ~= latestRollId or type(willAutoRoll) ~= "boolean" then
		return
	end
	rollFinished:Fire(rollId, willAutoRoll)
end

function RollController.AutoRollChanged(_, enabled)
	if type(enabled) ~= "boolean" then
		return
	end
	autoRollEnabled = enabled
	autoRollChanged:Fire(enabled)
end

function RollController.Init()
	rollNetwork = Networker.client.new("RollController", RollController)
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

function RollController.GetRollStartedSignal()
	return rollStarted
end

function RollController.GetBonusActivatedSignal()
	return bonusActivated
end

function RollController.GetRollFinishedSignal()
	return rollFinished
end

function RollController.GetAutoRollChangedSignal()
	return autoRollChanged
end

return RollController
