local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Signal = require(ReplicatedStorage.Packages.signal)
local PartyTeleporterConfig = require(ReplicatedStorage.Modules.Game.PartyTeleporterConfig)
local CharacterController = require(script.Parent.CharacterController)
local MapController = require(script.Parent.MapController)
local ServerContext = require(script.Parent.ServerContext)

local TELEPORT_DATA_VERSION = 1

local PartyTeleportService = {}

local studioLoadingStarted = Signal.new()
local studioCompleted = Signal.new()
local studioFailed = Signal.new()
local studioAttempts = {}
local activeStudioRunId: string?

local function validateRequest(players: { Player }, leader: Player, runId: string): (boolean, string?)
	if type(players) ~= "table" or #players == 0 or type(runId) ~= "string" or runId == "" then
		return false, "The party is no longer valid."
	end

	local seen = {}
	local hasLeader = false
	for _, player in players do
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players or seen[player] then
			return false, "The party contains an invalid player."
		end
		seen[player] = true
		hasLeader = hasLeader or player == leader
	end
	if not hasLeader then
		return false, "The party leader is no longer present."
	end
	return true, nil
end

local function buildTeleportData(players: { Player }, leader: Player, runId: string)
	local partyMemberIds = table.create(#players)
	for _, player in players do
		table.insert(partyMemberIds, player.UserId)
	end
	return {
		version = TELEPORT_DATA_VERSION,
		serverType = "Game",
		runId = runId,
		partyLeaderUserId = leader.UserId,
		partySize = #players,
		partyMemberIds = partyMemberIds,
		sourceJobId = game.JobId,
	}
end

local function validateStudioParty(players: { Player }): (boolean, string?)
	local playerLookup = {}
	for _, player in players do
		playerLookup[player] = true
	end
	for _, connectedPlayer in Players:GetPlayers() do
		if not playerLookup[connectedPlayer] then
			-- One Studio server cannot split clients across source and destination sessions.
			return false, "Every connected Studio test player must join the party before teleporting."
		end
	end
	if #players ~= #Players:GetPlayers() then
		return false, "The Studio test party changed before teleporting."
	end
	return true, nil
end

local function failStudioAttempt(runId: string, message: string)
	local attempt = studioAttempts[runId]
	if not attempt then
		return
	end
	studioAttempts[runId] = nil
	if activeStudioRunId == runId then
		activeStudioRunId = nil
	end
	studioFailed:Fire(runId, attempt.players, message)
end

local function startStudioTeleport(players: { Player }, leader: Player, runId: string, teleportData): (boolean, string?)
	if activeStudioRunId then
		return false, "Another local teleport is already in progress."
	end
	local partyValid, partyError = validateStudioParty(players)
	if not partyValid then
		return false, partyError
	end
	local contextValid, contextError = ServerContext.CanActivateStudioGameSession(teleportData)
	if not contextValid then
		return false, contextError
	end

	local attempt = {
		players = table.clone(players),
		leader = leader,
		teleportData = teleportData,
	}
	studioAttempts[runId] = attempt
	activeStudioRunId = runId
	studioLoadingStarted:Fire(runId, attempt.players, teleportData)

	task.delay(PartyTeleporterConfig.StudioTeleportLoadingDelay, function()
		if studioAttempts[runId] ~= attempt then
			return
		end

		local requestValid, requestError = validateRequest(attempt.players, attempt.leader, runId)
		local currentPartyValid, currentPartyError = validateStudioParty(attempt.players)
		if not requestValid or not currentPartyValid then
			failStudioAttempt(runId, requestError or currentPartyError or "The Studio test party changed.")
			return
		end

		local mapActivated, mapError = MapController.ActivateStudioGameDestination()
		if not mapActivated then
			failStudioAttempt(runId, mapError or "The local Game destination could not be loaded.")
			return
		end
		local contextActivated, activationError = ServerContext.ActivateStudioGameSession(attempt.teleportData)
		if not contextActivated then
			failStudioAttempt(runId, activationError or "The local Game session could not be started.")
			return
		end

		studioAttempts[runId] = nil
		activeStudioRunId = nil
		for _, player in attempt.players do
			if player.Parent == Players and not CharacterController.ReloadCharacter(player) then
				warn(string.format("Studio fake teleport could not immediately reload %s", player.Name))
			end
		end
		studioCompleted:Fire(runId, attempt.players, attempt.teleportData)
	end)

	return true, nil
end

function PartyTeleportService.Teleport(players: { Player }, leader: Player, runId: string): (boolean, string?)
	local requestValid, requestError = validateRequest(players, leader, runId)
	if not requestValid then
		return false, requestError
	end
	local teleportData = buildTeleportData(players, leader, runId)

	if RunService:IsStudio() then
		-- Studio never calls TeleportAsync; the local simulator keeps the same validated request and payload.
		return startStudioTeleport(players, leader, runId, teleportData)
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = true
	teleportOptions:SetTeleportData(teleportData)

	local success, result = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, players, teleportOptions)
	if not success then
		return false, tostring(result)
	end
	return true, nil
end

function PartyTeleportService.Cancel(runId: string)
	-- Cancellation only owns local delayed work; Roblox owns accepted published teleports.
	if RunService:IsStudio() then
		studioAttempts[runId] = nil
		if activeStudioRunId == runId then
			activeStudioRunId = nil
		end
	end
end

function PartyTeleportService.GetStudioLoadingStartedSignal()
	return studioLoadingStarted
end

function PartyTeleportService.GetStudioCompletedSignal()
	return studioCompleted
end

function PartyTeleportService.GetStudioFailedSignal()
	return studioFailed
end

return PartyTeleportService
