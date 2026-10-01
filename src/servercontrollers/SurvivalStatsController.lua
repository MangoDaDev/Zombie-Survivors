local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local Networker = require(ReplicatedStorage.Packages.networker)
local SurvivalStatsConfig = require(ReplicatedStorage.Modules.Game.SurvivalStatsConfig)
local RoundController = require(ServerStorage.Controllers.RoundController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)

type Runtime = {
	roundsSurvived: number,
	classId: string,
	classChangedConnection: any,
}

local SurvivalStatsController = {}

local dataService
local statsNetwork
local runtimes: { [Player]: Runtime } = {}

local function normalizeRoundsSurvived(value): number
	return if type(value) == "number" and value % 1 == 0 and value >= 0 then value else SurvivalStatsConfig.DefaultRoundsSurvived
end

local function normalizeClassId(value): string
	return if type(value) == "string" and ClassDefinitions.ById[value] then value else ClassDefinitions.DefaultId
end

local function makePacket(player: Player)
	local runtime = runtimes[player]
	return runtime and {
		userId = player.UserId,
		roundsSurvived = runtime.roundsSurvived,
		classId = runtime.classId,
	} or nil
end

local function broadcastPlayer(player: Player)
	if not statsNetwork or not ServerContext.IsLobbyServer() then
		return
	end
	local packet = makePacket(player)
	if not packet then
		return
	end
	for _, recipient in Players:GetPlayers() do
		statsNetwork:fire(recipient, "PlayerStatsChanged", packet)
	end
end

local function recordHighestRound(completedRound: number, playersWhoSurvived: { Player })
	for _, player in playersWhoSurvived do
		local runtime = runtimes[player]
		if runtime and player.Parent == Players and completedRound > runtime.roundsSurvived then
			-- This public stat is the player's personal best, not a lifetime total. Only an
			-- authoritative round completion while alive can raise it, so replaying earlier
			-- rounds or joining another run cannot inflate the saved value.
			runtime.roundsSurvived = completedRound
			dataService:set(player, SurvivalStatsConfig.DataKey, runtime.roundsSurvived)
			AnalyticsController.TrackLifetimeProgression(player, runtime.roundsSurvived)
		end
	end
end

function SurvivalStatsController.GetPublicStats(_, _requestingPlayer: Player)
	local packets = {}
	if not ServerContext.IsLobbyServer() then
		return packets
	end
	for player in runtimes do
		local packet = makePacket(player)
		if packet then
			table.insert(packets, packet)
		end
	end
	return packets
end

function SurvivalStatsController.SetDataService(service)
	dataService = service
end

function SurvivalStatsController.Init()
	statsNetwork = Networker.server.new("SurvivalStatsController", SurvivalStatsController, {
		SurvivalStatsController.GetPublicStats,
	})
	RoundController.GetRoundCompletedSignal():Connect(function(completedRound, playersWhoSurvived)
		recordHighestRound(completedRound, playersWhoSurvived)
	end)
end

function SurvivalStatsController.OnPlayerAdded(player: Player)
	local savedRounds = dataService:get(player, SurvivalStatsConfig.DataKey)
	local classData = dataService:get(player, ClassDefinitions.DataKey)
	local roundsSurvived = normalizeRoundsSurvived(savedRounds)
	if roundsSurvived ~= savedRounds then
		dataService:set(player, SurvivalStatsConfig.DataKey, roundsSurvived)
	end
	local runtime: Runtime
	runtime = {
		roundsSurvived = roundsSurvived,
		classId = normalizeClassId(type(classData) == "table" and classData.Equipped or nil),
		classChangedConnection = dataService:getChangedSignal(player, { ClassDefinitions.DataKey }):Connect(function(newClassData)
			runtime.classId = normalizeClassId(type(newClassData) == "table" and newClassData.Equipped or nil)
			broadcastPlayer(player)
		end),
	}
	runtimes[player] = runtime
	broadcastPlayer(player)
end

function SurvivalStatsController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.classChangedConnection:Disconnect()
		runtimes[player] = nil
	end
end

return SurvivalStatsController
