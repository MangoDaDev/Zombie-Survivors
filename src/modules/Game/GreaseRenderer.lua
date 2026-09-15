local GreaseRenderer = {}
local MinimumPatchCount = 12
local MaximumPatchCount = 108
local PatchCountPerLinearStud = 7.2
local PatchCoverageScale = 0.68
local PatchSizeMinimumScale = 0.82
local PatchSizeMaximumScale = 1.18
local MinimumPatchDiameter = 0.1
local MaximumFaceCoverage = 0.5
local PlacementAttempts = 5
local MinimumSpacingScale = 0.42
local SurfaceOffset = 0.012
local FullRotation = math.pi * 2
local PatchStates = setmetatable({}, { __mode = "k" })

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

local function GetSurfacePoint(Part: BasePart, Generator: Random): (Vector3, Vector3, number)
	local Size = Part.Size
	local XArea = Size.Y * Size.Z
	local YArea = Size.X * Size.Z
	local ZArea = Size.X * Size.Y
	local Selection = Generator:NextNumber(0, 2 * (XArea + YArea + ZArea))
	local LocalPosition
	local LocalNormal
	local MaximumFaceDimension
	if Selection <= 2 * XArea then
		local Sign = if Selection <= XArea then -1 else 1
		LocalPosition = Vector3.new(Sign * Size.X / 2, Generator:NextNumber(-Size.Y / 2, Size.Y / 2), Generator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(Sign, 0, 0)
		MaximumFaceDimension = math.max(Size.Y, Size.Z)
	elseif Selection <= 2 * (XArea + YArea) then
		local Sign = if Selection <= 2 * XArea + YArea then -1 else 1
		LocalPosition = Vector3.new(Generator:NextNumber(-Size.X / 2, Size.X / 2), Sign * Size.Y / 2, Generator:NextNumber(-Size.Z / 2, Size.Z / 2))
		LocalNormal = Vector3.new(0, Sign, 0)
		MaximumFaceDimension = math.max(Size.X, Size.Z)
	else
		local Sign = if Selection <= 2 * (XArea + YArea) + ZArea then -1 else 1
		LocalPosition = Vector3.new(Generator:NextNumber(-Size.X / 2, Size.X / 2), Generator:NextNumber(-Size.Y / 2, Size.Y / 2), Sign * Size.Z / 2)
		LocalNormal = Vector3.new(0, 0, Sign)
		MaximumFaceDimension = math.max(Size.X, Size.Y)
	end
	return Part.CFrame:PointToWorldSpace(LocalPosition), Part.CFrame:VectorToWorldSpace(LocalNormal), MaximumFaceDimension
end

function GreaseRenderer.GetSuggestedCount(Model: Model, Generator: Random?): number
	local SurfaceParts, TotalArea = GetSurfaceParts(Model)
	if #SurfaceParts == 0 then return 1 end
	local Variance = if Generator then Generator:NextNumber(0.92, 1.08) else 1
	return math.clamp(math.round(math.sqrt(TotalArea) * PatchCountPerLinearStud * Variance), MinimumPatchCount, MaximumPatchCount)
end

function GreaseRenderer.Add(Model: Model, Count: number, HP: number, Color: Color3, Transparency: number): Folder?
	GreaseRenderer.Clear(Model)
	local SurfaceParts, TotalArea = GetSurfaceParts(Model)
	if #SurfaceParts == 0 or Count <= 0 then return nil end
	local Folder = Instance.new("Folder")
	Folder.Name = "Grease"
	Folder.Parent = Model
	local RenderCount = math.min(math.max(1, math.round(Count)), GreaseRenderer.GetSuggestedCount(Model))
	local BaseDiameter = math.max(MinimumPatchDiameter, math.sqrt(TotalArea / RenderCount) * PatchCoverageScale)
	local Generator = Random.new((tonumber(string.byte(Model.Name, 1)) or 1) * 313)
	local PlacementsByPart = {}
	for _ = 1, RenderCount do
		local SurfacePart = SelectSurfacePart(SurfaceParts, TotalArea, Generator)
		local Placements = PlacementsByPart[SurfacePart] or {}
		PlacementsByPart[SurfacePart] = Placements
		local Position
		local Normal
		local Diameter
		local BestClearance = -math.huge
		for _ = 1, PlacementAttempts do
			local CandidatePosition, CandidateNormal, MaximumFaceDimension = GetSurfacePoint(SurfacePart, Generator)
			local CandidateDiameter = math.max(MinimumPatchDiameter, math.min(
				BaseDiameter * Generator:NextNumber(PatchSizeMinimumScale, PatchSizeMaximumScale),
				MaximumFaceDimension * MaximumFaceCoverage
			))
			local Clearance = math.huge
			for _, Existing in Placements do
				Clearance = math.min(Clearance, (Existing.Position - CandidatePosition).Magnitude - (Existing.Diameter + CandidateDiameter) * MinimumSpacingScale)
			end
			if Clearance > BestClearance then
				Position = CandidatePosition
				Normal = CandidateNormal
				Diameter = CandidateDiameter
				BestClearance = Clearance
			end
			if Clearance >= 0 then break end
		end
		table.insert(Placements, { Position = Position, Diameter = Diameter })
		local UpVector = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local Patch = Instance.new("Part")
		Patch.Name = "Grease"
		Patch.Shape = Enum.PartType.Cylinder
		Patch.Anchored = false
		Patch.CanCollide = false
		Patch.CanQuery = true
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
		PatchStates[Patch] = {
			BaseTransparency = Transparency,
			CurrentHealth = HP,
			MaximumHealth = HP,
		}
		Patch.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = SurfacePart
		Weld.Part1 = Patch
		Weld.Parent = Patch
	end
	return Folder
end

function GreaseRenderer.Damage(Patch: BasePart, Damage: number): boolean
	local State = PatchStates[Patch]
	if not State then return false end
	local HP = State.CurrentHealth
	local MaximumHP = State.MaximumHealth
	local NewHP = math.max(0, HP - Damage)
	State.CurrentHealth = NewHP
	local BaseTransparency = State.BaseTransparency
	Patch.Transparency = BaseTransparency + (1 - BaseTransparency) * (1 - NewHP / math.max(MaximumHP, 0.001))
	if HP > 0 and NewHP <= 0 then Patch:Destroy(); return true end
	return false
end

function GreaseRenderer.GetHealth(Patch: BasePart): (number, number)
	local State = PatchStates[Patch]

	if not State then
		return 0, 1
	end

	return State.CurrentHealth, State.MaximumHealth
end

function GreaseRenderer.Clear(Model: Model)
	local Existing = Model:FindFirstChild("Grease")
	if Existing then Existing:Destroy() end
end

return GreaseRenderer
