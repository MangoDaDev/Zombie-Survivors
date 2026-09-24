local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local PlayerStatController = require(ServerStorage.Controllers.PlayerStatController)

local HEART_MODIFIER_ID = "Ability:Heart"
local BOOTS_MODIFIER_ID = "Ability:Boots"

type PlayerRuntime = {
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	connections: { RBXScriptConnection },
	refreshToken: number,
	heartLevel: number?,
	bootsLevel: number?,
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

local getAbilityData
local runtimes: { [Player]: PlayerRuntime } = {}

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

function PassiveEffects.Init(getDataCallback)
	getAbilityData = getDataCallback
end

function PassiveEffects.Refresh(player: Player)
	local runtime = runtimes[player]
	if not runtime or not getAbilityData then
		return
	end

	local heartWasEquipped = runtime.heartLevel ~= nil
	disconnectCharacter(runtime)
	local data = getAbilityData(player)
	runtime.heartLevel = getEquippedLevel(data, "Heart")
	runtime.bootsLevel = getEquippedLevel(data, "Boots")
	runtime.sprintActive = false
	runtime.quickStartActive = false
	if runtime.heartLevel and not heartWasEquipped then
		-- Newly equipping Recovery starts its damage-free delay instead of granting immediate regeneration.
		runtime.lastDamageAt = workspace:GetServerTimeNow()
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
	local root = character:FindFirstChild("HumanoidRootPart")
	runtime.root = if root and root:IsA("BasePart") then root else nil
	PassiveEffects.Refresh(player)
end

function PassiveEffects.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		disconnectCharacter(runtime)
	end
	runtimes[player] = nil
end

return PassiveEffects
