local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
local ClassAccessoryFit = require(ReplicatedStorage.Modules.Game.Classes.ClassAccessoryFit)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local CoinsController = require(script.Parent.CoinsController)
local PlayerStatController = require(script.Parent.PlayerStatController)
local ServerContext = require(script.Parent.ServerContext)

local REQUEST_COOLDOWN = 0.2
local MOVEMENT_THRESHOLD = 0.5
local STAT_MODIFIER_ID = "Class"
local RAGE_SPEED_MODIFIER_ID = "ClassRageKills"
local ACCESSORY_NAME = "ClassAccessory"

local ClassController = {}

local dataService
local classNetwork
local runtimes = {}

local function normalizeData(rawData)
	local owned = { [ClassDefinitions.DefaultId] = true }
	if type(rawData) == "table" and type(rawData.Owned) == "table" then
		for classId, isOwned in rawData.Owned do
			if type(classId) == "string" and ClassDefinitions.ById[classId] and isOwned == true then
				owned[classId] = true
			end
		end
	end
	local equipped = type(rawData) == "table" and rawData.Equipped or nil
	if type(equipped) ~= "string" or not owned[equipped] then
		equipped = ClassDefinitions.DefaultId
	end
	return { Owned = owned, Equipped = equipped }
end

local function getData(player: Player)
	return normalizeData(dataService:get(player, ClassDefinitions.DataKey))
end

local function getDefinition(player: Player)
	local runtime = runtimes[player]
	return ClassDefinitions.ById[runtime and runtime.classId or ClassDefinitions.DefaultId]
end

local function getBonuses(player: Player)
	return getDefinition(player).Bonuses
end

local function meetsPrerequisite(player: Player, definition): boolean
	local requiredAbilityId = definition.RequiredAbilityId
	if not requiredAbilityId then return true end
	local abilities = dataService:get(player, AbilityDefinitions.DataKey)
	return type(abilities) == "table" and type(abilities.Owned) == "table"
		and abilities.Owned[requiredAbilityId] == true
end

local function clearRageKillSpeed(player: Player, runtime)
	runtime.rageSpeedRevision += 1
	runtime.rageSpeedStacks = 0
	PlayerStatController.SetModifier(player, RAGE_SPEED_MODIFIER_ID, nil)
end

local function clearCharacter(player: Player, runtime)
	if runtime.movementConnection then
		runtime.movementConnection:Disconnect()
		runtime.movementConnection = nil
	end
	if runtime.headSizeConnection then
		runtime.headSizeConnection:Disconnect()
		runtime.headSizeConnection = nil
	end
	runtime.movementRevision += 1
	runtime.moving = false
	runtime.movingRangeBonus = false
	runtime.swordHitCount = 0
	runtime.shieldEndsAt = 0
	clearRageKillSpeed(player, runtime)
	if runtime.accessory then
		runtime.accessory:Destroy()
		runtime.accessory = nil
	end
end

local function applyStats(player: Player)
	local definition = getDefinition(player)
	PlayerStatController.SetModifier(player, STAT_MODIFIER_ID, {
		MaxHealthMultiplier = definition.Bonuses.MaxHealth or 0,
		WalkSpeedMultiplier = definition.Bonuses.WalkSpeed or 0,
	})
end

local function applyAccessory(player: Player, runtime, character: Model, head: BasePart)
	if player.Character ~= character or runtimes[player] ~= runtime then
		return
	end
	if runtime.accessory then
		runtime.accessory:Destroy()
		runtime.accessory = nil
	end
	local assets = ReplicatedStorage.Assets.Models:FindFirstChild("Classes")
	local template = assets and assets:FindFirstChild(runtime.classId)
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Missing authored class accessory: " .. runtime.classId)
		return
	end
	local accessory = template:Clone()
	accessory.Name = ACCESSORY_NAME
	-- The fit is shared with the 3D menu preview so both R6 and scaled MeshPart heads wear the same model.
	ClassAccessoryFit.FitToHead(accessory, head)
	for _, descendant in accessory:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Name = "HeadWeld"
	headWeld.Part0 = head
	headWeld.Part1 = accessory.PrimaryPart
	headWeld.Parent = accessory.PrimaryPart
	accessory.Parent = character
	runtime.accessory = accessory
end

local function bindMovement(player: Player, runtime, humanoid: Humanoid)
	local function updateMovement(speed)
		local moving = speed > MOVEMENT_THRESHOLD and humanoid.Health > 0
		if moving == runtime.moving then
			return
		end
		runtime.moving = moving
		runtime.movingRangeBonus = false
		runtime.movementRevision += 1
		local revision = runtime.movementRevision
		local definition = getDefinition(player)
		local delaySeconds = definition.Bonuses.MovementSeconds
		if moving and delaySeconds then
			-- Scout's range bonus needs uninterrupted movement; a stop, respawn, or class change invalidates this timer.
			task.delay(delaySeconds, function()
				if runtimes[player] == runtime
					and runtime.movementRevision == revision
					and runtime.moving
					and humanoid.Health > 0
					and getDefinition(player) == definition
				then
					runtime.movingRangeBonus = true
				end
			end)
		end
	end
	runtime.movementConnection = humanoid.Running:Connect(updateMovement)
	-- Equipping Scout while already walking should start the same uninterrupted-movement timer.
	updateMovement(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
end

local function sendResult(player: Player, success: boolean, message: string)
	classNetwork:fire(player, "ActionResult", success, message)
end

local function canRequest(player: Player): boolean
	local runtime = runtimes[player]
	if not runtime or player.Parent ~= Players then
		return false
	end
	local now = os.clock()
	if now - runtime.lastRequestAt < REQUEST_COOLDOWN then
		return false
	end
	runtime.lastRequestAt = now
	return true
end

function ClassController.GetStartingAbilityId(player: Player): string
	return getDefinition(player).AbilityId
end

function ClassController.GetPickupMagnetMultiplier(player: Player): number
	return 1 + (getBonuses(player).PickupMagnet or 0)
end

function ClassController.GetCoinPickupMagnetMultiplier(player: Player): number
	local bonuses = getBonuses(player)
	-- Scavenger's radius is coin-only; Survivor's general magnet still covers coins and XP.
	return 1 + (bonuses.PickupMagnet or 0) + (bonuses.CoinPickupRadius or 0)
end

function ClassController.GetCoinRewardMultiplier(player: Player): number
	return 1 + (getBonuses(player).CoinReward or 0)
end

function ClassController.GetPowerupLifetimeBonus(player: Player): number
	return getBonuses(player).PowerupLifetime or 0
end

function ClassController.GetWeaponDamageMultiplier(player: Player): number
	return 1 + (getBonuses(player).WeaponDamage or 0)
end

function ClassController.GetDamageOverTimeDamageMultiplier(player: Player): number
	return 1 + (getBonuses(player).DamageOverTimeDamage or 0)
end

function ClassController.GetKnockbackMultiplier(player: Player): number
	return 1 + (getBonuses(player).Knockback or 0)
end

function ClassController.GetCooldownMultiplier(player: Player): number
	return 1 - (getBonuses(player).CooldownReduction or 0)
end

function ClassController.GetHealingReceivedMultiplier(player: Player): number
	return 1 + (getBonuses(player).HealingReceived or 0)
end

function ClassController.GetRageDurationBonus(player: Player): number
	return getBonuses(player).RageDuration or 0
end

function ClassController.GetBombRadiusMultiplier(player: Player): number
	return ClassController.GetExplosionRadiusMultiplier(player) * (1 + (getBonuses(player).BombRadius or 0))
end

function ClassController.GetNearbyDefenseConfig(player: Player): (number?, number?)
	local bonuses = getBonuses(player)
	return bonuses.NearbyRadius, bonuses.NearbyZombieCount
end

function ClassController.GetIncomingDamageMultiplier(player: Player, nearbyZombieCount: number): number
	local bonuses = getBonuses(player)
	local multiplier = 1
	if bonuses.NearbyDamageReduction and nearbyZombieCount >= bonuses.NearbyZombieCount then
		multiplier *= 1 - bonuses.NearbyDamageReduction
	end
	local runtime = runtimes[player]
	if runtime and workspace:GetServerTimeNow() < runtime.shieldEndsAt then
		multiplier *= 1 - (bonuses.SwordShieldDamageReduction or 0)
	end
	return multiplier
end

function ClassController.GetAfflictionSlow(player: Player): (number?, number?)
	local bonuses = getBonuses(player)
	if not bonuses.AfflictedSlow then return nil, nil end
	return 1 - bonuses.AfflictedSlow, bonuses.AfflictedSlowDuration
end

function ClassController.RegisterSwordHit(player: Player)
	local runtime = runtimes[player]
	local bonuses = getBonuses(player)
	if not runtime or not bonuses.SwordShieldEveryHits then return end
	runtime.swordHitCount += 1
	if runtime.swordHitCount % bonuses.SwordShieldEveryHits == 0 then
		runtime.shieldEndsAt = workspace:GetServerTimeNow() + bonuses.SwordShieldDuration
	end
end

function ClassController.RegisterRageKill(player: Player, rageActive: boolean)
	local runtime = runtimes[player]
	local bonuses = getBonuses(player)
	if not runtime or not rageActive or not bonuses.RageKillWalkSpeed then return end
	runtime.rageSpeedStacks = math.min(runtime.rageSpeedStacks + 1, bonuses.RageKillMaxStacks)
	runtime.rageSpeedRevision += 1
	local revision = runtime.rageSpeedRevision
	PlayerStatController.SetModifier(player, RAGE_SPEED_MODIFIER_ID, {
		WalkSpeedMultiplier = runtime.rageSpeedStacks * bonuses.RageKillWalkSpeed,
	})
	-- Successive kills refresh the brief stack window; Rage end clears it immediately.
	task.delay(bonuses.RageKillDuration, function()
		if runtimes[player] == runtime and runtime.rageSpeedRevision == revision then
			clearRageKillSpeed(player, runtime)
		end
	end)
end

function ClassController.ClearRageKillSpeed(player: Player)
	local runtime = runtimes[player]
	if runtime then clearRageKillSpeed(player, runtime) end
end

function ClassController.GetProjectileRangeMultiplier(player: Player): number
	local runtime = runtimes[player]
	return 1 + (if runtime and runtime.movingRangeBonus then getDefinition(player).Bonuses.MovingProjectileRange or 0 else 0)
end

function ClassController.GetStraightRangeMultiplier(player: Player): number
	return 1 + (getBonuses(player).StraightRange or 0)
end

function ClassController.GetExplosionRadiusMultiplier(player: Player): number
	return 1 + (getDefinition(player).Bonuses.ExplosionRadius or 0)
end

function ClassController.GetDamageOverTimeDurationMultiplier(player: Player): number
	return 1 + (getDefinition(player).Bonuses.DamageOverTimeDuration or 0)
end

function ClassController.ApplyWeaponStats(player: Player, abilityId: string, stats)
	-- GetStats returns a fresh cast snapshot; change that snapshot only, never the shared ability definition.
	local bonuses = getBonuses(player)
	if abilityId == "Boomerang" or abilityId == "Drill" then
		stats.Range *= ClassController.GetProjectileRangeMultiplier(player)
	elseif abilityId == "Fireball" then
		stats.ExplosionRadius *= ClassController.GetExplosionRadiusMultiplier(player)
		local durationMultiplier = ClassController.GetDamageOverTimeDurationMultiplier(player)
		stats.BurnDuration *= durationMultiplier
		stats.GroundDuration *= durationMultiplier
	elseif abilityId == "Mine" then
		stats.Radius *= ClassController.GetExplosionRadiusMultiplier(player)
	elseif abilityId == "Poison" then
		stats.Duration *= ClassController.GetDamageOverTimeDurationMultiplier(player)
	elseif abilityId == "Shotgun" then
		stats.Range *= ClassController.GetProjectileRangeMultiplier(player)
	elseif abilityId == "Meteor" then
		stats.Radius *= ClassController.GetExplosionRadiusMultiplier(player)
	elseif abilityId == "Vortex" then
		stats.Duration *= ClassController.GetDamageOverTimeDurationMultiplier(player)
	end
	if abilityId == "Lightning" and bonuses.LightningTargets then
		stats.MaximumTargets += bonuses.LightningTargets
	elseif abilityId == "Ball" and bonuses.BallBounces then
		stats.BounceCount += bonuses.BallBounces
		stats.ClassUniqueRicochetDamage = bonuses.UniqueRicochetDamage
		stats.ClassUniqueRicochetCap = bonuses.UniqueRicochetCap
	elseif abilityId == "OrbitingSwords" and bonuses.OrbitSpeed then
		stats.RotationSpeed *= 1 + bonuses.OrbitSpeed
		stats.OrbitRadius *= 1 + bonuses.OrbitRadius
	end
	if bonuses.StraightWidth then
		if abilityId == "Drill" then
			stats.Width *= 1 + bonuses.StraightWidth
			stats.Range *= 1 + bonuses.StraightRange
		elseif abilityId == "Shotgun" then
			stats.PelletRadius *= 1 + bonuses.StraightWidth
			stats.Range *= 1 + bonuses.StraightRange
		elseif abilityId == "Fireball" then
			stats.ProjectileScale *= 1 + bonuses.StraightWidth
		end
	end
	if bonuses.DeployableDuration then
		if abilityId == "Mine" then
			stats.MaximumActive += bonuses.AdditionalDeployables
			stats.Lifetime = AbilityDefinitions.ById.Mine.Combat.Lifetime * (1 + bonuses.DeployableDuration)
		elseif abilityId == "Poison" or abilityId == "Turret" then
			stats.MaximumActive += bonuses.AdditionalDeployables
			stats.Duration *= 1 + bonuses.DeployableDuration
		elseif abilityId == "Vortex" then
			stats.MaximumActive = AbilityDefinitions.ById.Vortex.Combat.MaximumActive + bonuses.AdditionalDeployables
			stats.Duration *= 1 + bonuses.DeployableDuration
		end
	end
	if bonuses.DamageOverTimeDamage then
		if abilityId == "Fireball" then
			stats.BurnDamage *= 1 + bonuses.DamageOverTimeDamage
			stats.GroundDamage *= 1 + bonuses.DamageOverTimeDamage
		elseif abilityId == "Poison" or abilityId == "Aura" or abilityId == "Vortex" then
			stats.Damage *= 1 + bonuses.DamageOverTimeDamage
		end
	end
	return stats
end

function ClassController.UnlockClass(_, player: Player, classId: any)
	if not canRequest(player) or type(classId) ~= "string" or not ServerContext.IsLobbyServer() then
		return
	end
	local definition = ClassDefinitions.ById[classId]
	if not definition then
		return
	end
	if not meetsPrerequisite(player, definition) then
		sendResult(player, false, "Unlock " .. AbilityDefinitions.ById[definition.RequiredAbilityId].Name .. " first.")
		return
	end
	local data = getData(player)
	if data.Owned[classId] then
		sendResult(player, false, definition.Name .. " is already unlocked.")
		return
	end
	if definition.UnlockCost <= 0 or not CoinsController.Remove(player, definition.UnlockCost) then
		sendResult(player, false, "Not enough Coins to unlock " .. definition.Name .. ".")
		return
	end
	-- The server chooses the fixed price and persists ownership only after the authoritative debit succeeds.
	data.Owned[classId] = true
	dataService:set(player, ClassDefinitions.DataKey, data)
	sendResult(player, true, definition.Name .. " unlocked!")
end

function ClassController.EquipClass(_, player: Player, classId: any)
	if not canRequest(player) or type(classId) ~= "string" or not ServerContext.IsLobbyServer() then
		return
	end
	local definition = ClassDefinitions.ById[classId]
	local data = getData(player)
	if not definition or not data.Owned[classId] or not meetsPrerequisite(player, definition) then
		return
	end
	if data.Equipped == classId then
		return
	end
	data.Equipped = classId
	dataService:set(player, ClassDefinitions.DataKey, data)
	local runtime = runtimes[player]
	runtime.classId = classId
	runtime.movingRangeBonus = false
	runtime.movementRevision += 1
	runtime.moving = false
	runtime.swordHitCount = 0
	runtime.shieldEndsAt = 0
	clearRageKillSpeed(player, runtime)
	applyStats(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if runtime.movementConnection then runtime.movementConnection:Disconnect() end
		bindMovement(player, runtime, humanoid)
	end
	if character and head and head:IsA("BasePart") then
		applyAccessory(player, runtime, character, head)
	end
	sendResult(player, true, definition.Name .. " equipped!")
end

function ClassController.SetDataService(service)
	dataService = service
end

function ClassController.Init()
	classNetwork = Networker.server.new("ClassController", ClassController, {
		ClassController.UnlockClass,
		ClassController.EquipClass,
	})
end

function ClassController.OnPlayerAdded(player: Player)
	local rawData = dataService:get(player, ClassDefinitions.DataKey)
	local data = normalizeData(rawData)
	-- A saved prerequisite-gated class cannot stay equipped after its prerequisite is gone.
	if not meetsPrerequisite(player, ClassDefinitions.ById[data.Equipped]) then
		data.Equipped = ClassDefinitions.DefaultId
	end
	if type(rawData) ~= "table" or type(rawData.Owned) ~= "table"
		or rawData.Owned[ClassDefinitions.DefaultId] ~= true
		or rawData.Equipped ~= data.Equipped
	then
		dataService:set(player, ClassDefinitions.DataKey, data)
	end
	runtimes[player] = {
		classId = data.Equipped,
		lastRequestAt = -math.huge,
		movementRevision = 0,
		moving = false,
		movingRangeBonus = false,
		movementConnection = nil,
		headSizeConnection = nil,
		accessory = nil,
		swordHitCount = 0,
		shieldEndsAt = 0,
		rageSpeedStacks = 0,
		rageSpeedRevision = 0,
	}
	applyStats(player)
end

function ClassController.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime then
		return
	end
	clearCharacter(player, runtime)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
	if player.Character ~= character or not humanoid or not humanoid:IsA("Humanoid")
		or not head or not head:IsA("BasePart")
	then
		return
	end
	bindMovement(player, runtime, humanoid)
	applyAccessory(player, runtime, character, head)
	-- Avatar appearance can resize the head after CharacterAdded; refit without polling.
	runtime.headSizeConnection = head:GetPropertyChangedSignal("Size"):Connect(function()
		if player.Character == character and runtimes[player] == runtime then
			applyAccessory(player, runtime, character, head)
		end
	end)
end

function ClassController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then
		clearCharacter(player, runtime)
		runtimes[player] = nil
	end
end

return ClassController
