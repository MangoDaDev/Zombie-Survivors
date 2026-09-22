local LeaderstatsController = {}
local DataService
local cashConnections: { [Player]: RBXScriptConnection } = {}

function LeaderstatsController.SetDataService(service)
	DataService = service
end

function LeaderstatsController.OnPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = DataService:get(player, "Cash") or 0
	cash.Parent = leaderstats
	leaderstats.Parent = player

	-- Cash in DataService is authoritative; leaderstats only mirrors it for display.
	cashConnections[player] = DataService:getChangedSignal(player, "Cash"):Connect(function(value)
		cash.Value = value or 0
	end)
end

function LeaderstatsController.OnPlayerRemoving(player: Player)
	local connection = cashConnections[player]
	if connection then connection:Disconnect() end
	cashConnections[player] = nil
end

return LeaderstatsController
