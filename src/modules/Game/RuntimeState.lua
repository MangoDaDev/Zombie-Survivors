local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

local RuntimeState = {}
local States = setmetatable({}, { __mode = "k" })
local ChangedSignals = setmetatable({}, { __mode = "k" })

local function GetPlayerState(Player)
	local State = States[Player]

	if not State then
		State = {}
		States[Player] = State
	end

	return State
end

function RuntimeState.Get(Player, Key, DefaultValue)
	local State = States[Player]
	local Value = State and State[Key]

	if Value == nil then
		return DefaultValue
	end

	return Value
end

function RuntimeState.Set(Player, Key, Value)
	local State = GetPlayerState(Player)

	if State[Key] == Value then
		return
	end

	State[Key] = Value

	local PlayerSignals = ChangedSignals[Player]
	local ChangedSignal = PlayerSignals and PlayerSignals[Key]

	if ChangedSignal then
		ChangedSignal:Fire(Value)
	end
end

function RuntimeState.GetSnapshot(Player)
	return table.clone(GetPlayerState(Player))
end

function RuntimeState.GetChangedSignal(Player, Key)
	local PlayerSignals = ChangedSignals[Player]

	if not PlayerSignals then
		PlayerSignals = {}
		ChangedSignals[Player] = PlayerSignals
	end

	if not PlayerSignals[Key] then
		PlayerSignals[Key] = Signal.new()
	end

	return PlayerSignals[Key]
end

function RuntimeState.Clear(Player)
	States[Player] = nil

	local PlayerSignals = ChangedSignals[Player]

	if PlayerSignals then
		for _, ChangedSignal in PlayerSignals do
			ChangedSignal:DisconnectAll()
		end
	end

	ChangedSignals[Player] = nil
end

return RuntimeState
