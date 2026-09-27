local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local LobbyPlayerBillboard = require(ReplicatedStorage.UI.World.LobbyPlayerBillboard)
local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local Vide = require(ReplicatedStorage.Packages.vide)

type PublicStats = {
	roundsSurvived: number,
	classId: string,
}

type PlayerView = {
	changed: any,
	characterConnection: RBXScriptConnection,
	characterChildConnection: RBXScriptConnection?,
	unmount: (() -> ())?,
}

local LobbyPlayerBillboardController = {}

local statsNetwork: Networker.Client?
local statsByUserId: { [number]: PublicStats } = {}
local views: { [Player]: PlayerView } = {}
local playerAddedConnection: RBXScriptConnection?
local playerRemovingConnection: RBXScriptConnection?
local lobbyAddedConnection: RBXScriptConnection?
local lobbyRemovedConnection: RBXScriptConnection?

local function isNonNegativeInteger(value): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0
end

local function validatePacket(packet): (number?, PublicStats?)
	if type(packet) ~= "table"
		or not isNonNegativeInteger(packet.userId)
		or not isNonNegativeInteger(packet.roundsSurvived)
		or type(packet.classId) ~= "string"
		or not ClassDefinitions.ById[packet.classId]
	then
		return nil, nil
	end
	return packet.userId, {
		roundsSurvived = packet.roundsSurvived,
		classId = packet.classId,
	}
end

local function clearMountedView(view: PlayerView)
	if view.characterChildConnection then
		view.characterChildConnection:Disconnect()
		view.characterChildConnection = nil
	end
	if view.unmount then
		view.unmount()
		view.unmount = nil
	end
end

local function mountToHead(player: Player, character: Model, head: BasePart)
	local view = views[player]
	local stats = statsByUserId[player.UserId]
	if not view or not stats or not Workspace:FindFirstChild("Lobby") or player.Character ~= character then
		return
	end

	clearMountedView(view)
	local definition = ClassDefinitions.ById[stats.classId]
	view.unmount = Vide.mount(function()
		return LobbyPlayerBillboard({
			Adornee = head,
			RoundsSurvived = stats.roundsSurvived,
			ClassName = definition.Name,
			Changed = view.changed,
		})
	end, character)
end

local function bindCharacter(player: Player, character: Model)
	local view = views[player]
	if not view then
		return
	end
	clearMountedView(view)

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		mountToHead(player, character, head)
		return
	end

	-- Character replication is not atomic; listen for the required head instead of assuming it exists immediately.
	view.characterChildConnection = character.ChildAdded:Connect(function(child)
		if child.Name == "Head" and child:IsA("BasePart") then
			view.characterChildConnection:Disconnect()
			view.characterChildConnection = nil
			mountToHead(player, character, child)
		end
	end)
end

local function addPlayer(player: Player)
	if views[player] then
		return
	end
	local view: PlayerView = {
		changed = Signal.new(),
		characterConnection = player.CharacterAdded:Connect(function(character)
			bindCharacter(player, character)
		end),
		characterChildConnection = nil,
		unmount = nil,
	}
	views[player] = view
	if player.Character then
		bindCharacter(player, player.Character)
	end
end

local function removePlayer(player: Player)
	local view = views[player]
	if not view then
		return
	end
	clearMountedView(view)
	view.characterConnection:Disconnect()
	view.changed:Destroy()
	views[player] = nil
	statsByUserId[player.UserId] = nil
end

local function applyPacket(packet)
	local userId, stats = validatePacket(packet)
	if not userId or not stats then
		return
	end
	statsByUserId[userId] = stats
	local player = Players:GetPlayerByUserId(userId)
	local view = player and views[player]
	if view then
		view.changed:Fire(stats.roundsSurvived, ClassDefinitions.ById[stats.classId].Name)
		if player.Character and not view.unmount then
			bindCharacter(player, player.Character)
		end
	end
end

local function refreshLobbyViews()
	for player, view in views do
		if Workspace:FindFirstChild("Lobby") then
			if player.Character then
				bindCharacter(player, player.Character)
			end
		else
			clearMountedView(view)
		end
	end
end

function LobbyPlayerBillboardController.PlayerStatsChanged(_, packet)
	applyPacket(packet)
end

function LobbyPlayerBillboardController.Init()
	statsNetwork = Networker.client.new("SurvivalStatsController", LobbyPlayerBillboardController)
	local packets = (statsNetwork :: Networker.Client):fetch("GetPublicStats")
	if type(packets) == "table" then
		for _, packet in packets do
			applyPacket(packet)
		end
	end

	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	lobbyAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Lobby" then
			refreshLobbyViews()
		end
	end)
	lobbyRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Lobby" then
			refreshLobbyViews()
		end
	end)
end

return LobbyPlayerBillboardController
