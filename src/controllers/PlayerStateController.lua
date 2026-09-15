local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)

local LocalPlayer = Players.LocalPlayer
local PlayerStateController = {}

function PlayerStateController.SyncState(_, Snapshot)
	if type(Snapshot) ~= "table" then
		return
	end

	for Key, Value in Snapshot do
		if type(Key) == "string" then
			RuntimeState.Set(LocalPlayer, Key, Value)
		end
	end
end

function PlayerStateController.UpdateState(_, Key, Value)
	if type(Key) == "string" then
		RuntimeState.Set(LocalPlayer, Key, Value)
	end
end

function PlayerStateController.Init()
	local StateNetwork = Networker.client.new("PlayerStateController", PlayerStateController)
	local Snapshot = StateNetwork:fetch("GetState")

	PlayerStateController.SyncState(nil, Snapshot)
end

return PlayerStateController
