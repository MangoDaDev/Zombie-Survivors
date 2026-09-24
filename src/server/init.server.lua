local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local data_service = require(ReplicatedStorage.Packages.dataservice).server

Players.CharacterAutoLoads = false

data_service:init({
	template = require(ReplicatedStorage.Modules.Game.DataTemplate),
	profileStoreIndex = "Default",
	profileStoreDataPrefix = if RunService:IsStudio() then "STUDIOTEST_" else "PLAYER_",
})

local modules_to_init = {
	ServerStorage.Controllers.ChatCommandController,
	ServerStorage.Controllers.PlayerStateController,
	ServerStorage.Controllers.CoinsController,
	ServerStorage.Controllers.RageController,
	ServerStorage.Controllers.PlayerStatController,
	ServerStorage.Controllers.AbilityController,
	ServerStorage.Controllers.CollisionController,
	ServerStorage.Controllers.CharacterController,
	ServerStorage.Controllers.ZombieController,
}

-- Simulator-era roll, coin-drop, carried-backpack, and extraction controllers are intentionally
-- excluded from startup. Preserving the modules keeps reusable reward logic without live listeners or loops.

local initialized_modules = {}
local removing_players = {}

for _, module_script in modules_to_init do
	local module = require(module_script)

	if module.SetDataService then
		module.SetDataService(data_service)
	end

	table.insert(initialized_modules, module)

	if module.Init then
		module.Init()
	elseif module.init then
		module:init()
	end
end

local function OnPlayerRemoving(player: Player)
	if removing_players[player] then
		return
	end
	removing_players[player] = true

	for _, module in initialized_modules do
		if module.OnPlayerRemoving then
			module.OnPlayerRemoving(player)
		end
	end
end

local function OnCharacterAdded(player: Player, character: Model)
	for _, module in initialized_modules do
		if module.OnCharacterAdded then
			module.OnCharacterAdded(player, character)
		end
	end
end

local function OnPlayerAdded(player: Player)
	if not data_service:waitForData(player) or player.Parent ~= Players then
		return
	end

	for _, module in initialized_modules do
		if module.OnPlayerAdded then
			module.OnPlayerAdded(player)
		end
	end

	if player.Character then
		OnCharacterAdded(player, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
end

data_service:addPlayerRemovingCallback(OnPlayerRemoving)

Players.PlayerAdded:Connect(function(player)
	task.spawn(OnPlayerAdded, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(OnPlayerAdded, player)
end
