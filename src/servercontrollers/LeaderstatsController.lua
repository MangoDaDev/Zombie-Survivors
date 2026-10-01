local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)
local SurvivalStatsConfig = require(ReplicatedStorage.Modules.Game.SurvivalStatsConfig)

type Runtime = {
	leaderstats: Folder,
	connections: { any },
}

local LeaderstatsController = {}

local dataService
local runtimes: { [Player]: Runtime } = {}

local function normalizeWholeNumber(value: any, fallback: number): number
	return if type(value) == "number" and value == value and value >= 0 and value % 1 == 0 then value else fallback
end

local function createDisplayValue(name: string, value: number, parent: Folder): IntValue
	local displayValue = Instance.new("IntValue")
	displayValue.Name = name
	displayValue.Value = value
	displayValue.Parent = parent
	return displayValue
end

function LeaderstatsController.SetDataService(service)
	dataService = service
end

function LeaderstatsController.OnPlayerAdded(player: Player)
	if player.Parent ~= Players or runtimes[player] then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = createDisplayValue(
		"Coins",
		normalizeWholeNumber(dataService:get(player, CoinsConfig.DataKey), CoinsConfig.DefaultBalance),
		leaderstats
	)
	local roundsSurvived = createDisplayValue(
		"Rounds Survived",
		normalizeWholeNumber(
			dataService:get(player, SurvivalStatsConfig.DataKey),
			SurvivalStatsConfig.DefaultRoundsSurvived
		),
		leaderstats
	)

	-- Roblox requires ValueObjects beneath a folder named "leaderstats" for its player-list UI.
	-- These are presentation-only mirrors: all gameplay reads and writes remain in DataService so
	-- client-side changes to replicated copies can never grant currency or progression.
	local connections = {
		dataService:getChangedSignal(player, { CoinsConfig.DataKey }):Connect(function(newBalance)
			coins.Value = normalizeWholeNumber(newBalance, CoinsConfig.DefaultBalance)
		end),
		dataService:getChangedSignal(player, { SurvivalStatsConfig.DataKey }):Connect(function(newHighestRound)
			roundsSurvived.Value = normalizeWholeNumber(
				newHighestRound,
				SurvivalStatsConfig.DefaultRoundsSurvived
			)
		end),
	}

	runtimes[player] = {
		leaderstats = leaderstats,
		connections = connections,
	}
	leaderstats.Parent = player
end

function LeaderstatsController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end

	for _, connection in runtime.connections do
		connection:Disconnect()
	end
	runtime.leaderstats:Destroy()
	runtimes[player] = nil
end

return LeaderstatsController
