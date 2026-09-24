local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)
local CoinsController = require(ServerStorage.Controllers.CoinsController)
local RageController = require(ServerStorage.Controllers.RageController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)
local ActiveWeapons = require(script.Parent.Ability.ActiveWeapons)
local OrbitingSwords = require(script.Parent.Ability.OrbitingSwords)
local PassiveEffects = require(script.Parent.Ability.PassiveEffects)

local REQUEST_COOLDOWN = 0.12
local VOLLEY_NETWORK_LEAD = 0.06
local VOLLEY_STAGGER = 0.075

type PlayerRuntime = {
	attackToken: number,
	lastRequestAt: number,
	nextDaggerAt: number,
}

local AbilityController = {}

local dataService
local abilityNetwork
local discoveryAcknowledgedCallback
local runtimes: { [Player]: PlayerRuntime } = {}

local function makeEmptyData()
	return {
		Owned = {},
		Levels = {},
		Equipped = {
			Weapon = {},
			Passive = {},
		},
	}
end

local function normalizeData(rawData)
	local normalized = makeEmptyData()
	if type(rawData) ~= "table" then
		return normalized
	end

	local rawOwned = if type(rawData.Owned) == "table" then rawData.Owned else {}
	local rawLevels = if type(rawData.Levels) == "table" then rawData.Levels else {}
	for abilityId, owned in rawOwned do
		local definition = type(abilityId) == "string" and AbilityDefinitions.ById[abilityId]
		if definition and owned == true then
			normalized.Owned[abilityId] = true
			local level = rawLevels[abilityId]
			normalized.Levels[abilityId] = if type(level) == "number" and level % 1 == 0
				then math.clamp(level, 1, definition.MaxLevel)
				else 1
		end
	end

	local rawEquipped = if type(rawData.Equipped) == "table" then rawData.Equipped else {}
	for _, category in AbilityDefinitions.Categories do
		local equipped = normalized.Equipped[category]
		local seen = {}
		local rawCategory = rawEquipped[category]
		if type(rawCategory) == "table" then
			for _, abilityId in rawCategory do
				local definition = type(abilityId) == "string" and AbilityDefinitions.ById[abilityId]
				if definition
					and definition.Category == category
					and normalized.Owned[abilityId]
					and not seen[abilityId]
					and #equipped < AbilityDefinitions.EquipLimits[category]
				then
					seen[abilityId] = true
					table.insert(equipped, abilityId)
				end
			end
		end
	end

	return normalized
end

local function deepEqual(left, right): boolean
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function getData(player: Player)
	return normalizeData(dataService:get(player, AbilityDefinitions.DataKey))
end

local function isEquipped(data, abilityId: string): boolean
	local definition = AbilityDefinitions.ById[abilityId]
	if not definition then
		return false
	end
	return table.find(data.Equipped[definition.Category], abilityId) ~= nil
end

local function canRequest(player: Player): boolean
	local runtime = runtimes[player]
	if not runtime then
		return false
	end

	local now = workspace:GetServerTimeNow()
	if now - runtime.lastRequestAt < REQUEST_COOLDOWN then
		return false
	end
	runtime.lastRequestAt = now
	return true
end

local function sendResult(player: Player, success: boolean, message: string, milestone: boolean?)
	abilityNetwork:fire(player, "ActionResult", success, message, milestone == true)
end

local function damageZombie(player: Player, definition, targetId: number, damage: number, hitOrigin: Vector3, isRage: boolean)
	local knockback = definition.Combat.Knockback
		* (if isRage then definition.Rage.KnockbackMultiplier or 1 else 1)
	ZombieController.DamageZombie(targetId, damage, hitOrigin, knockback, {
		player = player,
		source = definition.Id,
		canApplyHitPassives = true,
	})
end

local function fireDaggerVolley(player: Player, definition, level: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end

	local rageActive = RageController.IsActive(player)
	local stats = if rageActive and definition.GetRageStats
		then definition.GetRageStats(level)
		else definition.GetStats(level)
	local range = stats.Range or definition.Combat.Range
	local projectileSpeed = stats.ProjectileSpeed or definition.Combat.ProjectileSpeed
	local volleyStagger = stats.VolleyStagger or VOLLEY_STAGGER
	local origin = root.Position + Vector3.new(0, 1.7, 0)
	local targets = ZombieController.GetNearestZombies(origin, range, stats.DaggerCount)
	if #targets == 0 then
		return false
	end

	for daggerIndex = 1, stats.DaggerCount do
		local target = targets[(daggerIndex - 1) % #targets + 1]
		local spacing = (daggerIndex - (stats.DaggerCount + 1) / 2) * 0.72
		local startPosition = origin + root.CFrame.RightVector * spacing
		local distance = (target.position - startPosition).Magnitude
		local duration = math.clamp(
			distance / projectileSpeed,
			definition.Combat.MinimumTravelDuration,
			definition.Combat.MaximumTravelDuration
		)
		-- A tiny shared lead lets every client begin the cosmetic projectile at the same smooth timestamp.
		local launchDelay = VOLLEY_NETWORK_LEAD + (daggerIndex - 1) * volleyStagger
		local launchAt = workspace:GetServerTimeNow() + launchDelay

		abilityNetwork:fireAll("DaggerThrown", {
			ownerUserId = player.UserId,
			startPosition = startPosition,
			targetPosition = target.position,
			launchAt = launchAt,
			duration = duration,
			scale = stats.ProjectileScale,
			daggerIndex = daggerIndex,
			daggerCount = stats.DaggerCount,
			rage = stats.IsRage == true,
		})

		task.delay(launchDelay + duration, function()
			if player.Parent == Players then
				damageZombie(player, definition, target.id, stats.Damage, startPosition, stats.IsRage == true)
			end
		end)
	end

	return true
end

local function refreshAttacks(player: Player)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	runtime.attackToken += 1
	local token = runtime.attackToken
	local data = getData(player)
	if not isEquipped(data, "Dagger") then
		return
	end

	task.spawn(function()
		while player.Parent == Players and runtimes[player] == runtime and runtime.attackToken == token do
			local waitDuration = math.max(runtime.nextDaggerAt - workspace:GetServerTimeNow(), 0)
			if waitDuration > 0 then
				task.wait(waitDuration)
			end
			if player.Parent ~= Players or runtimes[player] ~= runtime or runtime.attackToken ~= token then
				return
			end

			local currentData = getData(player)
			if not isEquipped(currentData, "Dagger") then
				return
			end

			local definition = AbilityDefinitions.ById.Dagger
			local level = currentData.Levels.Dagger or 1
			local rageActive = RageController.IsActive(player)
			local rageStats = if rageActive and definition.GetRageStats then definition.GetRageStats(level) else nil
			local cooldown = rageStats and rageStats.Cooldown or definition.Combat.Cooldown
			local attacked = fireDaggerVolley(player, definition, level)
			local retryDelay = if attacked then cooldown else math.min(cooldown, 0.35)
			-- This timestamp survives equip toggles so clients cannot reset the authoritative attack cooldown.
			runtime.nextDaggerAt = workspace:GetServerTimeNow() + retryDelay
		end
	end)
end

function AbilityController.TryDiscover(player: Player, abilityId: string, autoRollWasActive: boolean?): boolean
	local definition = AbilityDefinitions.ById[abilityId]
	local runtime = runtimes[player]
	if not definition or not runtime then
		return false
	end

	local data = getData(player)
	-- Ability rolls are unique forever; ownership is persisted before any presentation event is sent.
	if data.Owned[abilityId] then
		return false
	end
	data.Owned[abilityId] = true
	data.Levels[abilityId] = 1
	dataService:set(player, AbilityDefinitions.DataKey, data)

	local revealAt = workspace:GetServerTimeNow() + RollDefinitions.Timing.ReelDuration
	abilityNetwork:fire(player, "AbilityDiscovered", abilityId, revealAt, autoRollWasActive == true)
	return true
end

function AbilityController.IsOwned(player: Player, abilityId: string): boolean
	return runtimes[player] ~= nil and getData(player).Owned[abilityId] == true
end

function AbilityController.SetDiscoveryAcknowledgedCallback(callback)
	discoveryAcknowledgedCallback = callback
end

function AbilityController.EquipAbility(_, player: Player, abilityId: any)
	if not canRequest(player) or type(abilityId) ~= "string" then
		return
	end
	local definition = AbilityDefinitions.ById[abilityId]
	local data = getData(player)
	if not definition or not data.Owned[abilityId] then
		sendResult(player, false, "Discover this ability before equipping it.")
		return
	end

	local equipped = data.Equipped[definition.Category]
	if table.find(equipped, abilityId) then
		return
	end
	if #equipped >= AbilityDefinitions.EquipLimits[definition.Category] then
		sendResult(player, false, string.format("All %d %s slots are full.", #equipped, definition.Category:lower()))
		return
	end

	table.insert(equipped, abilityId)
	dataService:set(player, AbilityDefinitions.DataKey, data)
	refreshAttacks(player)
	ActiveWeapons.Refresh(player)
	OrbitingSwords.Refresh(player)
	if definition.Category == AbilityDefinitions.Categories.Passive then
		PassiveEffects.Refresh(player)
	end
	sendResult(player, true, definition.Name .. " equipped!")
end

function AbilityController.UnequipAbility(_, player: Player, abilityId: any)
	if not canRequest(player) or type(abilityId) ~= "string" then
		return
	end
	local definition = AbilityDefinitions.ById[abilityId]
	if not definition then
		return
	end

	local data = getData(player)
	local equipped = data.Equipped[definition.Category]
	local index = table.find(equipped, abilityId)
	if not index then
		return
	end
	table.remove(equipped, index)
	dataService:set(player, AbilityDefinitions.DataKey, data)
	refreshAttacks(player)
	ActiveWeapons.Refresh(player)
	OrbitingSwords.Refresh(player)
	if definition.Category == AbilityDefinitions.Categories.Passive then
		PassiveEffects.Refresh(player)
	end
	sendResult(player, true, definition.Name .. " unequipped.")
end

function AbilityController.UpgradeAbility(_, player: Player, abilityId: any)
	if not canRequest(player) or type(abilityId) ~= "string" then
		return
	end
	local definition = AbilityDefinitions.ById[abilityId]
	local data = getData(player)
	if not definition or not data.Owned[abilityId] then
		sendResult(player, false, "Discover this ability before upgrading it.")
		return
	end

	local currentLevel = data.Levels[abilityId] or 1
	local cost = AbilityDefinitions.GetUpgradeCost(definition, currentLevel)
	if not cost then
		sendResult(player, false, definition.Name .. " is already max level.")
		return
	end

	local spent = CoinsController.Remove(player, cost)
	if not spent then
		sendResult(player, false, string.format("You need %d Coins to upgrade.", cost))
		return
	end

	local newLevel = currentLevel + 1
	data.Levels[abilityId] = newLevel
	dataService:set(player, AbilityDefinitions.DataKey, data)
	if abilityId == "OrbitingSwords" then
		OrbitingSwords.ForceSync(player)
	end
	if definition.Category == AbilityDefinitions.Categories.Passive then
		PassiveEffects.Refresh(player)
	end
	-- Active attack loops read the new level before their next volley; upgrades must not reset attack cooldowns.
	local reachedMilestone = false
	for _, milestone in definition.Milestones do
		if milestone.Level == newLevel then
			reachedMilestone = true
			break
		end
	end
	sendResult(player, true, string.format("%s reached Level %d!", definition.Name, newLevel), reachedMilestone)
end

function AbilityController.AcknowledgeDiscovery(_, player: Player, abilityId: any)
	if type(abilityId) == "string" and AbilityDefinitions.ById[abilityId] and discoveryAcknowledgedCallback then
		discoveryAcknowledgedCallback(player, abilityId)
	end
end

function AbilityController.SetDataService(service)
	dataService = service
end

function AbilityController.Init()
	-- The archived simulator inventory/upgrade UI no longer exposes persistent loadout mutations.
	-- Keep the implementation for a future progression flow, but do not accept these requests until that flow owns them.
	abilityNetwork = Networker.server.new("AbilityController", AbilityController, {})
	ActiveWeapons.Init(abilityNetwork, getData)
	OrbitingSwords.Init(abilityNetwork, getData)
	PassiveEffects.Init(abilityNetwork, getData)
	RageController.GetActivatedSignal():Connect(function(player: Player)
		local runtime = runtimes[player]
		if runtime then
			-- Activation immediately starts the ability's Rage cadence instead of waiting out its normal cooldown.
			runtime.nextDaggerAt = workspace:GetServerTimeNow() + 0.06
			refreshAttacks(player)
			ActiveWeapons.ForceImmediate(player)
			OrbitingSwords.ForceSync(player)
		end
	end)
end

function AbilityController.OnPlayerAdded(player: Player)
	runtimes[player] = {
		attackToken = 0,
		lastRequestAt = -math.huge,
		nextDaggerAt = workspace:GetServerTimeNow() + 0.2,
	}

	local rawData = dataService:get(player, AbilityDefinitions.DataKey)
	local normalized = normalizeData(rawData)
	if not deepEqual(rawData, normalized) then
		dataService:set(player, AbilityDefinitions.DataKey, normalized)
	end
	ActiveWeapons.OnPlayerAdded(player)
	OrbitingSwords.OnPlayerAdded(player)
	PassiveEffects.OnPlayerAdded(player)
	refreshAttacks(player)
end

function AbilityController.OnCharacterAdded(player: Player, character: Model)
	refreshAttacks(player)
	ActiveWeapons.Restart(player)
	OrbitingSwords.Restart(player)
	PassiveEffects.OnCharacterAdded(player, character)
end

function AbilityController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		runtime.attackToken += 1
	end
	ActiveWeapons.OnPlayerRemoving(player)
	OrbitingSwords.OnPlayerRemoving(player)
	PassiveEffects.OnPlayerRemoving(player)
	runtimes[player] = nil
end

return AbilityController
