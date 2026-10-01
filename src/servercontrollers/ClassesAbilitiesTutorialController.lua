local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local ClassesAbilitiesTutorialConfig = require(ReplicatedStorage.Modules.Game.ClassesAbilitiesTutorialConfig)
local SurvivalStatsConfig = require(ReplicatedStorage.Modules.Game.SurvivalStatsConfig)
local ServerContext = require(script.Parent.ServerContext)

local ClassesAbilitiesTutorialController = {}

local dataService
local tutorialNetwork
local activePlayers: { [Player]: boolean } = {}

local function makeState(player: Player)
	return {
		active = activePlayers[player] == true,
		targetClassId = ClassesAbilitiesTutorialConfig.TargetClassId,
	}
end

function ClassesAbilitiesTutorialController.GetState(_, player: Player)
	return makeState(player)
end

function ClassesAbilitiesTutorialController.IsActive(player: Player): boolean
	return activePlayers[player] == true
end

function ClassesAbilitiesTutorialController.Complete(player: Player)
	if not activePlayers[player] then
		return
	end
	-- Completion is written only after the authoritative free claim succeeds. Leaving at any earlier
	-- point intentionally leaves this false so the one-time tutorial resumes on the next lobby join.
	dataService:set(player, ClassesAbilitiesTutorialConfig.DataKey, true)
	activePlayers[player] = nil
	if tutorialNetwork and player.Parent == Players then
		tutorialNetwork:fire(player, "StateChanged", makeState(player))
	end
end

function ClassesAbilitiesTutorialController.SetDataService(service)
	dataService = service
end

function ClassesAbilitiesTutorialController.Init()
	tutorialNetwork = Networker.server.new("ClassesAbilitiesTutorialController", ClassesAbilitiesTutorialController, {
		ClassesAbilitiesTutorialController.GetState,
	})
end

function ClassesAbilitiesTutorialController.OnPlayerAdded(player: Player)
	local completed = dataService:get(player, ClassesAbilitiesTutorialConfig.DataKey) == true
	local roundsSurvived = dataService:get(player, SurvivalStatsConfig.DataKey)
	-- Eligibility is snapshotted on join. Finishing a first round in this session must not start a
	-- lobby tutorial immediately; the requested returning-player tutorial begins on a later rejoin.
	activePlayers[player] = ServerContext.IsLobbyServer()
		and not completed
		and type(roundsSurvived) == "number"
		and roundsSurvived >= 1
		or nil
	-- This also closes the narrow race where the client fetched before the server's player lifecycle reached us.
	if tutorialNetwork then
		tutorialNetwork:fire(player, "StateChanged", makeState(player))
	end
end

function ClassesAbilitiesTutorialController.OnPlayerRemoving(player: Player)
	activePlayers[player] = nil
end

return ClassesAbilitiesTutorialController
