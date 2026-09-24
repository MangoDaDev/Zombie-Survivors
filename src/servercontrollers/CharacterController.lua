local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)

local REQUEST_COOLDOWN = 0.5

local CharacterController = {}

local readyPlayers: { [Player]: boolean } = {}
local loadingPlayers: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}

function CharacterController.ReloadCharacter(player: Player): boolean
	if not readyPlayers[player] or loadingPlayers[player] or player.Parent ~= Players then
		return false
	end

	-- All server features that replace a character use this path so concurrent loads cannot race one another.
	lastRequestAt[player] = os.clock()
	loadingPlayers[player] = true
	player:LoadCharacter()
	loadingPlayers[player] = nil

	return player.Character ~= nil
end

function CharacterController.RequestCharacter(_, player: Player): boolean
	if not readyPlayers[player] or loadingPlayers[player] or player.Parent ~= Players then
		return false
	end

	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < REQUEST_COOLDOWN then
		return false
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return true
	end

	-- CharacterAutoLoads is disabled so every spawn request remains server-authorized and rate-limited.
	return CharacterController.ReloadCharacter(player)
end

function CharacterController.Init()
	Networker.server.new("CharacterController", CharacterController, {
		CharacterController.RequestCharacter,
	})
end

function CharacterController.OnPlayerAdded(player: Player)
	readyPlayers[player] = true
end

function CharacterController.OnPlayerRemoving(player: Player)
	readyPlayers[player] = nil
	loadingPlayers[player] = nil
	lastRequestAt[player] = nil
end

return CharacterController
