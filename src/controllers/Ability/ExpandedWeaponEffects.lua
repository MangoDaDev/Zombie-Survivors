local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local ExpandedWeaponEffects = {}
local TAU = math.pi * 2

local effectsFolder: Folder?
local buzzsaws = {}
local crushers = {}
local lasers = {}
local random = Random.new()

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

local function flash(position: Vector3, color: Color3, radius: number, duration: number)
	if not effectsFolder then return end
	local part = makeBlock("ExpandedAbilityFlash", Vector3.one * 0.18, color:Lerp(Color3.new(1, 1, 1), 0.5), 0.06)
	part.CFrame = CFrame.new(position)
	part.Parent = effectsFolder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = math.clamp(radius * 0.5, 1.2, 4)
	light.Range = math.max(radius * 1.5, 5)
	light.Parent = part
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(duration), { Brightness = 0 }):Play()
	Debris:AddItem(part, duration + 0.05)
	return part
end

local function burstStuds(position: Vector3, color: Color3, count: number, distance: number, duration: number)
	if not effectsFolder then return end
	for index = 1, count do
		local angle = TAU * (index - 1) / count + random:NextNumber(-0.12, 0.12)
		local direction = Vector3.new(math.cos(angle), random:NextNumber(0.12, 0.42), math.sin(angle)).Unit
		local stud = makeBlock("ImpactStud", Vector3.new(0.22, 0.22, random:NextNumber(0.5, 0.95)), color, 0.05)
		stud.CFrame = CFrame.lookAt(position + direction * 0.3, position + direction)
		stud.Parent = effectsFolder
		TweenService:Create(stud, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(position + direction * distance, position + direction * (distance + 1)),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.22),
		}):Play()
		Debris:AddItem(stud, duration + 0.05)
	end
end

local function tracer(origin: Vector3, destination: Vector3, color: Color3, width: number, duration: number)
	if not effectsFolder then return end
	local offset = destination - origin
	if offset.Magnitude < 0.1 then return end
	for layer = 1, 2 do
		local layerWidth = if layer == 1 then width * 2.4 else width
		local part = makeBlock(
			if layer == 1 then "CrossfireGlow" else "CrossfireCore",
			Vector3.new(layerWidth, layerWidth, offset.Magnitude),
			if layer == 1 then color else color:Lerp(Color3.new(1, 1, 1), 0.58),
			if layer == 1 then 0.68 else 0.04
		)
		part.CFrame = CFrame.lookAt(origin:Lerp(destination, 0.5), destination)
		part.Parent = effectsFolder
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(layerWidth * 0.2, layerWidth * 0.2, offset.Magnitude),
		}):Play()
		Debris:AddItem(part, duration + 0.05)
	end
end

local function createBuzzsawModel(radius: number, rage: boolean, overcharged: boolean): Model?
	if not effectsFolder then return nil end
	local model = Instance.new("Model")
	model.Name = "Buzzsaw"
	local color = if overcharged then Color3.fromRGB(239, 103, 255)
		elseif rage then Color3.fromRGB(255, 110, 35) else Color3.fromRGB(164, 182, 205)
	local hub = makeBlock("Hub", Vector3.new(radius * 0.7, 0.34, radius * 0.7), Color3.fromRGB(52, 62, 82))
	hub.Parent = model
	model.PrimaryPart = hub
	for index = 1, 12 do
		local angle = TAU * (index - 1) / 12
		local tooth = makeBlock("SawTooth", Vector3.new(radius * 0.3, 0.28, radius * 0.82), color)
		tooth.CFrame = CFrame.new(math.cos(angle) * radius * 0.72, 0, math.sin(angle) * radius * 0.72)
			* CFrame.Angles(0, -angle, 0)
		tooth.Parent = model
	end
	for index = 1, 4 do
		local angle = TAU * (index - 1) / 4
		local spoke = makeBlock("SawSpoke", Vector3.new(radius * 0.3, 0.31, radius * 0.9), Color3.fromRGB(75, 88, 111))
		spoke.CFrame = CFrame.new(math.cos(angle) * radius * 0.28, 0, math.sin(angle) * radius * 0.28)
			* CFrame.Angles(0, -angle, 0)
		spoke.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function createWall(name: string, length: number, rage: boolean, overcharged: boolean): Model?
	if not effectsFolder then return nil end
	local model = Instance.new("Model")
	model.Name = name
	local color = if overcharged then Color3.fromRGB(231, 104, 255)
		elseif rage then Color3.fromRGB(199, 102, 255) else Color3.fromRGB(95, 89, 126)
	local base = makeBlock("CrusherBase", Vector3.new(length, 2.6, 1.15), color, 0.05)
	base.Parent = model
	model.PrimaryPart = base
	for index = 1, math.clamp(math.floor(length / 3), 3, 9) do
		local x = (index - 0.5) / math.clamp(math.floor(length / 3), 3, 9) * length - length * 0.5
		local cap = makeBlock("CrusherStud", Vector3.new(1.5, 0.55, 0.46), color:Lerp(Color3.new(1, 1, 1), 0.18))
		cap.CFrame = CFrame.new(x, 1.5, -0.62)
		cap.Parent = model
	end
	model.Parent = effectsFolder
	return model
end

local function removeOwned(ownerUserId: number, abilityId: string)
	if abilityId == "Buzzsaw" then
		for id, saw in buzzsaws do
			if saw.ownerUserId == ownerUserId then saw.model:Destroy(); buzzsaws[id] = nil end
		end
	elseif abilityId == "Crusher" then
		for id, crusher in crushers do
			if crusher.ownerUserId == ownerUserId then
				crusher.left:Destroy(); crusher.right:Destroy(); crushers[id] = nil
			end
		end
	elseif abilityId == "LaserSweep" then
		for id, laser in lasers do
			if laser.ownerUserId == ownerUserId then
				for _, part in laser.parts do part:Destroy() end
				laser.emitter:Destroy()
				lasers[id] = nil
			end
		end
	end
end

function ExpandedWeaponEffects.Init(folder: Folder)
	effectsFolder = folder
end

function ExpandedWeaponEffects.CrowbarSwung(packet)
	if not effectsFolder or type(packet) ~= "table" or typeof(packet.position) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3" or not finite(packet.reach) or packet.reach <= 0 or packet.reach > 30
		or not finite(packet.arcDegrees) or packet.arcDegrees <= 0 or packet.arcDegrees > 240
	then return end
	local color = if packet.overcharged then Color3.fromRGB(235, 91, 255)
		elseif packet.rage then Color3.fromRGB(255, 150, 53) else Color3.fromRGB(79, 211, 255)
	local directionAngle = math.atan2(packet.direction.Z, packet.direction.X)
	-- A chunky three-block Crowbar silhouette accompanies the energy arc; the model is intentionally
	-- assembled from studded rectangular Parts to match the game's classic construction language.
	local crowbar = Instance.new("Model")
	crowbar.Name = "CrowbarSwing"
	local handleLength = math.clamp(packet.reach * 0.62, 4, 7.5)
	local handle = makeBlock("Handle", Vector3.new(0.48, 0.48, handleLength), Color3.fromRGB(53, 68, 88))
	handle.Parent = crowbar
	crowbar.PrimaryPart = handle
	local hook = makeBlock("Hook", Vector3.new(1.9, 0.48, 0.55), color)
	hook.CFrame = CFrame.new(0.72, 0, -handleLength * 0.48)
	hook.Parent = crowbar
	local tip = makeBlock("Tip", Vector3.new(0.48, 1.05, 0.55), color)
	tip.CFrame = CFrame.new(1.42, -0.28, -handleLength * 0.48)
	tip.Parent = crowbar
	local crowbarCenter = packet.position + packet.direction * math.min(packet.reach * 0.48, 5)
	crowbar:PivotTo(CFrame.lookAt(crowbarCenter, crowbarCenter + packet.direction)
		* CFrame.Angles(math.rad(-18), 0, math.rad(if packet.swingIndex % 2 == 0 then -32 else 32)))
	crowbar.Parent = effectsFolder
	for _, part in crowbar:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
	end
	Debris:AddItem(crowbar, 0.3)
	local segments = 11
	for index = 1, segments do
		local alpha = (index - 1) / math.max(segments - 1, 1)
		local angle = directionAngle + math.rad((-packet.arcDegrees * 0.5) + packet.arcDegrees * alpha)
		local distance = packet.reach * (0.68 + 0.24 * math.sin(alpha * math.pi))
		local segment = makeBlock("CrowbarArcStud", Vector3.new(0.34, 0.34, packet.reach * 0.14), color, 0.08)
		local position = packet.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		segment.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
		segment.Parent = effectsFolder
		TweenService:Create(segment, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(0.12, 0.12, packet.reach * 0.05),
		}):Play()
		Debris:AddItem(segment, 0.3)
	end
	flash(packet.position + packet.direction * math.min(packet.reach * 0.7, 7), color, 2.2, 0.15)
	Sounds.Play(if packet.swingIndex == 1 then "SlowSwoosh" else "Swoosh", crowbar.PrimaryPart, 95)
end

function ExpandedWeaponEffects.CrossfireFired(packet)
	if type(packet) ~= "table" or typeof(packet.origin) ~= "Vector3" or type(packet.endpoints) ~= "table"
		or #packet.endpoints > 12 or not finite(packet.width) or packet.width <= 0 or packet.width > 5 then return end
	local color = if packet.overcharged then Color3.fromRGB(240, 103, 255)
		elseif packet.rage then Color3.fromRGB(255, 232, 91) else Color3.fromRGB(255, 181, 52)
	for _, endpoint in packet.endpoints do
		if typeof(endpoint) == "Vector3" and (endpoint - packet.origin).Magnitude <= 100 then
			tracer(packet.origin, endpoint, color, math.clamp(packet.width * 0.15, 0.14, 0.5), 0.17)
		end
	end
	local originFlash = flash(packet.origin, color, if packet.rage then 3 else 2.2, 0.14)
	if originFlash then Sounds.Play("FreezeRayShoot", originFlash, 110) end
end

function ExpandedWeaponEffects.BuzzsawCreated(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or not finite(packet.radius) or packet.radius <= 0 or packet.radius > 18
		or not finite(packet.duration) or packet.duration <= 0 or packet.duration > 12 then return end
	local model = createBuzzsawModel(packet.radius, packet.rage == true, packet.overcharged == true)
	if not model then return end
	model:PivotTo(CFrame.new(packet.position + Vector3.yAxis * 0.32))
	buzzsaws[packet.id] = {
		model = model, ownerUserId = packet.ownerUserId, position = packet.position,
		createdAt = Workspace:GetServerTimeNow(), expiresAt = Workspace:GetServerTimeNow() + packet.duration,
		rage = packet.rage == true,
	}
	flash(packet.position + Vector3.yAxis * 0.4,
		if packet.overcharged then Color3.fromRGB(240, 101, 255) else Color3.fromRGB(255, 122, 42), 2.4, 0.18)
	burstStuds(packet.position, Color3.fromRGB(255, 191, 76), packet.ricochet and 9 or 6, 3.2, 0.25)
	Sounds.Play("AbilityDrillStart", model.PrimaryPart, 90)
end

function ExpandedWeaponEffects.BuzzsawRemoved(id)
	if not finite(id) then return end
	local saw = buzzsaws[id]
	if saw then
		flash(saw.position + Vector3.yAxis * 0.3, Color3.fromRGB(255, 114, 41), 1.8, 0.14)
		saw.model:Destroy()
		buzzsaws[id] = nil
	end
end

function ExpandedWeaponEffects.CrusherWarned(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3" or not finite(packet.length) or packet.length <= 0 or packet.length > 45
		or not finite(packet.width) or packet.width <= 0 or packet.width > 25 or not finite(packet.impactAt) then return end
	local left = createWall("CrusherLeft", packet.length, packet.rage == true, packet.overcharged == true)
	local right = createWall("CrusherRight", packet.length, packet.rage == true, packet.overcharged == true)
	if not left or not right then if left then left:Destroy() end; if right then right:Destroy() end; return end
	local direction = Vector3.new(packet.direction.X, 0, packet.direction.Z).Unit
	local side = Vector3.yAxis:Cross(direction)
	local rotation = CFrame.lookAt(Vector3.zero, side)
	left:PivotTo(CFrame.new(packet.position - side * packet.width * 0.75 + Vector3.yAxis * 1.25) * rotation.Rotation)
	right:PivotTo(CFrame.new(packet.position + side * packet.width * 0.75 + Vector3.yAxis * 1.25) * rotation.Rotation)
	crushers[packet.id] = {
		left = left, right = right, ownerUserId = packet.ownerUserId, position = packet.position,
		direction = direction, side = side, width = packet.width, impactAt = packet.impactAt,
		createdAt = Workspace:GetServerTimeNow(),
	}
	Sounds.Play("Alert", left.PrimaryPart, 85)
end

function ExpandedWeaponEffects.CrusherImpacted(packet)
	if type(packet) ~= "table" or not finite(packet.id) or typeof(packet.position) ~= "Vector3" then return end
	local crusher = crushers[packet.id]
	if crusher then
		crusher.left:Destroy(); crusher.right:Destroy(); crushers[packet.id] = nil
	end
	local color = if packet.overcharged then Color3.fromRGB(241, 103, 255)
		elseif packet.rage then Color3.fromRGB(224, 145, 255) else Color3.fromRGB(177, 104, 255)
	local impactFlash = flash(packet.position + Vector3.yAxis * 0.75, color, math.min(packet.width * 0.58, 6), 0.28)
	burstStuds(packet.position + Vector3.yAxis * 0.4, color, 14, math.min(packet.width * 0.7, 7), 0.34)
	if impactFlash then Sounds.Play("BodyImpact", impactFlash, 125) end
end

function ExpandedWeaponEffects.CrusherCancelled(id)
	if not finite(id) then return end
	local crusher = crushers[id]
	if crusher then crusher.left:Destroy(); crusher.right:Destroy(); crushers[id] = nil end
end

function ExpandedWeaponEffects.LaserSweepStarted(packet)
	if not effectsFolder or type(packet) ~= "table" or not finite(packet.id) or not finite(packet.ownerUserId)
		or not finite(packet.startedAt) or not finite(packet.duration) or packet.duration <= 0 or packet.duration > 8
		or not finite(packet.range) or packet.range <= 0 or packet.range > 90
		or not finite(packet.width) or packet.width <= 0 or packet.width > 8
		or not finite(packet.rotations) or not finite(packet.beamCount) or not finite(packet.startAngle) then return end
	local parts = {}
	local emitter = Instance.new("Model")
	emitter.Name = "LaserEmitter"
	local emitterBase = makeBlock("EmitterBase", Vector3.new(2.4, 0.45, 2.4), Color3.fromRGB(42, 60, 65))
	emitterBase.Parent = emitter
	emitter.PrimaryPart = emitterBase
	local emitterBody = makeBlock("EmitterBody", Vector3.new(1.45, 0.8, 1.45),
		if packet.overcharged then Color3.fromRGB(224, 83, 255)
		elseif packet.rage then Color3.fromRGB(255, 219, 72) else Color3.fromRGB(67, 225, 112))
	emitterBody.CFrame = CFrame.new(0, 0.6, 0)
	emitterBody.Parent = emitter
	for side = -1, 1, 2 do
		local fin = makeBlock("EmitterFin", Vector3.new(0.38, 0.5, 1.3), Color3.fromRGB(64, 83, 91))
		fin.CFrame = CFrame.new(side * 0.9, 0.32, 0)
		fin.Parent = emitter
	end
	emitter.Parent = effectsFolder
	for beamIndex = 1, math.clamp(math.floor(packet.beamCount), 1, 2) do
		for layer = 1, 2 do
			local width = if layer == 1 then packet.width * 2.25 else packet.width
			local color = if packet.overcharged then Color3.fromRGB(237, 93, 255)
				elseif packet.rage then Color3.fromRGB(255, 235, 91) else Color3.fromRGB(70, 255, 127)
			local part = makeBlock(if layer == 1 then "LaserGlow" else "LaserCore",
				Vector3.new(width, width, packet.range),
				if layer == 1 then color else color:Lerp(Color3.new(1, 1, 1), 0.7),
				if layer == 1 then 0.72 else 0.06)
			part.Parent = effectsFolder
			table.insert(parts, { part = part, beamIndex = beamIndex })
		end
	end
	lasers[packet.id] = {
		parts = parts, emitter = emitter, ownerUserId = packet.ownerUserId, startedAt = packet.startedAt,
		duration = packet.duration, range = packet.range, rotations = packet.rotations,
		beamCount = packet.beamCount, startAngle = packet.startAngle,
	}
	Sounds.Play("FreezeRayShoot", emitter.PrimaryPart, 130)
end

function ExpandedWeaponEffects.LaserSweepEnded(id)
	if not finite(id) then return end
	local laser = lasers[id]
	if laser then
		for _, entry in laser.parts do entry.part:Destroy() end
		laser.emitter:Destroy()
		lasers[id] = nil
	end
end

function ExpandedWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
	if finite(ownerUserId) and type(abilityId) == "string" then removeOwned(ownerUserId, abilityId) end
end

function ExpandedWeaponEffects.Render(now: number, deltaTime: number)
	for id, saw in buzzsaws do
		if not saw.model.Parent or now >= saw.expiresAt + 0.5 then
			ExpandedWeaponEffects.BuzzsawRemoved(id)
		else
			local rotationSpeed = if saw.rage then 14 else 10
			saw.model:PivotTo(saw.model:GetPivot() * CFrame.Angles(0, rotationSpeed * deltaTime, 0))
		end
	end
	for id, crusher in crushers do
		if not crusher.left.Parent or not crusher.right.Parent then
			ExpandedWeaponEffects.CrusherCancelled(id)
		else
			local duration = math.max(crusher.impactAt - crusher.createdAt, 0.1)
			local alpha = math.clamp((now - crusher.createdAt) / duration, 0, 1)
			local eased = alpha * alpha
			local separation = crusher.width * (0.75 - eased * 0.68)
			local rotation = CFrame.lookAt(Vector3.zero, crusher.side).Rotation
			crusher.left:PivotTo(CFrame.new(crusher.position - crusher.side * separation + Vector3.yAxis * 1.25) * rotation)
			crusher.right:PivotTo(CFrame.new(crusher.position + crusher.side * separation + Vector3.yAxis * 1.25) * rotation)
		end
	end
	for id, laser in lasers do
		local owner = Players:GetPlayerByUserId(laser.ownerUserId)
		local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		local alpha = math.clamp((now - laser.startedAt) / laser.duration, 0, 1)
		if alpha >= 1 or not root or not root:IsA("BasePart") then
			ExpandedWeaponEffects.LaserSweepEnded(id)
		else
			laser.emitter:PivotTo(CFrame.new(root.Position + Vector3.yAxis * 0.45))
			for _, entry in laser.parts do
				local angle = laser.startAngle + alpha * laser.rotations * TAU
					+ TAU * (entry.beamIndex - 1) / laser.beamCount
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local origin = root.Position + Vector3.yAxis * 1.2
				entry.part.CFrame = CFrame.lookAt(origin + direction * laser.range * 0.5, origin + direction * laser.range)
			end
		end
	end
end

return ExpandedWeaponEffects
