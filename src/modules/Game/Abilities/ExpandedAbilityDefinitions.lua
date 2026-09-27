local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local ExpandedAbilityDefinitions = {}
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

local crowbar = {
	Id = "Crowbar", Name = "Crowbar", Category = "Weapon",
	Description = "Swings a heavy Crowbar through the nearest crowd and knocks zombies away.",
	UpgradeDescription = "Levels improve damage, reach, arc, and swing rate. Milestones add follow-up swings and crowd control.",
	RageDescription = "Rapid alternating swings surround you, with stronger knockback and a guaranteed three-hit combo.",
	Icon = Images.Abilities.Crowbar, Color = Color3.fromRGB(78, 210, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 115, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 8, Rarity = "Uncommon", RarityRank = 2 },
	Combat = { MaximumTargets = 45, Knockback = 17, FollowUpDelay = 0.16 },
	Milestones = {
		{ Level = 5, Description = "Wide Swing - increases the Crowbar's attack arc" },
		{ Level = 10, Description = "Heavy Swing - stronger knockback and a short slow" },
		{ Level = 20, Description = "Backswing - follows every attack with a second swing" },
		{ Level = 30, Description = "Crowd Breaker - deals more damage when hitting a large group" },
		{ Level = 40, Description = "Fast Hands - substantially improves swing speed" },
		{ Level = 50, Description = "Full Combo - adds a third, larger finishing swing" },
	},
}

function crowbar.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(27 * (1 + (valid - 1) * 0.052) * (if valid >= 50 then 1.15 else 1) + 0.5),
		Reach = math.min(13, 8 * (1 + (valid - 1) * 0.006) * (if valid >= 5 then 1.12 else 1)),
		ArcDegrees = if valid >= 50 then 190 elseif valid >= 5 then 150 else 118,
		Cooldown = math.max(0.82, (1.65 - (valid - 1) * 0.011) * (if valid >= 40 then 0.82 else 1)),
		SwingCount = if valid >= 50 then 3 elseif valid >= 20 then 2 else 1,
		HeavySlow = valid >= 10,
		CrowdBonus = valid >= 30,
	}
end

function crowbar.GetRageStats(level: number)
	local stats = crowbar.GetStats(level)
	stats.Cooldown *= 0.5
	stats.SwingCount = math.max(stats.SwingCount, 3)
	stats.ArcDegrees = math.max(stats.ArcDegrees, 190)
	stats.Reach *= 1.12
	stats.IsRage = true
	return stats
end

function crowbar.GetStatsText(level: number): string
	return statsText(crowbar, level, {
		{ Key = "Damage", Label = "Damage", Format = tostring },
		{ Key = "Reach", Label = "Reach", Format = number },
		{ Key = "ArcDegrees", Label = "Swing Arc", Format = function(value) return string.format("%d degrees", value) end },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local crossfire = {
	Id = "Crossfire", Name = "Crossfire", Category = "Weapon",
	Description = "Fires piercing bolts in fixed directions around you, rewarding careful positioning.",
	UpgradeDescription = "Levels improve damage, width, range, and fire rate. Milestones add diagonals and rotating follow-up volleys.",
	RageDescription = "Fires rapid eight-way volleys followed by a rotated second burst, covering every approach.",
	Icon = Images.Abilities.Crossfire, Color = Color3.fromRGB(255, 190, 48),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 120, UpgradeCostGrowth = 1.146,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Combat = { MaximumTargetsPerBolt = 35, Knockback = 7, FollowUpDelay = 0.14 },
	Milestones = {
		{ Level = 5, Description = "Long Bolts - increases Crossfire range" },
		{ Level = 10, Description = "Eight Ways - adds four diagonal bolts" },
		{ Level = 20, Description = "Wide Bolts - increases bolt width and hitbox" },
		{ Level = 30, Description = "Rotating Volley - fires a weaker volley between the first directions" },
		{ Level = 40, Description = "Deep Pierce - damage rises after each zombie pierced" },
		{ Level = 50, Description = "Starburst - faster, larger volleys with a full-strength follow-up" },
	},
}

function crossfire.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(22 * (1 + (valid - 1) * 0.05) + 0.5),
		Range = math.min(72, 43 * (1 + (valid - 1) * 0.007) * (if valid >= 5 then 1.18 else 1)),
		Width = 1.3 * (1 + (valid - 1) * 0.004) * (if valid >= 20 then 1.28 else 1),
		Cooldown = math.max(1.15, 2.25 - (valid - 1) * 0.016),
		DirectionCount = if valid >= 10 then 8 else 4,
		FollowUp = valid >= 30,
		FollowUpDamageMultiplier = if valid >= 50 then 1 else 0.62,
		PierceGrowth = if valid >= 40 then 0.06 else 0,
	}
end

function crossfire.GetRageStats(level: number)
	local stats = crossfire.GetStats(level)
	stats.Cooldown *= 0.52
	stats.DirectionCount = 8
	stats.FollowUp = true
	stats.FollowUpDamageMultiplier = math.max(stats.FollowUpDamageMultiplier, 0.82)
	stats.Width *= 1.16
	stats.IsRage = true
	return stats
end

function crossfire.GetStatsText(level: number): string
	return statsText(crossfire, level, {
		{ Key = "Damage", Label = "Bolt Damage", Format = tostring },
		{ Key = "DirectionCount", Label = "Bolts", Format = tostring },
		{ Key = "Range", Label = "Range", Format = number },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local buzzsaw = {
	Id = "Buzzsaw", Name = "Buzzsaw", Category = "Weapon",
	Description = "Throws a Buzzsaw into a nearby crowd, where it spins and repeatedly damages zombies.",
	UpgradeDescription = "Levels improve tick damage, size, duration, and deployment rate. Milestones add ricochets and extra saws.",
	RageDescription = "Deploys larger, faster-ticking Buzzsaws that chase fresh crowds after clearing their current area.",
	Icon = Images.Abilities.Buzzsaw, Color = Color3.fromRGB(255, 103, 38),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 125, UpgradeCostGrowth = 1.147,
	Roll = { BaseOdds = 20, Rarity = "Epic", RarityRank = 4 },
	Combat = { Range = 62, TickInterval = 0.42, MaximumTargets = 35, MaximumActive = 6, Knockback = 2 },
	Milestones = {
		{ Level = 5, Description = "Large Teeth - increases Buzzsaw radius" },
		{ Level = 10, Description = "Long Spin - Buzzsaws remain active longer" },
		{ Level = 20, Description = "Twin Saws - throws two Buzzsaws at separate groups" },
		{ Level = 30, Description = "Ricochet - a finished Buzzsaw jumps once to a fresh group" },
		{ Level = 40, Description = "Hot Teeth - each repeated tick on a target grows stronger" },
		{ Level = 50, Description = "Saw Storm - three larger, longer, faster-ticking Buzzsaws" },
	},
}

function buzzsaw.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(9 * (1 + (valid - 1) * 0.052) + 0.5),
		Radius = math.min(9.5, 5 * (1 + (valid - 1) * 0.006) * (if valid >= 5 then 1.22 else 1) * (if valid >= 50 then 1.12 else 1)),
		Duration = math.min(7, 3.6 * (1 + (valid - 1) * 0.006) * (if valid >= 10 then 1.2 else 1) * (if valid >= 50 then 1.15 else 1)),
		Cooldown = math.max(2, 3.55 - (valid - 1) * 0.018),
		TickInterval = buzzsaw.Combat.TickInterval * (if valid >= 50 then 0.72 else 1),
		Count = if valid >= 50 then 3 elseif valid >= 20 then 2 else 1,
		Ricochet = valid >= 30,
		HeatGrowth = if valid >= 40 then 0.08 else 0,
	}
end

function buzzsaw.GetRageStats(level: number)
	local stats = buzzsaw.GetStats(level)
	stats.Cooldown *= 0.52
	stats.TickInterval *= 0.58
	stats.Radius *= 1.16
	stats.Count = math.max(stats.Count, 2)
	stats.Ricochet = true
	stats.IsRage = true
	return stats
end

function buzzsaw.GetStatsText(level: number): string
	return statsText(buzzsaw, level, {
		{ Key = "Damage", Label = "Tick Damage", Format = tostring },
		{ Key = "Radius", Label = "Radius", Format = number },
		{ Key = "Duration", Label = "Duration", Format = seconds },
		{ Key = "Count", Label = "Buzzsaws", Format = tostring },
	})
end

local crusher = {
	Id = "Crusher", Name = "Crusher", Category = "Weapon",
	Description = "Summons two blocky walls that warn, then slam together around a nearby crowd.",
	UpgradeDescription = "Levels improve damage, wall size, warning speed, and cooldown. Milestones add stun and repeated slams.",
	RageDescription = "Rapid Crushers strike wider groups with shorter warnings and a crushing second slam.",
	Icon = Images.Abilities.Crusher, Color = Color3.fromRGB(190, 91, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 135, UpgradeCostGrowth = 1.148,
	Roll = { BaseOdds = 25, Rarity = "Epic", RarityRank = 4 },
	Combat = { Range = 68, MaximumTargets = 60, Knockback = 12, RepeatDelay = 0.24 },
	Milestones = {
		{ Level = 5, Description = "Long Walls - increases the Crusher's length" },
		{ Level = 10, Description = "Fast Clamp - shortens the warning" },
		{ Level = 20, Description = "Concussion - briefly stuns regular zombies" },
		{ Level = 30, Description = "Wide Clamp - increases the space caught between walls" },
		{ Level = 40, Description = "Aftershock - follows with a weaker perpendicular slam" },
		{ Level = 50, Description = "Total Crush - larger walls and a full-strength Aftershock" },
	},
}

function crusher.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(55 * (1 + (valid - 1) * 0.058) * (if valid >= 50 then 1.18 else 1) + 0.5),
		Length = math.min(28, 16 * (1 + (valid - 1) * 0.008) * (if valid >= 5 then 1.15 else 1) * (if valid >= 50 then 1.1 else 1)),
		Width = math.min(15, 8 * (1 + (valid - 1) * 0.006) * (if valid >= 30 then 1.22 else 1)),
		Cooldown = math.max(3.4, 6 - (valid - 1) * 0.035),
		WarningDuration = math.max(0.48, 0.95 - (valid - 1) * 0.003 - (if valid >= 10 then 0.18 else 0)),
		Stun = valid >= 20,
		Aftershock = valid >= 40,
		AftershockDamageMultiplier = if valid >= 50 then 1 else 0.65,
	}
end

function crusher.GetRageStats(level: number)
	local stats = crusher.GetStats(level)
	stats.Cooldown *= 0.52
	stats.WarningDuration *= 0.62
	stats.Length *= 1.12
	stats.Width *= 1.15
	stats.Aftershock = true
	stats.AftershockDamageMultiplier = math.max(stats.AftershockDamageMultiplier, 0.82)
	stats.IsRage = true
	return stats
end

function crusher.GetStatsText(level: number): string
	return statsText(crusher, level, {
		{ Key = "Damage", Label = "Slam Damage", Format = tostring },
		{ Key = "Length", Label = "Wall Length", Format = number },
		{ Key = "WarningDuration", Label = "Warning", Format = seconds },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local laserSweep = {
	Id = "LaserSweep", Name = "Laser Sweep", Category = "Weapon",
	Description = "Rotates a long Laser around you, damaging each zombie it crosses.",
	UpgradeDescription = "Levels improve beam damage, width, reach, and sweep rate. Milestones add burns and a second beam.",
	RageDescription = "Two wide, fast beams sweep repeatedly in opposite directions throughout the attack.",
	Icon = Images.Abilities.LaserSweep, Color = Color3.fromRGB(80, 255, 134),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 140, UpgradeCostGrowth = 1.149,
	Roll = { BaseOdds = 35, Rarity = "Legendary", RarityRank = 5 },
	Combat = { MaximumTargetsPerStep = 50, Knockback = 5, StepInterval = 0.04 },
	Milestones = {
		{ Level = 5, Description = "Long Beam - increases Laser reach" },
		{ Level = 10, Description = "Wide Beam - increases beam width and hitbox" },
		{ Level = 20, Description = "Double Beam - adds a second beam on the opposite side" },
		{ Level = 30, Description = "Searing Light - repeated crossings deal increasing damage" },
		{ Level = 40, Description = "Second Rotation - each activation sweeps around twice" },
		{ Level = 50, Description = "Lightshow - faster, wider, stronger double beams with three rotations" },
	},
}

function laserSweep.GetStats(level: number)
	local valid = levelOf(level)
	return {
		Damage = math.floor(24 * (1 + (valid - 1) * 0.055) * (if valid >= 50 then 1.15 else 1) + 0.5),
		Range = math.min(62, 36 * (1 + (valid - 1) * 0.008) * (if valid >= 5 then 1.16 else 1)),
		Width = 1.4 * (1 + (valid - 1) * 0.005) * (if valid >= 10 then 1.3 else 1) * (if valid >= 50 then 1.12 else 1),
		Cooldown = math.max(4, 7 - (valid - 1) * 0.035),
		Duration = math.max(0.85, 1.35 - (valid - 1) * 0.004) * (if valid >= 40 then 2 else 1) * (if valid >= 50 then 1.5 else 1),
		Rotations = if valid >= 50 then 3 elseif valid >= 40 then 2 else 1,
		BeamCount = if valid >= 20 then 2 else 1,
		SearingGrowth = if valid >= 30 then 0.12 else 0,
	}
end

function laserSweep.GetRageStats(level: number)
	local stats = laserSweep.GetStats(level)
	stats.Cooldown *= 0.5
	stats.Duration *= 0.82
	stats.Rotations = math.max(stats.Rotations, 2)
	stats.BeamCount = 2
	stats.Width *= 1.2
	stats.IsRage = true
	return stats
end

function laserSweep.GetStatsText(level: number): string
	return statsText(laserSweep, level, {
		{ Key = "Damage", Label = "Beam Damage", Format = tostring },
		{ Key = "Range", Label = "Range", Format = number },
		{ Key = "BeamCount", Label = "Beams", Format = tostring },
		{ Key = "Cooldown", Label = "Cooldown", Format = seconds },
	})
end

local armor = {
	Id = "Armor", Name = "Armor", Category = "Passive",
	Description = "Reduces damage taken from zombies.",
	UpgradeDescription = "Levels improve damage reduction. Milestones soften heavy hits and briefly reinforce Armor after taking one.",
	RageDescription = "Rage reinforces Armor, greatly reducing incoming damage and guaranteeing heavy-hit protection.",
	Icon = Images.Abilities.Armor, Color = Color3.fromRGB(91, 180, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 110, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 10, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Reinforced - adds extra damage reduction" },
		{ Level = 10, Description = "Brace - heavy hits are reduced further" },
		{ Level = 20, Description = "Thick Plates - another reduction increase" },
		{ Level = 35, Description = "Fortify - heavy hits briefly strengthen Armor" },
		{ Level = 50, Description = "Juggernaut - maximum reduction and stronger Fortify" },
	},
}

function armor.GetStats(level: number)
	local valid = levelOf(level)
	return {
		ReductionPercent = math.min(32, 6 + (valid - 1) * 0.28 + (if valid >= 5 then 3 else 0) + (if valid >= 20 then 5 else 0) + (if valid >= 50 then 4 else 0)),
		HeavyHitThresholdPercent = if valid >= 10 then 18 else 100,
		HeavyHitReductionPercent = if valid >= 10 then 18 + (if valid >= 50 then 10 else 0) else 0,
		FortifyDuration = if valid >= 35 then 2.5 else 0,
		FortifyReductionPercent = if valid >= 50 then 14 elseif valid >= 35 then 8 else 0,
	}
end

function armor.GetRageStats(level: number)
	local stats = armor.GetStats(level)
	stats.ReductionPercent = math.min(55, stats.ReductionPercent * 1.55)
	stats.HeavyHitThresholdPercent = math.min(stats.HeavyHitThresholdPercent, 15)
	stats.HeavyHitReductionPercent = math.max(stats.HeavyHitReductionPercent, 25)
	stats.FortifyDuration = math.max(stats.FortifyDuration, 3)
	stats.FortifyReductionPercent = math.max(stats.FortifyReductionPercent, 12)
	return stats
end

function armor.GetStatsText(level: number): string
	return statsText(armor, level, {
		{ Key = "ReductionPercent", Label = "Damage Reduction", Format = percent },
		{ Key = "HeavyHitReductionPercent", Label = "Heavy Hit Guard", Format = percent },
	})
end

local magnet = {
	Id = "Magnet", Name = "Magnet", Category = "Passive",
	Description = "Pulls XP and Coins toward you from farther away.",
	UpgradeDescription = "Levels improve pickup range and pull speed. Milestones add bursts that collect nearby rewards instantly.",
	RageDescription = "Massively expands pickup range and periodically pulls every available reward toward you during Rage.",
	Icon = Images.Abilities.Magnet, Color = Color3.fromRGB(255, 78, 91),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 105, UpgradeCostGrowth = 1.144,
	Roll = { BaseOdds = 8, Rarity = "Uncommon", RarityRank = 2 },
	Milestones = {
		{ Level = 5, Description = "Strong Pull - improves pickup range" },
		{ Level = 10, Description = "Fast Pull - rewards travel toward you faster" },
		{ Level = 20, Description = "Coin Pull - adds extra range for permanent Coins" },
		{ Level = 35, Description = "Magnetic Burst - periodically grabs rewards in a wide radius" },
		{ Level = 50, Description = "Super Magnet - maximum range, speed, and more frequent bursts" },
	},
}

function magnet.GetStats(level: number)
	local valid = levelOf(level)
	return {
		RadiusBonusPercent = math.min(110, 18 + (valid - 1) * 1.05 + (if valid >= 5 then 10 else 0) + (if valid >= 50 then 18 else 0)),
		PullSpeedBonusPercent = math.min(100, (valid - 1) * 0.9 + (if valid >= 10 then 20 else 0) + (if valid >= 50 then 20 else 0)),
		CoinRadiusBonusPercent = if valid >= 20 then 20 else 0,
		BurstRadius = if valid >= 35 then (if valid >= 50 then 44 else 34) else 0,
		BurstInterval = if valid >= 50 then 8 elseif valid >= 35 then 12 else 0,
	}
end

function magnet.GetRageStats(level: number)
	local stats = magnet.GetStats(level)
	stats.RadiusBonusPercent = math.min(220, stats.RadiusBonusPercent * 1.75)
	stats.PullSpeedBonusPercent = math.min(180, stats.PullSpeedBonusPercent + 65)
	stats.BurstRadius = math.max(stats.BurstRadius, 80)
	stats.BurstInterval = if stats.BurstInterval > 0 then math.min(stats.BurstInterval, 2.5) else 2.5
	return stats
end

function magnet.GetStatsText(level: number): string
	return statsText(magnet, level, {
		{ Key = "RadiusBonusPercent", Label = "Pickup Range", Format = percent },
		{ Key = "PullSpeedBonusPercent", Label = "Pull Speed", Format = percent },
	})
end

local executioner = {
	Id = "Executioner", Name = "Executioner", Category = "Passive",
	Description = "Deals bonus damage to wounded zombies.",
	UpgradeDescription = "Levels improve finishing damage and its health threshold. Milestones add larger bonuses against strong enemies.",
	RageDescription = "Executioner activates much earlier and strikes wounded zombies with a substantially stronger bonus.",
	Icon = Images.Abilities.Executioner, Color = Color3.fromRGB(255, 67, 67),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 120, UpgradeCostGrowth = 1.146,
	Roll = { BaseOdds = 15, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Clean Finish - improves finishing damage" },
		{ Level = 10, Description = "Early Opening - activates below 35% health" },
		{ Level = 20, Description = "Merciless - another large damage increase" },
		{ Level = 35, Description = "Giant Slayer - stronger bonus against high-threat zombies" },
		{ Level = 50, Description = "Final Verdict - activates below 45% health with maximum damage" },
	},
}

function executioner.GetStats(level: number)
	local valid = levelOf(level)
	return {
		DamageBonusPercent = math.min(65, 12 + (valid - 1) * 0.55 + (if valid >= 5 then 5 else 0) + (if valid >= 20 then 10 else 0) + (if valid >= 50 then 8 else 0)),
		HealthThresholdPercent = if valid >= 50 then 45 elseif valid >= 10 then 35 else 25,
		StrongEnemyBonusPercent = if valid >= 35 then 18 else 0,
	}
end

function executioner.GetRageStats(level: number)
	local stats = executioner.GetStats(level)
	stats.DamageBonusPercent = math.min(100, stats.DamageBonusPercent * 1.45)
	stats.HealthThresholdPercent = math.max(stats.HealthThresholdPercent, 60)
	stats.StrongEnemyBonusPercent += 12
	return stats
end

function executioner.GetStatsText(level: number): string
	return statsText(executioner, level, {
		{ Key = "DamageBonusPercent", Label = "Finish Damage", Format = percent },
		{ Key = "HealthThresholdPercent", Label = "Health Threshold", Format = percent },
	})
end

local trainingManual = {
	Id = "TrainingManual", Name = "Training Manual", Category = "Passive",
	Description = "Increases XP gained from crystals.",
	UpgradeDescription = "Levels improve XP gained. Milestones add bonus XP from valuable crystals and level-up momentum.",
	RageDescription = "Greatly increases all XP gained during Rage, with stronger bonuses from valuable crystals.",
	Icon = Images.Abilities.TrainingManual, Color = Color3.fromRGB(69, 176, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 110, UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Milestones = {
		{ Level = 5, Description = "Study Habit - adds extra XP gain" },
		{ Level = 10, Description = "Advanced Lesson - valuable crystals grant bonus XP" },
		{ Level = 20, Description = "Fast Learner - another XP gain increase" },
		{ Level = 35, Description = "Breakthrough - leveling up boosts the next crystal" },
		{ Level = 50, Description = "Mastery - maximum XP gain and stronger crystal bonuses" },
	},
}

function trainingManual.GetStats(level: number)
	local valid = levelOf(level)
	return {
		XPBonusPercent = math.min(55, 8 + (valid - 1) * 0.38 + (if valid >= 5 then 4 else 0) + (if valid >= 20 then 8 else 0) + (if valid >= 50 then 8 else 0)),
		LargeCrystalBonusPercent = if valid >= 10 then (if valid >= 50 then 24 else 14) else 0,
		LargeCrystalMinimum = 12,
		BreakthroughBonusPercent = if valid >= 35 then (if valid >= 50 then 30 else 20) else 0,
	}
end

function trainingManual.GetRageStats(level: number)
	local stats = trainingManual.GetStats(level)
	stats.XPBonusPercent = math.min(90, stats.XPBonusPercent * 1.55)
	stats.LargeCrystalBonusPercent += 15
	stats.BreakthroughBonusPercent += 10
	return stats
end

function trainingManual.GetStatsText(level: number): string
	return statsText(trainingManual, level, {
		{ Key = "XPBonusPercent", Label = "XP Gain", Format = percent },
		{ Key = "LargeCrystalBonusPercent", Label = "Large Crystal", Format = percent },
	})
end

local overcharge = {
	Id = "Overcharge", Name = "Overcharge", Category = "Passive",
	Description = "Weapon activations build charge. At full charge, the next activation repeats at reduced power.",
	UpgradeDescription = "Levels reduce activations required and improve repeat damage. Milestones add faster repeats and chain charge.",
	RageDescription = "Charge builds much faster and repeated activations strike at full power during Rage.",
	Icon = Images.Abilities.Overcharge, Color = Color3.fromRGB(224, 86, 255),
	MaxLevel = MAX_LEVEL, BaseUpgradeCost = 135, UpgradeCostGrowth = 1.148,
	Roll = { BaseOdds = 25, Rarity = "Epic", RarityRank = 4 },
	Milestones = {
		{ Level = 5, Description = "High Voltage - improves repeat damage" },
		{ Level = 10, Description = "Quick Charge - requires one fewer activation" },
		{ Level = 20, Description = "Fast Echo - repeated activations happen sooner" },
		{ Level = 35, Description = "Feedback - repeated activations retain one charge" },
		{ Level = 50, Description = "Maximum Power - requires fewer activations and repeats at full power" },
	},
}

function overcharge.GetStats(level: number)
	local valid = levelOf(level)
	return {
		ActivationsRequired = if valid >= 50 then 4 elseif valid >= 10 then 5 else 6,
		RepeatDamageMultiplier = math.min(1, 0.6 + (valid - 1) * 0.004 + (if valid >= 5 then 0.08 else 0) + (if valid >= 50 then 0.18 else 0)),
		RepeatDelay = if valid >= 20 then 0.1 else 0.16,
		RetainedCharge = if valid >= 35 then 1 else 0,
	}
end

function overcharge.GetRageStats(level: number)
	local stats = overcharge.GetStats(level)
	stats.ActivationsRequired = math.max(2, stats.ActivationsRequired - 2)
	stats.RepeatDamageMultiplier = 1
	stats.RepeatDelay = math.min(stats.RepeatDelay, 0.08)
	stats.RetainedCharge = math.max(stats.RetainedCharge, 1)
	return stats
end

function overcharge.GetStatsText(level: number): string
	return statsText(overcharge, level, {
		{ Key = "ActivationsRequired", Label = "Activations", Format = tostring },
		{ Key = "RepeatDamageMultiplier", Label = "Repeat Power", Format = function(value) return percent(value * 100) end },
		{ Key = "RepeatDelay", Label = "Repeat Delay", Format = seconds },
	})
end

ExpandedAbilityDefinitions.List = {
	crowbar, crossfire, buzzsaw, crusher, laserSweep,
	armor, magnet, executioner, trainingManual, overcharge,
}

return ExpandedAbilityDefinitions
