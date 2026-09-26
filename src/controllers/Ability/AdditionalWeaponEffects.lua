local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local AdditionalWeaponEffects = {}

local effectsFolder: Folder?
local novaWaves = {}
local groundRings = {}
local bursts = {}
local meteors = {}
local turrets = {}
local vortexes = {}

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function makeBlock(name: string, size: Vector3, color: Color3, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	return part
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

local function pulse(position: Vector3, radius: number, color: Color3, duration: number, soundName: string?)
	local ring = makeRing("AbilityPulse", 1, color, 12)
	if not ring then
		return
	end
	ring:PivotTo(CFrame.new(position + Vector3.yAxis * 0.2))
	ring:ScaleTo(0.2)
	table.insert(bursts, { model = ring, startedAt = os.clock(), duration = duration, radius = radius })
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
	local part = makeBlock("WeaponTracer", Vector3.new(width, width, offset.Magnitude), color, 0.08)
	part.CFrame = CFrame.lookAt(origin:Lerp(destination, 0.5), destination)
	part.Parent = effectsFolder
	TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1, Size = Vector3.new(width * 0.35, width * 0.35, offset.Magnitude) }):Play()
	Debris:AddItem(part, duration + 0.05)
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
	novaWaves[packet.id] = {
		model = model, ownerUserId = packet.ownerUserId,
		startedAt = packet.startedAt or Workspace:GetServerTimeNow(),
		duration = packet.duration, radius = packet.radius,
	}
	Sounds.Play("FreezeRayShoot", model.PrimaryPart, 90)
end

function AdditionalWeaponEffects.FrostShattered(packet)
	if type(packet) == "table" and typeof(packet.position) == "Vector3" then
		pulse(packet.position, 2.5, Color3.fromRGB(190, 244, 255), 0.18, "MetalHitSoft")
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
	Sounds.Play("MetalHitSoft", model.PrimaryPart, 75)
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
	local model = makeRing("Vortex", packet.radius,
		if packet.rage then Color3.fromRGB(206, 143, 255) else Color3.fromRGB(120, 132, 255), 16)
	if not model then return end
	model:PivotTo(CFrame.new(packet.position + Vector3.yAxis * 0.12))
	vortexes[packet.id] = {
		model = model, position = packet.position, ownerUserId = packet.ownerUserId,
		mobile = packet.mobile, radius = packet.radius, createdAt = os.clock(),
	}
	Sounds.Play("MagicSpell", model.PrimaryPart, 80)
end

function AdditionalWeaponEffects.VortexCollapsed(packet)
	if type(packet) == "table" and typeof(packet.position) == "Vector3"
		and finite(packet.radius) and packet.radius > 0 and packet.radius <= 35 then
		pulse(packet.position, packet.radius, Color3.fromRGB(189, 114, 255), 0.35, "BodyImpact")
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
		vortex.model:PivotTo(CFrame.new(vortex.position + Vector3.yAxis * 0.12)
			* CFrame.Angles(0, (os.clock() - vortex.createdAt) * 1.2, 0))
	end
end

return AdditionalWeaponEffects
