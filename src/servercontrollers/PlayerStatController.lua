local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatConfig = require(ReplicatedStorage.Modules.Game.Stats.PlayerStatConfig)

type StatModifier = {
	MaxHealthMultiplier: number?,
	WalkSpeedMultiplier: number?,
}

type PlayerRuntime = {
	baseMaxHealth: number,
	baseWalkSpeed: number,
	humanoid: Humanoid?,
	modifiers: { [string]: StatModifier },
}

local PlayerStatController = {}

local runtimes: { [Player]: PlayerRuntime } = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function getTotals(runtime: PlayerRuntime): (number, number)
	local maxHealthMultiplier = 0
	local walkSpeedMultiplier = 0
	for _, modifier in runtime.modifiers do
		maxHealthMultiplier += modifier.MaxHealthMultiplier or 0
		walkSpeedMultiplier += modifier.WalkSpeedMultiplier or 0
	end

	local maxHealth = math.max(1, runtime.baseMaxHealth * math.max(0.01, 1 + maxHealthMultiplier))
	local walkSpeed = math.clamp(
		runtime.baseWalkSpeed * math.max(0, 1 + walkSpeedMultiplier),
		0,
		PlayerStatConfig.MaximumWalkSpeed
	)
	return maxHealth, walkSpeed
end

local function applyStats(runtime: PlayerRuntime)
	local humanoid = runtime.humanoid
	if not humanoid or not humanoid.Parent then
		return
	end

	local maxHealth, walkSpeed = getTotals(runtime)
	local previousMaxHealth = humanoid.MaxHealth
	local previousHealth = humanoid.Health
	humanoid.MaxHealth = maxHealth
	-- Preserve absolute damage while adding newly gained capacity, so equipping or upgrading Heart
	-- never makes the health bar lose percentage merely because its maximum increased.
	if maxHealth > previousMaxHealth and previousHealth > 0 then
		humanoid.Health = math.min(previousHealth + maxHealth - previousMaxHealth, maxHealth)
	elseif previousHealth > maxHealth then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = walkSpeed
end

function PlayerStatController.SetModifier(player: Player, sourceId: string, modifier: StatModifier?)
	local runtime = runtimes[player]
	if not runtime or type(sourceId) ~= "string" or sourceId == "" then
		return
	end

	if modifier == nil then
		runtime.modifiers[sourceId] = nil
	else
		local maxHealthMultiplier = modifier.MaxHealthMultiplier
		local walkSpeedMultiplier = modifier.WalkSpeedMultiplier
		if maxHealthMultiplier ~= nil and not isFiniteNumber(maxHealthMultiplier) then
			return
		end
		if walkSpeedMultiplier ~= nil and not isFiniteNumber(walkSpeedMultiplier) then
			return
		end
		runtime.modifiers[sourceId] = {
			MaxHealthMultiplier = maxHealthMultiplier,
			WalkSpeedMultiplier = walkSpeedMultiplier,
		}
	end
	applyStats(runtime)
end

function PlayerStatController.GetFinalStats(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return nil
	end
	local maxHealth, walkSpeed = getTotals(runtime)
	return {
		MaxHealth = maxHealth,
		WalkSpeed = walkSpeed,
	}
end

function PlayerStatController.OnPlayerAdded(player: Player)
	runtimes[player] = {
		baseMaxHealth = PlayerStatConfig.DefaultBaseMaxHealth,
		baseWalkSpeed = PlayerStatConfig.DefaultBaseWalkSpeed,
		humanoid = nil,
		modifiers = {},
	}
end

function PlayerStatController.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not runtime or not humanoid then
		return
	end
	if not humanoid:IsA("Humanoid") then
		return
	end

	-- Capture the character's authored base once per spawn. Every gameplay system should then contribute
	-- a named modifier instead of competing by writing MaxHealth or WalkSpeed directly.
	runtime.baseMaxHealth = humanoid.MaxHealth
	runtime.baseWalkSpeed = humanoid.WalkSpeed
	runtime.humanoid = humanoid
	applyStats(runtime)
end

function PlayerStatController.OnPlayerRemoving(player: Player)
	runtimes[player] = nil
end

return PlayerStatController
