local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local DataController = {}
local DataService
local ResettingPlayers: { [Player]: boolean } = {}

function DataController.SetDataService(Service)
	DataService = Service
end

function DataController.Init()
	Players.PlayerRemoving:Connect(function(Player)
		ResettingPlayers[Player] = nil
	end)
	local ResetDataCommand = Instance.new("TextChatCommand")
	ResetDataCommand.Name = "ResetDataCommand"
	ResetDataCommand.PrimaryAlias = "/resetdata"
	ResetDataCommand.Triggered:Connect(function(TextSource)
		local Player = Players:GetPlayerByUserId(TextSource.UserId)
		if not Player or ResettingPlayers[Player] then return end
		ResettingPlayers[Player] = true
		DataService:resetData(Player)
	end)
	ResetDataCommand.Parent = TextChatService
end

return DataController
