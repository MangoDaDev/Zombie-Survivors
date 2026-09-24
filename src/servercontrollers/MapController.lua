local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ServerContext = require(script.Parent.ServerContext)

local INACTIVE_MAPS_FOLDER_NAME = "InactiveMaps"
local LOBBY_MAP_NAME = "Lobby"
local GAME_MAP_NAME = "Game"
local LOBBY_SPAWN_NAME = "LobbySpawnPos"
local GAME_SPAWN_NAME = "GameSpawnPos"

local MapController = {}

local activeSpawn: SpawnLocation?

local function getOrCreateInactiveMapsFolder(): Folder
	local existing = ServerStorage:FindFirstChild(INACTIVE_MAPS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = INACTIVE_MAPS_FOLDER_NAME
	folder.Parent = ServerStorage
	return folder
end

local function findMap(name: string): Instance?
	return Workspace:FindFirstChild(name) or ServerStorage:FindFirstChild(INACTIVE_MAPS_FOLDER_NAME)
		and ServerStorage[INACTIVE_MAPS_FOLDER_NAME]:FindFirstChild(name)
end

function MapController.Init()
	local activeMapName = if ServerContext.IsGameServer() then GAME_MAP_NAME else LOBBY_MAP_NAME
	local inactiveMapName = if ServerContext.IsGameServer() then LOBBY_MAP_NAME else GAME_MAP_NAME
	local spawnName = if ServerContext.IsGameServer() then GAME_SPAWN_NAME else LOBBY_SPAWN_NAME
	local inactiveMaps = getOrCreateInactiveMapsFolder()
	local activeMap = findMap(activeMapName)
	local inactiveMap = findMap(inactiveMapName)

	if activeMap then
		activeMap.Parent = Workspace
	else
		warn(string.format("MapController could not find the %s map", activeMapName))
	end
	if inactiveMap then
		-- Only one complete map may remain replicated and physically active in a server at a time.
		inactiveMap.Parent = inactiveMaps
	end

	local spawn = activeMap and activeMap:FindFirstChild(spawnName)
	if spawn and spawn:IsA("SpawnLocation") then
		activeSpawn = spawn
	else
		warn(string.format("MapController could not find %s.%s", activeMapName, spawnName))
	end
end

function MapController.GetSpawnCFrame(): CFrame?
	return activeSpawn and activeSpawn.CFrame or nil
end

return MapController
