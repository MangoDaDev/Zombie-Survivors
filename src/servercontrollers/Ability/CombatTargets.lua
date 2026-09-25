local ServerStorage = game:GetService("ServerStorage")

local BreakableController = require(ServerStorage.Controllers.BreakableController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local CombatTargets = {}

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
	if target.kind == "Breakable" then
		return BreakableController.DamageBreakable(target.id, amount, hitOrigin, knockbackImpulse)
	end
	if target.kind == "Zombie" then
		return ZombieController.DamageZombie(target.id, amount, hitOrigin, knockbackImpulse, damageContext)
	end
	return false, false
end

return CombatTargets
