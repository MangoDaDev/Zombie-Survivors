local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ItemInteractionConfig = require(script.Parent.ItemInteractionConfig)

local SurfacePlacement = {}
local ExcludedRestorationFolders = {
	Bent = true,
	BentComponents = true,
	Dirt = true,
	Grease = true,
	LightDust = true,
	LooseDebris = true,
	Metal = true,
	MetalComponents = true,
}

export type SurfacePart = {
	Area: number,
	Part: BasePart,
}

export type Placement = {
	MaximumFaceDimension: number,
	Normal: Vector3,
	Part: BasePart,
	Position: Vector3,
}

local function IsUsablePart(Part: Instance): boolean
	local Current = Part.Parent
	while Current do
		if ExcludedRestorationFolders[Current.Name] then return false end
		Current = Current.Parent
	end
	return Part:IsA("BasePart")
		and Part.Name ~= "BoundingBox"
		and Part.Transparency < 1
end

local function GetSurfaceArea(Part: BasePart): number
	local Size = Part.Size
	return 2 * (Size.X * Size.Y + Size.X * Size.Z + Size.Y * Size.Z)
end

local function GetMaximumFaceDimension(Part: BasePart, WorldNormal: Vector3): number
	local LocalNormal = Part.CFrame:VectorToObjectSpace(WorldNormal)
	local Size = Part.Size
	if math.abs(LocalNormal.X) >= math.abs(LocalNormal.Y) and math.abs(LocalNormal.X) >= math.abs(LocalNormal.Z) then
		return math.max(Size.Y, Size.Z)
	elseif math.abs(LocalNormal.Y) >= math.abs(LocalNormal.Z) then
		return math.max(Size.X, Size.Z)
	end
	return math.max(Size.X, Size.Y)
end

local function SelectSurfacePart(SurfaceParts: { SurfacePart }, TotalArea: number, Generator: Random): BasePart
	local Selection = Generator:NextNumber(0, TotalArea)
	for _, Surface in SurfaceParts do
		Selection -= Surface.Area
		if Selection <= 0 then return Surface.Part end
	end
	return SurfaceParts[#SurfaceParts].Part
end

local function GetCandidate(Part: BasePart, Generator: Random): (Vector3, Vector3)
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

function SurfacePlacement.GetSurfaceParts(Model: Model): ({ SurfacePart }, number)
	local SurfaceParts = {}
	local TotalArea = 0
	for _, Descendant in Model:GetDescendants() do
		if not IsUsablePart(Descendant) then continue end
		local Area = GetSurfaceArea(Descendant)
		if Area <= 0 then continue end
		TotalArea += Area
		table.insert(SurfaceParts, { Area = Area, Part = Descendant })
	end
	return SurfaceParts, TotalArea
end

function SurfacePlacement.Begin(Model: Model, SurfaceParts: { SurfacePart })
	local OriginalParent = Model.Parent
	local TemporaryWorld: WorldModel?
	local WorldRoot = Model:FindFirstAncestorWhichIsA("WorldRoot")
	if not WorldRoot then
		TemporaryWorld = Instance.new("WorldModel")
		TemporaryWorld.Name = "SurfacePlacementWorld"
		TemporaryWorld.Parent = if RunService:IsServer() then game:GetService("ServerStorage") else Workspace
		Model.Parent = TemporaryWorld
		WorldRoot = TemporaryWorld
	end

	local QueryStates = {}
	local Filter = {}
	for _, Surface in SurfaceParts do
		local Part = Surface.Part
		QueryStates[Part] = Part.CanQuery
		Part.CanQuery = true
		table.insert(Filter, Part)
	end

	local Parameters = RaycastParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Include
	Parameters.FilterDescendantsInstances = Filter
	Parameters.IgnoreWater = true
	local _, BoundingSize = Model:GetBoundingBox()
	local RayLength = BoundingSize.Magnitude + 2

	local Context = {
		Model = Model,
		Parameters = Parameters,
		RayLength = RayLength,
		WorldRoot = WorldRoot,
	}

	local function Finish()
		for Part, CanQuery in QueryStates do
			if Part.Parent then Part.CanQuery = CanQuery end
		end
		if TemporaryWorld then
			Model.Parent = OriginalParent
			TemporaryWorld:Destroy()
		end
	end

	return Context, Finish
end

function SurfacePlacement.GetPlacement(Context, SurfaceParts: { SurfacePart }, TotalArea: number, Generator: Random): Placement?
	if #SurfaceParts == 0 or TotalArea <= 0 then return nil end
	for _ = 1, ItemInteractionConfig.SurfacePlacementAttempts do
		local SelectedPart = SelectSurfacePart(SurfaceParts, TotalArea, Generator)
		local CandidatePosition, CandidateNormal = GetCandidate(SelectedPart, Generator)
		local Origin = CandidatePosition + CandidateNormal * Context.RayLength
		local Result = Context.WorldRoot:Raycast(Origin, -CandidateNormal * (Context.RayLength + 0.25), Context.Parameters)
		if not Result or not Result.Instance:IsA("BasePart") then continue end
		if Result.Normal:Dot(CandidateNormal) < 0.45 then continue end
		return {
			MaximumFaceDimension = GetMaximumFaceDimension(Result.Instance, Result.Normal),
			Normal = Result.Normal.Unit,
			Part = Result.Instance,
			Position = Result.Position,
		}
	end
	return nil
end

return SurfacePlacement
