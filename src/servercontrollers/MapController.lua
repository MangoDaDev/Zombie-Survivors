local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
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
	local activeMap = Workspace:FindFirstChild(name)
	if activeMap then
		return activeMap
	end
	local inactiveMaps = ServerStorage:FindFirstChild(INACTIVE_MAPS_FOLDER_NAME)
	return inactiveMaps and inactiveMaps:FindFirstChild(name) or nil
end

local function activateMap(activeMapName: string, inactiveMapName: string, spawnName: string): (boolean, string?)
	local inactiveMaps = getOrCreateInactiveMapsFolder()
	local activeMap = findMap(activeMapName)
	local inactiveMap = findMap(inactiveMapName)

	if not activeMap then
		return false, string.format("MapController could not find the %s map", activeMapName)
	end
	local spawn = activeMap:FindFirstChild(spawnName)
	if not spawn or not spawn:IsA("SpawnLocation") then
		return false, string.format("MapController could not find %s.%s", activeMapName, spawnName)
	end

	activeMap.Parent = Workspace
	if inactiveMap then
		-- Only one complete map may remain replicated and physically active in a server at a time.
		inactiveMap.Parent = inactiveMaps
	end
	activeSpawn = spawn
	return true, nil
end

function MapController.Init()
	local success, errorMessage = if ServerContext.IsGameServer()
		then activateMap(GAME_MAP_NAME, LOBBY_MAP_NAME, GAME_SPAWN_NAME)
		else activateMap(LOBBY_MAP_NAME, GAME_MAP_NAME, LOBBY_SPAWN_NAME)
	if not success then
		warn(errorMessage)
	end
end

function MapController.ActivateStudioGameDestination(): (boolean, string?)
	-- Published servers select their map only from verified join data during bootstrap.
	if not RunService:IsStudio() then
		return false, "Studio destination switching is unavailable in published servers."
	end
	return activateMap(GAME_MAP_NAME, LOBBY_MAP_NAME, GAME_SPAWN_NAME)
end

function MapController.GetSpawnCFrame(): CFrame?
	return activeSpawn and activeSpawn.CFrame or nil
end

return MapController
