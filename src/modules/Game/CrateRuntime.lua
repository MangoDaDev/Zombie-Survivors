local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

local CrateRuntime = {}
local Crates = setmetatable({}, { __mode = "k" })
local HealthSignals = setmetatable({}, { __mode = "k" })
local ResetChanged = Signal.new()
local ResetState = {
	IsResetting = false,
	NextResetTime = nil,
}

function CrateRuntime.Get(Model)
	return Crates[Model]
end

function CrateRuntime.Set(Model, CrateId, Health, MaximumHealth)
	local State = Crates[Model]

	if not State then
		State = {}
		Crates[Model] = State
	end

	State.CrateId = CrateId or State.CrateId
	State.MaximumHealth = MaximumHealth or State.MaximumHealth
	State.Health = Health

	local HealthSignal = HealthSignals[Model]

	if HealthSignal then
		HealthSignal:Fire(Health)
	end
end

function CrateRuntime.GetHealthChangedSignal(Model)
	if not HealthSignals[Model] then
		HealthSignals[Model] = Signal.new()
	end

	return HealthSignals[Model]
end

function CrateRuntime.Clear(Model)
	Crates[Model] = nil

	local HealthSignal = HealthSignals[Model]

	if HealthSignal then
		HealthSignal:DisconnectAll()
	end

	HealthSignals[Model] = nil
end

function CrateRuntime.SetResetState(NextResetTime, IsResetting)
	ResetState.NextResetTime = NextResetTime
	ResetState.IsResetting = IsResetting == true
	ResetChanged:Fire(ResetState.NextResetTime, ResetState.IsResetting)
end

function CrateRuntime.GetResetState()
	return ResetState.NextResetTime, ResetState.IsResetting
end

function CrateRuntime.GetResetChangedSignal()
	return ResetChanged
end

return CrateRuntime
