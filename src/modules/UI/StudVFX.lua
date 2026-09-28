local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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

	local light = Instance.new("PointLight")
	light.Name = "StudFlashLight"
	light.Color = color
	light.Brightness = math.clamp(radius * 0.5, 0.8, 4)
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

return StudVFX
