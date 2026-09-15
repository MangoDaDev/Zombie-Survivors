local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)

local PlayerStateController = {}
local StateNetwork

function PlayerStateController.Get(Player, Key, DefaultValue)
	return RuntimeState.Get(Player, Key, DefaultValue)
end

function PlayerStateController.Set(Player, Key, Value)
	RuntimeState.Set(Player, Key, Value)

	if StateNetwork then
		StateNetwork:fire(Player, "UpdateState", Key, Value)
	end
end

function PlayerStateController.GetChangedSignal(Player, Key)
	return RuntimeState.GetChangedSignal(Player, Key)
end

function PlayerStateController.GetState(_, Player)
	return RuntimeState.GetSnapshot(Player)
end

function PlayerStateController.Init()
	StateNetwork = Networker.server.new("PlayerStateController", PlayerStateController, {
		PlayerStateController.GetState,
	})
end

function PlayerStateController.OnPlayerRemoving(Player)
	RuntimeState.Clear(Player)
end

return PlayerStateController
