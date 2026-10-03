local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameReadyController = require(ReplicatedStorage.Controllers.GameReadyController)
local ZombieController = require(script.Parent.Parent.ZombieController)

local DaggerPrediction = {}
local schedule
local lastSequence = 0
local records = {}
local spawnProjectile

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function getKey(sequence, index): string
	return tostring(sequence) .. ":" .. tostring(index)
end

function DaggerPrediction.Init(spawn)
	spawnProjectile = spawn
end

function DaggerPrediction.ApplySchedule(packet)
	if type(packet) ~= "table" or not finite(packet.sequence) or packet.sequence % 1 ~= 0
		or packet.sequence <= lastSequence or type(packet.enabled) ~= "boolean" then
		return
	end
	if packet.enabled and (not finite(packet.nextAt) or not finite(packet.count)
		or packet.count % 1 ~= 0 or packet.count < 1 or packet.count > 64
		or not finite(packet.range) or packet.range <= 0
		or not finite(packet.speed) or packet.speed <= 0
		or not finite(packet.stagger) or packet.stagger < 0
		or not finite(packet.lead) or packet.lead < 0
		or not finite(packet.minimumDuration) or packet.minimumDuration <= 0
		or not finite(packet.maximumDuration) or packet.maximumDuration < packet.minimumDuration
		or not finite(packet.scale) or packet.scale <= 0 or type(packet.rage) ~= "boolean"
		or not finite(packet.damage) or packet.damage <= 0) then
		return
	end
	lastSequence = packet.sequence
	schedule = if packet.enabled then packet else nil
	if not packet.enabled then
		DaggerPrediction.Clear()
	end
end

function DaggerPrediction.Clear()
	schedule = nil
	ZombieController.ClearPredictedHits("Dagger")
	for _, record in records do
		record.packet = nil
		if record.projectile and record.projectile.predicted and record.projectile.model.Parent then
			record.projectile.model:Destroy()
		end
	end
end

function DaggerPrediction.Render(now: number)
	if schedule and now >= schedule.nextAt then
		local current = schedule
		schedule = nil
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if now <= current.nextAt + 0.1 and GameReadyController.GetState().started
			and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local origin = root.Position + Vector3.yAxis * 1.7
			local targets = ZombieController.GetNearestZombiePositions(origin, current.range, current.count)
			if #targets > 0 then
				for index = 1, current.count do
					local key = getKey(current.sequence, index)
					if not records[key] then
						local candidate = targets[(index - 1) % #targets + 1]
						local target = candidate.position
						local start = origin + root.CFrame.RightVector * ((index - (current.count + 1) / 2) * 0.72)
						records[key] = {
							expiresAt = now + 8,
							packet = {
								startPosition = start, targetPosition = target,
								launchAt = current.nextAt + current.lead + (index - 1) * current.stagger,
								duration = math.clamp((target - start).Magnitude / current.speed, current.minimumDuration, current.maximumDuration),
								scale = current.scale, rage = current.rage, daggerIndex = index, predicted = true,
								targetId = candidate.id, damage = current.damage, predictionKey = key,
							},
						}
					end
				end
			end
		end
	end
	for key, record in records do
		if now >= record.expiresAt then
			records[key] = nil
		elseif record.packet and now >= record.packet.launchAt then
			record.projectile = spawnProjectile(record.packet)
			record.packet = nil
		end
	end
end

function DaggerPrediction.Confirm(packet): boolean
	if packet.ownerUserId ~= Players.LocalPlayer.UserId or not finite(packet.sequence) then
		return false
	end
	local key = getKey(packet.sequence, packet.daggerIndex)
	local record = records[key]
	if not record then
		records[key] = { expiresAt = Workspace:GetServerTimeNow() + 8, confirmed = true }
		return false
	end
	if record.confirmed then
		return true
	end
	record.confirmed = true
	record.packet = nil
	local projectile = record.projectile
	-- A local target may differ from the server's selection; restore only that view immediately.
	if projectile and projectile.targetId ~= packet.targetId then
		ZombieController.CancelPredictedHit(projectile.targetId, "Dagger", key)
	end
	if projectile and projectile.model.Parent then
		-- Reconcile the existing flight and target without replaying launch/impact feedback.
		projectile.predicted = false
		projectile.targetId = packet.targetId
		projectile.damage = packet.damage
		projectile.predictionKey = packet.predictionKey
		projectile.correctedTargetPosition = packet.targetPosition
		projectile.launchAt = packet.launchAt
		projectile.duration = packet.duration
		return true
	elseif projectile then
		-- Its local impact already played. A late launch confirmation must never play it a second time.
		return true
	end
	return false
end

return DaggerPrediction
