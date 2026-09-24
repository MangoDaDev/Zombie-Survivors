local AbilityDefinitions = require(script.Parent.Parent.Abilities.AbilityDefinitions)

local RollDefinitions = {}

RollDefinitions.InventoryDataKey = "RollInventory"
RollDefinitions.TotalRollsDataKey = "TotalRolls"
RollDefinitions.AutoRollEnabledDataKey = "AutoRollEnabled"
RollDefinitions.PresentationHiddenDataKey = "RollPresentationHidden"
-- Auto Roll is earned through normal rolling; the server validates this threshold before enabling it.
RollDefinitions.AutoRollUnlockRolls = 5

-- These timings are shared only so the authoritative server cadence stays aligned with the client presentation.
RollDefinitions.Timing = {
	ReelDuration = 2.85,
	ResultHoldDuration = 0.8,
	AutoRollDelay = 0.45,
	DiscoveryAutoResumeDelay = 5,
}

-- The catalog is intentionally sourced only from real ability definitions. Adding another Roll entry to an
-- ability automatically expands the generic weighted RNG without restoring placeholder/test rewards.
RollDefinitions.Items = {}

for _, ability in AbilityDefinitions.List do
	if ability.Roll then
		table.insert(RollDefinitions.Items, {
			Id = "Ability_" .. ability.Id,
			Name = ability.Name,
			Image = ability.Icon,
			BaseOdds = ability.Roll.BaseOdds,
			Rarity = ability.Roll.Rarity,
			RarityRank = ability.Roll.RarityRank,
			Color = ability.Color,
			AbilityId = ability.Id,
		})
	end
end

RollDefinitions.ById = {}
for _, item in RollDefinitions.Items do
	item.Weight = 1 / item.BaseOdds
	RollDefinitions.ById[item.Id] = item
end

return RollDefinitions
