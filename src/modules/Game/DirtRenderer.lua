local ItemInteractionConfig = require(script.Parent.ItemInteractionConfig)
local SurfacePlacement = require(script.Parent.SurfacePlacement)

local DirtRenderer = {}

local DirtSize = 0.42
local DirtSizeMinimumScale = 0.7
local DirtSizeMaximumScale = 1.3
local DirtDensity = 4.5
local DirtCountVariance = 0.1
local FullRotation = math.pi * 2
local HealthByPart = setmetatable({}, { __mode = "k" })

local function GetSurfaceCFrame(Position: Vector3, Normal: Vector3, RandomGenerator: Random, Height: number): CFrame
	local Reference = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local Right = Reference:Cross(Normal).Unit
	local Back = Right:Cross(Normal).Unit
	return CFrame.fromMatrix(
		Position + Normal * (Height / 2 + ItemInteractionConfig.SurfacePlacementOffset),
		Right,
		Normal,
		Back
	) * CFrame.Angles(0, RandomGenerator:NextNumber(0, FullRotation), 0)
end

function DirtRenderer.GetSuggestedCount(Model: Model, RandomGenerator: Random?): number
	local _, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	local Generator = RandomGenerator or Random.new()
	local Variance = Generator:NextNumber(1 - DirtCountVariance, 1 + DirtCountVariance)
	return math.clamp(math.round(TotalArea * DirtDensity * Variance), 1, ItemInteractionConfig.MaximumDirtCount)
end

function DirtRenderer.Add(Model: Model, Count: number, HP: number?): Folder?
	DirtRenderer.Clear(Model)
	local SurfaceParts, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	if #SurfaceParts == 0 or Count <= 0 then
		return nil
	end
	local Context, FinishPlacement = SurfacePlacement.Begin(Model, SurfaceParts)

	local Folder = Instance.new("Folder")
	Folder.Name = "Dirt"
	Folder.Parent = Model
	local RandomGenerator = Random.new(tonumber(string.byte(Model.Name, 1)) or 1)
	for _ = 1, math.min(math.round(Count), ItemInteractionConfig.MaximumDirtCount) do
		local Placement = SurfacePlacement.GetPlacement(Context, SurfaceParts, TotalArea, RandomGenerator)
		if not Placement then continue end
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
		Dirt.CFrame = GetSurfaceCFrame(Placement.Position, Placement.Normal, RandomGenerator, DirtDimensions.Y)
		HealthByPart[Dirt] = {
			Current = HP or 1,
			Maximum = HP or 1,
		}
		Dirt.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Placement.Part
		Weld.Part1 = Dirt
		Weld.Parent = Dirt
	end
	FinishPlacement()
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
