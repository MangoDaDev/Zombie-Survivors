local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)
local ZombieIndexConfig = require(ReplicatedStorage.Modules.Game.Zombies.ZombieIndexConfig)
local CoinsController = require(ServerStorage.Controllers.CoinsController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local REQUEST_COOLDOWN = 0.2
local PERSIST_DELAY = 1

local ZombieIndexController = {}

local dataService
local indexNetwork
local runtimes = {}

local function normalizeData(rawData)
	local normalized = {}
	if type(rawData) ~= "table" then
		return normalized
	end

	for zombieId, rawEntry in rawData do
		if type(zombieId) == "string" and ZombieIndexConfig.ById[zombieId] and type(rawEntry) == "table" then
			local kills = rawEntry.Kills
			if type(kills) == "number" and kills == kills and kills >= 1 and kills % 1 == 0 then
				normalized[zombieId] = {
					Kills = math.min(kills, CoinsConfig.MaximumBalance),
					RewardClaimed = rawEntry.RewardClaimed == true,
				}
			end
		end
	end

	return normalized
end

local function deepEqual(left, right): boolean
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function persistRuntime(player: Player, runtime)
	if runtimes[player] ~= runtime or not runtime.dirty then
		return
	end
	runtime.dirty = false
	dataService:set(player, ZombieIndexConfig.DataKey, runtime.data)
end

local function queuePersist(player: Player, runtime)
	if runtime.dirty then
		return
	end
	runtime.dirty = true
	runtime.persistToken += 1
	local token = runtime.persistToken
	-- Kill bursts are coalesced into one profile update instead of writing once per defeated zombie.
	task.delay(PERSIST_DELAY, function()
		if runtimes[player] == runtime and runtime.persistToken == token then
			persistRuntime(player, runtime)
		end
	end)
end

local function canRequest(player: Player, runtime): boolean
	if not runtime or player.Parent ~= Players then
		return false
	end
	local now = os.clock()
	if now - runtime.lastRequestAt < REQUEST_COOLDOWN then
		return false
	end
	runtime.lastRequestAt = now
	return true
end

local function sendResult(player: Player, success: boolean, message: string)
	indexNetwork:fire(player, "ActionResult", success, message)
end

local function onZombieDied(death)
	if type(death) ~= "table" or type(death.typeName) ~= "string" or not ZombieIndexConfig.ById[death.typeName] then
		return
	end
	local killer = death.killer
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") or killer.Parent ~= Players then
		return
	end
	local runtime = runtimes[killer]
	if not runtime then
		return
	end

	local entry = runtime.data[death.typeName]
	if not entry then
		entry = { Kills = 0, RewardClaimed = false }
		runtime.data[death.typeName] = entry
	end
	entry.Kills = math.min(entry.Kills + 1, CoinsConfig.MaximumBalance)
	queuePersist(killer, runtime)
end

function ZombieIndexController.GetSnapshot(_, player: Player)
	local runtime = runtimes[player]
	return if runtime then runtime.data else {}
end

function ZombieIndexController.ClaimDiscoveryReward(_, player: Player, zombieId: any)
	local runtime = runtimes[player]
	if not canRequest(player, runtime) or type(zombieId) ~= "string" then
		return
	end
	local definition = ZombieIndexConfig.ById[zombieId]
	local entry = definition and runtime.data[zombieId]
	if not definition or not entry or entry.Kills < 1 then
		sendResult(player, false, "Defeat this zombie before claiming its discovery reward.")
		return
	end
	if entry.RewardClaimed then
		sendResult(player, false, definition.Name .. " reward already claimed.")
		return
	end

	local added = CoinsController.Add(player, definition.DiscoveryReward)
	if not added then
		sendResult(player, false, "The discovery reward could not be added right now.")
		return
	end

	-- The authoritative entry is marked exactly once after the fixed server-selected coin award succeeds.
	entry.RewardClaimed = true
	runtime.dirty = true
	persistRuntime(player, runtime)
	sendResult(player, true, string.format("Claimed %d Coins for discovering %s!", definition.DiscoveryReward, definition.Name))
end

function ZombieIndexController.SetDataService(service)
	dataService = service
end

function ZombieIndexController.Init()
	indexNetwork = Networker.server.new("ZombieIndexController", ZombieIndexController, {
		ZombieIndexController.GetSnapshot,
		ZombieIndexController.ClaimDiscoveryReward,
	})
	ZombieController.GetZombieDiedSignal():Connect(onZombieDied)
end

function ZombieIndexController.OnPlayerAdded(player: Player)
	local rawData = dataService:get(player, ZombieIndexConfig.DataKey)
	local normalized = normalizeData(rawData)
	runtimes[player] = {
		data = normalized,
		dirty = false,
		persistToken = 0,
		lastRequestAt = -math.huge,
	}
	if not deepEqual(rawData, normalized) then
		dataService:set(player, ZombieIndexConfig.DataKey, normalized)
	end
end

function ZombieIndexController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.persistToken += 1
		persistRuntime(player, runtime)
		runtimes[player] = nil
	end
end

return ZombieIndexController
