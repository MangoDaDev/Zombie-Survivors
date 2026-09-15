local DirtRenderer = {}

local DirtSize = 0.22 * 1.6
local DirtSizeMinimumScale = 0.7
local DirtSizeMaximumScale = 1.3
local DirtDensity = 4.5
local DirtCountVariance = 0.1
local FullRotation = math.pi * 2
local HealthByPart = setmetatable({}, { __mode = "k" })

type SurfacePart = {
	Part: BasePart,
	Area: number,
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
			and Descendant.Name ~= "Grease"
			and Descendant:FindFirstAncestor("Grease") == nil
			and Descendant.Transparency < 1
		then
			local Area = GetPartSurfaceArea(Descendant)
			if Area > 0 then
				TotalArea += Area
				table.insert(SurfaceParts, {
					Part = Descendant,
					Area = Area,
				})
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

local function GetRandomSurfaceCFrame(Part: BasePart, RandomGenerator: Random, SurfaceOffset: number): CFrame
	local Size = Part.Size
	local XFaceArea = Size.Y * Size.Z
	local YFaceArea = Size.X * Size.Z
	local ZFaceArea = Size.X * Size.Y
	local Selection = RandomGenerator:NextNumber(0, 2 * (XFaceArea + YFaceArea + ZFaceArea))
	local Position
	local Normal

	if Selection <= 2 * XFaceArea then
		local Sign = if Selection <= XFaceArea then -1 else 1
		Position = Vector3.new(Sign * Size.X / 2, RandomGenerator:NextNumber(-Size.Y / 2, Size.Y / 2), RandomGenerator:NextNumber(-Size.Z / 2, Size.Z / 2))
		Normal = Vector3.new(Sign, 0, 0)
	elseif Selection <= 2 * (XFaceArea + YFaceArea) then
		local Sign = if Selection <= 2 * XFaceArea + YFaceArea then -1 else 1
		Position = Vector3.new(RandomGenerator:NextNumber(-Size.X / 2, Size.X / 2), Sign * Size.Y / 2, RandomGenerator:NextNumber(-Size.Z / 2, Size.Z / 2))
		Normal = Vector3.new(0, Sign, 0)
	else
		local Sign = if Selection <= 2 * (XFaceArea + YFaceArea) + ZFaceArea then -1 else 1
		Position = Vector3.new(RandomGenerator:NextNumber(-Size.X / 2, Size.X / 2), RandomGenerator:NextNumber(-Size.Y / 2, Size.Y / 2), Sign * Size.Z / 2)
		Normal = Vector3.new(0, 0, Sign)
	end

	return Part.CFrame
		* CFrame.new(Position + Normal * SurfaceOffset * 0.4)
		* CFrame.Angles(
			RandomGenerator:NextNumber(0, FullRotation),
			RandomGenerator:NextNumber(0, FullRotation),
			RandomGenerator:NextNumber(0, FullRotation)
		)
end

function DirtRenderer.GetSuggestedCount(Model: Model, RandomGenerator: Random?): number
	local _, TotalArea = GetSurfaceParts(Model)
	local Generator = RandomGenerator or Random.new()
	local Variance = Generator:NextNumber(1 - DirtCountVariance, 1 + DirtCountVariance)
	return math.max(1, math.round(TotalArea * DirtDensity * Variance))
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
	local RandomGenerator = Random.new(tonumber(string.byte(Model.Name, 1)) or 1)
	for _ = 1, Count do
		local SurfacePart = GetRandomSurfacePart(SurfaceParts, TotalArea, RandomGenerator)
		local DirtScale = Vector3.new(
			RandomGenerator:NextNumber(DirtSizeMinimumScale, DirtSizeMaximumScale),
			RandomGenerator:NextNumber(DirtSizeMinimumScale, DirtSizeMaximumScale),
			RandomGenerator:NextNumber(DirtSizeMinimumScale, DirtSizeMaximumScale)
		)
		local DirtDimensions = DirtScale * DirtSize
		local Dirt = Instance.new("Part")
		Dirt.Name = "Dirt"
		Dirt.Shape = Enum.PartType.Block
		Dirt.Size = DirtDimensions
		Dirt.Color = Color3.fromRGB(
			RandomGenerator:NextInteger(67, 88),
			RandomGenerator:NextInteger(43, 58),
			RandomGenerator:NextInteger(27, 39)
		)
		Dirt.Material = Enum.Material.Plastic
		Dirt.CanCollide = false
		Dirt.CanQuery = false
		Dirt.CanTouch = false
		Dirt.Massless = true
		Dirt.CFrame = GetRandomSurfaceCFrame(
			SurfacePart,
			RandomGenerator,
			math.max(DirtDimensions.X, DirtDimensions.Y, DirtDimensions.Z)
		)
		HealthByPart[Dirt] = {
			Current = HP or 1,
			Maximum = HP or 1,
		}
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
	if Existing then Existing:Destroy() end
end

return DirtRenderer
