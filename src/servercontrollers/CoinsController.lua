local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)

local CoinsController = {}

local dataService
local readyPlayers: { [Player]: boolean } = {}

local function isValidBalance(value: any): boolean
	return type(value) == "number"
		and value == value
		and value >= 0
		and value <= CoinsConfig.MaximumBalance
		and value % 1 == 0
end

local function isValidChange(value: any): boolean
	return isValidBalance(value) and value > 0
end

local function canAccessData(player: any): boolean
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player.Parent == Players
		and readyPlayers[player] == true
		and dataService ~= nil
end

function CoinsController.SetDataService(service)
	dataService = service
end

function CoinsController.Get(player: Player): number?
	if not canAccessData(player) then
		return nil
	end

	local balance = dataService:get(player, CoinsConfig.DataKey)
	return if isValidBalance(balance) then balance else nil
end

function CoinsController.Set(player: Player, balance: number): (boolean, number?)
	if not canAccessData(player) or not isValidBalance(balance) then
		return false, CoinsController.Get(player)
	end

	local currentBalance = CoinsController.Get(player)
	if currentBalance == nil then
		return false, nil
	end

	if currentBalance ~= balance then
		-- DataService owns persistence and emits a single path update to this player for UI replication.
		dataService:set(player, CoinsConfig.DataKey, balance)
	end

	return true, balance
end

function CoinsController.Add(player: Player, amount: number): (boolean, number?)
	if not isValidChange(amount) then
		return false, CoinsController.Get(player)
	end

	local currentBalance = CoinsController.Get(player)
	if currentBalance == nil or amount > CoinsConfig.MaximumBalance - currentBalance then
		return false, currentBalance
	end

	return CoinsController.Set(player, currentBalance + amount)
end

function CoinsController.Remove(player: Player, amount: number): (boolean, number?)
	if not isValidChange(amount) then
		return false, CoinsController.Get(player)
	end

	local currentBalance = CoinsController.Get(player)
	if currentBalance == nil or amount > currentBalance then
		return false, currentBalance
	end

	-- Spending never permits a negative result; callers can trust false to mean no balance changed.
	return CoinsController.Set(player, currentBalance - amount)
end

function CoinsController.OnPlayerAdded(player: Player)
	readyPlayers[player] = true

	local balance = dataService:get(player, CoinsConfig.DataKey)
	if not isValidBalance(balance) then
		-- Repair malformed legacy data to the declared default before any gameplay system can consume it.
		dataService:set(player, CoinsConfig.DataKey, CoinsConfig.DefaultBalance)
	end
end

function CoinsController.OnPlayerRemoving(player: Player)
	readyPlayers[player] = nil
end

return CoinsController
