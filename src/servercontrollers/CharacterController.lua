local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)

local REQUEST_COOLDOWN = 0.5

local CharacterController = {}

local readyPlayers: { [Player]: boolean } = {}
local loadingPlayers: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}

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
	lastRequestAt[player] = now
	loadingPlayers[player] = true
	player:LoadCharacter()
	loadingPlayers[player] = nil

	return player.Character ~= nil
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
