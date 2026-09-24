local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local AbilityDefinitions = {}

AbilityDefinitions.DataKey = "Abilities"
AbilityDefinitions.Categories = {
	Weapon = "Weapon",
	Passive = "Passive",
}
-- The server treats these five-slot limits as authoritative for every current and future ability.
AbilityDefinitions.EquipLimits = {
	Weapon = 5,
	Passive = 5,
}

local function getDaggerCount(level: number): number
	if level >= 50 then
		return 5
	elseif level >= 20 then
		return 4
	elseif level >= 10 then
		return 3
	elseif level >= 5 then
		return 2
	end
	return 1
end

local function getOrbitingSwordCount(level: number): number
	if level >= 50 then
		return 4
	elseif level >= 20 then
		return 3
	elseif level >= 5 then
		return 2
	end
	return 1
end

local dagger = {
	Id = "Dagger",
	Name = "Dagger",
	Category = AbilityDefinitions.Categories.Weapon,
	Description = "Periodically hurls a dagger at the nearest zombie.",
	UpgradeDescription = "Upgrades increase damage and projectile size. Milestones add another dagger to every volley.",
	-- The same authored icon is the single UI representation for Dagger in rolls, inventory, upgrades, and discovery.
	Icon = Images.Abilities.Dagger,
	AssetName = "Dagger",
	Color = Color3.fromRGB(95, 183, 255),
	MaxLevel = 50,
	BaseUpgradeCost = 120,
	UpgradeCostGrowth = 1.145,
	Roll = {
		BaseOdds = 8,
		Rarity = "Rare",
		RarityRank = 3,
	},
	Combat = {
		Cooldown = 1.25,
		Range = 100,
		ProjectileSpeed = 115,
		Knockback = 15,
	},
	Rage = {
		RagePerHit = 7,
		Cooldown = 0.24,
		Range = 135,
		ProjectileSpeed = 165,
		AdditionalDaggers = 3,
		MaximumDaggers = 8,
		ProjectileScaleMultiplier = 1.28,
		KnockbackMultiplier = 1.35,
		VolleyStagger = 0.04,
	},
	Milestones = {
		{ Level = 5, Description = "Throws 2 Daggers" },
		{ Level = 10, Description = "Throws 3 Daggers" },
		{ Level = 20, Description = "Throws 4 Daggers" },
		{ Level = 50, Description = "Throws 5 Daggers" },
	},
}

function dagger.GetStats(level: number)
	local clampedLevel = math.clamp(math.floor(level), 1, dagger.MaxLevel)
	return {
		Damage = math.floor(22 + (clampedLevel - 1) * 3.1 + 0.5),
		ProjectileScale = 0.22 + (clampedLevel - 1) * 0.0035,
		DaggerCount = getDaggerCount(clampedLevel),
	}
end

function dagger.GetRageStats(level: number)
	local normalStats = dagger.GetStats(level)
	-- Rage behavior belongs to the ability definition so future weapons can opt into wholly different mechanics.
	return {
		Damage = normalStats.Damage,
		ProjectileScale = normalStats.ProjectileScale * dagger.Rage.ProjectileScaleMultiplier,
		DaggerCount = math.min(normalStats.DaggerCount + dagger.Rage.AdditionalDaggers, dagger.Rage.MaximumDaggers),
		Cooldown = dagger.Rage.Cooldown,
		Range = dagger.Rage.Range,
		ProjectileSpeed = dagger.Rage.ProjectileSpeed,
		VolleyStagger = dagger.Rage.VolleyStagger,
		IsRage = true,
	}
end

function dagger.GetStatsText(level: number): string
	local current = dagger.GetStats(level)
	if level >= dagger.MaxLevel then
		return string.format(
			"Damage  %d\nProjectile Size  %d%%\nDaggers per Volley  %d",
			current.Damage,
			math.floor(current.ProjectileScale / 0.22 * 100 + 0.5),
			current.DaggerCount
		)
	end
	local nextStats = dagger.GetStats(level + 1)
	return string.format(
		"Damage  %d  >  %d\nProjectile Size  %d%%  >  %d%%\nDaggers per Volley  %d  >  %d",
		current.Damage,
		nextStats.Damage,
		math.floor(current.ProjectileScale / 0.22 * 100 + 0.5),
		math.floor(nextStats.ProjectileScale / 0.22 * 100 + 0.5),
		current.DaggerCount,
		nextStats.DaggerCount
	)
end

local orbitingSwords = {
	Id = "OrbitingSwords",
	Name = "Orbiting Swords",
	Category = AbilityDefinitions.Categories.Weapon,
	Description = "Spectral swords orbit you and damage zombies they physically pass through.",
	UpgradeDescription = "Every level improves damage, blade size, rotation speed, and eventually hit cadence.",
	Icon = Images.Abilities.Sword,
	AssetName = "Sword",
	Color = Color3.fromRGB(142, 116, 255),
	MaxLevel = 50,
	BaseUpgradeCost = 150,
	UpgradeCostGrowth = 1.15,
	Roll = {
		BaseOdds = 18,
		Rarity = "Epic",
		RarityRank = 4,
	},
	Combat = {
		SimulationInterval = 1 / 15,
		MaximumCandidates = 80,
		MaximumHitsPerSwordStep = 12,
		BaseDamage = 18,
		BaseScale = 0.3,
		BaseRotationSpeed = 1.9,
		BaseHitCooldown = 0.72,
		BaseRadius = 7.5,
		HitRadius = 1.65,
		WoundDuration = 2.5,
		WoundDamageMultiplier = 1.18,
		MomentumPerKill = 0.07,
		MaximumMomentum = 0.35,
		MomentumHoldDuration = 2.5,
		MomentumDecayPerSecond = 0.09,
		InnerDamageMultiplier = 0.55,
		InnerScaleMultiplier = 0.72,
		InnerRadiusMultiplier = 0.52,
		ReleaseDamageMultiplier = 0.8,
		ReleaseRange = 30,
		ReleaseTravelDuration = 0.34,
		Knockback = 8,
	},
	Rage = {
		RagePerHit = 3,
		RadiusMultiplier = 1.15,
		ScaleMultiplier = 1.2,
		RotationSpeedMultiplier = 2.4,
		AdditionalSwords = 2,
		KnockbackMultiplier = 1.4,
	},
	Milestones = {
		{ Level = 5, Description = "Twin Blades - adds a second sword opposite the first" },
		{ Level = 10, Description = "Extended Reach - noticeably widens the orbit" },
		{ Level = 15, Description = "Serrated Blades - Sword hits apply Wounded" },
		{ Level = 20, Description = "Triple Blades - adds a third equally spaced sword" },
		{ Level = 25, Description = "Momentum Blades - kills temporarily accelerate rotation" },
		{ Level = 30, Description = "Inner Orbit - adds a smaller defensive sword" },
		{ Level = 40, Description = "Blade Release - periodically launches a spectral copy" },
		{ Level = 50, Description = "Blade Storm - four blades and faster releases" },
	},
}

function orbitingSwords.GetStats(level: number)
	local clampedLevel = math.clamp(math.floor(level), 1, orbitingSwords.MaxLevel)
	local levelOffset = clampedLevel - 1
	local radius = orbitingSwords.Combat.BaseRadius
	if clampedLevel >= 10 then
		radius += 1.8
	end
	if clampedLevel >= 50 then
		radius += 1
	end

	return {
		Damage = math.floor(orbitingSwords.Combat.BaseDamage * (1 + levelOffset * 0.06) + 0.5),
		SwordScale = orbitingSwords.Combat.BaseScale * (1 + levelOffset * 0.005),
		RotationSpeed = orbitingSwords.Combat.BaseRotationSpeed * (1 + levelOffset * 0.005),
		HitCooldown = math.max(0.52, orbitingSwords.Combat.BaseHitCooldown - math.max(clampedLevel - 10, 0) * 0.004),
		OrbitRadius = radius,
		MainSwordCount = getOrbitingSwordCount(clampedLevel),
		Wounded = clampedLevel >= 15,
		Momentum = clampedLevel >= 25,
		InnerOrbit = clampedLevel >= 30,
		BladeRelease = clampedLevel >= 40,
		ReleaseEveryRotations = if clampedLevel >= 50 then 1.75 else 3,
	}
end

function orbitingSwords.GetRageStats(level: number)
	local stats = orbitingSwords.GetStats(level)
	stats.OrbitRadius *= orbitingSwords.Rage.RadiusMultiplier
	stats.SwordScale *= orbitingSwords.Rage.ScaleMultiplier
	stats.RotationSpeed *= orbitingSwords.Rage.RotationSpeedMultiplier
	stats.AdditionalSwords = orbitingSwords.Rage.AdditionalSwords
	stats.IsRage = true
	return stats
end

function orbitingSwords.GetStatsText(level: number): string
	local current = orbitingSwords.GetStats(level)
	if level >= orbitingSwords.MaxLevel then
		return string.format(
			"Damage  %d\nSword Size  %d%%\nRotation Speed  %d%%\nHit Cooldown  %.2fs\nRadius %.1f  |  Swords %d",
			current.Damage,
			math.floor(current.SwordScale / orbitingSwords.Combat.BaseScale * 100 + 0.5),
			math.floor(current.RotationSpeed / orbitingSwords.Combat.BaseRotationSpeed * 100 + 0.5),
			current.HitCooldown,
			current.OrbitRadius,
			current.MainSwordCount
		)
	end
	local nextStats = orbitingSwords.GetStats(level + 1)
	return string.format(
		"Damage  %d > %d\nSword Size  %d%% > %d%%\nRotation Speed  %d%% > %d%%\nHit Cooldown  %.2fs > %.2fs\nRadius %.1f > %.1f  |  Swords %d > %d",
		current.Damage,
		nextStats.Damage,
		math.floor(current.SwordScale / orbitingSwords.Combat.BaseScale * 100 + 0.5),
		math.floor(nextStats.SwordScale / orbitingSwords.Combat.BaseScale * 100 + 0.5),
		math.floor(current.RotationSpeed / orbitingSwords.Combat.BaseRotationSpeed * 100 + 0.5),
		math.floor(nextStats.RotationSpeed / orbitingSwords.Combat.BaseRotationSpeed * 100 + 0.5),
		current.HitCooldown,
		nextStats.HitCooldown,
		current.OrbitRadius,
		nextStats.OrbitRadius,
		current.MainSwordCount,
		nextStats.MainSwordCount
	)
end

local heart = {
	Id = "Heart",
	Name = "Heart",
	Category = AbilityDefinitions.Categories.Passive,
	Description = "Increases maximum health and preserves the gained health when equipped or upgraded.",
	UpgradeDescription = "Every level increases Max Health. Milestones add simple recovery effects.",
	Icon = Images.Abilities.Heart,
	Color = Color3.fromRGB(255, 104, 128),
	MaxLevel = 50,
	BaseUpgradeCost = 95,
	UpgradeCostGrowth = 1.14,
	Roll = {
		BaseOdds = 5,
		Rarity = "Uncommon",
		RarityRank = 2,
	},
	Config = {
		BaseMaxHealthPercent = 10,
		MaxHealthPercentPerLevel = 2,
		StrongHeart = {
			Level = 5,
			AdditionalPercentPerLevel = 0.25,
		},
		Recovery = {
			Level = 10,
			DelayAfterDamage = 6,
			PercentPerSecond = 0.8,
			TickInterval = 0.5,
		},
		Healthy = {
			Level = 20,
			BonusPercent = 12,
		},
		SecondWind = {
			Level = 35,
			ThresholdPercent = 30,
			RegenPercentPerSecond = 4,
			Duration = 4,
			TickInterval = 0.25,
		},
		GiantHeart = {
			Level = 50,
			BonusPercent = 20,
			RecoveryPercentPerSecond = 1.25,
			SecondWindRegenPercentPerSecond = 6,
		},
	},
	Milestones = {
		{ Level = 5, Description = "Strong Heart - improves Max Health gained per level" },
		{ Level = 10, Description = "Recovery - regenerate after avoiding damage for 6 seconds" },
		{ Level = 20, Description = "Healthy - gain an additional 12% Max Health" },
		{ Level = 35, Description = "Second Wind - once per run, low health triggers brief regeneration" },
		{ Level = 50, Description = "Giant Heart - gain 20% Max Health and stronger regeneration" },
	},
}

function heart.GetStats(level: number)
	local clampedLevel = math.clamp(math.floor(level), 1, heart.MaxLevel)
	local config = heart.Config
	local maxHealthPercent = config.BaseMaxHealthPercent + (clampedLevel - 1) * config.MaxHealthPercentPerLevel
	if clampedLevel >= config.StrongHeart.Level then
		maxHealthPercent += (clampedLevel - config.StrongHeart.Level + 1) * config.StrongHeart.AdditionalPercentPerLevel
	end
	if clampedLevel >= config.Healthy.Level then
		maxHealthPercent += config.Healthy.BonusPercent
	end
	if clampedLevel >= config.GiantHeart.Level then
		maxHealthPercent += config.GiantHeart.BonusPercent
	end

	return {
		MaxHealthPercent = maxHealthPercent,
		RecoveryUnlocked = clampedLevel >= config.Recovery.Level,
		RecoveryPercentPerSecond = if clampedLevel >= config.GiantHeart.Level
			then config.GiantHeart.RecoveryPercentPerSecond
			else config.Recovery.PercentPerSecond,
		SecondWindUnlocked = clampedLevel >= config.SecondWind.Level,
		SecondWindThresholdPercent = config.SecondWind.ThresholdPercent,
		SecondWindRegenPercentPerSecond = if clampedLevel >= config.GiantHeart.Level
			then config.GiantHeart.SecondWindRegenPercentPerSecond
			else config.SecondWind.RegenPercentPerSecond,
	}
end

function heart.GetDescription(level: number): string
	local stats = heart.GetStats(level)
	return string.format("Increase Max Health by +%.1f%%.", stats.MaxHealthPercent)
end

function heart.GetStatsText(level: number): string
	local clampedLevel = math.clamp(math.floor(level), 1, heart.MaxLevel)
	local current = heart.GetStats(clampedLevel)
	local lines = {}
	if clampedLevel >= heart.MaxLevel then
		table.insert(lines, string.format("Max Health  +%.1f%%", current.MaxHealthPercent))
	else
		local nextStats = heart.GetStats(clampedLevel + 1)
		table.insert(lines, string.format("Max Health  +%.1f%%  >  +%.1f%%", current.MaxHealthPercent, nextStats.MaxHealthPercent))
	end
	if current.RecoveryUnlocked then
		table.insert(lines, string.format("Recovery  %.2f%% Max Health / second", current.RecoveryPercentPerSecond))
	end
	if current.SecondWindUnlocked then
		table.insert(lines, "Second Wind  ready once per run")
	end
	return table.concat(lines, "\n")
end

local boots = {
	Id = "Boots",
	Name = "Boots",
	Category = AbilityDefinitions.Categories.Passive,
	Description = "Increases movement speed while respecting the game's final speed limit.",
	UpgradeDescription = "Every level increases Movement Speed. Milestones reward sustained or renewed movement.",
	Icon = Images.Abilities.Boots,
	Color = Color3.fromRGB(104, 190, 255),
	MaxLevel = 50,
	BaseUpgradeCost = 90,
	UpgradeCostGrowth = 1.14,
	Roll = {
		BaseOdds = 6,
		Rarity = "Uncommon",
		RarityRank = 2,
	},
	Config = {
		BaseMovementSpeedPercent = 5,
		MovementSpeedPercentPerLevel = 1,
		MovementThreshold = 0.5,
		LightFeet = {
			Level = 5,
			AdditionalPercentPerLevel = 0.1,
		},
		Sprint = {
			Level = 10,
			ActivationDelay = 3,
			StopGracePeriod = 1.5,
			BonusPercent = 6,
		},
		FastFeet = {
			Level = 20,
			BonusPercent = 5,
		},
		QuickStart = {
			Level = 35,
			RequiredStationaryDuration = 2,
			Duration = 1.5,
			Cooldown = 6,
			BonusPercent = 10,
		},
		Speedy = {
			Level = 50,
			BonusPercent = 8,
			SprintBonusPercent = 8,
		},
	},
	Milestones = {
		{ Level = 5, Description = "Light Feet - improves Movement Speed gained per level" },
		{ Level = 10, Description = "Sprint - sustained movement grants another 6% speed" },
		{ Level = 20, Description = "Fast Feet - gain an additional 5% Movement Speed" },
		{ Level = 35, Description = "Quick Start - moving after a pause grants a brief speed burst" },
		{ Level = 50, Description = "Speedy - gain 8% Movement Speed and a stronger Sprint" },
	},
}

function boots.GetStats(level: number)
	local clampedLevel = math.clamp(math.floor(level), 1, boots.MaxLevel)
	local config = boots.Config
	local movementSpeedPercent = config.BaseMovementSpeedPercent
		+ (clampedLevel - 1) * config.MovementSpeedPercentPerLevel
	if clampedLevel >= config.LightFeet.Level then
		movementSpeedPercent += (clampedLevel - config.LightFeet.Level + 1) * config.LightFeet.AdditionalPercentPerLevel
	end
	if clampedLevel >= config.FastFeet.Level then
		movementSpeedPercent += config.FastFeet.BonusPercent
	end
	if clampedLevel >= config.Speedy.Level then
		movementSpeedPercent += config.Speedy.BonusPercent
	end

	return {
		MovementSpeedPercent = movementSpeedPercent,
		SprintUnlocked = clampedLevel >= config.Sprint.Level,
		SprintBonusPercent = if clampedLevel >= config.Speedy.Level
			then config.Speedy.SprintBonusPercent
			else config.Sprint.BonusPercent,
		QuickStartUnlocked = clampedLevel >= config.QuickStart.Level,
		QuickStartBonusPercent = config.QuickStart.BonusPercent,
	}
end

function boots.GetDescription(level: number): string
	local stats = boots.GetStats(level)
	return string.format("Increase Movement Speed by +%.1f%%.", stats.MovementSpeedPercent)
end

function boots.GetStatsText(level: number): string
	local clampedLevel = math.clamp(math.floor(level), 1, boots.MaxLevel)
	local current = boots.GetStats(clampedLevel)
	local lines = {}
	if clampedLevel >= boots.MaxLevel then
		table.insert(lines, string.format("Movement Speed  +%.1f%%", current.MovementSpeedPercent))
	else
		local nextStats = boots.GetStats(clampedLevel + 1)
		table.insert(
			lines,
			string.format("Movement Speed  +%.1f%%  >  +%.1f%%", current.MovementSpeedPercent, nextStats.MovementSpeedPercent)
		)
	end
	if current.SprintUnlocked then
		table.insert(lines, string.format("Sprint  +%.1f%% while active", current.SprintBonusPercent))
	end
	if current.QuickStartUnlocked then
		table.insert(lines, string.format("Quick Start  +%.1f%% burst", current.QuickStartBonusPercent))
	end
	return table.concat(lines, "\n")
end

AbilityDefinitions.List = { dagger, orbitingSwords, heart, boots }
AbilityDefinitions.ById = {
	[dagger.Id] = dagger,
	[orbitingSwords.Id] = orbitingSwords,
	[heart.Id] = heart,
	[boots.Id] = boots,
}

function AbilityDefinitions.GetUpgradeCost(ability, currentLevel: number): number?
	if currentLevel >= ability.MaxLevel then
		return nil
	end

	-- Rounding to five keeps costs readable while exponential growth preserves long-term coin value.
	local rawCost = ability.BaseUpgradeCost * ability.UpgradeCostGrowth ^ (currentLevel - 1)
	return math.max(5, math.floor(rawCost / 5 + 0.5) * 5)
end

function AbilityDefinitions.GetNextMilestone(ability, currentLevel: number)
	for _, milestone in ability.Milestones do
		if milestone.Level > currentLevel then
			return milestone
		end
	end
	return nil
end

function AbilityDefinitions.GetDescription(ability, level: number): string
	return if ability.GetDescription then ability.GetDescription(level) else ability.Description
end

return AbilityDefinitions
