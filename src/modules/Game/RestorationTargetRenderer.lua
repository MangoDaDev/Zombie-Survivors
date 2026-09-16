local ItemInteractionConfig = require(script.Parent.ItemInteractionConfig)
local PaintRenderer = require(script.Parent.PaintRenderer)
local SurfacePlacement = require(script.Parent.SurfacePlacement)

local RestorationTargetRenderer = {}
local States = setmetatable({}, { __mode = "k" })

local function GetSeed(Model: Model, Salt: number): number
	return (tonumber(string.byte(Model.Name, 1)) or 1) * Salt
end

local function GetSurfaceCFrame(Position: Vector3, Normal: Vector3, Rotation: number): CFrame
	local Reference = if math.abs(Normal:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local Right = Reference:Cross(Normal).Unit
	local Back = Right:Cross(Normal).Unit
	return CFrame.fromMatrix(Position + Normal * ItemInteractionConfig.SurfacePlacementOffset, Right, Normal, Back)
		* CFrame.Angles(0, Rotation, 0)
end

function RestorationTargetRenderer.GetSuggestedCount(Model: Model, Type: string): number
	if Type == "Polish" then return #PaintRenderer.GetPaintParts(Model) end
	if Type == "Bent" then
		local Folder = Model:FindFirstChild("BentComponents")
		return if Folder then math.max(1, #Folder:GetChildren()) else 1
	end
	if Type == "Metal" then
		local Folder = Model:FindFirstChild("MetalComponents")
		if Folder and #Folder:GetChildren() > 0 then return #Folder:GetChildren() end
	end
	local _, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	local Density = if Type == "LightDust" then 5.2 elseif Type == "LooseDebris" then 2.5 else 0.55
	local Maximum = if Type == "LightDust" then 84 elseif Type == "LooseDebris" then 48 else 8
	return math.clamp(math.round(math.sqrt(TotalArea) * Density), 1, Maximum)
end

function RestorationTargetRenderer.Add(Model: Model, Type: string, Count: number, HP: number, Step): { BasePart }
	RestorationTargetRenderer.Clear(Model, Type)
	if Type == "Polish" then
		local Targets = PaintRenderer.GetPaintParts(Model)
		for Index, Part in Targets do
			if Index > Count then break end
			local OriginalColor = Part.Color
			local Hue, Saturation, Value = OriginalColor:ToHSV()
			local DullColor = Color3.fromHSV(Hue, Saturation * 0.34, Value * 0.78)
			Part.Color = DullColor
			States[Part] = { CurrentHealth = HP, MaximumHealth = HP, OriginalColor = OriginalColor, DullColor = DullColor, Type = Type }
		end
		return Targets
	end

	local ExistingFolder = Model:FindFirstChild(Type == "Bent" and "BentComponents" or Type == "Metal" and "MetalComponents" or "")
	if ExistingFolder and (Type == "Bent" or Type == "Metal") then
		local Targets = {}
		for _, Part in ExistingFolder:GetChildren() do
			if not Part:IsA("BasePart") then continue end
			local RestoredCFrame = Part.CFrame
			if Type == "Bent" then Part.CFrame *= CFrame.Angles(math.rad(22), math.rad(-14), math.rad(9)) end
			States[Part] = { CurrentHealth = HP, MaximumHealth = HP, RestoredCFrame = RestoredCFrame, StartCFrame = Part.CFrame, Type = Type }
			table.insert(Targets, Part)
		end
		if #Targets > 0 then return Targets end
	end

	local SurfaceParts, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	if #SurfaceParts == 0 then return {} end
	local Context, FinishPlacement = SurfacePlacement.Begin(Model, SurfaceParts)
	local Folder = Instance.new("Folder")
	Folder.Name = Type
	Folder.Parent = Model
	local Generator = Random.new(GetSeed(Model, if Type == "LightDust" then 491 elseif Type == "LooseDebris" then 557 else 613))
	local Targets = {}
	for _ = 1, math.min(Count, RestorationTargetRenderer.GetSuggestedCount(Model, Type)) do
		local Placement = SurfacePlacement.GetPlacement(Context, SurfaceParts, TotalArea, Generator)
		if not Placement then continue end
		local Target = Instance.new("Part")
		Target.Name = Type
		Target.Anchored = true
		Target.CanCollide = false
		Target.CanTouch = false
		Target.CanQuery = true
		Target.CastShadow = false
		Target.Massless = true
		Target.Material = Enum.Material.SmoothPlastic
		if Type == "LightDust" then
			local Size = math.clamp(math.sqrt(TotalArea / math.max(Count, 1)) * 0.48, 0.08, 0.42)
			Target.Shape = Enum.PartType.Block
			Target.Size = Vector3.new(Size, 0.018, Size)
			Target.Color = Step.PatchColor
			Target.Transparency = Step.PatchTransparency
		elseif Type == "LooseDebris" then
			local Size = Generator:NextNumber(0.08, 0.2)
			Target.Shape = Enum.PartType.Ball
			Target.Size = Vector3.one * Size
			Target.Color = Color3.fromRGB(112, 103, 91)
			Target.Transparency = 0.12
		else
			local Size = Generator:NextNumber(0.12, 0.22)
			Target.Shape = Enum.PartType.Cylinder
			Target.Size = Vector3.new(Generator:NextNumber(0.35, 0.62), Size, Size)
			Target.Color = Color3.fromRGB(92, 99, 108)
			Target.Material = Enum.Material.Metal
		end
		Target.CFrame = GetSurfaceCFrame(Placement.Position, Placement.Normal, Generator:NextNumber(0, math.pi * 2))
		States[Target] = { CurrentHealth = HP, MaximumHealth = HP, StartCFrame = Target.CFrame, Type = Type }
		Target.Parent = Folder
		table.insert(Targets, Target)
	end
	FinishPlacement()
	return Targets
end

function RestorationTargetRenderer.GetHealth(Target: BasePart): (number, number)
	local State = States[Target]
	return if State then State.CurrentHealth else 0, if State then State.MaximumHealth else 1
end

function RestorationTargetRenderer.GetState(Target: BasePart)
	return States[Target]
end

function RestorationTargetRenderer.Clear(Model: Model, Type: string)
	local Folder = Model:FindFirstChild(Type)
	if Folder then Folder:Destroy() end
end

return RestorationTargetRenderer
