local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local TAU = math.pi * 2
local HORIZONTAL_ORIENTATION = CFrame.Angles(math.rad(90), 0, 0)

local OrbitingSwordsView = {}

local effectsFolder: Folder?
local views = {}
local releasedBlades = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function destroyView(userId: number)
	local view = views[userId]
	if not view then
		return
	end
	for _, sword in view.models do
		sword.model:Destroy()
	end
	views[userId] = nil
end

local function addSpectralTrail(model: Model, rage: boolean, inner: boolean)
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		return
	end
	local halfLength = primaryPart.Size.Y * 0.38
	local top = Instance.new("Attachment")
	top.Name = "SpectralTrailTop"
	top.Position = Vector3.new(0, halfLength, 0)
	top.Parent = primaryPart
	local bottom = Instance.new("Attachment")
	bottom.Name = "SpectralTrailBottom"
	bottom.Position = Vector3.new(0, -halfLength, 0)
	bottom.Parent = primaryPart
	local trail = Instance.new("Trail")
	trail.Name = "SpectralTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = if rage
		then ColorSequence.new(Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 63, 35))
		elseif inner
		then ColorSequence.new(Color3.fromRGB(164, 245, 255), Color3.fromRGB(88, 126, 255))
		else ColorSequence.new(Color3.fromRGB(220, 205, 255), Color3.fromRGB(116, 91, 255))
	trail.LightEmission = 0.9
	trail.Lifetime = if rage then 0.24 else 0.16
	trail.MinLength = 0.08
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(if inner then 0.7 else 1, 0)
	trail.Parent = primaryPart
end

local function cloneSword(scale: number, rage: boolean, inner: boolean, temporary: boolean): Model?
	if not effectsFolder then
		return nil
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild("Sword")
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	model.Name = if inner then "InnerOrbitSword" elseif temporary then "RageOrbitSword" else "OrbitSword"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if descendant.Name ~= "Hitbox" then
				descendant.Material = Enum.Material.Neon
				descendant.Transparency = math.max(descendant.Transparency, if temporary then 0.3 else 0.16)
				descendant.Color = if rage
					then descendant.Color:Lerp(Color3.fromRGB(255, 79, 38), 0.48)
					else descendant.Color:Lerp(Color3.fromRGB(137, 119, 255), if inner then 0.58 else 0.4)
			end
		end
	end
	model:ScaleTo(scale)
	addSpectralTrail(model, rage, inner)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SpectralGlow"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = if rage then Color3.fromRGB(255, 75, 32) else Color3.fromRGB(125, 105, 255)
	highlight.FillTransparency = if temporary then 0.64 else 0.76
	highlight.OutlineColor = if rage then Color3.fromRGB(255, 231, 124) else Color3.fromRGB(207, 235, 255)
	highlight.OutlineTransparency = 0.18
	highlight.Parent = model
	model.Parent = effectsFolder
	return model
end

local function rebuildView(view)
	for _, sword in view.models do
		sword.model:Destroy()
	end
	view.models = {}
	local packet = view.packet
	for swordIndex = 1, packet.mainSwordCount do
		local model = cloneSword(packet.swordScale, packet.rage, false, false)
		if model then
			table.insert(view.models, { model = model, kind = "Main", index = swordIndex })
		end
	end
	for swordIndex = 1, packet.additionalSwordCount do
		local model = cloneSword(packet.swordScale * 0.92, true, false, true)
		if model then
			table.insert(view.models, { model = model, kind = "Rage", index = swordIndex })
		end
	end
	if packet.innerOrbit then
		local model = cloneSword(packet.innerScale, packet.rage, true, false)
		if model then
			table.insert(view.models, { model = model, kind = "Inner", index = 1 })
		end
	end
	view.visualSignature = string.format(
		"%d:%d:%.4f:%d:%d",
		packet.mainSwordCount,
		packet.additionalSwordCount,
		packet.swordScale,
		packet.innerOrbit and 1 or 0,
		packet.rage and 1 or 0
	)
end

local function emitReleaseImpact(position: Vector3, rage: boolean)
	if not effectsFolder then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "ReleasedSwordImpact"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Transparency = 1
	holder.Position = position
	holder.Parent = effectsFolder
	for _, child in ReplicatedStorage.Assets.VFX.CriticalHit.Impact:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			emitter.Color = if rage
				then ColorSequence.new(Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 65, 32))
				else ColorSequence.new(Color3.fromRGB(211, 200, 255), Color3.fromRGB(105, 91, 255))
			emitter.Parent = holder
			emitter:Emit(if child.Name == "Flash" then 1 else 8)
		end
	end
	Sounds.Play("BulletHit", holder, 110)
	Debris:AddItem(holder, 2)
end

function OrbitingSwordsView.Init(folder: Folder)
	effectsFolder = folder
	for _, view in views do
		rebuildView(view)
	end
end

function OrbitingSwordsView.ApplyState(packet): boolean
	if type(packet) ~= "table"
		or type(packet.ownerUserId) ~= "number"
		or packet.ownerUserId % 1 ~= 0
		or type(packet.active) ~= "boolean"
		or type(packet.sequence) ~= "number"
		or packet.sequence % 1 ~= 0
	then
		return false
	end

	local existing = views[packet.ownerUserId]
	if existing and packet.sequence <= existing.sequence then
		return false
	end
	if not packet.active then
		destroyView(packet.ownerUserId)
		return true
	end
	if not isFiniteNumber(packet.serverTime)
		or not isFiniteNumber(packet.angle)
		or not isFiniteNumber(packet.rotationSpeed)
		or packet.rotationSpeed <= 0
		or packet.rotationSpeed > 20
		or not isFiniteNumber(packet.orbitRadius)
		or packet.orbitRadius <= 0
		or packet.orbitRadius > 30
		or not isFiniteNumber(packet.swordScale)
		or packet.swordScale <= 0
		or packet.swordScale > 2
		or type(packet.mainSwordCount) ~= "number"
		or packet.mainSwordCount % 1 ~= 0
		or packet.mainSwordCount < 1
		or packet.mainSwordCount > 6
		or type(packet.additionalSwordCount) ~= "number"
		or packet.additionalSwordCount % 1 ~= 0
		or packet.additionalSwordCount < 0
		or packet.additionalSwordCount > 4
		or type(packet.innerOrbit) ~= "boolean"
		or not isFiniteNumber(packet.innerRadius)
		or not isFiniteNumber(packet.innerScale)
		or type(packet.rage) ~= "boolean"
	then
		return false
	end

	local view = existing or { models = {} }
	view.sequence = packet.sequence
	view.packet = packet
	views[packet.ownerUserId] = view
	local signature = string.format(
		"%d:%d:%.4f:%d:%d",
		packet.mainSwordCount,
		packet.additionalSwordCount,
		packet.swordScale,
		packet.innerOrbit and 1 or 0,
		packet.rage and 1 or 0
	)
	if signature ~= view.visualSignature then
		rebuildView(view)
	end
	return true
end

function OrbitingSwordsView.SpawnReleased(packet): boolean
	if type(packet) ~= "table"
		or type(packet.ownerUserId) ~= "number"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.targetPosition) ~= "Vector3"
		or not isFiniteNumber(packet.launchAt)
		or not isFiniteNumber(packet.outwardDuration)
		or packet.outwardDuration <= 0
		or packet.outwardDuration > 1
		or not isFiniteNumber(packet.scale)
		or packet.scale <= 0
		or packet.scale > 2
		or type(packet.rage) ~= "boolean"
	then
		return false
	end
	local model = cloneSword(packet.scale, packet.rage, false, true)
	if not model then
		return false
	end
	table.insert(releasedBlades, {
		model = model,
		ownerUserId = packet.ownerUserId,
		startPosition = packet.startPosition,
		targetPosition = packet.targetPosition,
		launchAt = packet.launchAt,
		outwardDuration = packet.outwardDuration,
		rage = packet.rage,
		impacted = false,
	})
	return true
end

function OrbitingSwordsView.Render(now: number)
	for userId, view in views do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player then
			destroyView(userId)
		elseif root and root:IsA("BasePart") then
			local packet = view.packet
			local angle = packet.angle + (now - packet.serverTime) * packet.rotationSpeed
			local center = root.Position + Vector3.new(0, 1.2, 0)
			for _, sword in view.models do
				local swordAngle
				local radius
				if sword.kind == "Main" then
					swordAngle = angle + TAU * (sword.index - 1) / packet.mainSwordCount
					radius = packet.orbitRadius
				elseif sword.kind == "Rage" then
					local gapIndex = math.floor((sword.index - 1) * packet.mainSwordCount / packet.additionalSwordCount) + 1
					swordAngle = angle + TAU * (gapIndex - 0.5) / packet.mainSwordCount
					radius = packet.orbitRadius
				else
					swordAngle = -angle * 1.35
					radius = packet.innerRadius
				end
				local radial = Vector3.new(math.cos(swordAngle), 0, math.sin(swordAngle))
				local tangent = Vector3.new(-radial.Z, 0, radial.X)
				local position = center + radial * radius
				-- The authored sword's blade runs along local Y; pitch it onto the ground plane while orbiting.
				sword.model:PivotTo(CFrame.lookAt(position, position + tangent) * HORIZONTAL_ORIENTATION)
			end
		end
	end

	for index = #releasedBlades, 1, -1 do
		local blade = releasedBlades[index]
		local elapsed = now - blade.launchAt
		local outwardAlpha = math.clamp(elapsed / blade.outwardDuration, 0, 1)
		local player = Players:GetPlayerByUserId(blade.ownerUserId)
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local returnPosition = if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.2, 0) else blade.startPosition
		local position
		local targetDirection
		if elapsed <= blade.outwardDuration then
			position = blade.startPosition:Lerp(blade.targetPosition, outwardAlpha)
			targetDirection = blade.targetPosition
		else
			if not blade.impacted then
				blade.impacted = true
				emitReleaseImpact(blade.targetPosition, blade.rage)
			end
			local returnAlpha = math.clamp((elapsed - blade.outwardDuration) / blade.outwardDuration, 0, 1)
			position = blade.targetPosition:Lerp(returnPosition, returnAlpha)
			targetDirection = returnPosition
		end
		position += Vector3.yAxis * math.sin(math.clamp(elapsed / (blade.outwardDuration * 2), 0, 1) * math.pi) * 0.8
		local flightDirection = targetDirection - position
		if flightDirection.Magnitude < 0.001 then
			flightDirection = Vector3.zAxis
		end
		blade.model:PivotTo(CFrame.lookAt(position, position + flightDirection) * CFrame.Angles(0, 0, elapsed * 8))
		if elapsed >= blade.outwardDuration * 2 then
			blade.model:Destroy()
			table.remove(releasedBlades, index)
		end
	end
end

return OrbitingSwordsView
