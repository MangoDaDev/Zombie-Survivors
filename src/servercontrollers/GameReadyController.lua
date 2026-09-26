local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameReadyConfig = require(ReplicatedStorage.Modules.Game.GameReadyConfig)
local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ServerContext = require(script.Parent.ServerContext)

local GameReadyController = {}

local readyNetwork
local active = false
local started = false
local startedAt: number? = nil
local deadline: number? = nil
local phaseToken = 0
local requiredUserIds: { [number]: boolean } = {}
local joinedUserIds: { [number]: boolean } = {}
local readyUserIds: { [number]: boolean } = {}
local gameStarted = Signal.new()

local function getRequiredCount(): number
	local count = 0
	for _ in requiredUserIds do
		count += 1
	end
	return count
end

local function getReadyCount(): number
	local count = 0
	for userId in requiredUserIds do
		if readyUserIds[userId] then
			count += 1
		end
	end
	return count
end

local function makePacket(player: Player)
	return {
		active = active,
		started = started,
		startedAt = startedAt,
		deadline = deadline,
		readyCount = getReadyCount(),
		requiredCount = getRequiredCount(),
		isReady = readyUserIds[player.UserId] == true,
	}
end

local function sendState(player: Player)
	if player.Parent == Players then
		readyNetwork:fire(player, "ReadyStateChanged", makePacket(player))
	end
end

local function broadcastState()
	for _, player in Players:GetPlayers() do
		sendState(player)
	end
end

local function configureRequiredPlayers()
	table.clear(requiredUserIds)
	local runData = ServerContext.GetRunData()
	local memberIds = type(runData) == "table" and runData.partyMemberIds or nil
	if type(memberIds) == "table" then
		for _, userId in memberIds do
			if type(userId) == "number" and userId % 1 == 0 and userId > 0 then
				requiredUserIds[userId] = true
			end
		end
	end

	-- Studio and defensive fallback sessions may not have a complete teleport roster. In that
	-- case the players already in the Game server become the authoritative ready group.
	if next(requiredUserIds) == nil then
		for _, player in Players:GetPlayers() do
			requiredUserIds[player.UserId] = true
		end
	end
end

local function areAllRequiredPlayersReady(): boolean
	local requiredCount = getRequiredCount()
	return requiredCount > 0 and getReadyCount() == requiredCount
end

local function startGame()
	if started or not active then
		return
	end
	active = false
	started = true
	startedAt = workspace:GetServerTimeNow()
	deadline = nil
	phaseToken += 1
	broadcastState()
	gameStarted:Fire(startedAt)
end

local function beginReadyPhase()
	if active or started or not ServerContext.IsGameServer() then
		return
	end
	configureRequiredPlayers()
	for _, player in Players:GetPlayers() do
		if requiredUserIds[player.UserId] then
			joinedUserIds[player.UserId] = true
		end
	end

	active = true
	deadline = workspace:GetServerTimeNow() + GameReadyConfig.Duration
	phaseToken += 1
	local token = phaseToken
	broadcastState()
	task.delay(GameReadyConfig.Duration, function()
		if active and not started and phaseToken == token then
			startGame()
		end
	end)
end

function GameReadyController.GetState(_, player: Player)
	return makePacket(player)
end

function GameReadyController.ReadyUp(_, player: Player)
	if not active
		or started
		or player.Parent ~= Players
		or not requiredUserIds[player.UserId]
		or not joinedUserIds[player.UserId]
		or readyUserIds[player.UserId]
	then
		return
	end

	readyUserIds[player.UserId] = true
	broadcastState()
	-- Only the server-owned destination roster can release the combat gate early. Client packets
	-- contain no counts or timestamps and can only mark their authenticated sender as ready.
	if areAllRequiredPlayersReady() then
		startGame()
	end
end

function GameReadyController.IsStarted(): boolean
	return started
end

function GameReadyController.GetStartedSignal()
	return gameStarted
end

function GameReadyController.Init()
	readyNetwork = Networker.server.new("GameReadyController", GameReadyController, {
		GameReadyController.GetState,
		GameReadyController.ReadyUp,
	})
end

function GameReadyController.OnPlayerAdded(player: Player)
	if not ServerContext.IsGameServer() or started then
		return
	end
	joinedUserIds[player.UserId] = true
	if active then
		broadcastState()
	end
end

function GameReadyController.OnCharacterAdded(player: Player, _character: Model)
	if not ServerContext.IsGameServer() or started then
		return
	end
	joinedUserIds[player.UserId] = true
	if not active then
		-- Begin only once an avatar has reached the arena so loading time does not consume the
		-- visible 30-second decision window.
		beginReadyPhase()
	else
		broadcastState()
	end
end

function GameReadyController.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	joinedUserIds[userId] = nil
	readyUserIds[userId] = nil
	if active and requiredUserIds[userId] then
		-- A player who actually reached this server no longer blocks the remaining group after leaving.
		requiredUserIds[userId] = nil
		broadcastState()
		if areAllRequiredPlayersReady() then
			startGame()
		end
	end
end

return GameReadyController
