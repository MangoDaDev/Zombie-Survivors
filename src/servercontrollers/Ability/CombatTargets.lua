local ServerStorage = game:GetService("ServerStorage")

local BreakableController = require(ServerStorage.Controllers.BreakableController)
local ClassController = require(ServerStorage.Controllers.ClassController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local CombatTargets = {}
local hitModifier
local hitResolved

function CombatTargets.SetHitCallbacks(modifier, resolved)
	-- Passive hooks are installed during AbilityController initialization without making targeting
	-- depend on PassiveEffects at require time (PassiveEffects itself uses CombatTargets).
	hitModifier = modifier
	hitResolved = resolved
end

local function addIdentity(candidate, kind: string)
	candidate.kind = kind
	-- Zombies use positive keys and breakables use negative keys so per-attack hit sets never collide.
	candidate.key = if kind == "Zombie" then candidate.id else -candidate.id
	return candidate
end

local function trimNearest(candidates, position: Vector3, maximumCount: number?)
	for _, candidate in candidates do
		local offset = candidate.position - position
		candidate.distance = Vector2.new(offset.X, offset.Z).Magnitude
	end
	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)
	local countLimit = maximumCount or math.huge
	for index = #candidates, countLimit + 1, -1 do
		table.remove(candidates, index)
	end
	return candidates
end

-- Automatic target selection is zombie-only. Breakables enter combat solely through this
-- collision/AOE query so attacks can damage props without ever aiming themselves at one.
function CombatTargets.GetDamageablesInRadius(position: Vector3, maximumDistance: number, maximumCount: number?)
	local candidates = {}
	for _, candidate in ZombieController.GetZombiesInRadius(position, maximumDistance, maximumCount) do
		table.insert(candidates, addIdentity(candidate, "Zombie"))
	end
	for _, candidate in BreakableController.GetBreakablesInRadius(position, maximumDistance, maximumCount) do
		table.insert(candidates, addIdentity(candidate, "Breakable"))
	end
	return trimNearest(candidates, position, maximumCount)
end

function CombatTargets.GetHostilesInRadius(position: Vector3, maximumDistance: number, maximumCount: number?)
	local candidates = {}
	for _, candidate in ZombieController.GetZombiesInRadius(position, maximumDistance, maximumCount) do
		table.insert(candidates, addIdentity(candidate, "Zombie"))
	end
	return trimNearest(candidates, position, maximumCount)
end

function CombatTargets.GetNearestHostiles(position: Vector3, maximumDistance: number, maximumCount: number)
	local candidates = {}
	for _, candidate in ZombieController.GetNearestZombies(position, maximumDistance, maximumCount) do
		table.insert(candidates, addIdentity(candidate, "Zombie"))
	end
	return trimNearest(candidates, position, maximumCount)
end

function CombatTargets.DamageTarget(target, amount: number, hitOrigin: Vector3?, knockbackImpulse: number?, damageContext)
	if type(target) ~= "table" or type(target.id) ~= "number" then
		return false, false
	end
	local critical = false
	if hitModifier and type(damageContext) == "table" and damageContext.canApplyHitPassives == true then
		amount, knockbackImpulse, critical = hitModifier(target, amount, knockbackImpulse or 0, damageContext)
	end
	local damaged, killed
	if target.kind == "Breakable" then
		local owner = type(damageContext) == "table" and damageContext.player
		if typeof(owner) == "Instance" and owner:IsA("Player") then
			amount *= ClassController.GetWeaponDamageMultiplier(owner)
		end
		damaged, killed = BreakableController.DamageBreakable(target.id, amount, hitOrigin, knockbackImpulse,
			type(damageContext) == "table" and damageContext.player or nil)
	elseif target.kind == "Zombie" then
		damaged, killed = ZombieController.DamageZombie(target.id, amount, hitOrigin, knockbackImpulse, damageContext)
	else
		return false, false
	end
	if damaged and hitResolved then
		hitResolved(target, critical, damageContext)
	end
	return damaged, killed
end

return CombatTargets
