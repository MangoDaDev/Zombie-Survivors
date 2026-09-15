local DirtRenderer = {}

local MINIMUM_DIRT_COUNT = 6
local MAXIMUM_DIRT_COUNT = 56
local DIRT_COUNT_PER_LINEAR_STUD = 3.25
local DIRT_COUNT_VARIANCE = 0.08
local DIRT_COVERAGE_SCALE = 1.35
local DIRT_SIZE_MINIMUM_SCALE = 0.82
local DIRT_SIZE_MAXIMUM_SCALE = 1.18
local MINIMUM_DIRT_DIAMETER = 0.28
local MAXIMUM_FACE_COVERAGE = 1.05
local SURFACE_OFFSET = 0.018
local PLACEMENT_ATTEMPTS = 6
local MINIMUM_SPACING_SCALE = 0.36
local FULL_ROTATION = math.pi * 2
local HealthByPart = setmetatable({}, { __mode = "k" })

type SurfacePart = {
	Part: BasePart,
	Area: number,
}

type Placement = {
	Position: Vector3,
	Diameter: number,
}

local function GetPartSurfaceArea(Part: BasePart): number
	local Size = Part.Size
	return 2 * (Size.X * Size.Y + Size.X * Size.Z + Size.Y * Size.Z)
end

local function GetSurfaceParts(Model: Model): ({ SurfacePart }, number)
	local SurfaceParts = {}
	local TotalArea = 0
	for _, Descendant in Model:GetDescendants() do
		if
			Descendant:IsA("BasePart")
			and Descendant.Name ~= "BoundingBox"
			and Descendant.Name ~= "Dirt"
			and Descendant.Name ~= "Grease"
			and Descendant:FindFirstAncestor("Dirt") == nil
			and Descendant:FindFirstAncestor("Grease") == nil
			and Descendant.Transparency < 1
		then
			local Area = GetPartSurfaceArea(Descendant)
			if Area > 0 then
				TotalArea += Area
				table.insert(SurfaceParts, { Part = Descendant, Area = Area })
			end
		end
	end
	return SurfaceParts, TotalArea
end

local function GetRandomSurfacePart(SurfaceParts: { SurfacePart }, TotalArea: number, RandomGenerator: Random): BasePart
	local Selection = RandomGenerator:NextNumber(0, TotalArea)
	for _, Surface in SurfaceParts do
		Selection -= Surface.Area
		if Selection <= 0 then
			return Surface.Part
		end
	end
	return SurfaceParts[#SurfaceParts].Part
end

local function GetRandomSurfacePoint(Part: BasePart, RandomGenerator: Random): (Vector3, Vector3, number)
	local Size = Part.Size
	local XFaceArea = Size.Y * Size.Z
	local YFaceArea = Size.X * Size.Z
	local ZFaceArea = Size.X * Size.Y
	local Selection = RandomGenerator:NextNumber(0, 2 * (XFaceArea + YFaceArea + ZFaceArea))
	local LocalPosition
	local LocalNormal
	local MaximumFaceDimension

	if Selection <= 2 * XFaceArea then
		local Sign = if Selection <= XFaceArea then -1 else 1
		LocalPosition = Vector3.new(Sign * Size.X / 2, RandomGenerator:NextNumber(-Size.Y / 2, Size.Y / 2), RandomGenerator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(Sign, 0, 0)
		MaximumFaceDimension = math.max(Size.Y, Size.Z)
	elseif Selection <= 2 * (XFaceArea + YFaceArea) then
		local Sign = if Selection <= 2 * XFaceArea + YFaceArea then -1 else 1
		LocalPosition = Vector3.new(RandomGenerator:NextNumber(-Size.X / 2, Size.X / 2), Sign * Size.Y / 2, RandomGenerator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(0, Sign, 0)
		MaximumFaceDimension = math.max(Size.X, Size.Z)
	else
		local Sign = if Selection <= 2 * (XFaceArea + YFaceArea) + ZFaceArea then -1 else 1
		LocalPosition = Vector3.new(RandomGenerator:NextNumber(-Size.X / 2, Size.X / 2), RandomGenerator:NextNumber(-Size.Y / 2, Size.Y / 2), Sign * Size.Z / 2)
		LocalNormal = Vector3.new(0, 0, Sign)
		MaximumFaceDimension = math.max(Size.X, Size.Y)
	end

	return Part.CFrame:PointToWorldSpace(LocalPosition), Part.CFrame:VectorToWorldSpace(LocalNormal), MaximumFaceDimension
end

local function GetPlacement(
	SurfacePart: BasePart,
	RandomGenerator: Random,
	BaseDiameter: number,
	Placements: { Placement }
): (Vector3, Vector3, number)
	local BestPosition
	local BestNormal
	local BestDiameter = BaseDiameter
	local BestClearance = -math.huge

	for _ = 1, PLACEMENT_ATTEMPTS do
		local Position, Normal, MaximumFaceDimension = GetRandomSurfacePoint(SurfacePart, RandomGenerator)
		local Diameter = math.max(
			MINIMUM_DIRT_DIAMETER,
			math.min(BaseDiameter * RandomGenerator:NextNumber(DIRT_SIZE_MINIMUM_SCALE, DIRT_SIZE_MAXIMUM_SCALE), MaximumFaceDimension * MAXIMUM_FACE_COVERAGE)
		)
		local Clearance = math.huge
		for _, Existing in Placements do
			Clearance = math.min(Clearance, (Existing.Position - Position).Magnitude - (Existing.Diameter + Diameter) * MINIMUM_SPACING_SCALE)
		end
		if Clearance > BestClearance then
			BestPosition = Position
			BestNormal = Normal
			BestDiameter = Diameter
			BestClearance = Clearance
		end
		if Clearance >= 0 then
			break
		end
	end

	return BestPosition, BestNormal, BestDiameter
end

function DirtRenderer.GetSuggestedCount(Model: Model, RandomGenerator: Random?): number
	local SurfaceParts, TotalArea = GetSurfaceParts(Model)
	if #SurfaceParts == 0 then
		return 1
	end
	local Variance = if RandomGenerator
		then RandomGenerator:NextNumber(1 - DIRT_COUNT_VARIANCE, 1 + DIRT_COUNT_VARIANCE)
		else 1
	return math.clamp(math.round(math.sqrt(TotalArea) * DIRT_COUNT_PER_LINEAR_STUD * Variance), MINIMUM_DIRT_COUNT, MAXIMUM_DIRT_COUNT)
end

function DirtRenderer.Add(Model: Model, Count: number, HP: number?): Folder?
	DirtRenderer.Clear(Model)
	local SurfaceParts, TotalArea = GetSurfaceParts(Model)
	if #SurfaceParts == 0 or Count <= 0 then
		return nil
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "Dirt"
	Folder.Parent = Model
	local RenderCount = math.min(math.max(1, math.round(Count)), DirtRenderer.GetSuggestedCount(Model))
	local RandomGenerator = Random.new(tonumber(string.byte(Model.Name, 1)) or 1)
	local BaseDiameter = math.max(MINIMUM_DIRT_DIAMETER, math.sqrt(TotalArea / RenderCount) * DIRT_COVERAGE_SCALE)
	local PlacementsByPart: { [BasePart]: { Placement } } = {}
	for _ = 1, RenderCount do
		local SurfacePart = GetRandomSurfacePart(SurfaceParts, TotalArea, RandomGenerator)
		local Placements = PlacementsByPart[SurfacePart]
		if not Placements then
			Placements = {}
			PlacementsByPart[SurfacePart] = Placements
		end
		local Position, Normal, Diameter = GetPlacement(SurfacePart, RandomGenerator, BaseDiameter, Placements)
		table.insert(Placements, { Position = Position, Diameter = Diameter })
		local UpVector = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local Dirt = Instance.new("Part")
		Dirt.Name = "Dirt"
		Dirt.Shape = Enum.PartType.Cylinder
		Dirt.Size = Vector3.new(math.max(0.035, Diameter * 0.045), Diameter, Diameter * RandomGenerator:NextNumber(0.72, 1))
		Dirt.Color = Color3.fromRGB(RandomGenerator:NextInteger(54, 78), RandomGenerator:NextInteger(34, 51), RandomGenerator:NextInteger(20, 34))
		Dirt.Material = Enum.Material.SmoothPlastic
		Dirt.CanCollide = false
		Dirt.CanQuery = false
		Dirt.CanTouch = false
		Dirt.CastShadow = false
		Dirt.Massless = true
		Dirt.CFrame = CFrame.lookAt(Position + Normal * SURFACE_OFFSET, Position + Normal, UpVector)
			* CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(RandomGenerator:NextNumber(0, FULL_ROTATION), 0, 0)
		HealthByPart[Dirt] = { Current = HP or 1, Maximum = HP or 1 }
		Dirt.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = SurfacePart
		Weld.Part1 = Dirt
		Weld.Parent = Dirt
	end
	return Folder
end

function DirtRenderer.GetHealth(Dirt: BasePart): (number, number)
	local Health = HealthByPart[Dirt]
	if not Health then
		return 0, 1
	end
	return Health.Current, Health.Maximum
end

function DirtRenderer.SetHealth(Dirt: BasePart, Health: number)
	local State = HealthByPart[Dirt]
	if State then
		State.Current = Health
	end
end

function DirtRenderer.Clear(Model: Model)
	local Existing = Model:FindFirstChild("Dirt")
	if Existing then
		Existing:Destroy()
	end
end

return DirtRenderer
