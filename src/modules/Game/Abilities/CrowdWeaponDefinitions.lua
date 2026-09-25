local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local CrowdWeaponDefinitions = {}

local MAX_LEVEL = 50

local function clampLevel(level: number): number
	return math.clamp(math.floor(level), 1, MAX_LEVEL)
end

local function rounded(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

local function makeStatsText(definition, level: number, fields): string
	local current = definition.GetStats(level)
	local nextStats = if level < definition.MaxLevel then definition.GetStats(level + 1) else nil
	local lines = {}
	for _, field in fields do
		local currentText = field.Format(current[field.Key])
		if nextStats then
			table.insert(lines, string.format("%s  %s > %s", field.Label, currentText, field.Format(nextStats[field.Key])))
		else
			table.insert(lines, string.format("%s  %s", field.Label, currentText))
		end
	end
	return table.concat(lines, "\n")
end

local aura = {
	Id = "Aura",
	Name = "Aura",
	Category = "Weapon",
	Description = "Continuously damages zombies that stay close to you.",
	UpgradeDescription = "Every level improves damage, radius, and tick speed. Milestones add stronger pulses.",
	Icon = Images.Abilities.Aura,
	Color = Color3.fromRGB(104, 221, 255),
	MaxLevel = MAX_LEVEL,
	BaseUpgradeCost = 115,
	UpgradeCostGrowth = 1.145,
	Roll = { BaseOdds = 8, Rarity = "Uncommon", RarityRank = 2 },
	Combat = {
		BaseDamage = 8,
		DamagePerLevel = 0.05,
		BaseRadius = 8,
		RadiusPerLevel = 0.005,
		MaximumRadius = 14,
		BaseTickInterval = 0.75,
		TickSpeedPerLevel = 0.0025,
		MinimumTickInterval = 0.42,
		MaximumTargetsPerTick = 45,
		Knockback = 0,
		Pulse = { Level = 20, Interval = 4, RadiusMultiplier = 1.25, DamageMultiplier = 2 },
	},
	Rage = {
		RadiusMultiplier = 1.45,
		TickIntervalMultiplier = 0.48,
		DamageMultiplier = 1.15,
		PulseInterval = 1.5,
		PulseRadiusMultiplier = 1.42,
		PulseDamageMultiplier = 2.5,
		KnockbackMultiplier = 1,
	},
	Milestones = {
		{ Level = 5, Description = "Larger Aura - noticeably increases Aura radius" },
		{ Level = 10, Description = "Faster Aura - damages enemies more frequently" },
		{ Level = 20, Description = "Pulse - periodically releases a larger, stronger ring" },
		{ Level = 30, Description = "Strong Aura - significantly increases normal damage" },
		{ Level = 40, Description = "Double Pulse - pulses happen faster and hit harder" },
		{ Level = 50, Description = "Super Aura - improves radius, damage, tick speed, and Pulse" },
	},
}

function aura.GetStats(level: number)
	local validLevel = clampLevel(level)
	local combat = aura.Combat
	local damage = combat.BaseDamage * (1 + (validLevel - 1) * combat.DamagePerLevel)
	local radius = combat.BaseRadius * (1 + (validLevel - 1) * combat.RadiusPerLevel)
	local tickInterval = combat.BaseTickInterval / (1 + (validLevel - 1) * combat.TickSpeedPerLevel)
	if validLevel >= 5 then radius *= 1.2 end
	if validLevel >= 10 then tickInterval *= 0.88 end
	if validLevel >= 30 then damage *= 1.4 end
	local pulseInterval = if validLevel >= combat.Pulse.Level then combat.Pulse.Interval else nil
	local pulseDamageMultiplier = combat.Pulse.DamageMultiplier
	if validLevel >= 40 then
		pulseInterval *= 0.7
		pulseDamageMultiplier *= 1.35
	end
	if validLevel >= 50 then
		radius *= 1.2
		damage *= 1.3
		tickInterval *= 0.82
		pulseDamageMultiplier *= 1.3
	end
	return {
		Damage = rounded(damage),
		Radius = math.min(radius, combat.MaximumRadius),
		TickInterval = math.max(tickInterval, combat.MinimumTickInterval),
		PulseInterval = pulseInterval,
		PulseRadiusMultiplier = combat.Pulse.RadiusMultiplier,
		PulseDamageMultiplier = pulseDamageMultiplier,
		Cooldown = math.max(tickInterval, combat.MinimumTickInterval),
	}
end

function aura.GetRageStats(level: number)
	local stats = aura.GetStats(level)
	stats.Damage *= aura.Rage.DamageMultiplier
	stats.Radius = math.min(stats.Radius * aura.Rage.RadiusMultiplier, aura.Combat.MaximumRadius * 1.45)
	stats.TickInterval *= aura.Rage.TickIntervalMultiplier
	stats.Cooldown = stats.TickInterval
	stats.PulseInterval = aura.Rage.PulseInterval
	stats.PulseRadiusMultiplier = aura.Rage.PulseRadiusMultiplier
	stats.PulseDamageMultiplier = aura.Rage.PulseDamageMultiplier
	stats.IsRage = true
	return stats
end

function aura.GetStatsText(level: number): string
	return makeStatsText(aura, level, {
		{ Key = "Damage", Label = "Damage", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Radius", Label = "Radius", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "TickInterval", Label = "Tick Rate", Format = function(value) return string.format("%.2fs", value) end },
	})
end

local ball = {
	Id = "Ball",
	Name = "Ball",
	Category = "Weapon",
	Description = "Launches a heavy ball that ricochets between nearby zombies.",
	UpgradeDescription = "Every level improves damage, size, speed, and cooldown. Milestones add balls and bounces.",
	Icon = Images.Abilities.Ball,
	AssetName = "Ball",
	Color = Color3.fromRGB(255, 196, 62),
	MaxLevel = MAX_LEVEL,
	BaseUpgradeCost = 125,
	UpgradeCostGrowth = 1.147,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Combat = {
		BaseDamage = 28,
		DamagePerLevel = 0.05,
		BaseScale = 1,
		ScalePerLevel = 0.005,
		BaseSpeed = 42,
		SpeedPerLevel = 0.005,
		BaseCooldown = 2.25,
		CooldownReductionPerLevel = 0.012,
		MinimumCooldown = 1.35,
		TargetRange = 70,
		BounceRange = 24,
		BaseBounces = 3,
		MaximumCandidatePool = 35,
		MaximumActive = 10,
		MissLifetime = 0.5,
		Knockback = 12,
	},
	Rage = {
		CooldownMultiplier = 0.42,
		AdditionalBounces = 3,
		ScaleMultiplier = 1.35,
		SpeedMultiplier = 1.3,
		AdditionalBalls = 2,
		MaximumBalls = 5,
		MaximumActive = 16,
		KnockbackMultiplier = 1.2,
	},
	Milestones = {
		{ Level = 5, Description = "Extra Bounce - increases maximum bounces" },
		{ Level = 10, Description = "Big Ball - noticeably increases size and hitbox" },
		{ Level = 20, Description = "Double Ball - launches 2 balls toward separate enemies" },
		{ Level = 30, Description = "Power Bounce - consecutive new hits become stronger, up to a cap" },
		{ Level = 40, Description = "Extra Bounces - significantly increases maximum bounces" },
		{ Level = 50, Description = "Triple Ball - launches 3 larger, faster, stronger balls" },
	},
}

function ball.GetStats(level: number)
	local validLevel = clampLevel(level)
	local combat = ball.Combat
	local damage = combat.BaseDamage * (1 + (validLevel - 1) * combat.DamagePerLevel)
	local scale = combat.BaseScale * (1 + (validLevel - 1) * combat.ScalePerLevel)
	local speed = combat.BaseSpeed * (1 + (validLevel - 1) * combat.SpeedPerLevel)
	local cooldown = combat.BaseCooldown * (1 - (validLevel - 1) * combat.CooldownReductionPerLevel / 10)
	local bounceCount = combat.BaseBounces + (if validLevel >= 5 then 1 else 0) + (if validLevel >= 40 then 3 else 0)
	local ballCount = if validLevel >= 50 then 3 elseif validLevel >= 20 then 2 else 1
	if validLevel >= 10 then scale *= 1.3 end
	if validLevel >= 50 then
		damage *= 1.25
		scale *= 1.12
		speed *= 1.18
		bounceCount += 1
	end
	return {
		Damage = rounded(damage),
		Scale = scale,
		Speed = speed,
		Cooldown = math.max(cooldown, combat.MinimumCooldown),
		BounceCount = bounceCount,
		BallCount = ballCount,
		HitRadius = 1.25 * scale,
		PowerBouncePerHit = if validLevel >= 30 then 0.05 else 0,
		PowerBounceCap = 0.3,
		MaximumActive = combat.MaximumActive,
	}
end

function ball.GetRageStats(level: number)
	local stats = ball.GetStats(level)
	stats.Cooldown *= ball.Rage.CooldownMultiplier
	stats.BounceCount += ball.Rage.AdditionalBounces
	stats.Scale *= ball.Rage.ScaleMultiplier
	stats.HitRadius *= ball.Rage.ScaleMultiplier
	stats.Speed *= ball.Rage.SpeedMultiplier
	stats.BallCount = math.min(stats.BallCount + ball.Rage.AdditionalBalls, ball.Rage.MaximumBalls)
	stats.MaximumActive = ball.Rage.MaximumActive
	stats.IsRage = true
	return stats
end

function ball.GetStatsText(level: number): string
	return makeStatsText(ball, level, {
		{ Key = "Damage", Label = "Damage", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "BallCount", Label = "Balls", Format = tostring },
		{ Key = "BounceCount", Label = "Bounces", Format = tostring },
		{ Key = "Cooldown", Label = "Cooldown", Format = function(value) return string.format("%.2fs", value) end },
	})
end

local drill = {
	Id = "Drill",
	Name = "Drill",
	Category = "Weapon",
	Description = "Fires piercing drills straight in the direction your character faces.",
	UpgradeDescription = "Every level improves damage, width, range, and cooldown. Milestones add drills and speed.",
	Icon = Images.Abilities.Drill,
	AssetName = "Drill",
	Color = Color3.fromRGB(104, 169, 255),
	MaxLevel = MAX_LEVEL,
	BaseUpgradeCost = 120,
	UpgradeCostGrowth = 1.146,
	Roll = { BaseOdds = 8, Rarity = "Uncommon", RarityRank = 2 },
	Combat = {
		BaseDamage = 30,
		DamagePerLevel = 0.06,
		BaseWidth = 2,
		WidthPerLevel = 0.005,
		BaseRange = 45,
		RangePerLevel = 0.01,
		BaseCooldown = 2.4,
		CooldownReductionPerLevel = 0.012,
		MinimumCooldown = 1.3,
		BaseSpeed = 52,
		MaximumTargets = 60,
		Knockback = 8,
	},
	Rage = {
		CooldownMultiplier = 0.4,
		WidthMultiplier = 1.35,
		SpeedMultiplier = 1.25,
		AdditionalDrills = 2,
		SpreadDegrees = 10,
		KnockbackMultiplier = 1.15,
	},
	Milestones = {
		{ Level = 5, Description = "Long Drill - significantly increases travel distance" },
		{ Level = 10, Description = "Wide Drill - increases width and hitbox" },
		{ Level = 20, Description = "Double Drill - fires 2 drills side-by-side" },
		{ Level = 30, Description = "Fast Drill - significantly increases travel speed" },
		{ Level = 40, Description = "Triple Drill - fires 3 drills in a narrow spread" },
		{ Level = 50, Description = "Mega Drill - improves drill count, size, range, damage, and speed" },
	},
}

function drill.GetStats(level: number)
	local validLevel = clampLevel(level)
	local combat = drill.Combat
	local damage = combat.BaseDamage * (1 + (validLevel - 1) * combat.DamagePerLevel)
	local width = combat.BaseWidth * (1 + (validLevel - 1) * combat.WidthPerLevel)
	local range = combat.BaseRange * (1 + (validLevel - 1) * combat.RangePerLevel)
	local speed = combat.BaseSpeed
	local cooldown = combat.BaseCooldown * (1 - (validLevel - 1) * combat.CooldownReductionPerLevel / 10)
	if validLevel >= 5 then range *= 1.3 end
	if validLevel >= 10 then width *= 1.35 end
	if validLevel >= 30 then speed *= 1.35 end
	local drillCount = if validLevel >= 40 then 3 elseif validLevel >= 20 then 2 else 1
	local spreadDegrees = if validLevel >= 40 then 6 else 0
	if validLevel >= 50 then
		damage *= 1.25
		width *= 1.2
		range *= 1.2
		speed *= 1.18
	end
	return {
		Damage = rounded(damage),
		Width = width,
		Range = range,
		Speed = speed,
		Cooldown = math.max(cooldown, combat.MinimumCooldown),
		DrillCount = drillCount,
		SpreadDegrees = spreadDegrees,
	}
end

function drill.GetRageStats(level: number)
	local stats = drill.GetStats(level)
	stats.Cooldown *= drill.Rage.CooldownMultiplier
	stats.Width *= drill.Rage.WidthMultiplier
	stats.Speed *= drill.Rage.SpeedMultiplier
	stats.DrillCount += drill.Rage.AdditionalDrills
	stats.SpreadDegrees = math.max(stats.SpreadDegrees, drill.Rage.SpreadDegrees)
	stats.IsRage = true
	return stats
end

function drill.GetStatsText(level: number): string
	return makeStatsText(drill, level, {
		{ Key = "Damage", Label = "Damage", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Width", Label = "Width", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Range", Label = "Range", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "DrillCount", Label = "Drills", Format = tostring },
	})
end

local mine = {
	Id = "Mine",
	Name = "Mine",
	Category = "Weapon",
	Description = "Drops ground traps behind you that explode when zombies approach.",
	UpgradeDescription = "Every level improves explosion damage, radius, and deployment cooldown.",
	Icon = Images.Abilities.Mine,
	AssetName = "Mine",
	Color = Color3.fromRGB(255, 91, 66),
	MaxLevel = MAX_LEVEL,
	BaseUpgradeCost = 120,
	UpgradeCostGrowth = 1.146,
	Roll = { BaseOdds = 12, Rarity = "Rare", RarityRank = 3 },
	Combat = {
		BaseDamage = 42,
		DamagePerLevel = 0.06,
		BaseRadius = 7,
		RadiusPerLevel = 0.005,
		BaseCooldown = 4,
		CooldownReductionPerLevel = 0.018,
		MinimumCooldown = 2.1,
		TriggerRadius = 4.2,
		FuseDuration = 0.34,
		Lifetime = 15,
		MaximumActive = 12,
		MaximumTargetsPerExplosion = 50,
		PlacementBackDistance = 2.8,
		GroundRayHeight = 7,
		GroundRayDepth = 18,
		Knockback = 20,
		Chain = { Level = 30, Radius = 15, Stagger = 0.08 },
	},
	Rage = {
		CooldownMultiplier = 0.38,
		TriggerRadiusMultiplier = 1.35,
		RadiusMultiplier = 1.3,
		FuseMultiplier = 0.5,
		MaximumActive = 20,
		KnockbackMultiplier = 1.2,
	},
	Milestones = {
		{ Level = 5, Description = "Bigger Mine - increases explosion radius" },
		{ Level = 10, Description = "Extra Mine - deploys 2 offset Mines" },
		{ Level = 20, Description = "Strong Mine - significantly increases explosion damage" },
		{ Level = 30, Description = "Chain Mine - nearby Mines trigger with a short stagger" },
		{ Level = 40, Description = "Triple Mine - deploys 3 Mines in a small spread" },
		{ Level = 50, Description = "Mega Mine - improves explosions, cooldown, count, and trigger response" },
	},
}

function mine.GetStats(level: number)
	local validLevel = clampLevel(level)
	local combat = mine.Combat
	local damage = combat.BaseDamage * (1 + (validLevel - 1) * combat.DamagePerLevel)
	local radius = combat.BaseRadius * (1 + (validLevel - 1) * combat.RadiusPerLevel)
	local cooldown = combat.BaseCooldown * (1 - (validLevel - 1) * combat.CooldownReductionPerLevel / 10)
	if validLevel >= 5 then radius *= 1.25 end
	if validLevel >= 20 then damage *= 1.45 end
	local mineCount = if validLevel >= 40 then 3 elseif validLevel >= 10 then 2 else 1
	local fuseDuration = combat.FuseDuration
	if validLevel >= 50 then
		damage *= 1.25
		radius *= 1.2
		cooldown *= 0.82
		fuseDuration *= 0.65
	end
	return {
		Damage = rounded(damage),
		Radius = radius,
		Cooldown = math.max(cooldown, combat.MinimumCooldown),
		MineCount = mineCount,
		TriggerRadius = combat.TriggerRadius,
		FuseDuration = fuseDuration,
		ChainUnlocked = validLevel >= combat.Chain.Level,
		MaximumActive = combat.MaximumActive,
	}
end

function mine.GetRageStats(level: number)
	local stats = mine.GetStats(level)
	stats.Cooldown *= mine.Rage.CooldownMultiplier
	stats.TriggerRadius *= mine.Rage.TriggerRadiusMultiplier
	stats.Radius *= mine.Rage.RadiusMultiplier
	stats.FuseDuration *= mine.Rage.FuseMultiplier
	stats.MaximumActive = mine.Rage.MaximumActive
	stats.IsRage = true
	return stats
end

function mine.GetStatsText(level: number): string
	return makeStatsText(mine, level, {
		{ Key = "Damage", Label = "Damage", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Radius", Label = "Radius", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "MineCount", Label = "Mines", Format = tostring },
		{ Key = "Cooldown", Label = "Cooldown", Format = function(value) return string.format("%.2fs", value) end },
	})
end

local poison = {
	Id = "Poison",
	Name = "Poison",
	Category = "Weapon",
	Description = "Creates persistent toxic puddles beneath nearby zombie groups.",
	UpgradeDescription = "Every level improves tick damage, size, duration, and cooldown. Milestones add puddles and spreading.",
	Icon = Images.Abilities.Poison,
	Color = Color3.fromRGB(99, 230, 76),
	MaxLevel = MAX_LEVEL,
	BaseUpgradeCost = 125,
	UpgradeCostGrowth = 1.147,
	Roll = { BaseOdds = 20, Rarity = "Epic", RarityRank = 4 },
	Combat = {
		BaseDamage = 7,
		DamagePerLevel = 0.05,
		BaseRadius = 6,
		RadiusPerLevel = 0.005,
		BaseDuration = 5,
		DurationPerLevel = 0.005,
		MaximumDuration = 9,
		BaseCooldown = 3.2,
		CooldownReductionPerLevel = 0.014,
		MinimumCooldown = 1.75,
		TickInterval = 0.85,
		TargetRange = 65,
		MaximumTargetsPerTick = 45,
		MaximumActive = 12,
		GroundRayHeight = 7,
		GroundRayDepth = 18,
		Knockback = 0,
		Spread = {
			Level = 40,
			ChancePercent = 15,
			FinalChancePercent = 28,
			RadiusMultiplier = 0.58,
			DurationMultiplier = 0.55,
			DamageMultiplier = 0.7,
		},
	},
	Rage = {
		CooldownMultiplier = 0.38,
		RadiusMultiplier = 1.3,
		TickIntervalMultiplier = 0.55,
		DurationMultiplier = 1.18,
		MaximumActive = 20,
		KnockbackMultiplier = 1,
	},
	Milestones = {
		{ Level = 5, Description = "Bigger Puddle - significantly increases Poison radius" },
		{ Level = 10, Description = "Long Poison - puddles remain longer" },
		{ Level = 20, Description = "Double Poison - creates 2 puddles beneath separate groups" },
		{ Level = 30, Description = "Strong Poison - substantially increases tick damage" },
		{ Level = 40, Description = "Poison Spread - poisoned deaths can create one weaker secondary puddle" },
		{ Level = 50, Description = "Toxic Field - creates 3 larger, longer, stronger puddles with improved spread" },
	},
}

function poison.GetStats(level: number)
	local validLevel = clampLevel(level)
	local combat = poison.Combat
	local damage = combat.BaseDamage * (1 + (validLevel - 1) * combat.DamagePerLevel)
	local radius = combat.BaseRadius * (1 + (validLevel - 1) * combat.RadiusPerLevel)
	local duration = combat.BaseDuration * (1 + (validLevel - 1) * combat.DurationPerLevel)
	local cooldown = combat.BaseCooldown * (1 - (validLevel - 1) * combat.CooldownReductionPerLevel / 10)
	if validLevel >= 5 then radius *= 1.28 end
	if validLevel >= 10 then duration *= 1.3 end
	if validLevel >= 30 then damage *= 1.45 end
	local puddleCount = if validLevel >= 50 then 3 elseif validLevel >= 20 then 2 else 1
	if validLevel >= 50 then
		damage *= 1.25
		radius *= 1.18
		duration *= 1.15
	end
	return {
		Damage = rounded(damage),
		Radius = radius,
		Duration = math.min(duration, combat.MaximumDuration),
		Cooldown = math.max(cooldown, combat.MinimumCooldown),
		TickInterval = combat.TickInterval,
		PuddleCount = puddleCount,
		SpreadUnlocked = validLevel >= combat.Spread.Level,
		SpreadChancePercent = if validLevel >= 50 then combat.Spread.FinalChancePercent else combat.Spread.ChancePercent,
		MaximumActive = combat.MaximumActive,
	}
end

function poison.GetRageStats(level: number)
	local stats = poison.GetStats(level)
	stats.Cooldown *= poison.Rage.CooldownMultiplier
	stats.Radius *= poison.Rage.RadiusMultiplier
	stats.TickInterval *= poison.Rage.TickIntervalMultiplier
	stats.Duration = math.min(stats.Duration * poison.Rage.DurationMultiplier, poison.Combat.MaximumDuration * 1.18)
	stats.MaximumActive = poison.Rage.MaximumActive
	stats.IsRage = true
	return stats
end

function poison.GetStatsText(level: number): string
	return makeStatsText(poison, level, {
		{ Key = "Damage", Label = "Tick Damage", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Radius", Label = "Radius", Format = function(value) return string.format("%.1f", value) end },
		{ Key = "Duration", Label = "Duration", Format = function(value) return string.format("%.1fs", value) end },
		{ Key = "PuddleCount", Label = "Puddles", Format = tostring },
	})
end

CrowdWeaponDefinitions.List = { aura, ball, drill, mine, poison }

return CrowdWeaponDefinitions
