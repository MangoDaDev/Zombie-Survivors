local UpgradeConfig = require(script.Parent.UpgradeConfig)

local UpgradeLogic = {}

function UpgradeLogic.IsPurchased(Ownership, UpgradeId: string): boolean
	return type(Ownership) == "table" and Ownership[UpgradeId] == true
end

function UpgradeLogic.GetDefaultOwnership(): { [string]: boolean }
	local Ownership = {}
	for UpgradeId, IsOwned in UpgradeConfig.DefaultOwnership do
		if IsOwned == true then Ownership[UpgradeId] = true end
	end
	return Ownership
end

function UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade): boolean
	for _, PrerequisiteId in Upgrade.Prerequisites do
		if not UpgradeLogic.IsPurchased(Ownership, PrerequisiteId) then return false end
	end
	return true
end

function UpgradeLogic.NormalizeOwnership(Value): { [string]: boolean }
	local Ownership = UpgradeLogic.GetDefaultOwnership()
	if type(Value) == "table" then
		for UpgradeId, IsOwned in Value do
			if type(UpgradeId) == "string" and IsOwned == true and UpgradeConfig.Get(UpgradeId) then
				Ownership[UpgradeId] = true
			end
		end
	end

	-- Preserve previously purchased bat tiers when new bats are inserted into the progression.
	local InsertedBatPrerequisites = {
		GoldBat = "IronBat",
		DiamondBat = "TitaniumBat",
		ObsidianBat = "ReinforcedSteelBat",
	}
	for OwnedBatId, InsertedBatId in InsertedBatPrerequisites do
		if Ownership[OwnedBatId] == true then Ownership[InsertedBatId] = true end
	end
	local ToolUnlockProgression = {
		"UnlockSponge",
		"UnlockSoftBrush",
		"UnlockHairdryer",
		"UnlockSprayPaint",
		"UnlockPolisher",
		"UnlockHammer",
		"UnlockMagnet",
	}
	local HighestOwnedToolIndex = 0
	for Index, UpgradeId in ToolUnlockProgression do
		if Ownership[UpgradeId] == true then HighestOwnedToolIndex = Index end
	end
	for Index = 1, HighestOwnedToolIndex do
		Ownership[ToolUnlockProgression[Index]] = true
	end

	local RemovedInvalidUpgrade = true
	while RemovedInvalidUpgrade do
		RemovedInvalidUpgrade = false

		for UpgradeId, IsOwned in Ownership do
			local Upgrade = UpgradeConfig.Get(UpgradeId)
			if IsOwned == true and Upgrade and not UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade) then
				Ownership[UpgradeId] = nil
				RemovedInvalidUpgrade = true
			end
		end
	end

	return Ownership
end

function UpgradeLogic.GetState(Ownership, Upgrade): string
	if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) then return "Purchased" end
	return if UpgradeLogic.ArePrerequisitesMet(Ownership, Upgrade) then "Available" else "Locked"
end

function UpgradeLogic.CanPurchaseUpgrade(Ownership, Upgrade, Cash): boolean
	return Upgrade.Purchasable ~= false
		and UpgradeLogic.GetState(Ownership, Upgrade) == "Available"
		and type(Cash) == "number"
		and Cash >= Upgrade.Cost
end

UpgradeLogic.IsAffordable = UpgradeLogic.CanPurchaseUpgrade

function UpgradeLogic.GetAvailableUpgrades(Ownership): { any }
	local AvailableUpgrades = {}

	for _, Upgrade in UpgradeConfig.Upgrades do
		if Upgrade.Purchasable ~= false and UpgradeLogic.GetState(Ownership, Upgrade) == "Available" then
			table.insert(AvailableUpgrades, Upgrade)
		end
	end

	return AvailableUpgrades
end

function UpgradeLogic.GetAffordableUpgrades(Ownership, Cash): { any }
	local AffordableUpgrades = {}

	for _, Upgrade in UpgradeLogic.GetAvailableUpgrades(Ownership) do
		if type(Cash) == "number" and Cash >= Upgrade.Cost then
			table.insert(AffordableUpgrades, Upgrade)
		end
	end

	return AffordableUpgrades
end

function UpgradeLogic.GetDisplayLimit(Ownership): number
	local Limit = UpgradeConfig.DefaultDisplayLimit
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) and Effect and Effect.Type == "DisplayLimit" then
			Limit = math.max(Limit, Effect.Value)
		end
	end
	return Limit
end

function UpgradeLogic.GetGuestsPerItem(Ownership): number
	local Limit = UpgradeConfig.DefaultGuestsPerItem
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) and Effect and Effect.Type == "GuestsPerItem" then
			Limit = math.max(Limit, Effect.Value)
		end
	end
	return Limit
end

-- Preserve the old public API for systems outside this repository that may still call it.
UpgradeLogic.GetVisitorsPerDisplay = UpgradeLogic.GetGuestsPerItem

function UpgradeLogic.IsToolUnlocked(Ownership, ToolId: string): boolean
	if ToolId == "Spray" then return true end
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if
			UpgradeLogic.IsPurchased(Ownership, Upgrade.Id)
			and Effect
			and Effect.Type == "ToolUnlock"
			and Effect.ToolId == ToolId
		then
			return true
		end
	end
	return false
end

function UpgradeLogic.GetToolUnlockUpgrade(ToolId: string)
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if Effect and Effect.Type == "ToolUnlock" and Effect.ToolId == ToolId then return Upgrade end
	end
end

function UpgradeLogic.GetToolStrengthMultiplier(Ownership, ToolId: string): number
	local Multiplier = UpgradeConfig.DefaultToolStrengthMultiplier
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if
			UpgradeLogic.IsPurchased(Ownership, Upgrade.Id)
			and Effect
			and Effect.Type == "ToolStrength"
			and Effect.ToolId == ToolId
		then
			Multiplier = math.max(Multiplier, Effect.Multiplier)
		end
	end
	return Multiplier
end

function UpgradeLogic.GetToolRadiusMultiplier(Ownership, ToolId: string): number
	local Multiplier = UpgradeConfig.DefaultToolRadiusMultiplier
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if
			UpgradeLogic.IsPurchased(Ownership, Upgrade.Id)
			and Effect
			and Effect.Type == "ToolStrength"
			and Effect.ToolId == ToolId
		then
			Multiplier = math.max(Multiplier, Effect.RadiusMultiplier or Multiplier)
		end
	end
	return Multiplier
end

function UpgradeLogic.GetBatId(Ownership): string
	local BatId = UpgradeConfig.DefaultBatId
	local HighestTier = 0
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if
			UpgradeLogic.IsPurchased(Ownership, Upgrade.Id)
			and Effect
			and Effect.Type == "BatTier"
			and Effect.Tier > HighestTier
		then
			BatId = Effect.BatId
			HighestTier = Effect.Tier
		end
	end
	return BatId
end

function UpgradeLogic.GetBatCooldownMultiplier(Ownership): number
	local Multiplier = 1
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if
			UpgradeLogic.IsPurchased(Ownership, Upgrade.Id)
			and Effect
			and Effect.Type == "BatCooldown"
		then
			Multiplier = math.min(Multiplier, Effect.Multiplier)
		end
	end
	return Multiplier
end

function UpgradeLogic.GetWalkSpeed(Ownership): number
	local WalkSpeed = UpgradeConfig.DefaultWalkSpeed
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) and Effect and Effect.Type == "WalkSpeed" then
			WalkSpeed = math.max(WalkSpeed, Effect.Value)
		end
	end
	return WalkSpeed
end

function UpgradeLogic.GetJumpHeight(Ownership): number
	local JumpHeight = UpgradeConfig.DefaultJumpHeight
	for _, Upgrade in UpgradeConfig.Upgrades do
		local Effect = Upgrade.Effect
		if UpgradeLogic.IsPurchased(Ownership, Upgrade.Id) and Effect and Effect.Type == "JumpHeight" then
			JumpHeight = math.max(JumpHeight, Effect.Value)
		end
	end
	return JumpHeight
end

function UpgradeLogic.CanReveal(Ownership, Upgrade): boolean
	local Effect = Upgrade.Effect
	return not Effect or Effect.Type ~= "ToolStrength" or UpgradeLogic.IsToolUnlocked(Ownership, Effect.ToolId)
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
		if not UpgradeLogic.CanReveal(Ownership, Upgrade) then continue end
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
					local ConnectedUpgrade = UpgradeConfig.Get(ConnectedId)
					if not ConnectedUpgrade or not UpgradeLogic.CanReveal(Ownership, ConnectedUpgrade) then continue end
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
