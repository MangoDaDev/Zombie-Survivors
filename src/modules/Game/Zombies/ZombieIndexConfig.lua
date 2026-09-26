local ZombieDefinitions = require(script.Parent.ZombieDefinitions)

local BASE_DISCOVERY_REWARD = 25
local REWARD_PER_THREAT_LEVEL = 5

local orderedEntries = {
	{ Id = "Walker", Name = "Walker", Description = "A basic zombie that steadily chases the nearest survivor." },
	{ Id = "Runner", Name = "Runner", Description = "A fragile but very fast zombie with quick close-range attacks." },
	{ Id = "Brute", Name = "Brute", Description = "A slow, durable zombie that hits hard and takes plenty of punishment." },
	{ Id = "Spitter", Name = "Spitter", Description = "Keeps its distance and spits a damaging projectile at a predicted position." },
	{ Id = "Charger", Name = "Charger", Description = "Lines up a high-speed charge. A missed charge briefly leaves it vulnerable." },
	{ Id = "Screamer", Name = "Screamer", Description = "Stops to scream and summon a small group of Walkers." },
	{ Id = "Tank", Name = "Tank", Description = "A huge threat that winds up a damaging shockwave around itself." },
	{ Id = "Leaper", Name = "Leaper", Description = "Predicts a survivor's movement and quickly leaps toward that position." },
	{ Id = "Shielder", Name = "Shielder", Description = "Blocks direct attacks from the front; area and status damage bypass the shield." },
	{ Id = "Bomber", Name = "Bomber", Description = "Starts a countdown when close, then explodes and damages everything nearby." },
	{ Id = "Grabber", Name = "Grabber", Description = "Attacks from range and yanks the target toward itself." },
	{ Id = "Summoner", Name = "Summoner", Description = "Periodically summons several fast Splitlings around itself." },
	{ Id = "Splitter", Name = "Splitter", Description = "Breaks into two smaller Splitlings when defeated." },
	{ Id = "Splitling", Name = "Splitling", Description = "A tiny summoned zombie that trades durability for extreme speed." },
	{ Id = "Burrower", Name = "Burrower", Description = "Becomes untouchable underground, then emerges near the survivor after a warning." },
	{ Id = "Frenzy", Name = "Frenzy", Description = "Enrages below half health and gains a powerful temporary speed boost." },
	{ Id = "Medic", Name = "Medic", Description = "Releases healing pulses that restore nearby zombies." },
	{ Id = "Hardened", Name = "Hardened", Description = "Starts with a layer of armor that must be broken before its health is damaged." },
	{ Id = "Dodger", Name = "Dodger", Description = "Periodically sidesteps a direct hit and avoids all of its damage." },
	{ Id = "Sludger", Name = "Sludger", Description = "Leaves a lingering slowing puddle behind when defeated." },
	{ Id = "Warden", Name = "Warden", Description = "Projects an aura that makes nearby zombies faster and stronger." },
	{ Id = "CorpseEater", Name = "Corpse Eater", Description = "Consumes nearby zombie deaths to heal, grow tougher, move faster, and deal more damage." },
	{ Id = "Hexer", Name = "Hexer", Description = "Marks a predicted position, then detonates a delayed damaging hex there." },
	{ Id = "Anchor", Name = "Anchor", Description = "Tethers nearby survivors and continuously slows their movement." },
	{ Id = "Frostbite", Name = "Frostbite", Description = "Casts a freezing cone that slows every survivor caught in front of it." },
	{ Id = "Rallying", Name = "Rallying", Description = "Periodically rallies nearby Walkers with a large speed boost." },
	{ Id = "Hoarder", Name = "Hoarder", Description = "Steals nearby coin and XP drops, then releases everything when defeated." },
	{ Id = "BroodPod", Name = "Brood Pod", Description = "A stationary pod that hatches into a pack of Splitlings if not destroyed quickly." },
	{ Id = "Martyr", Name = "Martyr", Description = "Empowers nearby zombies with extra speed and damage when defeated." },
	{ Id = "Stalker", Name = "Stalker", Description = "Crawls while watched, but moves extremely quickly when no survivor is looking." },
	{ Id = "Juggernaut", Name = "Juggernaut", Description = "Builds speed and knockback resistance while advancing; damaging it resets the momentum." },
}

local byId = {}
for _, entry in orderedEntries do
	local definition = ZombieDefinitions[entry.Id]
	if definition then
		local threatLevel = math.max(math.floor(definition.ThreatLevel or 0), 0)
		-- Discovery rewards are fixed here so the server, UI, and future balance passes share one value.
		entry.DiscoveryReward = BASE_DISCOVERY_REWARD + threatLevel * REWARD_PER_THREAT_LEVEL
		entry.ThreatLevel = threatLevel
		entry.MaxHealth = definition.MaxHealth
		entry.EffectColor = definition.EffectColor
		byId[entry.Id] = entry
	end
end

local ZombieIndexConfig = {
	DataKey = "ZombieIndex",
	List = orderedEntries,
	ById = byId,
}

return table.freeze(ZombieIndexConfig)
