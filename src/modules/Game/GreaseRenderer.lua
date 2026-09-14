local GreaseRenderer = {}
local PatchDensity = 4.5
local PatchCountVariance = 0.1
local PatchSize = 0.22 * 1.6
local PatchSizeMinimumScale = 0.7
local PatchSizeMaximumScale = 1.3
local SurfaceOffset = 0.012
local FullRotation = math.pi * 2

type SurfacePart = {
	Part: BasePart,
	Area: number,
}

local function GetSurfaceArea(Part: BasePart): number
	local Size = Part.Size
	return 2 * (Size.X * Size.Y + Size.X * Size.Z + Size.Y * Size.Z)
end

local function GetSurfaceParts(Model: Model): ({ SurfacePart }, number)
	local SurfaceParts = {}
	local TotalArea = 0
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart")
			and Descendant.Name ~= "BoundingBox"
			and Descendant.Name ~= "Dirt"
			and Descendant.Name ~= "Grease"
			and Descendant:FindFirstAncestor("Dirt") == nil
			and Descendant:FindFirstAncestor("Grease") == nil
			and Descendant.Transparency < 1
			and Descendant:GetAttribute("NoGrease") ~= true
		then
			local Area = GetSurfaceArea(Descendant)
			if Area > 0 then
				TotalArea += Area
				table.insert(SurfaceParts, { Part = Descendant, Area = Area })
			end
		end
	end
	return SurfaceParts, TotalArea
end

local function SelectSurfacePart(SurfaceParts: { SurfacePart }, TotalArea: number, Generator: Random): BasePart
	local Selection = Generator:NextNumber(0, TotalArea)
	for _, Surface in SurfaceParts do
		Selection -= Surface.Area
		if Selection <= 0 then return Surface.Part end
	end
	return SurfaceParts[#SurfaceParts].Part
end

local function GetSurfacePoint(Part: BasePart, Generator: Random): (Vector3, Vector3)
	local Size = Part.Size
	local XArea = Size.Y * Size.Z
	local YArea = Size.X * Size.Z
	local ZArea = Size.X * Size.Y
	local Selection = Generator:NextNumber(0, 2 * (XArea + YArea + ZArea))
	local LocalPosition
	local LocalNormal
	if Selection <= 2 * XArea then
		local Sign = if Selection <= XArea then -1 else 1
		LocalPosition = Vector3.new(Sign * Size.X / 2, Generator:NextNumber(-Size.Y / 2, Size.Y / 2), Generator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(Sign, 0, 0)
	elseif Selection <= 2 * (XArea + YArea) then
		local Sign = if Selection <= 2 * XArea + YArea then -1 else 1
		LocalPosition = Vector3.new(Generator:NextNumber(-Size.X / 2, Size.X / 2), Sign * Size.Y / 2, Generator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(0, Sign, 0)
	else
		local Sign = if Selection <= 2 * (XArea + YArea) + ZArea then -1 else 1
		LocalPosition = Vector3.new(Generator:NextNumber(-Size.X / 2, Size.X / 2), Generator:NextNumber(-Size.Y / 2, Size.Y / 2), Sign * Size.Z / 2)
		LocalNormal = Vector3.new(0, 0, Sign)
	end
	return Part.CFrame:PointToWorldSpace(LocalPosition), Part.CFrame:VectorToWorldSpace(LocalNormal)
end

function GreaseRenderer.GetSuggestedCount(Model: Model, Generator: Random?): number
	local _, TotalArea = GetSurfaceParts(Model)
	local RandomGenerator = Generator or Random.new()
	local Variance = RandomGenerator:NextNumber(1 - PatchCountVariance, 1 + PatchCountVariance)
	return math.max(1, math.round(TotalArea * PatchDensity * Variance))
end

function GreaseRenderer.Add(Model: Model, Count: number, HP: number, Color: Color3, Transparency: number): Folder?
	GreaseRenderer.Clear(Model)
	local SurfaceParts, TotalArea = GetSurfaceParts(Model)
	if #SurfaceParts == 0 or Count <= 0 then return nil end
	local Folder = Instance.new("Folder")
	Folder.Name = "Grease"
	Folder.Parent = Model
	local Generator = Random.new((tonumber(string.byte(Model.Name, 1)) or 1) * 313)
	for _ = 1, Count do
		local SurfacePart = SelectSurfacePart(SurfaceParts, TotalArea, Generator)
		local Position, Normal = GetSurfacePoint(SurfacePart, Generator)
		local Diameter = PatchSize * Generator:NextNumber(PatchSizeMinimumScale, PatchSizeMaximumScale)
		local UpVector = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local Patch = Instance.new("Part")
		Patch.Name = "Grease"
		Patch.Shape = Enum.PartType.Cylinder
		Patch.Anchored = false
		Patch.CanCollide = false
		Patch.CanQuery = false
		Patch.CanTouch = false
		Patch.CastShadow = false
		Patch.Massless = true
		Patch.Color = Color
		Patch.Material = Enum.Material.SmoothPlastic
		Patch.Size = Vector3.new(0.02, Diameter, Diameter)
		Patch.Transparency = Transparency
		Patch.CFrame = CFrame.lookAt(Position + Normal * SurfaceOffset, Position + Normal, UpVector)
			* CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(Generator:NextNumber(0, FullRotation), 0, 0)
		Patch:SetAttribute("HP", HP)
		Patch:SetAttribute("MaxHP", HP)
		Patch:SetAttribute("BaseTransparency", Transparency)
		Patch.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = SurfacePart
		Weld.Part1 = Patch
		Weld.Parent = Patch
	end
	return Folder
end

function GreaseRenderer.Damage(Patch: BasePart, Damage: number): boolean
	local HP = Patch:GetAttribute("HP")
	local MaximumHP = Patch:GetAttribute("MaxHP")
	if type(HP) ~= "number" or type(MaximumHP) ~= "number" then return false end
	local NewHP = math.max(0, HP - Damage)
	Patch:SetAttribute("HP", NewHP)
	local BaseTransparency = Patch:GetAttribute("BaseTransparency") or 0.25
	Patch.Transparency = BaseTransparency + (1 - BaseTransparency) * (1 - NewHP / math.max(MaximumHP, 0.001))
	if HP > 0 and NewHP <= 0 then Patch:Destroy(); return true end
	return false
end

function GreaseRenderer.Clear(Model: Model)
	local Existing = Model:FindFirstChild("Grease")
	if Existing then Existing:Destroy() end
end

return GreaseRenderer
