local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local AdditionalAbilityDefinitions = {}
local MAX_LEVEL = 50

local function levelOf(level: number): number
	return math.clamp(math.floor(level), 1, MAX_LEVEL)
end

local function statsText(definition, level: number, fields): string
	local current = definition.GetStats(level)
	local nextStats = if level < MAX_LEVEL then definition.GetStats(level + 1) else nil
	local lines = {}
	for _, field in fields do
		local currentText = field.Format(current[field.Key])
		table.insert(lines, if nextStats
			then string.format("%s  %s > %s", field.Label, currentText, field.Format(nextStats[field.Key]))
			else string.format("%s  %s", field.Label, currentText))
	end
	return table.concat(lines, "\n")
end

local function number(value: number): string
	return string.format("%.1f", value)
end

local function seconds(value: number): string
	return string.format("%.2fs", value)
end

local function percent(value: number): string
	return string.format("%.1f%%", value)
end

local shotgun = {
	Id = "Shotgun", Name = "Shotgun", Category = "Weapon",
	Description = "Fires a cone of pellets into a nearby crowd. Multiple pellets can strike the same zombie.",
	UpgradeDescription = "Levels improve pellet damage, size, range, and fire rate. Milestones add barrels, stagger, and piercing.",
	RageDescription = "Fires faster with extra pellets, stronger knockback, and a follow-up blast after every shot.",
	Icon = Images.Abilities.Shotgun, Color = Color3.fromRGB(255, 193, 75),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 120, UpgradeCostGrowth = 1.146,
	Roll = { BaseOdds = 10, Rarity = "Rare", RarityRank = 3 },
	Combat = { Range = 48, MaximumCandidates = 60, Knockback = 10, SecondBlastDelay = 0.18 },
	Milestones = {
		{ Level = 5, Description = "Tight Choke - narrower spread and longer range" },
		{ Level = 10, Description = "Extra Buckshot - two additional pellets per blast" },
		{ Level = 20, Description = "Double Barrel - a weaker second blast follows each shot" },
		{ Level = 30, Description = "Shell Shock - several pellets briefly stagger a zombie" },
		{ Level = 40, Description = "Heavy Load - pellets pierce one zombie" },
		{ Level = 50, Description = "Street Sweeper - more pellets and a full-strength second blast" },
	},
}

function shotgun.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(11 * (1 + (valid - 1) * 0.045) + 0.5),
		Pellets = 6 + (if valid >= 10 then 2 else 0) + (if valid >= 50 then 2 else 0),
		SpreadDegrees = if valid >= 5 then 30 else 38,
		Range = shotgun.Combat.Range * (1 + (valid - 1) * 0.003) * (if valid >= 5 then 1.15 else 1),
		PelletRadius = 0.62 * (1 + (valid - 1) * 0.003),
		Cooldown = math.max(1.18, 2.15 - (valid - 1) * 0.014),
		SecondBlast = valid >= 20,
		SecondDamageMultiplier = if valid >= 50 then 1 else 0.62,
		Stagger = valid >= 30,
		Pierce = valid >= 40,
	}
end

function shotgun.GetRageStats(level: number)
	local stats = shotgun.GetStats(level)
	stats.Pellets += 3
	stats.Cooldown *= 0.62
	stats.SecondBlast = true
	stats.SecondDamageMultiplier = math.max(stats.SecondDamageMultiplier, 0.8)
	stats.IsRage = true
	return stats
end

function shotgun.GetStatsText(level: number): string
	return statsText(shotgun, level, {
		{ Key = "Damage", Label = "Pellet Damage", Format = tostring },
		{ Key = "Pellets", Label = "Pellets", Format = tostring },
		{ Key = "Range", Label = "Range", Format = number },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local frostNova = {
	Id = "FrostNova", Name = "Frost Nova", Category = "Weapon",
	Description = "Releases an expanding ice ring that damages and slows zombies it crosses.",
	UpgradeDescription = "Levels improve damage, radius, Chill, and pulse rate. Milestones add shatter, aftershocks, and freezing.",
	RageDescription = "Fast Frost Novas surround the player. Repeated hits briefly freeze regular zombies and deeply Chill resistant enemies.",
	Icon = Images.Abilities.FrostNova, Color = Color3.fromRGB(132, 230, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 135, UpgradeCostGrowth = 1.147,
	Roll = { BaseOdds = 20, Rarity = "Epic", RarityRank = 4 },
	Combat = { WaveDuration = 0.48, MaximumTargets = 60, Knockback = 3, ChillDuration = 2.3 },
	Milestones = {
		{ Level = 5, Description = "Wide Nova - larger wave radius" },
		{ Level = 10, Description = "Deep Chill - stronger and longer slow" },
		{ Level = 20, Description = "Brittle Ice - the next hit shatters Chill for bonus damage" },
		{ Level = 30, Description = "Aftershock - a smaller second ring follows each Nova" },
		{ Level = 40, Description = "Frozen Ground - a lingering ring slows crossing zombies" },
		{ Level = 50, Description = "Absolute Zero - two full waves can freeze normal zombies" },
	},
}

function frostNova.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(19 * (1 + (valid - 1) * 0.052) + 0.5),
		Radius = math.min(19, 10 * (1 + (valid - 1) * 0.006) * (if valid >= 5 then 1.18 else 1)),
		Cooldown = math.max(2.1, 3.4 - (valid - 1) * 0.018),
		ChillMultiplier = math.max(0.44, 0.75 - (valid - 1) * 0.003 - (if valid >= 10 then 0.08 else 0)),
		ChillDuration = frostNova.Combat.ChillDuration + (valid - 1) * 0.013 + (if valid >= 10 then 0.6 else 0),
		Shatter = valid >= 20,
		Aftershock = valid >= 30,
		FrozenGround = valid >= 40,
		DoubleWave = valid >= 50,
	}
end

function frostNova.GetRageStats(level: number)
	local stats = frostNova.GetStats(level)
	stats.Cooldown *= 0.55
	stats.Radius *= 1.1
	stats.Aftershock = true
	stats.FreezeOnRepeat = true
	stats.IsRage = true
	return stats
end

function frostNova.GetStatsText(level: number): string
	return statsText(frostNova, level, {
		{ Key = "Damage", Label = "Damage", Format = tostring },
		{ Key = "Radius", Label = "Radius", Format = number },
		{ Key = "ChillDuration", Label = "Chill", Format = seconds },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local meteor = {
	Id = "Meteor", Name = "Meteor", Category = "Weapon",
	Description = "Marks a dense zombie group, then drops a delayed meteor from above for heavy area damage.",
	UpgradeDescription = "Levels improve impact damage, radius, targeting, and cast rate. Milestones add shockwaves, fragments, and more meteors.",
	RageDescription = "Each cast showers separate groups with smaller meteors before a powerful central impact.",
	Icon = Images.Abilities.Meteor, Color = Color3.fromRGB(255, 107, 55),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 145, UpgradeCostGrowth = 1.15,
	Roll = { BaseOdds = 40, Rarity = "Legendary", RarityRank = 5 },
	Combat = { MaximumCandidates = 40, MaximumTargets = 60, Knockback = 17, FragmentCount = 5, FragmentRadius = 2.6 },
	Milestones = {
		{ Level = 5, Description = "Fast Fall - shorter warning before impact" },
		{ Level = 10, Description = "Shockwave - a larger, weaker outer blast" },
		{ Level = 20, Description = "Twin Impact - targets two separate groups" },
		{ Level = 30, Description = "Falling Fragments - impact scatters small damaging fragments" },
		{ Level = 40, Description = "Extinction - impact kills advance the next cast, up to a cap" },
		{ Level = 50, Description = "Cataclysm - three larger meteors with stronger overlapping impacts" },
	},
}

function meteor.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(62 * (1 + (valid - 1) * 0.06) * (if valid >= 50 then 1.2 else 1) + 0.5),
		Radius = math.min(14, 7.5 * (1 + (valid - 1) * 0.006) * (if valid >= 50 then 1.12 else 1)),
		Range = 72 * (1 + (valid - 1) * 0.005),
		Cooldown = math.max(3.3, 5.4 - (valid - 1) * 0.025),
		FallDelay = math.max(0.55, 1.1 - (valid - 1) * 0.004 - (if valid >= 5 then 0.18 else 0)),
		Count = if valid >= 50 then 3 elseif valid >= 20 then 2 else 1,
		Shockwave = valid >= 10,
		Fragments = valid >= 30,
		Extinction = valid >= 40,
	}
end

function meteor.GetRageStats(level: number)
	local stats = meteor.GetStats(level)
	stats.Cooldown *= 0.55
	stats.Count = math.max(stats.Count, 3)
	stats.Shower = true
	stats.IsRage = true
	return stats
end

function meteor.GetStatsText(level: number): string
	return statsText(meteor, level, {
		{ Key = "Damage", Label = "Impact", Format = tostring },
		{ Key = "Radius", Label = "Radius", Format = number },
		{ Key = "Count", Label = "Meteors", Format = tostring },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local turret = {
	Id = "Turret", Name = "Turret", Category = "Weapon",
	Description = "Deploys a temporary sentry that automatically shoots nearby zombies.",
	UpgradeDescription = "Levels improve bullet damage, fire rate, range, and duration. Milestones add barrels, turrets, and piercing shots.",
	RageDescription = "Immediately deploys two overclocked sentries. All active turrets fire faster and release periodic piercing shots.",
	Icon = Images.Abilities.Turret, Color = Color3.fromRGB(255, 202, 75),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 140, UpgradeCostGrowth = 1.148,
	Roll = { BaseOdds = 25, Rarity = "Epic", RarityRank = 4 },
	Combat = { MaximumActive = 3, MaximumTargets = 16, Knockback = 6, RailRange = 36 },
	Milestones = {
		{ Level = 5, Description = "Long Barrel - more range and faster bullets" },
		{ Level = 10, Description = "Twin Barrel - two bullets per attack" },
		{ Level = 20, Description = "Expanded Network - two active turrets" },
		{ Level = 30, Description = "Target Lock - repeated shots against one zombie grow stronger" },
		{ Level = 40, Description = "Rail Shot - every fifth attack pierces multiple zombies" },
		{ Level = 50, Description = "Fortress - three turrets, longer deployment, and more Rail Shots" },
	},
}

function turret.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(14 * (1 + (valid - 1) * 0.05) + 0.5),
		FireInterval = math.max(0.36, 0.8 - (valid - 1) * 0.005) * (if valid >= 50 then 0.85 else 1),
		Range = 31 * (1 + (valid - 1) * 0.005) * (if valid >= 5 then 1.18 else 1),
		Duration = 8 * (1 + (valid - 1) * 0.004) * (if valid >= 50 then 1.2 else 1),
		Cooldown = math.max(6.5, 11 - (valid - 1) * 0.05),
		BulletRadius = 0.5,
		Barrels = if valid >= 10 then 2 else 1,
		MaximumActive = if valid >= 50 then 3 elseif valid >= 20 then 2 else 1,
		TargetLock = valid >= 30,
		RailEvery = if valid >= 50 then 4 elseif valid >= 40 then 5 else 0,
	}
end

function turret.GetRageStats(level: number)
	local stats = turret.GetStats(level)
	stats.Cooldown *= 0.55
	stats.FireInterval *= 0.55
	stats.MaximumActive = math.min(stats.MaximumActive + 2, 5)
	stats.RailEvery = if stats.RailEvery > 0 then math.max(3, stats.RailEvery - 1) else 5
	stats.IsRage = true
	return stats
end

function turret.GetStatsText(level: number): string
	return statsText(turret, level, {
		{ Key = "Damage", Label = "Bullet Damage", Format = tostring },
		{ Key = "FireInterval", Label = "Fire Rate", Format = seconds },
		{ Key = "Duration", Label = "Duration", Format = seconds },
		{ Key = "MaximumActive", Label = "Turrets", Format = tostring },
	})
end

local vortex = {
	Id = "Vortex", Name = "Vortex", Category = "Weapon",
	Description = "Creates a gravity well that pulls nearby zombies inward and damages them over time.",
	UpgradeDescription = "Levels improve damage, radius, pull, duration, and cooldown. Milestones add wells, compression, and collapse.",
	RageDescription = "A large mobile gravity well follows the player for the whole Rage window while normal wells continue spawning.",
	Icon = Images.Abilities.Vortex, Color = Color3.fromRGB(133, 116, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 145, UpgradeCostGrowth = 1.15,
	Roll = { BaseOdds = 35, Rarity = "Legendary", RarityRank = 5 },
	Combat = { Range = 62, TickInterval = 0.45, MaximumActive = 6, MaximumTargets = 45, Knockback = 0 },
	Milestones = {
		{ Level = 5, Description = "Wide Vortex - larger gravity area" },
		{ Level = 10, Description = "Strong Gravity - faster inward pull" },
		{ Level = 20, Description = "Binary Vortex - creates two wells at separate groups" },
		{ Level = 30, Description = "Compression - damage rises with trapped zombies, up to a cap" },
		{ Level = 40, Description = "Collapse - an expiring well releases a final blast" },
		{ Level = 50, Description = "Singularity - three longer, stronger wells with a larger Collapse" },
	},
}

function vortex.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(8 * (1 + (valid - 1) * 0.05) + 0.5),
		Radius = math.min(15, 7.5 * (1 + (valid - 1) * 0.006) * (if valid >= 5 then 1.2 else 1) * (if valid >= 50 then 1.1 else 1)),
		PullSpeed = 3.5 * (1 + (valid - 1) * 0.01) * (if valid >= 10 then 1.25 else 1) * (if valid >= 50 then 1.2 else 1),
		Duration = math.min(7, 4 * (1 + (valid - 1) * 0.005) * (if valid >= 50 then 1.2 else 1)),
		Cooldown = math.max(2.8, 4.4 - (valid - 1) * 0.018),
		Count = if valid >= 50 then 3 elseif valid >= 20 then 2 else 1,
		Compression = valid >= 30,
		Collapse = valid >= 40,
	}
end

function vortex.GetRageStats(level: number)
	local stats = vortex.GetStats(level)
	stats.Cooldown *= 0.6
	stats.Radius *= 1.15
	stats.IsRage = true
	return stats
end

function vortex.GetStatsText(level: number): string
	return statsText(vortex, level, {
		{ Key = "Damage", Label = "Tick Damage", Format = tostring },
		{ Key = "Radius", Label = "Radius", Format = number },
		{ Key = "Duration", Label = "Duration", Format = seconds },
		{ Key = "Count", Label = "Wells", Format = tostring },
	})
end

local giant = {
	Id = "Giant", Name = "Giant", Category = "Passive",
	Description = "Moderately increases damaging weapon size and coverage, with matching visual and hitbox growth.",
	UpgradeDescription = "Each level improves size slightly. Milestones add small capped boosts; Rage doubles the bonus.",
	RageDescription = "Doubles Giant's capped size bonus during Rage without increasing damage, range, or weapon count.",
	Icon = Images.Abilities.Giant, Color = Color3.fromRGB(88, 194, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 115, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Enlarged - adds 1% weapon size" },
		{ Level = 10, Description = "Wide Reach - adds 1% area radius" },
		{ Level = 20, Description = "Oversized - adds 1% projectile and weapon hitbox size" },
		{ Level = 35, Description = "Huge - adds 1% size to all supported weapons" },
		{ Level = 50, Description = "Colossal - adds 2% size, up to the 14% cap" },
	},
}

function giant.GetStats(level: number)
	local valid = levelOf(level)
	-- Radius, not area, is capped: even a 14% radius bonus already covers about 30% more ground.
	-- This stays below the cap until level 50, so every normal upgrade improves coverage.
	local bonus = 0.02 + (valid - 1) * 0.0014
	bonus += (if valid >= 5 then 0.01 else 0)
		+ (if valid >= 35 then 0.01 else 0)
		+ (if valid >= 50 then 0.02 else 0)
	return {
		SizeBonus = math.min(bonus, 0.14),
		AreaBonus = math.min(bonus + (if valid >= 10 then 0.01 else 0), 0.14),
		ProjectileBonus = math.min(bonus + (if valid >= 20 then 0.01 else 0), 0.14),
	}
end

function giant.GetRageStats(level: number)
	local stats = giant.GetStats(level)
	for _, field in { "SizeBonus", "AreaBonus", "ProjectileBonus" } do
		stats[field] = math.min(stats[field] * 2, 0.28)
	end
	return stats
end

function giant.GetDescription(level: number): string
	return string.format("Increase damaging weapon size by %.1f%%.", giant.GetStats(level).SizeBonus * 100)
end

function giant.GetStatsText(level: number): string
	return statsText(giant, level, {
		{ Key = "SizeBonus", Label = "Size Bonus", Format = function(value) return percent(value * 100) end },
		{ Key = "AreaBonus", Label = "Area Radius", Format = function(value) return percent(value * 100) end },
		{ Key = "ProjectileBonus", Label = "Hitbox Size", Format = function(value) return percent(value * 100) end },
	})
end

local greed = {
	Id = "Greed", Name = "Greed", Category = "Passive",
	Description = "Zombies have a chance to drop bonus Coins when defeated.",
	UpgradeDescription = "Levels improve bonus Coin chance. Milestones add extra value, jackpots, and stronger-zombie rewards.",
	RageDescription = "Zombies defeated during Rage have a substantially higher chance to award bonus Coins and jackpots.",
	Icon = Images.Abilities.Greed, Color = Color3.fromRGB(255, 216, 72),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 115, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 15, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Lucky Find - higher bonus Coin chance" },
		{ Level = 10, Description = "Extra Value - bonus drops can award two Coins" },
		{ Level = 20, Description = "Gold Rush - another chance increase" },
		{ Level = 35, Description = "Jackpot - a small chance for a valuable Coin drop" },
		{ Level = 50, Description = "Midas Touch - stronger zombies guarantee extra Coins" },
	},
}

function greed.GetStats(level: number)
	local valid = levelOf(level)
	return {
		ChancePercent = math.min(35, 6 + (valid - 1) * 0.35 + (if valid >= 5 then 3 else 0) + (if valid >= 20 then 6 else 0) + (if valid >= 50 then 3 else 0)),
		ExtraValueChancePercent = if valid >= 10 then 18 else 0,
		JackpotChancePercent = if valid >= 35 then 2.5 else 0,
		StrongBonus = valid >= 50,
	}
end

function greed.GetRageStats(level: number)
	local stats = greed.GetStats(level)
	stats.ChancePercent = math.min(65, stats.ChancePercent * 1.75)
	if stats.ExtraValueChancePercent > 0 then
		stats.ExtraValueChancePercent += 12
	end
	if stats.JackpotChancePercent > 0 then
		stats.JackpotChancePercent += 2
	end
	return stats
end

function greed.GetDescription(level: number): string
	return string.format("Zombie kills have a %.1f%% chance to drop bonus Coins.", greed.GetStats(level).ChancePercent)
end

function greed.GetStatsText(level: number): string
	return statsText(greed, level, {
		{ Key = "ChancePercent", Label = "Bonus Chance", Format = percent },
		{ Key = "ExtraValueChancePercent", Label = "Double Bonus", Format = percent },
	})
end

local critical = {
	Id = "Critical", Name = "Critical", Category = "Passive",
	Description = "Direct ability hits sometimes deal increased damage.",
	UpgradeDescription = "Levels improve critical chance and damage. Milestones provide larger boosts to each.",
	RageDescription = "Critical chance and damage rise substantially during Rage; level 50 adds an even stronger Rage critical.",
	Icon = Images.Abilities.Critical, Color = Color3.fromRGB(255, 103, 68),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 125, UpgradeCostGrowth = 1.147,
	Roll = { BaseOdds = 20, Rarity = "Epic", RarityRank = 4 },
	Milestones = {
		{ Level = 5, Description = "Sharp Strike - stronger critical damage" },
		{ Level = 10, Description = "Keen Eye - increased critical chance" },
		{ Level = 20, Description = "Heavy Critical - another large damage bonus" },
		{ Level = 35, Description = "Reliable Critical - another chance increase" },
		{ Level = 50, Description = "Perfect Strike - more chance and damage, especially during Rage" },
	},
}

function critical.GetStats(level: number)
	local valid = levelOf(level)
	return {
		ChancePercent = math.min(28, 5 + (valid - 1) * 0.22 + (if valid >= 10 then 3 else 0) + (if valid >= 35 then 4 else 0) + (if valid >= 50 then 3 else 0)),
		DamageMultiplier = 1.5 + (valid - 1) * 0.006 + (if valid >= 5 then 0.12 else 0) + (if valid >= 20 then 0.18 else 0) + (if valid >= 50 then 0.15 else 0),
	}
end

function critical.GetRageStats(level: number)
	local stats = critical.GetStats(level)
	stats.ChancePercent = math.min(45, stats.ChancePercent * 1.6)
	stats.DamageMultiplier += if level >= 50 then 0.45 else 0.3
	return stats
end

function critical.GetDescription(level: number): string
	local stats = critical.GetStats(level)
	return string.format("Direct hits have a %.1f%% chance to deal %.1fx damage.", stats.ChancePercent, stats.DamageMultiplier)
end

function critical.GetStatsText(level: number): string
	return statsText(critical, level, {
		{ Key = "ChancePercent", Label = "Critical Chance", Format = percent },
		{ Key = "DamageMultiplier", Label = "Critical Damage", Format = function(value) return string.format("%.2fx", value) end },
	})
end

local adrenaline = {
	Id = "Adrenaline", Name = "Adrenaline", Category = "Passive",
	Description = "Weapons activate faster while your health is low.",
	UpgradeDescription = "Levels improve attack speed. Milestones strengthen it and raise the health threshold.",
	RageDescription = "Adrenaline stays active throughout Rage, even at full health, with a stronger speed bonus.",
	Icon = Images.Abilities.Adrenaline, Color = Color3.fromRGB(168, 244, 72),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 110, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Quick Response - more attack speed" },
		{ Level = 10, Description = "Early Rush - activates below 45% health" },
		{ Level = 20, Description = "Surge - substantially more attack speed" },
		{ Level = 35, Description = "Last Push - activates below 50% health" },
		{ Level = 50, Description = "Maximum Adrenaline - strongest speed bonus, greatly empowered in Rage" },
	},
}

function adrenaline.GetStats(level: number)
	local valid = levelOf(level)
	return {
		SpeedBonusPercent = math.min(38, 8 + (valid - 1) * 0.27 + (if valid >= 5 then 3 else 0) + (if valid >= 20 then 6 else 0) + (if valid >= 50 then 5 else 0)),
		HealthThresholdPercent = if valid >= 35 then 50 elseif valid >= 10 then 45 else 40,
	}
end

function adrenaline.GetRageStats(level: number)
	local stats = adrenaline.GetStats(level)
	stats.SpeedBonusPercent = math.min(55, stats.SpeedBonusPercent * (if level >= 50 then 1.7 else 1.5))
	return stats
end

function adrenaline.GetDescription(level: number): string
	local stats = adrenaline.GetStats(level)
	return string.format("Weapons activate %.1f%% faster below %d%% health.", stats.SpeedBonusPercent, stats.HealthThresholdPercent)
end

function adrenaline.GetStatsText(level: number): string
	return statsText(adrenaline, level, {
		{ Key = "SpeedBonusPercent", Label = "Attack Speed", Format = percent },
		{ Key = "HealthThresholdPercent", Label = "Health Threshold", Format = function(value) return string.format("%d%%", value) end },
	})
end

local impact = {
	Id = "Impact", Name = "Impact", Category = "Passive",
	Description = "Damaging abilities push zombies farther away, including attacks with no natural knockback.",
	UpgradeDescription = "Levels improve knockback. Milestones strengthen weak pushes and slow resistant zombies.",
	RageDescription = "Rage greatly increases Impact's knockback; Vortex converts the force into stronger inward pull.",
	Icon = Images.Abilities.Impact, Color = Color3.fromRGB(255, 157, 81),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 110, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Heavy Hits - stronger knockback" },
		{ Level = 10, Description = "Strong Push - weak attacks gain a better push" },
		{ Level = 20, Description = "Massive Force - substantially stronger knockback" },
		{ Level = 35, Description = "Unsteady - resistant zombies are briefly slowed" },
		{ Level = 50, Description = "Unstoppable Force - maximum knockback and a stronger Rage bonus" },
	},
}

function impact.GetStats(level: number)
	local valid = levelOf(level)
	return {
		KnockbackBonusPercent = math.min(75, 12 + (valid - 1) * 0.7 + (if valid >= 5 then 6 else 0) + (if valid >= 20 then 12 else 0) + (if valid >= 50 then 10 else 0)),
		MinimumKnockback = if valid >= 10 then 3.5 else 2,
		SlowResistant = valid >= 35,
	}
end

function impact.GetRageStats(level: number)
	local stats = impact.GetStats(level)
	stats.KnockbackBonusPercent = math.min(125, stats.KnockbackBonusPercent * (if level >= 50 then 1.8 else 1.6))
	stats.MinimumKnockback *= 1.5
	return stats
end

function impact.GetDescription(level: number): string
	return string.format("Increase ability knockback by %.1f%%.", impact.GetStats(level).KnockbackBonusPercent)
end

function impact.GetStatsText(level: number): string
	return statsText(impact, level, {
		{ Key = "KnockbackBonusPercent", Label = "Knockback", Format = percent },
		{ Key = "MinimumKnockback", Label = "Minimum Push", Format = number },
	})
end

AdditionalAbilityDefinitions.List = {
	shotgun, frostNova, meteor, turret, vortex,
	giant, greed, critical, adrenaline, impact,
}

return AdditionalAbilityDefinitions
