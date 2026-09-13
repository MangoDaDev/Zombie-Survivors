local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConveyorItemController = {}

function ConveyorItemController:Init()
	require(ReplicatedStorage.Modules.Game.ConveyorItem)
end

return ConveyorItemController
