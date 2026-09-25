local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local MapController = require(script.Parent.MapController)
local ServerContext = require(script.Parent.ServerContext)

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
	if ServerContext.IsGameServer() and player.Character then
		-- Run deaths are terminal; clients cannot use the normal spawn request to re-enter combat.
		return false
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

function CharacterController.OnCharacterAdded(player: Player, character: Model)
	local spawnCFrame = MapController.GetSpawnCFrame()
	if not spawnCFrame then
		return
	end

	-- CharacterAutoLoads is disabled, so this authoritative placement guarantees each session mode
	-- uses its inspected spawn even if Roblox's default SpawnLocation selection changes later.
	task.defer(function()
		if player.Parent == Players and player.Character == character then
			character:PivotTo(spawnCFrame * CFrame.new(0, 3.5, 0))
		end
	end)
end

return CharacterController
