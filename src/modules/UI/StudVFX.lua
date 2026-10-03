local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EffectLightingConfig = require(ReplicatedStorage.Modules.UI.EffectLightingConfig)

local StudVFX = {}

local TAU = math.pi * 2
local random = Random.new()

local function setStudSurfaces(part: Part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
end

function StudVFX.PreparePart(part: Part): Part
	-- Runtime-built VFX keep this classic stud finish; callers may layer color/transparency but not physical gameplay.
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	setStudSurfaces(part)
	return part
end

function StudVFX.CreateBlock(
	parent: Instance?,
	name: string,
	size: Vector3,
	color: Color3,
	transparency: number?
): Part
	local part = StudVFX.PreparePart(Instance.new("Part"))
	part.Name = name
	part.Size = size
	part.Color = color
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

function StudVFX.Flash(
	parent: Instance?,
	position: Vector3,
	color: Color3,
	radius: number,
	duration: number
): Part?
	if not parent or radius <= 0 or duration <= 0 then
		return nil
	end

	local outer = StudVFX.CreateBlock(
		parent,
		"StudFlashGlow",
		Vector3.one * math.max(radius * 0.16, 0.18),
		color,
		0.58
	)
	outer.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(18), math.rad(32), math.rad(12))

	local core = StudVFX.CreateBlock(
		parent,
		"StudFlashCore",
		Vector3.one * math.max(radius * 0.09, 0.12),
		color:Lerp(Color3.new(1, 1, 1), 0.62),
		0.04
	)
	core.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(-12), math.rad(45), math.rad(25))

	-- Expanding crossed rays give the flash a readable silhouette instead of leaving it as one swelling cube.
	-- Four rays is the shared budget: this helper can fire many times in one frame during dense horde combat.
	for rayIndex = 1, 4 do
		local angle = TAU * (rayIndex - 1) / 4 + math.rad(22.5)
		local direction = Vector3.new(math.cos(angle), 0.18 + (rayIndex % 2) * 0.16, math.sin(angle)).Unit
		local rayLength = math.max(radius * 0.55, 0.45)
		local rayThickness = math.clamp(radius * 0.055, 0.12, 0.42)
		local ray = StudVFX.CreateBlock(
			parent,
			"StudFlashRay",
			Vector3.new(rayThickness, rayThickness, math.max(rayLength * 0.18, 0.2)),
			if rayIndex % 2 == 0 then color:Lerp(Color3.new(1, 1, 1), 0.52) else color,
			0.08
		)
		ray.CFrame = CFrame.lookAt(position + direction * rayLength * 0.08, position + direction)
		TweenService:Create(ray, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(position + direction * rayLength * 0.7, position + direction * rayLength),
			Size = Vector3.new(rayThickness * 0.35, rayThickness * 0.35, rayLength),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ray, duration + 0.05)
	end

	local light = Instance.new("PointLight")
	light.Name = "StudFlashLight"
	light.Color = color
	light.Brightness = EffectLightingConfig.Scale(math.clamp(radius * 0.5, 0.8, 4))
	light.Range = math.clamp(radius * 1.8, 4, 18)
	light.Parent = core

	TweenService:Create(outer, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius,
		Transparency = 1,
	}):Play()
	TweenService:Create(core, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 0.48,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
	}):Play()
	Debris:AddItem(outer, duration + 0.05)
	Debris:AddItem(core, duration + 0.05)
	return core
end

function StudVFX.Impact(
	parent: Instance?,
	position: Vector3,
	color: Color3,
	radius: number,
	duration: number,
	intensity: number?
): Part?
	if not parent or radius <= 0 or duration <= 0 then
		return nil
	end

	local strength = math.clamp(intensity or 1, 0.5, 2)
	local accent = color:Lerp(Color3.new(1, 1, 1), 0.55)
	local anchor = StudVFX.Flash(parent, position + Vector3.yAxis * math.min(radius * 0.08, 0.6), color, radius * 0.7, duration * 0.72)
	StudVFX.Ring(parent, position + Vector3.yAxis * 0.1, color, radius, duration, math.clamp(math.floor(radius * 1.6), 10, 22))
	StudVFX.Burst(
		parent,
		position + Vector3.yAxis * math.min(radius * 0.1, 0.75),
		color,
		math.clamp(math.floor(5 + radius * 0.55 * strength), 6, 18),
		math.min(radius * 0.68, 10),
		duration * 0.9,
		accent
	)

	-- A delayed inner echo gives the impact a second beat without a permanent update loop.
	task.delay(duration * 0.12, function()
		if parent.Parent then
			StudVFX.Ring(parent, position + Vector3.yAxis * 0.18, accent, radius * 0.62, duration * 0.7, 10)
		end
	end)
	return anchor
end

function StudVFX.Burst(
	parent: Instance?,
	position: Vector3,
	color: Color3,
	count: number,
	distance: number,
	duration: number,
	accentColor: Color3?
)
	if not parent or count <= 0 or distance <= 0 or duration <= 0 then
		return
	end

	-- Bound burst density because several enemies or weapons may trigger this helper in the same frame.
	local pieceCount = math.clamp(math.floor(count), 1, 24)
	local highlightColor = accentColor or color:Lerp(Color3.new(1, 1, 1), 0.42)
	for index = 1, pieceCount do
		local angle = TAU * (index - 1) / pieceCount + random:NextNumber(-0.16, 0.16)
		local direction = Vector3.new(
			math.cos(angle),
			random:NextNumber(0.12, 0.58),
			math.sin(angle)
		).Unit
		local length = random:NextNumber(0.5, 1.05)
		local thickness = random:NextNumber(0.18, 0.3)
		local piece = StudVFX.CreateBlock(
			parent,
			"StudBurstPiece",
			Vector3.new(thickness, thickness, length),
			if index % 3 == 0 then highlightColor else color,
			0.04 + random:NextNumber(0, 0.12)
		)
		local startPosition = position + direction * random:NextNumber(0.18, 0.42)
		local endPosition = position + direction * random:NextNumber(distance * 0.72, distance)
		piece.CFrame = CFrame.lookAt(startPosition, startPosition + direction)
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(endPosition, endPosition + direction)
				* CFrame.Angles(0, 0, random:NextNumber(-1.2, 1.2)),
			Size = Vector3.new(thickness * 0.45, thickness * 0.45, length * 0.36),
			Transparency = 1,
		}):Play()
		Debris:AddItem(piece, duration + 0.05)
	end
end

function StudVFX.Ring(
	parent: Instance?,
	position: Vector3,
	color: Color3,
	radius: number,
	duration: number,
	segmentCount: number?
)
	if not parent or radius <= 0 or duration <= 0 then
		return
	end

	local count = math.clamp(math.floor(segmentCount or radius * 1.5), 8, 24)
	local startRadius = math.max(radius * 0.16, 0.35)
	local segmentLength = math.max(TAU * radius / count * 0.72, 0.45)
	for index = 1, count do
		local angle = TAU * (index - 1) / count
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local segment = StudVFX.CreateBlock(
			parent,
			"StudRingSegment",
			Vector3.new(0.28, 0.16, math.max(segmentLength * 0.28, 0.24)),
			if index % 4 == 0 then color:Lerp(Color3.new(1, 1, 1), 0.38) else color,
			0.12
		)
		segment.CFrame = CFrame.new(position + direction * startRadius) * CFrame.Angles(0, -angle, 0)
		TweenService:Create(segment, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + direction * radius) * CFrame.Angles(0, -angle, 0),
			Size = Vector3.new(0.14, 0.08, segmentLength),
			Transparency = 1,
		}):Play()
		Debris:AddItem(segment, duration + 0.05)
	end
end

function StudVFX.Explosion(
	parent: Instance?,
	position: Vector3,
	color: Color3,
	radius: number,
	duration: number,
	intensity: number?,
	accentColor: Color3?
): Part?
	if not parent or radius <= 0 or duration <= 0 then
		return nil
	end

	local strength = math.clamp(intensity or 1, 0.65, 1.8)
	local hotColor = accentColor or color:Lerp(Color3.new(1, 1, 1), 0.72)
	local emberColor = color:Lerp(Color3.fromRGB(92, 24, 8), 0.28)
	local coreHeight = math.clamp(radius * 0.42, 1.4, 6.5)
	local core = StudVFX.CreateBlock(
		parent,
		"StudExplosionCore",
		Vector3.one * math.max(radius * 0.08, 0.3),
		hotColor,
		0.02
	)
	core.CFrame = CFrame.new(position + Vector3.yAxis * coreHeight * 0.28)
		* CFrame.Angles(math.rad(18), math.rad(34), math.rad(-12))

	local light = Instance.new("PointLight")
	light.Name = "StudExplosionLight"
	light.Color = color
	light.Brightness = EffectLightingConfig.Scale(math.clamp(2.4 * strength, 1.5, 5.5))
	light.Range = math.clamp(radius * 1.8, 6, 28)
	light.Parent = core

	-- A stack of offset blocks forms a fast, chunky fireball silhouette instead of an expanding primitive.
	-- Counts stay fixed because explosive passives can chain through a dense horde in the same frame.
	for layerIndex = 1, 6 do
		local alpha = (layerIndex - 1) / 5
		local layerRadius = radius * (0.17 + math.sin(alpha * math.pi) * 0.16)
		local startOffset = Vector3.new(
			random:NextNumber(-0.12, 0.12),
			alpha * coreHeight * 0.18,
			random:NextNumber(-0.12, 0.12)
		)
		local endOffset = Vector3.new(
			random:NextNumber(-0.16, 0.16) * radius,
			alpha * coreHeight,
			random:NextNumber(-0.16, 0.16) * radius
		)
		local layer = StudVFX.CreateBlock(
			parent,
			"StudExplosionLayer",
			Vector3.one * math.max(layerRadius * 0.22, 0.24),
			if layerIndex <= 2 then hotColor else if layerIndex <= 4 then color else emberColor,
			0.04 + alpha * 0.12
		)
		layer.CFrame = CFrame.new(position + startOffset)
			* CFrame.Angles(alpha * 1.8, layerIndex * 0.83, -alpha * 1.1)
		TweenService:Create(
			layer,
			TweenInfo.new(duration * (0.72 + alpha * 0.28), Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.new(position + endOffset)
					* CFrame.Angles(alpha * 3.2, layerIndex * 1.37, alpha * 2.4),
				Size = Vector3.new(layerRadius * 1.25, layerRadius * (1.1 + alpha * 0.45), layerRadius * 1.25),
				Transparency = 1,
			}
		):Play()
		Debris:AddItem(layer, duration + 0.05)
	end

	-- Ground chunks kick outward with an arcing midpoint. Two short tweens make the motion feel weighty
	-- without a frame loop or physics ownership, and the final pieces remain non-queryable presentation.
	local chunkCount = math.clamp(math.floor(6 + strength * 4), 8, 13)
	for chunkIndex = 1, chunkCount do
		local angle = TAU * (chunkIndex - 1) / chunkCount + random:NextNumber(-0.13, 0.13)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local travel = radius * random:NextNumber(0.48, 0.92)
		local chunkSize = math.clamp(radius * random:NextNumber(0.055, 0.1), 0.28, 1.35)
		local chunk = StudVFX.CreateBlock(
			parent,
			"StudExplosionChunk",
			Vector3.new(chunkSize * 1.35, chunkSize * 0.55, chunkSize),
			if chunkIndex % 3 == 0 then hotColor else emberColor,
			0.06
		)
		local startPosition = position + direction * radius * 0.08 + Vector3.yAxis * chunkSize * 0.3
		local peakPosition = position + direction * travel * 0.58
			+ Vector3.yAxis * random:NextNumber(radius * 0.16, radius * 0.34)
		local endPosition = position + direction * travel + Vector3.yAxis * chunkSize * 0.12
		chunk.CFrame = CFrame.new(startPosition) * CFrame.Angles(0, -angle, 0)
		local rise = TweenService:Create(
			chunk,
			TweenInfo.new(duration * 0.46, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(peakPosition) * CFrame.Angles(angle * 1.4, angle, -angle * 0.7) }
		)
		local fall = TweenService:Create(
			chunk,
			TweenInfo.new(duration * 0.54, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				CFrame = CFrame.new(endPosition) * CFrame.Angles(angle * 2.2, -angle * 1.4, angle),
				Size = chunk.Size * 0.58,
				Transparency = 1,
			}
		)
		rise.Completed:Once(function()
			if chunk.Parent then
				fall:Play()
			end
		end)
		rise:Play()
		Debris:AddItem(chunk, duration + 0.08)
	end

	TweenService:Create(core, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		CFrame = core.CFrame * CFrame.Angles(math.rad(55), math.rad(80), math.rad(35)),
		Size = Vector3.new(radius * 0.58, coreHeight * 0.72, radius * 0.58),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
		Range = radius * 0.7,
	}):Play()

	StudVFX.Ring(parent, position + Vector3.yAxis * 0.08, hotColor, radius * 0.72, duration * 0.58, 14)
	StudVFX.Ring(parent, position + Vector3.yAxis * 0.13, color, radius, duration * 0.92, 20)
	StudVFX.Burst(
		parent,
		position + Vector3.yAxis * math.min(radius * 0.16, 1.1),
		color,
		math.clamp(math.floor(8 + radius * 0.45 * strength), 10, 20),
		math.min(radius * 0.82, 14),
		duration * 0.78,
		hotColor
	)
	Debris:AddItem(core, duration + 0.08)
	return core
end

return StudVFX
