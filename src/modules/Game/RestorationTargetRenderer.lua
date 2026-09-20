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

local function GetReferenceCFrame(Model: Model): CFrame
	local Box = Model:FindFirstChild("BoundingBox")
	return if Box and Box:IsA("BasePart") then Box.CFrame else Model:GetPivot()
end

local function GetTargetState(Target: BasePart, Type: string?)
	local State = States[Target]
	while State and Type and State.Type ~= Type do State = State.PreviousState end
	return State
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
		elseif Type == "LooseDebris" then 10.8
		elseif Type == "Metal" and Step then Step.TargetDensity or 0.55
		else 0.55
	local Minimum = if Type == "Metal" and Step then Step.MinimumTargets or 1 else 1
	local Maximum = if Type == "LightDust"
		then 120
		elseif Type == "LooseDebris" then 192
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
				-- Preserve later-stage state so polishing cannot discard Hammer alignment transforms.
				PreviousState = States[Part],
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
		local ReferenceCFrame = GetReferenceCFrame(Model)
		for _, Part in Targets do
			local RestoredCFrame = Part.CFrame
			if Type == "Bent" then
				local BendRotation = Step.BendRotationDegrees or Vector3.new(28, -18, 12)
				Part.CFrame *= CFrame.Angles(math.rad(BendRotation.X), math.rad(BendRotation.Y), math.rad(BendRotation.Z))
			end
			States[Part] = {
				CurrentHealth = HP,
				MaximumHealth = HP,
				RestoredCFrame = RestoredCFrame,
				RestoredRelativeCFrame = ReferenceCFrame:ToObjectSpace(RestoredCFrame),
				StartCFrame = Part.CFrame,
				StartRelativeCFrame = ReferenceCFrame:ToObjectSpace(Part.CFrame),
				Type = Type,
			}
		end
		if #Targets > 0 then return Targets end
	end
	if Type == "Bent" then
		local Targets = RestorationTargetRenderer.GetBentParts(Model, Count)
		local BendRotation = Step.BendRotationDegrees or Vector3.new(28, -18, 12)
		local DamageRotation = CFrame.Angles(math.rad(BendRotation.X), math.rad(BendRotation.Y), math.rad(BendRotation.Z))
		local ReferenceCFrame = GetReferenceCFrame(Model)
		for _, Part in Targets do
			local RestoredRelativeCFrame = ReferenceCFrame:ToObjectSpace(Part.CFrame)
			Part.CFrame *= DamageRotation
			States[Part] = {
				CurrentHealth = HP,
				MaximumHealth = HP,
				RestoredCFrame = ReferenceCFrame * RestoredRelativeCFrame,
				RestoredRelativeCFrame = RestoredRelativeCFrame,
				StartCFrame = Part.CFrame,
				StartRelativeCFrame = ReferenceCFrame:ToObjectSpace(Part.CFrame),
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
			-- Hairdryer debris stays readable in motion at roughly 50% above the original size.
			local Size = Generator:NextNumber(0.21, 0.45)
			Target.Shape = Enum.PartType.Ball
			Target.Size = Vector3.one * Size
			Target.Color = Color3.fromRGB(112, 103, 91)
			Target.Transparency = 0.12
		else
			-- Magnet fragments use the same restrained 50% size lift as the debris effect.
			local Size = Generator:NextNumber(0.18, 0.33)
			Target.Shape = Enum.PartType.Cylinder
			Target.Size = Vector3.new(Generator:NextNumber(0.525, 0.93), Size, Size)
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

function RestorationTargetRenderer.GetHealth(Target: BasePart, Type: string?): (number, number)
	local State = GetTargetState(Target, Type)
	return if State then State.CurrentHealth else 0, if State then State.MaximumHealth else 1
end

function RestorationTargetRenderer.GetState(Target: BasePart, Type: string?)
	return GetTargetState(Target, Type)
end

function RestorationTargetRenderer.ApplyCurrentTransform(Model: Model, Target: BasePart, Type: string?)
	local State = GetTargetState(Target, Type)
	if not State or not Target.Parent then return end
	if State.RestoredRelativeCFrame and State.StartRelativeCFrame then
		local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
		local RelativeCFrame = if State.CurrentHealth <= 0
			then State.RestoredRelativeCFrame
			else State.StartRelativeCFrame:Lerp(State.RestoredRelativeCFrame, RestoredAmount)
		Target.CFrame = GetReferenceCFrame(Model) * RelativeCFrame
	elseif State.RestoredCFrame and State.StartCFrame then
		local RestoredAmount = 1 - State.CurrentHealth / math.max(State.MaximumHealth, 0.001)
		Target.CFrame = if State.CurrentHealth <= 0
			then State.RestoredCFrame
			else State.StartCFrame:Lerp(State.RestoredCFrame, RestoredAmount)
	end
end

function RestorationTargetRenderer.SetHealth(Model: Model, Target: BasePart, CurrentHealth: number, Type: string?)
	local State = GetTargetState(Target, Type)
	if not State or not Target.Parent then return end
	State.CurrentHealth = math.clamp(CurrentHealth, 0, State.MaximumHealth)
	RestorationTargetRenderer.ApplyCurrentTransform(Model, Target, Type)
end

function RestorationTargetRenderer.Restore(Model: Model, Target: BasePart, Type: string?)
	local State = GetTargetState(Target, Type)
	if not State or not Target.Parent then return end
	if State.OriginalColor then
		Target.Color = State.OriginalColor
		if States[Target] == State then States[Target] = State.PreviousState end
	elseif State.RestoredRelativeCFrame then
		State.CurrentHealth = 0
		RestorationTargetRenderer.ApplyCurrentTransform(Model, Target, Type)
	elseif State.RestoredCFrame then
		State.CurrentHealth = 0
		RestorationTargetRenderer.ApplyCurrentTransform(Model, Target, Type)
	end
end

function RestorationTargetRenderer.Clear(Model: Model, Type: string)
	local Folder = Model:FindFirstChild(Type)
	if Folder then Folder:Destroy() end
end

return RestorationTargetRenderer
