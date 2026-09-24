local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local ZombieController = require(script.Parent.Parent.ZombieController)

local BOOMERANG_HOMING_SPEED = 7
local BOOMERANG_RETURN_DISTANCE = 2.6
local BOOMERANG_CORRECTION_SPEED = 18

local ActiveWeaponEffects = {}

local effectsFolder: Folder?
local fireballs = {}
local boomerangs = {}
local burns = {}
local grounds = {}
local random = Random.new()

local function isFiniteNumber(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function prepareModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
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

local function addTrail(part: BasePart, rage: boolean, fire: boolean): Trail
	local front = Instance.new("Attachment")
	front.Name = "TrailFront"
	front.Position = Vector3.new(0, 0, 0.6)
	front.Parent = part
	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, 0, -0.6)
	back.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "AbilityTrail"
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = if fire
		then ColorSequence.new(Color3.fromRGB(255, 244, 107), Color3.fromRGB(255, 62, 18))
		elseif rage
		then ColorSequence.new(Color3.fromRGB(255, 242, 116), Color3.fromRGB(255, 105, 38))
		else ColorSequence.new(Color3.fromRGB(255, 230, 130), Color3.fromRGB(255, 157, 55))
	trail.LightEmission = if rage then 0.85 else 0.75
	trail.Lifetime = if rage then 0.3 else 0.2
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new(0.12, 1)
	trail.WidthScale = NumberSequence.new(if rage then 1.3 else 1, 0)
	trail.Parent = part
	return trail
end

local function createFireballModel(scale: number, rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild("Fireball")
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.Name = "FireballProjectile"
	prepareModel(model)
	model:ScaleTo(scale)
	local primaryPart = getFirstPart(model)
	if not primaryPart then
		model:Destroy()
		return nil
	end
	addTrail(primaryPart, rage, true)
	local highlight = Instance.new("Highlight")
	highlight.Name = "FireballGlow"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = if rage then Color3.fromRGB(255, 68, 18) else Color3.fromRGB(255, 126, 31)
	highlight.FillTransparency = if rage then 0.46 else 0.58
	highlight.OutlineColor = Color3.fromRGB(255, 239, 126)
	highlight.OutlineTransparency = if rage then 0.22 else 0.2
	highlight.Parent = model
	model.Parent = effectsFolder
	return model
end

local function createBoomerangFallback(): Model
	local model = Instance.new("Model")
	model.Name = "BoomerangProjectile"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Parent = model
	model.PrimaryPart = core
	for index, sign in { -1, 1 } do
		local arm = Instance.new("WedgePart")
		arm.Name = "Arm" .. index
		arm.Size = Vector3.new(1.8, 0.28, 0.65)
		arm.Material = Enum.Material.Neon
		arm.Color = if sign < 0 then Color3.fromRGB(255, 184, 55) else Color3.fromRGB(255, 119, 30)
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.CFrame = CFrame.new(sign * 0.72, 0, 0.18) * CFrame.Angles(0, math.rad(sign * 28), 0)
		arm.Parent = model
	end
	return model
end

local function createBoomerangModel(scale: number, rage: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild("Boomerang")
	local model = if template and template:IsA("Model") then template:Clone() else createBoomerangFallback()
	if not getFirstPart(model) then
		model:Destroy()
		model = createBoomerangFallback()
	end
	model.Name = "BoomerangProjectile"
	prepareModel(model)
	model:ScaleTo(scale)
	local primaryPart = getFirstPart(model)
	if not primaryPart then
		model:Destroy()
		return nil
	end
	addTrail(primaryPart, rage, false)
	if rage then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 126, 35)
		light.Brightness = 1.2
		light.Range = 5.5
		light.Parent = primaryPart
	end
	model.Parent = effectsFolder
	return model
end

local function makeSphere(name: string, position: Vector3, color: Color3, size: number, transparency: number): Part?
	if not effectsFolder then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.one * size
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = position
	part.Parent = effectsFolder
	return part
end

local function pulseScreen()
	local blur = Instance.new("BlurEffect")
	blur.Name = "FireballImpactBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local grow = TweenService:Create(blur, TweenInfo.new(0.06), { Size = 1.35 })
	local fade = TweenService:Create(blur, TweenInfo.new(0.14), { Size = 0 })
	grow.Completed:Connect(function()
		if blur.Parent then
			fade:Play()
		end
	end)
	grow:Play()
	Debris:AddItem(blur, 0.25)
end

local function playExplosion(position: Vector3, radius: number, rage: boolean, empowered: boolean)
	local color = if rage then Color3.fromRGB(255, 64, 15) else Color3.fromRGB(255, 123, 28)
	local flash = makeSphere("FireballImpact", position, Color3.fromRGB(255, 235, 123), 1.2, 0.05)
	if flash then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = if rage or empowered then 3.2 else 2
		light.Range = radius * 1.5
		light.Parent = flash
		TweenService:Create(
			flash,
			TweenInfo.new(if rage then 0.32 else 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * radius * 2, Transparency = 1 }
		):Play()
		Sounds.Play("FlameBurst", flash, 130)
		Debris:AddItem(flash, 0.4)
	end
	local wave = makeSphere("FireballShockwave", position, color, 0.8, 0.4)
	if wave then
		TweenService:Create(
			wave,
			TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.one * radius * 2.35, Transparency = 1 }
		):Play()
		Debris:AddItem(wave, 0.45)
	end
	if radius >= 10 or rage or empowered then
		pulseScreen()
	end
end

local function createLightningPiece(
	fromPosition: Vector3,
	toPosition: Vector3,
	color: Color3,
	thickness: number,
	transparency: number,
	lifetime: number,
	name: string
)
	if not effectsFolder then
		return
	end
	local offset = toPosition - fromPosition
	if offset.Magnitude <= 0.001 then
		return
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(thickness, thickness, offset.Magnitude)
	part.CFrame = CFrame.lookAt(fromPosition:Lerp(toPosition, 0.5), toPosition)
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = effectsFolder
	TweenService:Create(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, lifetime + 0.05)
end

local function createJaggedLightningPoints(fromPosition: Vector3, toPosition: Vector3, rage: boolean, branch: boolean)
	local offset = toPosition - fromPosition
	local length = offset.Magnitude
	local direction = offset.Unit
	local reference = if math.abs(direction:Dot(Vector3.yAxis)) < 0.92 then Vector3.yAxis else Vector3.xAxis
	local side = direction:Cross(reference).Unit
	local vertical = direction:Cross(side).Unit
	local pieceCount = math.clamp(math.floor(length / 5) + 2, 3, if branch then 5 else 7)
	local maximumJitter = math.min(math.max(length * 0.11, 0.5), if rage then 2.8 else 2.2)
	if branch then
		maximumJitter *= 0.65
	end

	local points = { fromPosition }
	for pieceIndex = 1, pieceCount - 1 do
		local alpha = pieceIndex / pieceCount
		-- Tapering the random offset at both ends keeps every bolt connected while giving its middle a unique silhouette.
		local envelope = math.sin(alpha * math.pi)
		local sidewaysOffset = random:NextNumber(-maximumJitter, maximumJitter) * envelope
		local verticalOffset = random:NextNumber(-maximumJitter * 0.65, maximumJitter * 0.65) * envelope
		table.insert(
			points,
			fromPosition:Lerp(toPosition, alpha) + side * sidewaysOffset + vertical * verticalOffset
		)
	end
	table.insert(points, toPosition)
	return points
end

local function drawLightningPolyline(points, rage: boolean, branch: boolean, addVisualFork: boolean)
	local baseColor = if rage then Color3.fromRGB(255, 205, 65) else Color3.fromRGB(68, 184, 255)
	local hotColor = if rage then Color3.fromRGB(255, 250, 173) else Color3.fromRGB(224, 249, 255)
	local thickness = if branch then 0.085 else if rage then 0.19 else 0.13
	local lifetime = random:NextNumber(if rage then 0.18 else 0.14, if rage then 0.25 else 0.2)
	local name = if branch then "LightningBranch" else "LightningBolt"

	for pointIndex = 2, #points do
		local fromPosition = points[pointIndex - 1]
		local toPosition = points[pointIndex]
		local colorMix = random:NextNumber(0.18, 0.62)
		local coreColor = baseColor:Lerp(hotColor, colorMix)
		-- A short-lived soft shell makes the thin randomized core read clearly without flashing the whole screen.
		createLightningPiece(
			fromPosition,
			toPosition,
			baseColor,
			thickness * 3.2,
			0.72,
			lifetime + 0.05,
			name .. "Glow"
		)
		createLightningPiece(
			fromPosition,
			toPosition,
			coreColor,
			thickness * random:NextNumber(0.82, 1.18),
			random:NextNumber(0, 0.12),
			lifetime,
			name
		)
	end

	if addVisualFork and #points >= 4 then
		local forkIndex = random:NextInteger(2, #points - 1)
		local forkOrigin = points[forkIndex]
		local incoming = (forkOrigin - points[forkIndex - 1]).Unit
		local side = incoming:Cross(if math.abs(incoming.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
		local forkDirection = (side * random:NextNumber(-1, 1) + Vector3.yAxis * random:NextNumber(-0.35, 0.75)).Unit
		local forkEnd = forkOrigin + forkDirection * random:NextNumber(1.6, if rage then 4.2 else 3.1)
		local forkPoints = createJaggedLightningPoints(forkOrigin, forkEnd, rage, true)
		drawLightningPolyline(forkPoints, rage, true, false)
	end
end

local function drawLightningSegment(fromPosition: Vector3, toPosition: Vector3, rage: boolean, branch: boolean)
	if not effectsFolder then
		return
	end
	local offset = toPosition - fromPosition
	if offset.Magnitude <= 0.001 then
		return
	end
	local points = createJaggedLightningPoints(fromPosition, toPosition, rage, branch)
	drawLightningPolyline(points, rage, branch, not branch and random:NextNumber() <= (if rage then 0.8 else 0.45))
end

local function playLightningImpact(position: Vector3, rage: boolean, final: boolean)
	local flash = makeSphere(
		"LightningImpact",
		position + Vector3.new(0, 1.2, 0),
		if rage then Color3.fromRGB(255, 238, 105) else Color3.fromRGB(118, 220, 255),
		if final then 1.8 else 1,
		0.12
	)
	if flash then
		local light = Instance.new("PointLight")
		light.Color = flash.Color
		light.Brightness = if final then 3.4 else if rage then 2.6 else 2
		light.Range = if final then 8.5 else 6.5
		light.Parent = flash
		TweenService:Create(flash, TweenInfo.new(0.16), {
			Size = Vector3.one * (if final then 4.2 else 2.5),
			Transparency = 1,
		}):Play()
		Debris:AddItem(flash, 0.22)
	end

	local sparkCount = if final then 6 else if rage then 4 else 3
	for _ = 1, sparkCount do
		local direction = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(0.1, 1),
			random:NextNumber(-1, 1)
		).Unit
		local sparkEnd = position + Vector3.new(0, 1.2, 0) + direction * random:NextNumber(0.8, if final then 3.5 else 2.2)
		createLightningPiece(
			position + Vector3.new(0, 1.2, 0),
			sparkEnd,
			if rage then Color3.fromRGB(255, 233, 116) else Color3.fromRGB(185, 238, 255),
			if final then 0.1 else 0.07,
			0.08,
			random:NextNumber(0.1, 0.17),
			"LightningImpactSpark"
		)
	end
end

local function advanceBoomerangStep(projectile, deltaTime: number)
	if projectile.phase == "Outward" then
		local stepDistance = math.min(projectile.outwardSpeed * deltaTime, projectile.range - projectile.phaseDistance)
		projectile.position += projectile.direction * math.max(stepDistance, 0)
		projectile.phaseDistance += math.max(stepDistance, 0)
		if projectile.phaseDistance >= projectile.range then
			projectile.phase = "Turning"
			projectile.turnElapsed = 0
			projectile.turnStartPosition = projectile.position
			projectile.turnStartDirection = projectile.direction
		end
	elseif projectile.phase == "Turning" then
		projectile.turnElapsed = math.min(projectile.turnElapsed + deltaTime, projectile.turnDuration)
		local alpha = projectile.turnElapsed / projectile.turnDuration
		local angle = alpha * math.pi
		local side = Vector3.new(-projectile.turnStartDirection.Z, 0, projectile.turnStartDirection.X)
			* projectile.turnSide
		projectile.position = projectile.turnStartPosition
			+ projectile.turnStartDirection * math.sin(angle) * projectile.turnRadius
			+ side * (1 - math.cos(angle)) * projectile.turnRadius
		if alpha >= 1 then
			projectile.phase = "Return"
			projectile.direction = -projectile.turnStartDirection
		end
	else
		local owner = Players:GetPlayerByUserId(projectile.ownerUserId)
		local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = root.Position + Vector3.new(0, 1.3, 0) - projectile.position
			if offset.Magnitude > BOOMERANG_RETURN_DISTANCE then
				local desiredDirection = offset.Unit
				local blended = projectile.direction:Lerp(
					desiredDirection,
					math.clamp(deltaTime * BOOMERANG_HOMING_SPEED, 0, 1)
				)
				projectile.direction = if blended.Magnitude > 0.001 then blended.Unit else desiredDirection
				projectile.position += projectile.direction * projectile.returnSpeed * deltaTime
			end
		end
	end
end

local function advanceBoomerang(projectile, deltaTime: number)
	-- Timestamp catch-up is subdivided so homing and turns remain stable after delayed packets.
	local remaining = math.clamp(deltaTime, 0, 2)
	while remaining > 0.0001 do
		local step = math.min(remaining, 1 / 30)
		advanceBoomerangStep(projectile, step)
		remaining -= step
	end
end

function ActiveWeaponEffects.Init(folder: Folder)
	effectsFolder = folder
end

function ActiveWeaponEffects.FireballSpawned(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3"
		or packet.direction.Magnitude <= 0.001
		or not isFiniteNumber(packet.speed)
		or packet.speed <= 0
		or not isFiniteNumber(packet.maximumDistance)
		or packet.maximumDistance <= 0
		or not isFiniteNumber(packet.scale)
		or packet.scale <= 0
		or not isFiniteNumber(packet.launchAt)
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local model = createFireballModel(packet.scale, packet.rage)
	if not model then
		return
	end
	model:PivotTo(CFrame.new(packet.startPosition))
	fireballs[packet.id] = {
		model = model,
		ownerUserId = packet.ownerUserId,
		startPosition = packet.startPosition,
		direction = packet.direction.Unit,
		speed = packet.speed,
		maximumDistance = packet.maximumDistance,
		launchAt = packet.launchAt,
	}
end

function ActiveWeaponEffects.FireballExploded(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or type(packet.rage) ~= "boolean"
		or type(packet.empowered) ~= "boolean"
	then
		return
	end
	local projectile = fireballs[packet.id]
	if projectile then
		projectile.model:Destroy()
		fireballs[packet.id] = nil
	end
	playExplosion(packet.position, packet.radius, packet.rage, packet.empowered)
end

function ActiveWeaponEffects.FireballBurnApplied(packet)
	if type(packet) ~= "table"
		or type(packet.targetId) ~= "number"
		or not isFiniteNumber(packet.duration)
		or packet.duration <= 0
		or type(packet.rage) ~= "boolean"
		or not effectsFolder
	then
		return
	end
	local burn = burns[packet.targetId]
	if not burn then
		local holder = Instance.new("Part")
		holder.Name = "ZombieBurn"
		holder.Size = Vector3.new(0.1, 0.1, 0.1)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Parent = effectsFolder
		local flame = Instance.new("Fire")
		flame.Color = if packet.rage then Color3.fromRGB(255, 229, 92) else Color3.fromRGB(255, 128, 32)
		flame.SecondaryColor = Color3.fromRGB(255, 44, 10)
		flame.Heat = 3
		flame.Size = if packet.rage then 4.5 else 3.25
		flame.Parent = holder
		burn = { holder = holder }
		burns[packet.targetId] = burn
	end
	burn.expiresAt = os.clock() + packet.duration
end

function ActiveWeaponEffects.FireballBurnEnded(targetId)
	if type(targetId) ~= "number" then
		return
	end
	local burn = burns[targetId]
	if burn then
		burn.holder:Destroy()
		burns[targetId] = nil
	end
end

function ActiveWeaponEffects.FireballGroundCreated(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or not isFiniteNumber(packet.duration)
		or packet.duration <= 0
		or type(packet.rage) ~= "boolean"
		or not effectsFolder
	then
		return
	end
	local area = Instance.new("Part")
	area.Name = "BurningGround"
	area.Shape = Enum.PartType.Cylinder
	area.Material = Enum.Material.Neon
	area.Color = if packet.rage then Color3.fromRGB(255, 72, 15) else Color3.fromRGB(255, 116, 26)
	area.Transparency = 0.48
	area.Size = Vector3.new(0.14, packet.radius * 2, packet.radius * 2)
	area.CFrame = CFrame.new(packet.position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	area.Anchored = true
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	area.CastShadow = false
	area.Parent = effectsFolder
	local light = Instance.new("PointLight")
	light.Color = area.Color
	light.Brightness = if packet.rage then 1.15 else 0.65
	light.Range = packet.radius * (if packet.rage then 1.15 else 1)
	light.Parent = area
	grounds[packet.id] = {
		part = area,
		ownerUserId = packet.ownerUserId,
		expiresAt = os.clock() + packet.duration,
	}
end

function ActiveWeaponEffects.FireballGroundRemoved(id)
	if type(id) ~= "number" then
		return
	end
	local ground = grounds[id]
	if ground then
		TweenService:Create(ground.part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		Debris:AddItem(ground.part, 0.25)
		grounds[id] = nil
	end
end

function ActiveWeaponEffects.LightningCast(packet)
	if type(packet) ~= "table"
		or type(packet.ownerUserId) ~= "number"
		or type(packet.chains) ~= "table"
		or type(packet.branches) ~= "table"
		or type(packet.rage) ~= "boolean"
		or type(packet.powerful) ~= "boolean"
	then
		return
	end
	local soundParent
	for _, chain in packet.chains do
		if type(chain) ~= "table" or type(chain.points) ~= "table" then
			continue
		end
		local points = chain.points
		if packet.rage and typeof(points[1]) == "Vector3" then
			local aura = makeSphere("LightningRageAura", points[1], Color3.fromRGB(96, 205, 255), 2, 0.72)
			if aura then
				TweenService:Create(aura, TweenInfo.new(0.2), { Size = Vector3.one * 7, Transparency = 1 }):Play()
				Debris:AddItem(aura, 0.25)
			end
		end
		if chain.fromAbove == true and typeof(points[2]) == "Vector3" then
			drawLightningSegment(points[2] + Vector3.new(0, 24, 0), points[2], packet.rage, false)
		end
		for index = 2, #points do
			local fromPosition = points[index - 1]
			local toPosition = points[index]
			if typeof(fromPosition) == "Vector3" and typeof(toPosition) == "Vector3" then
				drawLightningSegment(fromPosition, toPosition, packet.rage, false)
				playLightningImpact(toPosition, packet.rage, index == #points)
				if not soundParent then
					soundParent = makeSphere("LightningSound", toPosition, Color3.new(1, 1, 1), 0.1, 1)
				end
			end
		end
	end
	for _, branch in packet.branches do
		if type(branch) == "table" and typeof(branch[1]) == "Vector3" and typeof(branch[2]) == "Vector3" then
			drawLightningSegment(branch[1], branch[2], packet.rage, true)
			playLightningImpact(branch[2], packet.rage, false)
		end
	end
	if soundParent then
		Sounds.Play(if packet.powerful then "MagicSpell" else "FreezeRayShoot", soundParent, 140)
		Debris:AddItem(soundParent, 1)
	end
end

function ActiveWeaponEffects.BoomerangSpawned(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3"
		or packet.direction.Magnitude <= 0.001
		or not isFiniteNumber(packet.range)
		or packet.range <= 0
		or not isFiniteNumber(packet.outwardSpeed)
		or packet.outwardSpeed <= 0
		or not isFiniteNumber(packet.returnSpeed)
		or packet.returnSpeed <= 0
		or not isFiniteNumber(packet.turnDuration)
		or packet.turnDuration <= 0
		or not isFiniteNumber(packet.turnRadius)
		or packet.turnRadius <= 0
		or (packet.turnSide ~= -1 and packet.turnSide ~= 1)
		or not isFiniteNumber(packet.scale)
		or packet.scale <= 0
		or not isFiniteNumber(packet.serverTime)
		or type(packet.rage) ~= "boolean"
	then
		return
	end
	local model = createBoomerangModel(packet.scale, packet.rage)
	if not model then
		return
	end
	local projectile = {
		model = model,
		ownerUserId = packet.ownerUserId,
		position = packet.startPosition,
		visualPosition = packet.startPosition,
		direction = packet.direction.Unit,
		visualDirection = packet.direction.Unit,
		phase = "Outward",
		phaseDistance = 0,
		range = packet.range,
		outwardSpeed = packet.outwardSpeed,
		returnSpeed = packet.returnSpeed,
		turnDuration = packet.turnDuration,
		turnRadius = packet.turnRadius,
		turnElapsed = 0,
		turnSide = packet.turnSide,
		spin = 0,
		rage = packet.rage,
	}
	-- Gameplay has already advanced on the server; catch up the cosmetic state without granting client authority.
	advanceBoomerang(projectile, Workspace:GetServerTimeNow() - packet.serverTime)
	model:PivotTo(CFrame.lookAt(projectile.visualPosition, projectile.visualPosition + projectile.visualDirection))
	boomerangs[packet.id] = projectile
	Sounds.Play("Swoosh", model.PrimaryPart, 120)
end

function ActiveWeaponEffects.BoomerangPhaseChanged(packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.phase) ~= "string"
		or typeof(packet.position) ~= "Vector3"
		or typeof(packet.direction) ~= "Vector3"
		or not isFiniteNumber(packet.range)
		or not isFiniteNumber(packet.turnRadius)
		or packet.turnRadius <= 0
		or not isFiniteNumber(packet.serverTime)
	then
		return
	end
	local projectile = boomerangs[packet.id]
	if not projectile then
		return
	end
	if packet.phase ~= "Turning" and packet.phase ~= "Return" and packet.phase ~= "BonusLoop" then
		return
	end
	projectile.position = packet.position
	projectile.direction = packet.direction.Magnitude > 0.001 and packet.direction.Unit or projectile.direction
	projectile.turnRadius = packet.turnRadius
	if packet.phase == "Turning" then
		projectile.phase = "Turning"
		projectile.turnElapsed = 0
		projectile.turnStartPosition = packet.position
		projectile.turnStartDirection = projectile.direction
	elseif packet.phase == "Return" then
		projectile.phase = "Return"
		local trail = projectile.model:FindFirstChild("AbilityTrail", true)
		if trail and trail:IsA("Trail") then
			trail.Lifetime = if projectile.rage then 0.42 else 0.3
			trail.WidthScale = NumberSequence.new(if projectile.rage then 1.75 else 1.3, 0)
		end
		Sounds.Play("SlowSwoosh", projectile.model.PrimaryPart, 120)
	elseif packet.phase == "BonusLoop" then
		projectile.phase = "Outward"
		projectile.phaseDistance = 0
		projectile.range = packet.range
	end
	-- Correct logical state to the authoritative phase, then visually blend instead of snapping under latency.
	advanceBoomerang(projectile, Workspace:GetServerTimeNow() - packet.serverTime)
end

function ActiveWeaponEffects.BoomerangHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" or type(packet.rage) ~= "boolean" then
		return
	end
	local flash = makeSphere(
		"BoomerangHit",
		packet.position,
		if packet.rage then Color3.fromRGB(255, 217, 87) else Color3.fromRGB(255, 161, 49),
		0.55,
		0.1
	)
	if flash then
		TweenService:Create(flash, TweenInfo.new(0.12), { Size = Vector3.one * 1.6, Transparency = 1 }):Play()
		Sounds.Play("BulletHit", flash, 90)
		Debris:AddItem(flash, 0.18)
	end
end

function ActiveWeaponEffects.BoomerangEnded(id)
	if type(id) ~= "number" then
		return
	end
	local projectile = boomerangs[id]
	if projectile then
		projectile.model:Destroy()
		boomerangs[id] = nil
	end
end

function ActiveWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
	if type(ownerUserId) ~= "number" or type(abilityId) ~= "string" then
		return
	end
	if abilityId == "Fireball" then
		for id, projectile in fireballs do
			if projectile.ownerUserId == ownerUserId then
				projectile.model:Destroy()
				fireballs[id] = nil
			end
		end
		for id, ground in grounds do
			if ground.ownerUserId == ownerUserId then
				ground.part:Destroy()
				grounds[id] = nil
			end
		end
	elseif abilityId == "Boomerang" then
		for id, projectile in boomerangs do
			if projectile.ownerUserId == ownerUserId then
				projectile.model:Destroy()
				boomerangs[id] = nil
			end
		end
	end
end

function ActiveWeaponEffects.Render(now: number, deltaTime: number)
	for id, projectile in fireballs do
		if not projectile.model.Parent then
			fireballs[id] = nil
			continue
		end
		local elapsed = math.max(now - projectile.launchAt, 0)
		local distance = math.min(elapsed * projectile.speed, projectile.maximumDistance)
		local position = projectile.startPosition + projectile.direction * distance
		projectile.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, elapsed * 3.2, 0))
	end

	for id, projectile in boomerangs do
		if not projectile.model.Parent then
			boomerangs[id] = nil
			continue
		end
		advanceBoomerang(projectile, math.min(deltaTime, 0.1))
		local correctionAlpha = 1 - math.exp(-BOOMERANG_CORRECTION_SPEED * math.min(deltaTime, 0.1))
		projectile.visualPosition = projectile.visualPosition:Lerp(projectile.position, correctionAlpha)
		local visualDirection = projectile.visualDirection:Lerp(projectile.direction, correctionAlpha)
		projectile.visualDirection = if visualDirection.Magnitude > 0.001 then visualDirection.Unit else projectile.direction
		projectile.spin += deltaTime * (if projectile.rage then 16 else 12)
		local facing = CFrame.lookAt(
			projectile.visualPosition,
			projectile.visualPosition + projectile.visualDirection
		)
		projectile.model:PivotTo(facing * CFrame.Angles(0, 0, projectile.spin))
	end

	local localNow = os.clock()
	for targetId, burn in burns do
		if localNow >= burn.expiresAt then
			burn.holder:Destroy()
			burns[targetId] = nil
		else
			local position = ZombieController.GetZombieWorldPosition(targetId)
			if position then
				burn.holder.Position = position + Vector3.new(0, 1.4, 0)
			end
		end
	end
	for id, ground in grounds do
		if localNow >= ground.expiresAt then
			ground.part:Destroy()
			grounds[id] = nil
		end
	end
end

return ActiveWeaponEffects
