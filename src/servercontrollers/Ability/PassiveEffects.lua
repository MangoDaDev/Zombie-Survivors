local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local PlayerStatController = require(ServerStorage.Controllers.PlayerStatController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)
local CombatTargets = require(script.Parent.CombatTargets)

local HEART_MODIFIER_ID = "Ability:Heart"
local BOOTS_MODIFIER_ID = "Ability:Boots"
local BURN_UPDATE_INTERVAL = 0.1

type PlayerRuntime = {
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	connections: { RBXScriptConnection },
	refreshToken: number,
	heartLevel: number?,
	bootsLevel: number?,
	blastLevel: number?,
	burnLevel: number?,
	thornsLevel: number?,
	revengeUntil: number,
	lastDamageAt: number,
	lastHealth: number,
	secondWindUsed: boolean,
	moving: boolean,
	movementRevision: number,
	stationarySince: number,
	sprintActive: boolean,
	quickStartActive: boolean,
	quickStartReadyAt: number,
	sprintTrail: Trail?,
}

local PassiveEffects = {}

local abilityNetwork
local getAbilityData
local runtimes: { [Player]: PlayerRuntime } = {}
local burns = {}
local random = Random.new()
local nextBurnUpdateAt = 0

local function disconnectCharacter(runtime: PlayerRuntime)
	runtime.refreshToken += 1
	for _, connection in runtime.connections do
		connection:Disconnect()
	end
	table.clear(runtime.connections)
	if runtime.sprintTrail then
		local trailParent = runtime.sprintTrail.Parent
		runtime.sprintTrail:Destroy()
		runtime.sprintTrail = nil
		if trailParent then
			for _, childName in { "BootsTrailLeft", "BootsTrailRight" } do
				local attachment = trailParent:FindFirstChild(childName)
				if attachment then
					attachment:Destroy()
				end
			end
		end
	end
end

local function setSprintVisual(runtime: PlayerRuntime, enabled: boolean)
	if runtime.sprintTrail then
		runtime.sprintTrail.Enabled = enabled
	end
end

local function createSprintTrail(runtime: PlayerRuntime)
	local root = runtime.root
	if not root or runtime.sprintTrail or not runtime.bootsLevel or runtime.bootsLevel < 10 then
		return
	end

	local left = Instance.new("Attachment")
	left.Name = "BootsTrailLeft"
	left.Position = Vector3.new(-0.75, -1.8, 0.45)
	left.Parent = root
	local right = Instance.new("Attachment")
	right.Name = "BootsTrailRight"
	right.Position = Vector3.new(0.75, -1.8, 0.45)
	right.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "BootsSprintTrail"
	trail.Attachment0 = left
	trail.Attachment1 = right
	trail.Color = ColorSequence.new(Color3.fromRGB(162, 224, 255), Color3.fromRGB(91, 153, 255))
	trail.LightEmission = 0.45
	trail.Lifetime = 0.12
	trail.MinLength = 0.15
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(0.7, 0)
	trail.Enabled = false
	trail.Parent = root
	runtime.sprintTrail = trail
end

local function applyBootsModifier(player: Player, runtime: PlayerRuntime)
	local level = runtime.bootsLevel
	if not level then
		PlayerStatController.SetModifier(player, BOOTS_MODIFIER_ID, nil)
		return
	end

	local stats = AbilityDefinitions.ById.Boots.GetStats(level)
	local bonusPercent = stats.MovementSpeedPercent
	if runtime.sprintActive then
		bonusPercent += stats.SprintBonusPercent
	end
	if runtime.quickStartActive then
		bonusPercent += stats.QuickStartBonusPercent
	end
	PlayerStatController.SetModifier(player, BOOTS_MODIFIER_ID, {
		WalkSpeedMultiplier = bonusPercent / 100,
	})
end

local function activateSecondWind(player: Player, runtime: PlayerRuntime)
	local level = runtime.heartLevel
	if not level or level < 35 or runtime.secondWindUsed then
		return
	end
	runtime.secondWindUsed = true
	local stats = AbilityDefinitions.ById.Heart.GetStats(level)
	local config = AbilityDefinitions.ById.Heart.Config.SecondWind
	local tickCount = math.floor(config.Duration / config.TickInterval + 0.5)
	local humanoid = runtime.humanoid

	task.spawn(function()
		for _ = 1, tickCount do
			task.wait(config.TickInterval)
			if runtimes[player] ~= runtime or runtime.humanoid ~= humanoid or not runtime.heartLevel then
				return
			end
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			local healing = humanoid.MaxHealth * stats.SecondWindRegenPercentPerSecond / 100 * config.TickInterval
			humanoid.Health = math.min(humanoid.Health + healing, humanoid.MaxHealth)
		end
	end)
end

local function startRecoveryLoop(player: Player, runtime: PlayerRuntime, token: number)
	local level = runtime.heartLevel
	if not level or level < 10 then
		return
	end
	local config = AbilityDefinitions.ById.Heart.Config.Recovery

	task.spawn(function()
		while runtimes[player] == runtime and runtime.refreshToken == token do
			task.wait(config.TickInterval)
			local humanoid = runtime.humanoid
			local currentLevel = runtime.heartLevel
			if humanoid
				and humanoid.Health > 0
				and humanoid.Health < humanoid.MaxHealth
				and currentLevel
				and workspace:GetServerTimeNow() - runtime.lastDamageAt >= config.DelayAfterDamage
			then
				local stats = AbilityDefinitions.ById.Heart.GetStats(currentLevel)
				local healing = humanoid.MaxHealth * stats.RecoveryPercentPerSecond / 100 * config.TickInterval
				humanoid.Health = math.min(humanoid.Health + healing, humanoid.MaxHealth)
			end
		end
	end)
end

local function bindHeart(player: Player, runtime: PlayerRuntime, token: number)
	local humanoid = runtime.humanoid
	local level = runtime.heartLevel
	if not humanoid or not level then
		return
	end

	runtime.lastHealth = humanoid.Health
	table.insert(runtime.connections, humanoid.HealthChanged:Connect(function(health)
		local previousHealth = runtime.lastHealth
		runtime.lastHealth = health
		if health >= previousHealth then
			return
		end

		runtime.lastDamageAt = workspace:GetServerTimeNow()
		local stats = AbilityDefinitions.ById.Heart.GetStats(runtime.heartLevel or level)
		local threshold = humanoid.MaxHealth * stats.SecondWindThresholdPercent / 100
		-- Second Wind is intentionally consumed once per joined run and is not reset by death or respawn.
		if previousHealth > threshold and health > 0 and health <= threshold then
			activateSecondWind(player, runtime)
		end
	end))
	startRecoveryLoop(player, runtime, token)
end

local function bindBoots(player: Player, runtime: PlayerRuntime, token: number)
	local humanoid = runtime.humanoid
	local level = runtime.bootsLevel
	if not humanoid or not level then
		return
	end

	createSprintTrail(runtime)
	runtime.moving = humanoid.MoveDirection.Magnitude > 0.05
	runtime.movementRevision += 1
	runtime.stationarySince = workspace:GetServerTimeNow()
	runtime.sprintActive = false
	runtime.quickStartActive = false
	applyBootsModifier(player, runtime)

	table.insert(runtime.connections, humanoid.Running:Connect(function(speed)
		local now = workspace:GetServerTimeNow()
		local moving = speed > AbilityDefinitions.ById.Boots.Config.MovementThreshold
		if moving == runtime.moving then
			return
		end
		runtime.moving = moving
		runtime.movementRevision += 1
		local movementRevision = runtime.movementRevision

		if moving then
			local stats = AbilityDefinitions.ById.Boots.GetStats(runtime.bootsLevel or level)
			local quickStart = AbilityDefinitions.ById.Boots.Config.QuickStart
			if stats.QuickStartUnlocked
				and now - runtime.stationarySince >= quickStart.RequiredStationaryDuration
				and now >= runtime.quickStartReadyAt
			then
				runtime.quickStartActive = true
				runtime.quickStartReadyAt = now + quickStart.Cooldown
				applyBootsModifier(player, runtime)
				task.delay(quickStart.Duration, function()
					if runtimes[player] == runtime and runtime.refreshToken == token then
						runtime.quickStartActive = false
						applyBootsModifier(player, runtime)
					end
				end)
			end

			if stats.SprintUnlocked and not runtime.sprintActive then
				task.delay(AbilityDefinitions.ById.Boots.Config.Sprint.ActivationDelay, function()
					if runtimes[player] == runtime
						and runtime.refreshToken == token
						and runtime.movementRevision == movementRevision
						and runtime.moving
					then
						runtime.sprintActive = true
						applyBootsModifier(player, runtime)
						setSprintVisual(runtime, true)
					end
				end)
			end
		else
			runtime.stationarySince = now
			task.delay(AbilityDefinitions.ById.Boots.Config.Sprint.StopGracePeriod, function()
				if runtimes[player] == runtime and runtime.refreshToken == token and not runtime.moving then
					runtime.sprintActive = false
					setSprintVisual(runtime, false)
					applyBootsModifier(player, runtime)
				end
			end)
		end
	end))
end

local function getEquippedLevel(data, abilityId: string): number?
	local definition = AbilityDefinitions.ById[abilityId]
	local equipped = data.Equipped and data.Equipped[definition.Category]
	if type(equipped) ~= "table" or table.find(equipped, abilityId) == nil then
		return nil
	end
	local level = data.Levels and data.Levels[abilityId]
	return if type(level) == "number" then math.clamp(math.floor(level), 1, definition.MaxLevel) else 1
end

local function rollChance(percent: number): boolean
	return random:NextNumber(0, 100) < percent
end

local function removeBurn(targetId: number)
	if not burns[targetId] then
		return
	end
	burns[targetId] = nil
	abilityNetwork:fireAll("PassiveBurnEnded", targetId)
end

local function clearBurnsForPlayer(player: Player)
	for targetId, burnState in burns do
		if burnState.player == player then
			removeBurn(targetId)
		end
	end
end

local function applyBurn(player: Player, targetId: number, now: number)
	local runtime = runtimes[player]
	local level = runtime and runtime.burnLevel
	if not level or not ZombieController.GetZombiePosition(targetId) then
		return
	end

	local definition = AbilityDefinitions.ById.Burn
	local stats = definition.GetStats(level)
	local existing = burns[targetId]
	if existing then
		-- One burn per zombie is refreshed in place; only a stronger application takes ownership.
		existing.expiresAt = now + stats.Duration
		if stats.TickDamage > existing.damage then
			existing.player = player
			existing.damage = stats.TickDamage
		end
	else
		existing = {
			player = player,
			damage = stats.TickDamage,
			nextTickAt = now + definition.Config.TickInterval,
			expiresAt = now + stats.Duration,
		}
		burns[targetId] = existing
	end

	abilityNetwork:fireAll("PassiveBurnApplied", {
		targetId = targetId,
		duration = math.max(existing.expiresAt - now, 0),
	})
end

local function applyBlastExplosion(
	player: Player,
	position: Vector3,
	damage: number,
	radius: number,
	chainDepth: number,
	chainState,
	secondary: boolean
)
	local runtime = runtimes[player]
	if not runtime or not runtime.blastLevel then
		return
	end

	local definition = AbilityDefinitions.ById.Blast
	abilityNetwork:fireAll("BlastTriggered", {
		position = position,
		radius = radius,
		secondary = secondary,
	})
	for _, target in CombatTargets.GetDamageablesInRadius(position, radius, definition.Config.MaximumTargets) do
		CombatTargets.DamageTarget(target, damage, position, 0, {
			player = player,
			source = "Blast",
			canApplyHitPassives = false,
			chainDepth = chainDepth,
			chainState = chainState,
		})
	end
end

local function triggerBlast(player: Player, position: Vector3, chainDepth: number, chainState)
	local runtime = runtimes[player]
	local level = runtime and runtime.blastLevel
	if not level then
		return
	end

	local definition = AbilityDefinitions.ById.Blast
	local stats = definition.GetStats(level)
	local state = chainState or { count = 0 }
	if state.count >= definition.Config.ChainBlast.MaximumExplosionsPerReaction then
		return
	end
	state.count += 1
	applyBlastExplosion(player, position, stats.Damage, stats.Radius, chainDepth, state, false)

	if stats.DoubleUnlocked
		and rollChance(stats.DoubleChancePercent)
		and state.count < definition.Config.ChainBlast.MaximumExplosionsPerReaction
	then
		-- Reserve this explosion before delaying it so simultaneous chain kills cannot exceed the cap.
		state.count += 1
		task.delay(definition.Config.DoubleBlast.Delay, function()
			local currentRuntime = runtimes[player]
			local currentLevel = currentRuntime and currentRuntime.blastLevel
			if not currentLevel then
				return
			end
			local currentStats = definition.GetStats(currentLevel)
			applyBlastExplosion(
				player,
				position,
				math.max(1, math.floor(currentStats.Damage * definition.Config.DoubleBlast.DamageMultiplier + 0.5)),
				currentStats.Radius * definition.Config.DoubleBlast.RadiusMultiplier,
				chainDepth,
				state,
				true
			)
		end)
	end
end

local function spreadBurn(position: Vector3, burnState, now: number)
	local runtime = runtimes[burnState.player]
	local level = runtime and runtime.burnLevel
	if not level then
		return
	end

	local definition = AbilityDefinitions.ById.Burn
	local stats = definition.GetStats(level)
	if not stats.SpreadUnlocked or not rollChance(stats.SpreadChancePercent) then
		return
	end
	local target = ZombieController.GetNearestZombies(position, definition.Config.Spread.Radius, 1)[1]
	if target then
		applyBurn(burnState.player, target.id, now)
	end
end

local function onZombieDamaged(targetId, position, _actualDamage, killed, damageContext)
	if type(damageContext) ~= "table" then
		return
	end
	local player = damageContext.player
	local runtime = typeof(player) == "Instance" and player:IsA("Player") and runtimes[player]
	if not runtime then
		return
	end

	local now = workspace:GetServerTimeNow()
	if not killed and runtime.burnLevel and damageContext.canApplyHitPassives == true then
		local burnStats = AbilityDefinitions.ById.Burn.GetStats(runtime.burnLevel)
		if rollChance(burnStats.ChancePercent) then
			applyBurn(player, targetId, now)
		end
	end

	if not killed then
		return
	end
	local burnState = burns[targetId]
	if burnState then
		spreadBurn(position, burnState, now)
		removeBurn(targetId)
	end

	local blastLevel = runtime.blastLevel
	if not blastLevel then
		return
	end
	local definition = AbilityDefinitions.ById.Blast
	local stats = definition.GetStats(blastLevel)
	if damageContext.source == "Blast" then
		local depth = if type(damageContext.chainDepth) == "number" then damageContext.chainDepth else 0
		local state = damageContext.chainState
		if stats.ChainUnlocked
			and depth < definition.Config.ChainBlast.MaximumDepth
			and type(state) == "table"
			and state.count < definition.Config.ChainBlast.MaximumExplosionsPerReaction
			and rollChance(stats.ChainChancePercent)
		then
			triggerBlast(player, position, depth + 1, state)
		end
	elseif rollChance(stats.ChancePercent) then
		triggerBlast(player, position, 0, nil)
	end
end

local function onPlayerDamagedByZombie(player: Player, attackerId: number, attackerPosition: Vector3, actualDamage: number)
	local runtime = runtimes[player]
	local level = runtime and runtime.thornsLevel
	if not level or actualDamage <= 0 then
		return
	end

	local definition = AbilityDefinitions.ById.Thorns
	local stats = definition.GetStats(level)
	local now = workspace:GetServerTimeNow()
	local reflectionPercent = stats.ReflectionPercent
	if now < runtime.revengeUntil then
		reflectionPercent *= 1 + stats.RevengeBonusPercent / 100
	end
	local reflectedDamage = math.max(1, math.floor(actualDamage * reflectionPercent / 100 + 0.5))
	ZombieController.DamageZombie(attackerId, reflectedDamage, runtime.root and runtime.root.Position, 0, {
		player = player,
		source = "Thorns",
		canApplyHitPassives = false,
	})

	local playerPosition = if runtime.root then runtime.root.Position else attackerPosition
	if stats.BurstUnlocked then
		local burstDamage = math.max(1, math.floor(actualDamage * stats.BurstDamagePercent / 100 + 0.5))
		for _, target in CombatTargets.GetDamageablesInRadius(
			playerPosition,
			stats.BurstRadius,
			definition.Config.MaximumBurstTargets
		) do
			CombatTargets.DamageTarget(target, burstDamage, playerPosition, 0, {
				player = player,
				source = "Thorns",
				canApplyHitPassives = false,
			})
		end
	end

	-- Revenge is one refreshable window, never an accumulating stack, and starts after this hit resolves.
	if stats.RevengeUnlocked then
		runtime.revengeUntil = now + stats.RevengeDuration
	end
	abilityNetwork:fireAll("ThornsTriggered", {
		playerPosition = playerPosition,
		attackerPosition = attackerPosition,
		burstRadius = if stats.BurstUnlocked then stats.BurstRadius else 0,
	})
end

local function stepBurns()
	local now = workspace:GetServerTimeNow()
	if now < nextBurnUpdateAt then
		return
	end
	nextBurnUpdateAt = now + BURN_UPDATE_INTERVAL
	for targetId, burnState in burns do
		local runtime = runtimes[burnState.player]
		if burnState.player.Parent ~= Players
			or not runtime
			or not runtime.burnLevel
			or now >= burnState.expiresAt
		then
			removeBurn(targetId)
		elseif now >= burnState.nextTickAt then
			local position = ZombieController.GetZombiePosition(targetId)
			if not position then
				removeBurn(targetId)
			else
				local definition = AbilityDefinitions.ById.Burn
				local currentStats = definition.GetStats(runtime.burnLevel)
				burnState.damage = math.max(burnState.damage, currentStats.TickDamage)
				burnState.nextTickAt = now + definition.Config.TickInterval
				ZombieController.DamageZombie(targetId, burnState.damage, position, 0, {
					player = burnState.player,
					source = "Burn",
					canApplyHitPassives = false,
				})
			end
		end
	end
end

function PassiveEffects.Init(network, getDataCallback)
	abilityNetwork = network
	getAbilityData = getDataCallback
	ZombieController.GetZombieDamagedSignal():Connect(onZombieDamaged)
	ZombieController.GetPlayerDamagedByZombieSignal():Connect(onPlayerDamagedByZombie)
	RunService.Heartbeat:Connect(stepBurns)
end

function PassiveEffects.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime or not getAbilityData then
		return
	end

	local heartWasEquipped = runtime.heartLevel ~= nil
	local burnWasEquipped = runtime.burnLevel ~= nil
	disconnectCharacter(runtime)
	local data = getAbilityData(player)
	runtime.heartLevel = getEquippedLevel(data, "Heart")
	runtime.bootsLevel = getEquippedLevel(data, "Boots")
	runtime.blastLevel = getEquippedLevel(data, "Blast")
	runtime.burnLevel = getEquippedLevel(data, "Burn")
	runtime.thornsLevel = getEquippedLevel(data, "Thorns")
	runtime.sprintActive = false
	runtime.quickStartActive = false
	if runtime.heartLevel and not heartWasEquipped then
		-- Newly equipping Recovery starts its damage-free delay instead of granting immediate regeneration.
		runtime.lastDamageAt = workspace:GetServerTimeNow()
	end
	if burnWasEquipped and not runtime.burnLevel then
		-- Unequipping Burn immediately removes every owned status and its replicated visual.
		clearBurnsForPlayer(player)
	elseif runtime.burnLevel then
		local burnStats = AbilityDefinitions.ById.Burn.GetStats(runtime.burnLevel)
		for _, burnState in burns do
			if burnState.player == player then
				burnState.damage = math.max(burnState.damage, burnStats.TickDamage)
			end
		end
	end
	if not runtime.thornsLevel then
		runtime.revengeUntil = -math.huge
	end

	if runtime.heartLevel then
		local stats = AbilityDefinitions.ById.Heart.GetStats(runtime.heartLevel)
		PlayerStatController.SetModifier(player, HEART_MODIFIER_ID, {
			MaxHealthMultiplier = stats.MaxHealthPercent / 100,
		})
	else
		PlayerStatController.SetModifier(player, HEART_MODIFIER_ID, nil)
	end
	applyBootsModifier(player, runtime)

	local token = runtime.refreshToken
	bindHeart(player, runtime, token)
	bindBoots(player, runtime, token)
end

function PassiveEffects.OnPlayerAdded(player: Player)
	runtimes[player] = {
		character = nil,
		humanoid = nil,
		root = nil,
		connections = {},
		refreshToken = 0,
		heartLevel = nil,
		bootsLevel = nil,
		blastLevel = nil,
		burnLevel = nil,
		thornsLevel = nil,
		revengeUntil = -math.huge,
		lastDamageAt = -math.huge,
		lastHealth = 0,
		secondWindUsed = false,
		moving = false,
		movementRevision = 0,
		stationarySince = workspace:GetServerTimeNow(),
		sprintActive = false,
		quickStartActive = false,
		quickStartReadyAt = -math.huge,
		sprintTrail = nil,
	}
	PassiveEffects.Refresh(player)
end

function PassiveEffects.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	runtime.character = character
	runtime.humanoid = character:FindFirstChildOfClass("Humanoid")
	runtime.lastDamageAt = workspace:GetServerTimeNow()
	runtime.lastHealth = 0
	runtime.revengeUntil = -math.huge
	local root = character:FindFirstChild("HumanoidRootPart")
	runtime.root = if root and root:IsA("BasePart") then root else nil
	PassiveEffects.Refresh(player)
end

function PassiveEffects.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		disconnectCharacter(runtime)
	end
	clearBurnsForPlayer(player)
	runtimes[player] = nil
end

return PassiveEffects
