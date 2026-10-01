local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EffectLightingConfig = require(ReplicatedStorage.Modules.UI.EffectLightingConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local StudVFX = require(ReplicatedStorage.Modules.UI.StudVFX)

local AdditionalWeaponEffects = {}

local effectsFolder: Folder?
local novaWaves = {}
local groundRings = {}
local bursts = {}
local meteors = {}
local turrets = {}
local vortexes = {}
local random = Random.new()

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function makeBlock(name: string, size: Vector3, color: Color3, transparency: number?): Part
	return StudVFX.CreateBlock(nil, name, size, color, transparency)
end

local function makeRing(name: string, radius: number, color: Color3, segmentCount: number): Model?
	if not effectsFolder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	local pivot = makeBlock("Pivot", Vector3.one * 0.1, color, 1)
	pivot.Parent = model
	model.PrimaryPart = pivot
	for index = 1, segmentCount do
		local angle = (index - 1) / segmentCount * math.pi * 2
		local segment = makeBlock("StudRing", Vector3.new(0.46, 0.18,
			math.max(0.5, math.pi * 2 * radius / segmentCount * 0.78)), color, 0.22)
		segment.CFrame = CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle, 0)
		segment.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function burstStuds(position: Vector3, color: Color3, count: number, distance: number, duration: number)
	StudVFX.Burst(effectsFolder, position, color, count, distance, duration)
end

local function flash(position: Vector3, color: Color3, radius: number, duration: number)
	StudVFX.Flash(effectsFolder, position, color, radius, duration)
end

local function pulse(position: Vector3, radius: number, color: Color3, duration: number, soundName: string?)
	local ring = makeRing("AbilityPulse", 1, color, 12)
	if not ring then
		return
	end
	ring:PivotTo(CFrame.new(position + Vector3.yAxis * 0.2))
	ring:ScaleTo(0.2)
	table.insert(bursts, { model = ring, startedAt = os.clock(), duration = duration, radius = radius })
	-- The restrained flash and outward studs give every impact a readable hit frame while the ring communicates range.
	flash(position + Vector3.yAxis * 0.35, color, math.min(radius * 0.55, 4.5), duration * 0.72)
	burstStuds(position + Vector3.yAxis * 0.25, color, math.clamp(math.floor(radius * 0.7), 4, 10), math.min(radius * 0.6, 5), duration)
	if soundName and ring.PrimaryPart then
		Sounds.Play(soundName, ring.PrimaryPart, 90)
	end
end

local function tracer(origin: Vector3, destination: Vector3, color: Color3, width: number, duration: number)
	if not effectsFolder then
		return
	end
	local offset = destination - origin
	if offset.Magnitude < 0.1 then
		return
	end
	local center = origin:Lerp(destination, 0.5)
	-- A soft outer streak plus a bright narrow core makes rapid shots legible without lengthening their lifetime.
	for layer = 1, 2 do
		local layerWidth = if layer == 1 then width * 2.35 else width
		local layerColor = if layer == 1 then color else color:Lerp(Color3.new(1, 1, 1), 0.5)
		local part = makeBlock(
			if layer == 1 then "WeaponTracerGlow" else "WeaponTracerCore",
			Vector3.new(layerWidth, layerWidth, offset.Magnitude),
			layerColor,
			if layer == 1 then 0.65 else 0.04
		)
		part.CFrame = CFrame.lookAt(center, destination)
		part.Parent = effectsFolder
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(layerWidth * 0.25, layerWidth * 0.25, offset.Magnitude),
		}):Play()
		Debris:AddItem(part, duration + 0.05)
	end
end

local function makeMeteorModel(rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Meteor"
	local core = makeBlock("Core", Vector3.new(3.2, 2.6, 3.2),
		if rage then Color3.fromRGB(255, 142, 41) else Color3.fromRGB(126, 79, 62))
	core.Parent = model
	model.PrimaryPart = core
	for index = 1, 4 do
		local angle = index / 4 * math.pi * 2
		local brick = makeBlock("HotBrick", Vector3.new(1.2, 1.1, 1.15),
			if index % 2 == 0 then Color3.fromRGB(255, 100, 38) else Color3.fromRGB(186, 77, 49))
		brick.CFrame = CFrame.new(math.cos(angle) * 1.8, 0.3, math.sin(angle) * 1.8)
		brick.Parent = model
	end
	for index = 1, 3 do
		local trail = makeBlock(
			"MeteorTail",
			Vector3.new(1.7 - index * 0.28, 1.7 - index * 0.28, 1.7 - index * 0.28),
			if index == 1 then Color3.fromRGB(255, 214, 83) else Color3.fromRGB(255, 93, 35),
			0.12 + index * 0.18
		)
		trail.CFrame = CFrame.new(0, 1.5 + index * 1.05, 0)
		trail.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function makeTurretModel(rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Turret"
	local base = makeBlock("Base", Vector3.new(2.6, 0.5, 2.6), Color3.fromRGB(54, 68, 93))
	base.Parent = model
	model.PrimaryPart = base
	local body = makeBlock("Body", Vector3.new(1.7, 1.15, 1.5),
		if rage then Color3.fromRGB(255, 164, 56) else Color3.fromRGB(104, 144, 208))
	body.CFrame = CFrame.new(0, 0.75, 0)
	body.Parent = model
	for side = -1, 1, 2 do
		local barrel = makeBlock("Barrel", Vector3.new(0.4, 0.4, 1.45), Color3.fromRGB(55, 61, 77))
		barrel.CFrame = CFrame.new(side * 0.47, 0.82, -1.04)
		barrel.Parent = model
	end
	for side = -1, 1, 2 do
		local foot = makeBlock("Foot", Vector3.new(0.6, 0.28, 1.2), Color3.fromRGB(63, 75, 93))
		foot.CFrame = CFrame.new(side * 0.9, -0.3, 0)
		foot.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function removeOwned(ownerUserId: number, abilityId: string)
	if abilityId == "FrostNova" then
		for id, wave in novaWaves do
			if wave.ownerUserId == ownerUserId then
				wave.model:Destroy()
				novaWaves[id] = nil
			end
		end
	elseif abilityId == "Meteor" then
		for id, strike in meteors do
			if strike.ownerUserId == ownerUserId then
				strike.ring:Destroy()
				strike.model:Destroy()
				meteors[id] = nil
			end
		end
	elseif abilityId == "Turret" then
		for id, turret in turrets do
			if turret.ownerUserId == ownerUserId then
				turret.model:Destroy()
				turrets[id] = nil
			end
		end
	elseif abilityId == "Vortex" then
		for id, vortex in vortexes do
			if vortex.ownerUserId == ownerUserId then
				vortex.model:Destroy()
				vortexes[id] = nil
			end
		end
	end
	if abilityId == "FrostNova" then
		for index = #groundRings, 1, -1 do
			local ground = groundRings[index]
			if ground.ownerUserId == ownerUserId then
				ground.model:Destroy()
				table.remove(groundRings, index)
			end
		end
	end
end

function AdditionalWeaponEffects.Init(folder: Folder)
	effectsFolder = folder
end

function AdditionalWeaponEffects.ShotgunFired(packet)
	if type(packet) ~= "table" or typeof(packet.origin) ~= "Vector3"
		or type(packet.endpoints) ~= "table" or #packet.endpoints > 16 or type(packet.rage) ~= "boolean" then
		return
	end
	local color = if packet.rage then Color3.fromRGB(255, 224, 89) else Color3.fromRGB(255, 197, 105)
	local width = (if packet.rage then 0.21 else 0.14)
		* (if finite(packet.pelletRadius) then math.clamp(packet.pelletRadius / 0.62, 0.75, 1.5) else 1)
	for _, endpoint in packet.endpoints do
		if typeof(endpoint) == "Vector3" and (endpoint - packet.origin).Magnitude <= 100 then
			tracer(packet.origin, endpoint, color, width, 0.14)
		end
	end
	flash(packet.origin, color, if packet.rage then 2.2 else 1.55, 0.11)
	pulse(packet.origin, 2.2, color, 0.16, "Shoot")
end

function AdditionalWeaponEffects.FrostNovaStarted(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 35
		or not finite(packet.duration) or packet.duration <= 0 or packet.duration > 2 then
		return
	end
	local model = makeRing("FrostNova", 1,
		if packet.rage then Color3.fromRGB(232, 255, 255) else Color3.fromRGB(131, 232, 255), 16)
	if not model then
		return
	end
	model:PivotTo(CFrame.new(packet.position - Vector3.yAxis * 1.8))
	model:ScaleTo(0.1)
	burstStuds(packet.position - Vector3.yAxis * 1.45, Color3.fromRGB(205, 249, 255), if packet.rage then 12 else 8, 3.2, 0.32)
	novaWaves[packet.id] = {
		model = model, ownerUserId = packet.ownerUserId,
		startedAt = packet.startedAt or Workspace:GetServerTimeNow(),
		duration = packet.duration, radius = packet.radius,
	}
	-- These ability-specific cues preserve the action's identity instead of reusing unrelated weapon sounds.
	Sounds.Play("AbilityFrostNova", model.PrimaryPart, 90)
end

function AdditionalWeaponEffects.FrostShattered(packet)
	if type(packet) == "table" and typeof(packet.position) == "Vector3" then
		pulse(packet.position, 2.5, Color3.fromRGB(190, 244, 255), 0.18, "AbilityFrostShatter")
	end
end

function AdditionalWeaponEffects.FrostGroundCreated(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 35
		or not finite(packet.duration) or packet.duration <= 0 or packet.duration > 5 then
		return
	end
	local model = makeRing("FrozenGround", packet.radius, Color3.fromRGB(173, 236, 255), 16)
	if not model then return end
	model:PivotTo(CFrame.new(packet.position - Vector3.yAxis * 1.7))
	table.insert(groundRings, {
		model = model, ownerUserId = packet.ownerUserId,
		startedAt = os.clock(),
		expiresAt = os.clock() + packet.duration,
	})
end

function AdditionalWeaponEffects.MeteorWarned(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 30
		or not finite(packet.impactAt) or type(packet.rage) ~= "boolean" then
		return
	end
	local ring = makeRing("MeteorWarning", packet.radius, Color3.fromRGB(255, 147, 60), 16)
	local model = makeMeteorModel(packet.rage)
	if not ring or not model then
		if ring then ring:Destroy() end
		if model then model:Destroy() end
		return
	end
	ring:PivotTo(CFrame.new(packet.position + Vector3.yAxis * 0.15))
	flash(packet.position + Vector3.yAxis * 0.25, Color3.fromRGB(255, 112, 42), math.min(packet.radius * 0.22, 3), 0.3)
	meteors[packet.id] = {
		ring = ring, model = model, position = packet.position, radius = packet.radius,
		ownerUserId = packet.ownerUserId, impactAt = packet.impactAt,
		startedAt = Workspace:GetServerTimeNow(),
	}
	Sounds.Play("Alert", ring.PrimaryPart, 75)
end

function AdditionalWeaponEffects.MeteorImpacted(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 30 then
		return
	end
	AdditionalWeaponEffects.MeteorCancelled(packet.id)
	pulse(packet.position, packet.radius, Color3.fromRGB(255, 135, 56), 0.35, "FlameBurst")
	burstStuds(packet.position + Vector3.yAxis * 0.35, Color3.fromRGB(255, 221, 110), 12, math.min(packet.radius * 0.78, 8), 0.42)
	if packet.shockwave then
		pulse(packet.position, packet.radius * 1.38, Color3.fromRGB(255, 211, 106), 0.48, nil)
	end
	if packet.fragments then
		for index = 1, 5 do
			local angle = index / 5 * math.pi * 2
			local point = packet.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * packet.radius * 0.85
			pulse(point, 1.8, Color3.fromRGB(255, 165, 64), 0.2, nil)
		end
	end
end

function AdditionalWeaponEffects.MeteorCancelled(id)
	if not finite(id) then return end
	local strike = meteors[id]
	if strike then
		strike.ring:Destroy()
		strike.model:Destroy()
		meteors[id] = nil
	end
end

function AdditionalWeaponEffects.TurretDeployed(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.duration) or packet.duration <= 0 or packet.duration > 30
		or type(packet.rage) ~= "boolean" then
		return
	end
	local model = makeTurretModel(packet.rage)
	if not model then return end
	model:PivotTo(CFrame.new(packet.position))
	turrets[packet.id] = { model = model, position = packet.position, ownerUserId = packet.ownerUserId }
	Sounds.Play("AbilityTurretDeploy", model.PrimaryPart, 75)
end

function AdditionalWeaponEffects.TurretFired(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.origin) ~= "Vector3"
		or typeof(packet.targetPosition) ~= "Vector3" then
		return
	end
	local turret = turrets[packet.id]
	if not turret then return end
	local target = Vector3.new(packet.targetPosition.X, turret.position.Y, packet.targetPosition.Z)
	if (target - turret.position).Magnitude > 0.01 then
		turret.model:PivotTo(CFrame.lookAt(turret.position, target))
	end
	local color = if packet.rage then Color3.fromRGB(255, 199, 72) else Color3.fromRGB(167, 225, 255)
	local endpoints = if type(packet.endpoints) == "table" and #packet.endpoints <= 2
		then packet.endpoints else { packet.targetPosition }
	for _, endpoint in endpoints do
		if typeof(endpoint) == "Vector3" and (endpoint - packet.origin).Magnitude <= 100 then
			local width = (if packet.rail then 0.36 else 0.16)
				* (if finite(packet.bulletRadius) then math.clamp(packet.bulletRadius / 0.5, 0.75, 1.5) else 1)
			tracer(packet.origin, endpoint, color,
				width,
				if packet.rail then 0.24 elseif packet.fast then 0.08 else 0.12)
		end
	end
	flash(packet.origin, color, if packet.rail then 2.4 else 1.25, if packet.rail then 0.16 else 0.1)
	Sounds.Play(if packet.rail then "FreezeRayShoot" else "Shoot", turret.model.PrimaryPart, 75)
end

function AdditionalWeaponEffects.TurretRemoved(id)
	if not finite(id) then return end
	local turret = turrets[id]
	if turret then
		turret.model:Destroy()
		turrets[id] = nil
	end
end

function AdditionalWeaponEffects.VortexCreated(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 35
		or type(packet.mobile) ~= "boolean" or type(packet.rage) ~= "boolean" then
		return
	end
	local outerColor = if packet.rage then Color3.fromRGB(190, 104, 255) else Color3.fromRGB(91, 103, 238)
	local innerColor = if packet.rage then Color3.fromRGB(255, 204, 255) else Color3.fromRGB(145, 210, 255)
	local outerRing = makeRing("VortexOuterRing", packet.radius, outerColor, 10)
	local innerRing = makeRing("VortexInnerRing", packet.radius * 0.56, innerColor, 6)
	if not outerRing or not innerRing then
		if outerRing then outerRing:Destroy() end
		if innerRing then innerRing:Destroy() end
		return
	end

	local model = Instance.new("Model")
	model.Name = "Vortex"
	local pivot = makeBlock("Pivot", Vector3.one * 0.1, outerColor, 1)
	pivot.Parent = model
	model.PrimaryPart = pivot
	outerRing.Parent = model
	innerRing.Parent = model

	-- Angled inner vanes and counter-rotating rings create an inward spiral within the old effect's part budget.
	for index = 1, 5 do
		local angle = (index - 1) / 5 * math.pi * 2
		local vane = makeBlock("VortexVane", Vector3.new(0.26, 0.16, packet.radius * 0.48), innerColor, 0.34)
		vane.CFrame = CFrame.new(math.cos(angle) * packet.radius * 0.3, 0, math.sin(angle) * packet.radius * 0.3)
			* CFrame.Angles(0, -angle - math.rad(24), 0)
		vane.Parent = innerRing
	end

	local coreSize = math.clamp(packet.radius * 0.14, 0.9, 1.8)
	local core = makeBlock("VortexCore", Vector3.new(coreSize, 0.32, coreSize),
		innerColor:Lerp(Color3.new(1, 1, 1), 0.42), 0.08)
	core.Parent = model
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "GravityGlow"
	coreLight.Color = innerColor
	coreLight.Brightness = EffectLightingConfig.Scale(if packet.rage then 2.4 else 1.6)
	coreLight.Range = math.clamp(packet.radius * 1.15, 7, 18)
	coreLight.Parent = core

	model.Parent = effectsFolder
	model:PivotTo(CFrame.new(packet.position + Vector3.yAxis * 0.12))
	vortexes[packet.id] = {
		model = model, position = packet.position, ownerUserId = packet.ownerUserId,
		mobile = packet.mobile, radius = packet.radius, createdAt = os.clock(),
		outerRing = outerRing, innerRing = innerRing, core = core,
		coreLight = coreLight, coreSize = coreSize, coreBrightness = coreLight.Brightness,
	}
	flash(packet.position + Vector3.yAxis * 0.25, innerColor, math.min(packet.radius * 0.34, 3.5), 0.22)
	Sounds.Play("AbilityVortexCast", model.PrimaryPart, 80)
end

function AdditionalWeaponEffects.VortexCollapsed(packet)
	if type(packet) == "table" and typeof(packet.position) == "Vector3"
		and finite(packet.radius) and packet.radius > 0 and packet.radius <= 35 then
		pulse(packet.position, packet.radius, Color3.fromRGB(189, 114, 255), 0.35, "BodyImpact")
		pulse(packet.position + Vector3.yAxis * 0.08, packet.radius * 0.62,
			Color3.fromRGB(185, 222, 255), 0.25, nil)
	end
end

function AdditionalWeaponEffects.VortexRemoved(id)
	if not finite(id) then return end
	local vortex = vortexes[id]
	if vortex then
		vortex.model:Destroy()
		vortexes[id] = nil
	end
end

function AdditionalWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
	if finite(ownerUserId) and type(abilityId) == "string" then
		removeOwned(ownerUserId, abilityId)
	end
end

function AdditionalWeaponEffects.Render(now: number)
	local clock = os.clock()
	for index = #bursts, 1, -1 do
		local burst = bursts[index]
		local alpha = math.clamp((clock - burst.startedAt) / burst.duration, 0, 1)
		if alpha >= 1 or not burst.model.Parent then
			burst.model:Destroy()
			table.remove(bursts, index)
		else
			burst.model:ScaleTo(0.2 + burst.radius * alpha)
			for _, part in burst.model:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "Pivot" then
					part.Transparency = 0.22 + alpha * 0.78
				end
			end
		end
	end
	for index = #groundRings, 1, -1 do
		local ground = groundRings[index]
		if clock >= ground.expiresAt or not ground.model.Parent then
			ground.model:Destroy()
			table.remove(groundRings, index)
		else
			local remaining = ground.expiresAt - clock
			local entranceAlpha = math.clamp((clock - ground.startedAt) / 0.2, 0, 1)
			local fadeAlpha = math.clamp(remaining / 0.4, 0, 1)
			for _, part in ground.model:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "Pivot" then
					part.Transparency = 1 - math.min(entranceAlpha, fadeAlpha) * 0.72
				end
			end
		end
	end
	for id, wave in novaWaves do
		local alpha = math.clamp((now - wave.startedAt) / wave.duration, 0, 1)
		if alpha >= 1 or not wave.model.Parent then
			wave.model:Destroy()
			novaWaves[id] = nil
		else
			wave.model:ScaleTo(math.max(0.1, wave.radius * alpha))
		end
	end
	for id, strike in meteors do
		local duration = math.max(strike.impactAt - strike.startedAt, 0.1)
		local alpha = math.clamp((now - strike.startedAt) / duration, 0, 1)
		strike.model:PivotTo(CFrame.new(strike.position + Vector3.yAxis * (22 * (1 - alpha) + 1.7))
			* CFrame.Angles(alpha * 3, alpha * 1.4, 0))
		local warningPulse = 0.16 + math.max(0, math.sin(clock * 11)) * 0.34
		for _, part in strike.ring:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Pivot" then
				part.Transparency = warningPulse
			end
		end
		if now > strike.impactAt + 1 then
			AdditionalWeaponEffects.MeteorCancelled(id)
		end
	end
	for id, vortex in vortexes do
		if not vortex.model.Parent then
			vortexes[id] = nil
			continue
		end
		if vortex.mobile then
			local player = Players:GetPlayerByUserId(vortex.ownerUserId)
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				vortex.position = root.Position
			end
		end
		local age = clock - vortex.createdAt
		local center = CFrame.new(vortex.position + Vector3.yAxis * 0.12)
		-- Separate rotational speeds keep the well visibly turbulent while one pulsing core marks its damage center.
		vortex.model:PivotTo(center)
		vortex.outerRing:PivotTo(center * CFrame.Angles(0, -age * 0.72, 0))
		vortex.innerRing:PivotTo(center * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, age * 1.85, 0))
		local corePulse = 0.9 + (math.sin(age * 7) + 1) * 0.08
		vortex.core.Size = Vector3.new(vortex.coreSize * corePulse, 0.32, vortex.coreSize * corePulse)
		if vortex.coreLight.Parent then
			vortex.coreLight.Brightness = vortex.coreBrightness * (0.82 + corePulse * 0.16)
		end
	end
end

return AdditionalWeaponEffects
