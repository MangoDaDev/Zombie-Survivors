local ItemInteractionConfig = require(script.Parent.ItemInteractionConfig)
local SurfacePlacement = require(script.Parent.SurfacePlacement)

local GreaseRenderer = {}
local MinimumPatchCount = 12
local MaximumPatchCount = 108
local PatchCountPerLinearStud = 7.2
local PatchCoverageScale = 0.68
local PatchSizeMinimumScale = 0.82
local PatchSizeMaximumScale = 1.18
local MinimumPatchDiameter = 0.1
local MaximumFaceCoverage = 0.5
local PlacementAttempts = 3
local MinimumSpacingScale = 0.42
local SurfaceOffset = 0.012
local FullRotation = math.pi * 2
local PatchStates = setmetatable({}, { __mode = "k" })

function GreaseRenderer.GetSuggestedCount(Model: Model, Generator: Random?): number
	local SurfaceParts, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	if #SurfaceParts == 0 then return 1 end
	local Variance = if Generator then Generator:NextNumber(0.92, 1.08) else 1
	return math.clamp(math.round(math.sqrt(TotalArea) * PatchCountPerLinearStud * Variance), MinimumPatchCount, MaximumPatchCount)
end

function GreaseRenderer.Add(Model: Model, Count: number, HP: number, Color: Color3, Transparency: number): Folder?
	GreaseRenderer.Clear(Model)
	local SurfaceParts, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	if #SurfaceParts == 0 or Count <= 0 then return nil end
	local Context, FinishPlacement = SurfacePlacement.Begin(Model, SurfaceParts)
	local Folder = Instance.new("Folder")
	Folder.Name = "Grease"
	Folder.Parent = Model
	local RenderCount = math.min(math.max(1, math.round(Count)), GreaseRenderer.GetSuggestedCount(Model))
	local BaseDiameter = math.max(MinimumPatchDiameter, math.sqrt(TotalArea / RenderCount) * PatchCoverageScale)
	local Generator = Random.new((tonumber(string.byte(Model.Name, 1)) or 1) * 313)
	local PlacementsByPart = {}
	for _ = 1, RenderCount do
		local SurfacePart
		local Placements
		local Position
		local Normal
		local Diameter
		local PlacementPart
		local BestClearance = -math.huge
		for _ = 1, PlacementAttempts do
			local Placement = SurfacePlacement.GetPlacement(Context, SurfaceParts, TotalArea, Generator)
			if not Placement then continue end
			SurfacePart = Placement.Part
			Placements = PlacementsByPart[SurfacePart] or {}
			local CandidatePosition = Placement.Position
			local CandidateNormal = Placement.Normal
			local MaximumFaceDimension = Placement.MaximumFaceDimension
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
				PlacementPart = SurfacePart
				BestClearance = Clearance
			end
			if Clearance >= 0 then break end
		end
		if not Position or not Normal or not Diameter or not PlacementPart then continue end
		Placements = PlacementsByPart[PlacementPart] or {}
		PlacementsByPart[PlacementPart] = Placements
		table.insert(Placements, { Position = Position, Diameter = Diameter })
		local TangentReference = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local Tangent = (TangentReference - Normal * TangentReference:Dot(Normal)).Unit
		local Back = Normal:Cross(Tangent).Unit
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
		Patch.CFrame = CFrame.fromMatrix(
			Position + Normal * (Patch.Size.X / 2 + math.max(SurfaceOffset, ItemInteractionConfig.SurfacePlacementOffset)),
			Normal,
			Tangent,
			Back
		) * CFrame.Angles(Generator:NextNumber(0, FullRotation), 0, 0)
		PatchStates[Patch] = {
			BaseTransparency = Transparency,
			CurrentHealth = HP,
			MaximumHealth = HP,
		}
		Patch.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = PlacementPart
		Weld.Part1 = Patch
		Weld.Parent = Patch
	end
	FinishPlacement()
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
