local TeleportService = game:GetService("TeleportService")

local TELEPORT_DATA_VERSION = 1

local PartyTeleportService = {}

function PartyTeleportService.Teleport(players: { Player }, leader: Player, runId: string): (boolean, string?)
	if #players == 0 or leader.Parent == nil or type(runId) ~= "string" or runId == "" then
		return false, "The party is no longer valid."
	end

	local partyMemberIds = table.create(#players)
	for _, player in players do
		table.insert(partyMemberIds, player.UserId)
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = true
	teleportOptions:SetTeleportData({
		version = TELEPORT_DATA_VERSION,
		serverType = "Game",
		runId = runId,
		partyLeaderUserId = leader.UserId,
		partySize = #players,
		partyMemberIds = partyMemberIds,
		sourceJobId = game.JobId,
	})

	local success, result = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, players, teleportOptions)
	if not success then
		return false, tostring(result)
	end
	return true, nil
end

return PartyTeleportService
