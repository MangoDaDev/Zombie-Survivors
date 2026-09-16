local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)

local DataController = {}

function DataController.ShowMessage(_, Message)
	if type(Message) == "string" and Message ~= "" then NotificationManager.Notify(Message, 5) end
end

function DataController.Init()
	Networker.client.new("DataController", DataController)
end

return DataController
