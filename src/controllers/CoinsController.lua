local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)

local CoinsController = {}

local dataService

function CoinsController.SetDataService(service)
	dataService = service
end

function CoinsController.Get(): number
	local balance = dataService:get(CoinsConfig.DataKey)
	return if type(balance) == "number" then balance else CoinsConfig.DefaultBalance
end

function CoinsController.GetChangedSignal()
	-- The client mirror is display-only; all authoritative mutations remain in the server controller.
	return dataService:getChangedSignal(CoinsConfig.DataKey)
end

return CoinsController
