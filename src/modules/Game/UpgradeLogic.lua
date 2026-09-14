local UpgradeConfig = require(script.Parent.UpgradeConfig)

local UpgradeLogic = {}

function UpgradeLogic.IsPurchased(Ownership, UpgradeId: string): boolean
	return type(Ownership) == "table" and Ownership[UpgradeId] == true
end

function UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade): boolean
	for _, PrerequisiteId in Upgrade.Prerequisites do
		if not UpgradeLogic.IsPurchased(Ownership, PrerequisiteId) then return false end
	end
	return true
end

function UpgradeLogic.GetState(Ownership, Upgrade): string
	if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) then return "Purchased" end
	return if UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade) then "Available" else "Locked"
end

function UpgradeLogic.GetMissingPrerequisiteNames(Ownership, Upgrade): { string }
	local Names = {}
	for _, PrerequisiteId in Upgrade.Prerequisites do
		if not UpgradeLogic.IsPurchased(Ownership, PrerequisiteId) then
			local Prerequisite = UpgradeConfig.Get(PrerequisiteId)
			table.insert(Names, if Prerequisite then Prerequisite.Name else PrerequisiteId)
		end
	end
	return Names
end

function UpgradeLogic.GetRevealDistances(Ownership, MaximumDistance: number): { [string]: number }
	local Distances = {}
	local Queue = {}
	for _, Upgrade in UpgradeConfig.Upgrades do
		local State = UpgradeLogic.GetState(Ownership, Upgrade)
		if State == "Purchased" or State == "Available" then
			Distances[Upgrade.Id] = 0
			table.insert(Queue, Upgrade.Id)
		end
	end
	local QueueIndex = 1
	while QueueIndex <= #Queue do
		local UpgradeId = Queue[QueueIndex]
		QueueIndex += 1
		local Distance = Distances[UpgradeId]
		if Distance < MaximumDistance then
			local Upgrade = UpgradeConfig.Get(UpgradeId)
			if Upgrade then
				for _, ConnectedId in Upgrade.ConnectedUpgrades do
					local NextDistance = Distance + 1
					if Distances[ConnectedId] == nil or NextDistance < Distances[ConnectedId] then
						Distances[ConnectedId] = NextDistance
						table.insert(Queue, ConnectedId)
					end
				end
			end
		end
	end
	return Distances
end

return UpgradeLogic
