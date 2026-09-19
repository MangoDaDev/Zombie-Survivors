local ItemInteractionConfig = require(script.Parent.ItemInteractionConfig)
local PaintRenderer = require(script.Parent.PaintRenderer)
local SurfacePlacement = require(script.Parent.SurfacePlacement)

local RestorationTargetRenderer = {}
local States = setmetatable({}, { __mode = "k" })
local ExcludedBentFolders = {
	Bent = true,
	BentComponents = true,
	Dirt = true,
	Grease = true,
	LightDust = true,
	LooseDebris = true,
	Metal = true,
	MetalComponents = true,
}

local function IsBentCandidate(Model: Model, Part: Instance): boolean
	if not Part:IsA("BasePart") or Part.Name == "BoundingBox" or Part.Transparency >= 1 then return false end
	local Current = Part.Parent
	while Current and Current ~= Model do
		if ExcludedBentFolders[Current.Name] then return false end
		Current = Current.Parent
	end
	return true
end

local function GetCounterpart(Model: Model, Template: Model, Target: BasePart): BasePart?
	local Path = {}
	local Current: Instance = Target
	while Current ~= Model do
		local Parent = Current.Parent
		if not Parent then return nil end
		local Ordinal = 0
		for _, Sibling in Parent:GetChildren() do
			if Sibling.Name == Current.Name and Sibling.ClassName == Current.ClassName then
				Ordinal += 1
				if Sibling == Current then break end
			end
		end
		table.insert(Path, 1, { ClassName = Current.ClassName, Name = Current.Name, Ordinal = Ordinal })
		Current = Parent
	end
	Current = Template
	for _, Segment in Path do
		local Ordinal = 0
		local Match
		for _, Child in Current:GetChildren() do
			if Child.Name == Segment.Name and Child.ClassName == Segment.ClassName then
				Ordinal += 1
				if Ordinal == Segment.Ordinal then Match = Child; break end
			end
		end
		if not Match then return nil end
		Current = Match
	end
	return if Current:IsA("BasePart") then Current else nil
end

function RestorationTargetRenderer.GetBentParts(Model: Model, Count: number?): { BasePart }
	local Box = Model:FindFirstChild("BoundingBox")
	local Center = if Box and Box:IsA("BasePart") then Box.Position else Model:GetPivot().Position
	local Candidates = {}
	for _, Descendant in Model:GetDescendants() do
		if not IsBentCandidate(Model, Descendant) then continue end
		local Part = Descendant :: BasePart
		local Size = Part.Size
		local MinimumAxis = math.max(math.min(Size.X, Size.Y, Size.Z), 0.01)
		local Elongation = math.max(Size.X, Size.Y, Size.Z) / MinimumAxis
		table.insert(Candidates, {
			Part = Part,
			Score = (Part.Position - Center).Magnitude + math.min(Elongation, 8) * 0.2,
			Name = Part:GetFullName(),
		})
	end
	table.sort(Candidates, function(A, B)
		if math.abs(A.Score - B.Score) > 0.001 then return A.Score > B.Score end
		return A.Name < B.Name
	end)
	local Targets = {}
	for Index = 1, math.min(Count or 2, #Candidates) do table.insert(Targets, Candidates[Index].Part) end
	return Targets
end

function RestorationTargetRenderer.GetBentTargets(Model: Model, Count: number?): { BasePart }
	local Folder = Model:FindFirstChild("BentComponents")
	if not Folder then return RestorationTargetRenderer.GetBentParts(Model, Count) end
	local Candidates = {}
	for _, Child in Folder:GetChildren() do
		if Child:IsA("BasePart") then table.insert(Candidates, Child) end
	end
	table.sort(Candidates, function(A, B) return A:GetFullName() < B:GetFullName() end)
	local Targets = {}
	for Index = 1, math.min(Count or #Candidates, #Candidates) do table.insert(Targets, Candidates[Index]) end
	return Targets
end

function RestorationTargetRenderer.GetRestoredCFrame(Model: Model, Target: BasePart, Template: Model): CFrame?
	local TemplateTarget = GetCounterpart(Model, Template, Target)
	if not TemplateTarget then return nil end
	return Model:GetPivot() * Template:GetPivot():ToObjectSpace(TemplateTarget.CFrame)
end

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

function RestorationTargetRenderer.GetSuggestedCount(Model: Model, Type: string, Step): number
	if Type == "Polish" then return #PaintRenderer.GetPaintParts(Model) end
	if Type == "Bent" then
		local Folder = Model:FindFirstChild("BentComponents")
		if Folder then return math.max(1, #RestorationTargetRenderer.GetBentTargets(Model, math.huge)) end
		local CandidateCount = #RestorationTargetRenderer.GetBentParts(Model, math.huge)
		-- Keep Hammer damage prominent: at least half of every item's real visible parts begin bent.
		return math.max(1, math.ceil(CandidateCount * 0.5))
	end
	if Type == "Metal" then
		local Folder = Model:FindFirstChild("MetalComponents")
		if Folder and #Folder:GetChildren() > 0 then return #Folder:GetChildren() end
	end
	local _, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	-- Keep surface damage prominent without allowing large items to create unbounded part counts.
	-- Keep hairdryer debris numerous and readable enough for the airflow direction to register clearly.
	local Density = if Type == "LightDust"
		then 7.4
		elseif Type == "LooseDebris" then 7.2
		elseif Type == "Metal" and Step then Step.TargetDensity or 0.55
		else 0.55
	local Minimum = if Type == "Metal" and Step then Step.MinimumTargets or 1 else 1
	local Maximum = if Type == "LightDust"
		then 120
		elseif Type == "LooseDebris" then 128
		elseif Type == "Metal" and Step then Step.MaximumTargets or 8
		else 8
	return math.clamp(math.round(math.sqrt(TotalArea) * Density), Minimum, Maximum)
end

function RestorationTargetRenderer.Add(Model: Model, Type: string, Count: number, HP: number, Step, PaintCompleted: boolean?): { BasePart }
	RestorationTargetRenderer.Clear(Model, Type)
	if Type == "Polish" then
		local Targets = PaintRenderer.GetPaintParts(Model)
		for Index, Part in Targets do
			if Index > Count then break end
			local UnpaintedColor = PaintRenderer.GetUnpaintedColor(Part)
			local FinalAppearance = PaintRenderer.GetOriginalAppearance(Model, Part)
			local FinalColor = if FinalAppearance then FinalAppearance.Color else Part.Color
			local StartColor = if PaintCompleted == true then PaintRenderer.GetDullColor(FinalColor) else UnpaintedColor
			local PolishedColor = if PaintCompleted == true then FinalColor else PaintRenderer.GetCleanerColor(UnpaintedColor)
			-- Polish never derives a new color from an already modified one, preventing color drift.
			Part.Color = StartColor
			States[Part] = {
				CurrentHealth = HP,
				MaximumHealth = HP,
				OriginalColor = PolishedColor,
				DullColor = StartColor,
				Type = Type,
			}
		end
		return Targets
	end

	local ExistingFolder = Model:FindFirstChild(Type == "Bent" and "BentComponents" or Type == "Metal" and "MetalComponents" or "")
	if ExistingFolder and (Type == "Bent" or Type == "Metal") then
		local Targets = if Type == "Bent" then RestorationTargetRenderer.GetBentTargets(Model, Count) else {}
		if Type == "Metal" then
			for _, Child in ExistingFolder:GetChildren() do
				if Child:IsA("BasePart") then table.insert(Targets, Child) end
			end
			table.sort(Targets, function(A, B) return A:GetFullName() < B:GetFullName() end)
			while #Targets > Count do table.remove(Targets) end
		end
		for _, Part in Targets do
			local RestoredCFrame = Part.CFrame
			if Type == "Bent" then
				local BendRotation = Step.BendRotationDegrees or Vector3.new(28, -18, 12)
				Part.CFrame *= CFrame.Angles(math.rad(BendRotation.X), math.rad(BendRotation.Y), math.rad(BendRotation.Z))
			end
			local ModelPivot = Model:GetPivot()
			States[Part] = {
				CurrentHealth = HP,
				MaximumHealth = HP,
				RestoredCFrame = RestoredCFrame,
				RestoredRelativeCFrame = ModelPivot:ToObjectSpace(RestoredCFrame),
				StartCFrame = Part.CFrame,
				StartRelativeCFrame = ModelPivot:ToObjectSpace(Part.CFrame),
				Type = Type,
			}
		end
		if #Targets > 0 then return Targets end
	end
	if Type == "Bent" then
		local Targets = RestorationTargetRenderer.GetBentParts(Model, Count)
		local BendRotation = Step.BendRotationDegrees or Vector3.new(28, -18, 12)
		local DamageRotation = CFrame.Angles(math.rad(BendRotation.X), math.rad(BendRotation.Y), math.rad(BendRotation.Z))
		local ModelPivot = Model:GetPivot()
		for _, Part in Targets do
			local RestoredRelativeCFrame = ModelPivot:ToObjectSpace(Part.CFrame)
			Part.CFrame *= DamageRotation
			States[Part] = {
				CurrentHealth = HP,
				MaximumHealth = HP,
				RestoredCFrame = ModelPivot * RestoredRelativeCFrame,
				RestoredRelativeCFrame = RestoredRelativeCFrame,
				StartCFrame = Part.CFrame,
				StartRelativeCFrame = ModelPivot:ToObjectSpace(Part.CFrame),
				Type = Type,
			}
		end
		return Targets
	end

	local SurfaceParts, TotalArea = SurfacePlacement.GetSurfaceParts(Model)
	if #SurfaceParts == 0 then return {} end
	local Context, FinishPlacement = SurfacePlacement.Begin(Model, SurfaceParts)
	local Folder = Instance.new("Folder")
	Folder.Name = Type
	Folder.Parent = Model
	local Generator = Random.new(GetSeed(Model, if Type == "LightDust" then 491 elseif Type == "LooseDebris" then 557 else 613))
	local Targets = {}
	for _ = 1, math.min(Count, RestorationTargetRenderer.GetSuggestedCount(Model, Type, Step)) do
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
			local Size = math.clamp(math.sqrt(TotalArea / math.max(Count, 1)) * 0.56, 0.09, 0.42)
			Target.Shape = Enum.PartType.Block
			Target.Size = Vector3.new(Size, 0.018, Size)
			Target.Color = Step.PatchColor
			Target.Transparency = Step.PatchTransparency
		elseif Type == "LooseDebris" then
			local Size = Generator:NextNumber(0.14, 0.3)
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
		local RestoredCFrame = GetSurfaceCFrame(Placement.Position, Placement.Normal, Generator:NextNumber(0, math.pi * 2))
		Target.CFrame = RestoredCFrame
		States[Target] = {
			CurrentHealth = HP,
			MaximumHealth = HP,
			StartCFrame = Target.CFrame,
			RestoredCFrame = nil,
			Type = Type,
		}
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

function RestorationTargetRenderer.SetHealth(Model: Model, Target: BasePart, CurrentHealth: number)
	local State = States[Target]
	if not State or not Target.Parent then return end
	State.CurrentHealth = math.clamp(CurrentHealth, 0, State.MaximumHealth)
	if State.RestoredRelativeCFrame and State.StartRelativeCFrame then
		local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
		Target.CFrame = Model:GetPivot() * State.StartRelativeCFrame:Lerp(State.RestoredRelativeCFrame, RestoredAmount)
	elseif State.RestoredCFrame and State.StartCFrame then
		local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
		Target.CFrame = State.StartCFrame:Lerp(State.RestoredCFrame, RestoredAmount)
	end
end

function RestorationTargetRenderer.Restore(Model: Model, Target: BasePart)
	local State = States[Target]
	if not State or not Target.Parent then return end
	if State.OriginalColor then
		Target.Color = State.OriginalColor
	elseif State.RestoredRelativeCFrame then
		Target.CFrame = Model:GetPivot() * State.RestoredRelativeCFrame
	elseif State.RestoredCFrame then
		Target.CFrame = State.RestoredCFrame
	end
end

function RestorationTargetRenderer.Clear(Model: Model, Type: string)
	local Folder = Model:FindFirstChild(Type)
	if Folder then Folder:Destroy() end
end

return RestorationTargetRenderer
