local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuseumVisitorController = {}

function MuseumVisitorController.Init()
	require(ReplicatedStorage.Classes.MuseumVisitor)
end

return MuseumVisitorController
