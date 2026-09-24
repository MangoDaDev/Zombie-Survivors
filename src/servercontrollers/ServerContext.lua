local Players = game:GetService("Players")

local SERVER_TYPE_LOBBY = "Lobby"
local SERVER_TYPE_GAME = "Game"
local TELEPORT_DATA_VERSION = 1

local ServerContext = {}

local resolved = false
local serverType = SERVER_TYPE_LOBBY
local runData

local function containsUserId(userIds, userId: number): boolean
	if type(userIds) ~= "table" then
		return false
	end
	for _, candidate in userIds do
		if candidate == userId then
			return true
		end
	end
	return false
end

local function resolveFromPlayer(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	local cameFromThisPlace = joinData.SourceGameId == game.GameId and joinData.SourcePlaceId == game.PlaceId
	local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

	-- A normal join is always a lobby. Game mode requires Roblox-verified server teleport metadata,
	-- the reserved-server identity, and membership in the party that was sent with this player.
	if isReservedServer
		and cameFromThisPlace
		and type(teleportData) == "table"
		and teleportData.version == TELEPORT_DATA_VERSION
		and teleportData.serverType == SERVER_TYPE_GAME
		and type(teleportData.runId) == "string"
		and teleportData.runId ~= ""
		and containsUserId(teleportData.partyMemberIds, player.UserId)
	then
		serverType = SERVER_TYPE_GAME
		runData = teleportData
	end
end

function ServerContext.Resolve()
	if resolved then
		return
	end

	local firstPlayer = Players:GetPlayers()[1]
	if not firstPlayer then
		firstPlayer = Players.PlayerAdded:Wait()
	end
	resolveFromPlayer(firstPlayer)
	resolved = true
end

function ServerContext.IsLobbyServer(): boolean
	return serverType == SERVER_TYPE_LOBBY
end

function ServerContext.IsGameServer(): boolean
	return serverType == SERVER_TYPE_GAME
end

function ServerContext.GetServerType(): string
	return serverType
end

function ServerContext.GetRunData()
	return runData
end

return ServerContext
