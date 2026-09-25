local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local CrowdWeaponEffects = {}

local effectsFolder: Folder?
local auras = {}
local balls = {}
local drills = {}
local mines = {}
local puddles = {}
local bursts = {}
local random = Random.new()

local function isFiniteNumber(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function preparePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function prepareModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			preparePart(descendant)
		end
	end
end

local function getFirstPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		model.PrimaryPart = part
	end
	return part
end

local function makeBlock(name: string, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	preparePart(part)
	return part
end

local function createRing(name: string, radius: number, color: Color3, transparency: number, segmentCount: number): Model?
	if not effectsFolder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	local pivot = makeBlock("Pivot", Vector3.new(0.1, 0.1, 0.1), color, 1)
	pivot.Parent = model
	model.PrimaryPart = pivot
	local segmentLength = math.max(0.45, (math.pi * 2 * radius / segmentCount) * 0.8)
	for index = 1, segmentCount do
		local angle = (index - 1) / segmentCount * math.pi * 2
		local segment = makeBlock(
			"RingSegment",
			Vector3.new(0.22, 0.12, segmentLength),
			color,
			transparency + ((index % 3) * 0.04)
		)
		segment.CFrame = CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle, 0)
		segment.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function addBurst(position: Vector3, radius: number, color: Color3, duration: number, soundName: string?)
	local ring = createRing("AbilityBurst", 1, color, 0.16, 20)
	if not ring then
		return
	end
	ring:PivotTo(CFrame.new(position + Vector3.yAxis * 0.12))
	ring:ScaleTo(0.4)
	table.insert(bursts, {
		model = ring,
		startedAt = os.clock(),
		duration = duration,
		maximumScale = radius,
	})
	if soundName and ring.PrimaryPart then
		Sounds.Play(soundName, ring.PrimaryPart, 105)
	end
end

local function addImpact(position: Vector3, color: Color3, rage: boolean, soundName: string?)
	if not effectsFolder then
		return
	end
	local model = Instance.new("Model")
	model.Name = "WeaponImpact"
	local pivot = makeBlock("Pivot", Vector3.new(0.1, 0.1, 0.1), color, 1)
	pivot.CFrame = CFrame.new(position)
	pivot.Parent = model
	model.PrimaryPart = pivot
	for index = 1, (if rage then 7 else 5) do
		local shard = makeBlock(
			"ImpactBlock",
			Vector3.new(0.18, 0.18, if rage then 1.2 else 0.8),
			color,
			0.12
		)
		local angle = (index - 1) / (if rage then 7 else 5) * math.pi * 2
		shard.CFrame = CFrame.new(position + Vector3.new(math.cos(angle), 0.7, math.sin(angle)) * 0.45)
			* CFrame.Angles(math.rad(18), -angle, 0)
		shard.Parent = model
	end
	model.Parent = effectsFolder
	model:PivotTo(model:GetPivot())
	table.insert(bursts, {
		model = model,
		startedAt = os.clock(),
		duration = 0.22,
		maximumScale = if rage then 1.8 else 1.35,
	})
	if soundName then
		Sounds.Play(soundName, pivot, 95)
	end
end

local function addBlockTrail(model: Model, color: Color3, rage: boolean)
	local primaryPart = getFirstPart(model)
	if not primaryPart then
		return
	end
	for trailIndex = 1, 3 do
		local trailBlock = makeBlock(
			"TrailBlock",
			Vector3.new(0.22, 0.22, (if rage then 0.7 else 0.5) * (4 - trailIndex)),
			color,
			0.25 + trailIndex * 0.18
		)
		trailBlock.CFrame = primaryPart.CFrame * CFrame.new(0, 0, 0.8 + trailIndex * 0.55)
		trailBlock.Parent = model
	end
end

local function createFallbackBall(): Model
	local model = Instance.new("Model")
	model.Name = "BallProjectile"
	local core = makeBlock("Core", Vector3.new(2.1, 2.1, 2.1), Color3.fromRGB(255, 184, 48), 0)
	core.TopSurface = Enum.SurfaceType.Studs
	core.BottomSurface = Enum.SurfaceType.Inlet
	core.Parent = model
	model.PrimaryPart = core
	for axis = 1, 3 do
		local band = makeBlock("Band", Vector3.new(2.22, 0.25, 0.25), Color3.fromRGB(109, 58, 31), 0)
		band.CFrame = CFrame.Angles(0, 0, math.rad((axis - 1) * 60))
		band.Parent = model
	end
	return model
end

local function createFallbackDrill(): Model
	local model = Instance.new("Model")
	model.Name = "DrillProjectile"
	local core = makeBlock("Core", Vector3.new(1.15, 1.15, 2.4), Color3.fromRGB(104, 151, 194), 0)
	core.TopSurface = Enum.SurfaceType.Studs
	core.Parent = model
	model.PrimaryPart = core
	for stepIndex = 1, 4 do
		local step = makeBlock(
			"DrillStep",
			Vector3.new(1.15 - stepIndex * 0.18, 1.15 - stepIndex * 0.18, 0.5),
			if stepIndex % 2 == 0 then Color3.fromRGB(221, 230, 235) else Color3.fromRGB(82, 122, 158),
			0
		)
		step.CFrame = CFrame.new(0, 0, -1.2 - stepIndex * 0.38) * CFrame.Angles(0, 0, math.rad(stepIndex * 35))
		step.Parent = model
	end
	return model
end

local function cloneAbilityModel(assetName: string, fallbackFactory, scale: number, color: Color3, rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild(assetName)
	local model = if template and template:IsA("Model") then template:Clone() else fallbackFactory()
	prepareModel(model)
	if not getFirstPart(model) then
		model:Destroy()
		return nil
	end
	model:ScaleTo(scale)
	addBlockTrail(model, color, rage)
	model.Parent = effectsFolder
	return model
end

local function createMineModel(rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild("Mine")
	local model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local core = makeBlock("Core", Vector3.new(2.2, 0.45, 2.2), Color3.fromRGB(83, 87, 91), 0)
		core.TopSurface = Enum.SurfaceType.Studs
		core.Parent = model
		model.PrimaryPart = core
		local trigger = makeBlock("Trigger", Vector3.new(0.7, 0.3, 0.7), Color3.fromRGB(255, 69, 45), 0.05)
		trigger.CFrame = CFrame.new(0, 0.38, 0)
		trigger.Parent = model
	end
	model.Name = "Mine"
	prepareModel(model)
	local primary = getFirstPart(model)
	if not primary then
		model:Destroy()
		return nil
	end
	if rage then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= primary then
				descendant.Color = Color3.fromRGB(255, 90, 38)
			end
		end
	end
	model.Parent = effectsFolder
	return model
end

local function destroyOwned(ownerUserId: number, abilityId: string)
	if abilityId == "Aura" then
		local aura = auras[ownerUserId]
		if aura then
			aura.model:Destroy()
			auras[ownerUserId] = nil
		end
	elseif abilityId == "Ball" then
		for id, projectile in balls do
			if projectile.ownerUserId == ownerUserId then
				projectile.model:Destroy()
				balls[id] = nil
			end
		end
	elseif abilityId == "Drill" then
		for id, projectile in drills do
			if projectile.ownerUserId == ownerUserId then
				projectile.model:Destroy()
				drills[id] = nil
			end
		end
	elseif abilityId == "Mine" then
		for id, mine in mines do
			if mine.ownerUserId == ownerUserId then
				mine.model:Destroy()
				mines[id] = nil
			end
		end
	elseif abilityId == "Poison" then
		for id, puddle in puddles do
			if puddle.ownerUserId == ownerUserId then
				puddle.model:Destroy()
				puddles[id] = nil
			end
		end
	end
end

function CrowdWeaponEffects.Init(folder: Folder)
	effectsFolder = folder
end

function CrowdWeaponEffects.AuraState(packet)
	if type(packet) ~= "table"
		or type(packet.ownerUserId) ~= "number"
		or type(packet.enabled) ~= "boolean"
		or not isFiniteNumber(packet.radius)
		or packet.radius < 0
		or packet.radius > 25
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local existing = auras[packet.ownerUserId]
	if not packet.enabled then
		if existing then
			existing.model:Destroy()
			auras[packet.ownerUserId] = nil
		end
		return
	end
	if existing and math.abs(existing.radius - packet.radius) < 0.01 and existing.rage == packet.rage then
		return
	end
	if existing then
		existing.model:Destroy()
	end
	local color = if packet.rage then Color3.fromRGB(255, 188, 48) else Color3.fromRGB(92, 220, 255)
	local model = createRing("Aura", packet.radius, color, if packet.rage then 0.18 else 0.42, 28)
	if model then
		auras[packet.ownerUserId] = {
			model = model,
			radius = packet.radius,
			rage = packet.rage,
		}
	end
end

function CrowdWeaponEffects.AuraHit(packet)
	if type(packet) ~= "table" or type(packet.positions) ~= "table" or type(packet.rage) ~= "boolean" then
		return
	end
	for index, position in packet.positions do
		if index > 12 then
			break
		end
		if typeof(position) == "Vector3" then
			addImpact(
				position + Vector3.yAxis,
				if packet.rage then Color3.fromRGB(255, 203, 64) else Color3.fromRGB(99, 226, 255),
				packet.rage,
				nil
			)
		end
	end
end

function CrowdWeaponEffects.AuraPulse(packet)
	if type(packet) ~= "table"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or packet.radius > 35
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	addBurst(
		packet.position,
		packet.radius,
		if packet.rage then Color3.fromRGB(255, 176, 40) else Color3.fromRGB(92, 218, 255),
		0.42,
		"MagicSpell"
	)
end

function CrowdWeaponEffects.BallSpawned(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.targetPosition) ~= "Vector3"
		or not isFiniteNumber(packet.speed)
		or packet.speed <= 0
		or not isFiniteNumber(packet.scale)
		or packet.scale <= 0
		or not isFiniteNumber(packet.launchAt)
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local model = cloneAbilityModel(
		"Ball",
		createFallbackBall,
		packet.scale,
		if packet.rage then Color3.fromRGB(255, 95, 37) else Color3.fromRGB(255, 194, 55),
		packet.rage
	)
	if not model then
		return
	end
	model:PivotTo(CFrame.new(packet.startPosition))
	balls[packet.id] = {
		model = model,
		ownerUserId = packet.ownerUserId,
		position = packet.startPosition,
		targetPosition = packet.targetPosition,
		speed = packet.speed,
		launchAt = packet.launchAt,
		spin = 0,
	}
	Sounds.Play("Swoosh", model.PrimaryPart, 110)
end

function CrowdWeaponEffects.BallRedirected(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or typeof(packet.targetPosition) ~= "Vector3"
		or not isFiniteNumber(packet.serverTime)
	then
		return
	end
	local ball = balls[packet.id]
	if ball then
		ball.position = packet.position
		ball.targetPosition = packet.targetPosition
		ball.launchAt = packet.serverTime
	end
end

function CrowdWeaponEffects.BallHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" or type(packet.rage) ~= "boolean" then
		return
	end
	addImpact(
		packet.position,
		if packet.rage then Color3.fromRGB(255, 92, 38) else Color3.fromRGB(255, 190, 54),
		packet.rage,
		"BodyImpact"
	)
end

function CrowdWeaponEffects.BallEnded(id)
	if type(id) ~= "number" then
		return
	end
	local ball = balls[id]
	if ball then
		ball.model:Destroy()
		balls[id] = nil
	end
end

function CrowdWeaponEffects.DrillSpawned(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3"
		or packet.direction.Magnitude <= 0.001
		or not isFiniteNumber(packet.speed)
		or packet.speed <= 0
		or not isFiniteNumber(packet.range)
		or packet.range <= 0
		or not isFiniteNumber(packet.width)
		or packet.width <= 0
		or not isFiniteNumber(packet.launchAt)
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local model = cloneAbilityModel(
		"Drill",
		createFallbackDrill,
		packet.width / 2,
		if packet.rage then Color3.fromRGB(255, 126, 35) else Color3.fromRGB(99, 175, 240),
		packet.rage
	)
	if not model then
		return
	end
	drills[packet.id] = {
		model = model,
		ownerUserId = packet.ownerUserId,
		startPosition = packet.startPosition,
		direction = packet.direction.Unit,
		speed = packet.speed,
		range = packet.range,
		launchAt = packet.launchAt,
		rage = packet.rage,
	}
	Sounds.Play("FreezeRayShoot", model.PrimaryPart, 95)
end

function CrowdWeaponEffects.DrillHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" or type(packet.rage) ~= "boolean" then
		return
	end
	addImpact(
		packet.position,
		if packet.rage then Color3.fromRGB(255, 137, 36) else Color3.fromRGB(173, 210, 231),
		packet.rage,
		"MetalHitSoft"
	)
end

function CrowdWeaponEffects.DrillEnded(id)
	if type(id) ~= "number" then
		return
	end
	local drill = drills[id]
	if drill then
		drill.model:Destroy()
		drills[id] = nil
	end
end

function CrowdWeaponEffects.MinePlaced(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local model = createMineModel(packet.rage)
	if not model then
		return
	end
	model:PivotTo(CFrame.new(packet.position))
	mines[packet.id] = {
		model = model,
		ownerUserId = packet.ownerUserId,
		position = packet.position,
		rage = packet.rage,
		createdAt = os.clock(),
		triggeredAt = nil,
		fuseDuration = nil,
	}
	Sounds.Play("Beep", model.PrimaryPart, 65)
end

function CrowdWeaponEffects.MineTriggered(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or not isFiniteNumber(packet.fuseDuration)
		or packet.fuseDuration < 0
	then
		return
	end
	local mine = mines[packet.id]
	if mine then
		mine.triggeredAt = os.clock()
		mine.fuseDuration = math.max(packet.fuseDuration, 0.05)
		Sounds.Play("CountdownBeep", mine.model.PrimaryPart, 80)
	end
end

function CrowdWeaponEffects.MineExploded(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local mine = mines[packet.id]
	if mine then
		mine.model:Destroy()
		mines[packet.id] = nil
	end
	addBurst(
		packet.position,
		packet.radius,
		if packet.rage then Color3.fromRGB(255, 81, 25) else Color3.fromRGB(255, 153, 51),
		0.32,
		"CrateBreak2"
	)
	addImpact(packet.position + Vector3.yAxis, Color3.fromRGB(255, 201, 91), packet.rage, nil)
end

function CrowdWeaponEffects.MineRemoved(id)
	if type(id) ~= "number" then
		return
	end
	local mine = mines[id]
	if mine then
		mine.model:Destroy()
		mines[id] = nil
	end
end

function CrowdWeaponEffects.PoisonCreated(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or not isFiniteNumber(packet.duration)
		or packet.duration <= 0
		or type(packet.secondary) ~= "boolean"
		or type(packet.rage) ~= "boolean"
		or not effectsFolder
	then
		return
	end
	local color = if packet.rage then Color3.fromRGB(165, 255, 47) else Color3.fromRGB(72, 212, 75)
	local model = createRing("PoisonPuddle", packet.radius, color, 0.48, 24)
	if not model then
		return
	end
	model:PivotTo(CFrame.new(packet.position))
	for tileIndex = 1, (if packet.secondary then 4 else 7) do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(0, packet.radius * 0.7)
		local tile = makeBlock(
			"PoisonTile",
			Vector3.new(packet.radius * 0.35, 0.06, packet.radius * 0.28),
			color,
			0.64
		)
		tile.CFrame = CFrame.new(packet.position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
			* CFrame.Angles(0, angle, 0)
		tile.Parent = model
	end
	local bubbles = {}
	for bubbleIndex = 1, (if packet.secondary then 2 else 4) do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(packet.radius * 0.15, packet.radius * 0.72)
		local bubble = makeBlock("ToxicBubble", Vector3.one * 0.18, color, 0.18)
		bubble.Parent = model
		table.insert(bubbles, {
			part = bubble,
			offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			phase = bubbleIndex * 1.7,
		})
	end
	puddles[packet.id] = {
		model = model,
		ownerUserId = packet.ownerUserId,
		position = packet.position,
		bubbles = bubbles,
		expiresAt = os.clock() + packet.duration,
		rage = packet.rage,
	}
	Sounds.Play(if packet.rage then "Splash" else "Drip", model.PrimaryPart, 70)
end

function CrowdWeaponEffects.PoisonRemoved(id)
	if type(id) ~= "number" then
		return
	end
	local puddle = puddles[id]
	if puddle then
		puddle.model:Destroy()
		puddles[id] = nil
	end
end

function CrowdWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
	if type(ownerUserId) == "number" and type(abilityId) == "string" then
		destroyOwned(ownerUserId, abilityId)
	end
end

function CrowdWeaponEffects.Render(now: number, deltaTime: number)
	local localNow = os.clock()
	for ownerUserId, aura in auras do
		local player = Players:GetPlayerByUserId(ownerUserId)
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			aura.model:PivotTo(CFrame.new(root.Position - Vector3.yAxis * 2.75))
			local pulse = 1 + math.sin(localNow * (if aura.rage then 6 else 3)) * 0.025
			aura.model:ScaleTo(pulse)
		else
			aura.model:Destroy()
			auras[ownerUserId] = nil
		end
	end

	for id, ball in balls do
		if not ball.model.Parent then
			balls[id] = nil
			continue
		end
		if now >= ball.launchAt then
			local offset = ball.targetPosition - ball.position
			local stepDistance = ball.speed * math.min(deltaTime, 0.1)
			if offset.Magnitude > stepDistance then
				ball.position += offset.Unit * stepDistance
			else
				ball.position = ball.targetPosition
			end
			ball.spin += deltaTime * 11
			ball.model:PivotTo(CFrame.new(ball.position) * CFrame.Angles(ball.spin, ball.spin * 0.6, 0))
		end
	end

	for id, drill in drills do
		if not drill.model.Parent then
			drills[id] = nil
			continue
		end
		local elapsed = math.max(now - drill.launchAt, 0)
		local distance = math.min(elapsed * drill.speed, drill.range)
		local position = drill.startPosition + drill.direction * distance
		local facing = CFrame.lookAt(position, position + drill.direction)
		drill.model:PivotTo(facing * CFrame.Angles(0, 0, elapsed * (if drill.rage then 28 else 21)))
	end

	for id, mine in mines do
		if not mine.model.Parent then
			mines[id] = nil
			continue
		end
		local frequency = if mine.triggeredAt then 24 else 3
		local scale = 1 + math.max(0, math.sin(localNow * frequency)) * (if mine.triggeredAt then 0.16 else 0.025)
		mine.model:ScaleTo(scale)
	end

	for id, puddle in puddles do
		if not puddle.model.Parent or localNow >= puddle.expiresAt then
			puddle.model:Destroy()
			puddles[id] = nil
			continue
		end
		for _, bubble in puddle.bubbles do
			local cycle = (localNow * (if puddle.rage then 1.8 else 1.25) + bubble.phase) % 1
			bubble.part.Position = puddle.position + bubble.offset + Vector3.yAxis * (0.1 + cycle * 0.65)
			bubble.part.Transparency = 0.2 + cycle * 0.65
		end
	end

	for index = #bursts, 1, -1 do
		local burst = bursts[index]
		local alpha = math.clamp((localNow - burst.startedAt) / burst.duration, 0, 1)
		if alpha >= 1 or not burst.model.Parent then
			burst.model:Destroy()
			table.remove(bursts, index)
		else
			burst.model:ScaleTo(0.4 + burst.maximumScale * alpha)
			for _, descendant in burst.model:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Name ~= "Pivot" then
					descendant.Transparency = math.clamp(0.12 + alpha * 0.88, 0, 1)
				end
			end
		end
	end
end

return CrowdWeaponEffects
