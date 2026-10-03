local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local ZombieController = require(script.Parent.Parent.ZombieController)
local GameReadyController = require(script.Parent.Parent.GameReadyController)

local AuraPrediction = {}
local schedule
local lastSequence = 0

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function AuraPrediction.ApplySchedule(packet)
	if type(packet) ~= "table" or not finite(packet.sequence) or packet.sequence % 1 ~= 0 or packet.sequence <= lastSequence
		or type(packet.enabled) ~= "boolean" then
		return
	end
	if packet.enabled and (not finite(packet.nextAt) or not finite(packet.radius) or packet.radius <= 0
		or not finite(packet.damage) or packet.damage <= 0 or not finite(packet.interval) or packet.interval <= 0) then
		return
	end
	lastSequence = packet.sequence
	schedule = if packet.enabled then packet else nil
	if schedule then
		schedule.expiresAt = schedule.nextAt + 1.5
	end
	if not packet.enabled then
		ZombieController.ClearPredictedHits("Aura")
	end
end

function AuraPrediction.Clear()
	schedule = nil
	ZombieController.ClearPredictedHits("Aura")
end

function AuraPrediction.Render(now: number)
	if not schedule or now < schedule.nextAt then
		return
	end
	local packet = schedule
	if now > packet.expiresAt then
		schedule = nil
		return
	end
	-- Continue the known cadence through a delayed push, bounded to the same recovery window.
	-- Never burst missed ticks; a new versioned server schedule corrects the phase and stats.
	local sequence = packet.sequence
	packet.sequence += 1
	packet.nextAt = math.max(packet.nextAt + packet.interval, now + packet.interval)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not GameReadyController.GetState().started
		or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local definition = AbilityDefinitions.ById.Aura
	local candidates = ZombieController.GetContactCandidates(root.Position, packet.radius)
	local count = 0
	for _, candidate in candidates do
		local offset = candidate.position - root.Position
		local zone = definition.GetZoneAtDistance(packet.radius, Vector2.new(offset.X, offset.Z).Magnitude)
		ZombieController.PredictHit(candidate.id, "Aura", tostring(sequence),
			math.max(1, math.floor(packet.damage * (if zone then zone.DamageMultiplier else 1) + 0.5)))
		count += 1
		if count >= definition.Combat.MaximumTargetsPerTick then
			break
		end
	end
end

return AuraPrediction
