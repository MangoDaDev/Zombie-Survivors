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

return UpgradeLogic
