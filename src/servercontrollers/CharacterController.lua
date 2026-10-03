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
local requestedSpawnCFrames: { [Player]: CFrame } = {}

function CharacterController.ReloadCharacter(player: Player, spawnCFrame: CFrame?): boolean
	if not readyPlayers[player] or loadingPlayers[player] or player.Parent ~= Players then
		return false
	end

	-- All server features that replace a character use this path so concurrent loads cannot race one another.
	lastRequestAt[player] = os.clock()
	loadingPlayers[player] = true
	requestedSpawnCFrames[player] = spawnCFrame
	player:LoadCharacter()
	requestedSpawnCFrames[player] = nil
	loadingPlayers[player] = nil

	return player.Parent == Players and player.Character ~= nil
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
		-- Run deaths remain server-authorized: teammate and paid revives use ReloadCharacter directly,
		-- while a dead client cannot bypass the team-death rules through the normal spawn request.
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
	requestedSpawnCFrames[player] = nil
end

function CharacterController.OnCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and ServerContext.IsGameServer() then
		-- Set this before later character hooks can yield: downed bodies must retain their joints.
		humanoid.BreakJointsOnDeath = false
	end
	-- Revives return at the downed body; initial spawns and replays use the map spawn.
	local requestedSpawn = requestedSpawnCFrames[player]
	local spawnCFrame = requestedSpawn or MapController.GetSpawnCFrame()
	if not spawnCFrame then
		return
	end

	-- CharacterAutoLoads is disabled, so this authoritative placement guarantees each session mode
	-- uses its inspected spawn even if Roblox's default SpawnLocation selection changes later.
	task.defer(function()
		if player.Parent == Players and player.Character == character then
			character:PivotTo(if requestedSpawn then spawnCFrame else spawnCFrame * CFrame.new(0, 3.5, 0))
		end
	end)
end

return CharacterController
