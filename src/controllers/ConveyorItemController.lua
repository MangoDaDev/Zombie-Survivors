local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConveyorItemController = {}

function ConveyorItemController.Init()
	require(ReplicatedStorage.Classes.ConveyorItem)
end

return ConveyorItemController
