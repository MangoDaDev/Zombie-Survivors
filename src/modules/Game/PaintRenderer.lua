local PaintRenderer = {}
local PaintStates = setmetatable({}, { __mode = "k" })
local ConfiguredAppearances = setmetatable({}, { __mode = "k" })
local ExcludedRestorationFolders = {
	BentComponents = true,
	Dirt = true,
	Grease = true,
	LightDust = true,
	LooseDebris = true,
	Metal = true,
	MetalComponents = true,
}

local function IsRestorationTarget(Part: BasePart): boolean
	local Current = Part.Parent
	while Current do
		if ExcludedRestorationFolders[Current.Name] then return true end
		Current = Current.Parent
	end
	return false
end

local function CaptureAppearance(Part: BasePart)
	return {
		BrickColor = Part.BrickColor,
		Color = Part.Color,
		Material = Part.Material,
		MaterialVariant = Part.MaterialVariant,
		Reflectance = Part.Reflectance,
		Transparency = Part.Transparency,
	}
end

local function GetCleanerColor(Color: Color3): Color3
	return Color:Lerp(Color3.new(1, 1, 1), 0.12)
end

function PaintRenderer.GetDullColor(Color: Color3): Color3
	local Hue, Saturation, Value = Color:ToHSV()
	return Color3.fromHSV(Hue, Saturation * 0.7, Value * 0.82)
end

function PaintRenderer.GetCleanerColor(Color: Color3): Color3
	return GetCleanerColor(Color)
end

function PaintRenderer.ApplyAppearance(Part: BasePart, Appearance)
	if not Part.Parent or type(Appearance) ~= "table" then return end
	Part.BrickColor = Appearance.BrickColor
	Part.Color = Appearance.Color
	Part.Material = Appearance.Material
	Part.MaterialVariant = Appearance.MaterialVariant
	Part.Reflectance = Appearance.Reflectance
	Part.Transparency = Appearance.Transparency
end

function PaintRenderer.GetPaintParts(Model: Model): { BasePart }
	local Parts = {}
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart")
			and Descendant.Name ~= "BoundingBox"
			and not IsRestorationTarget(Descendant)
			and Descendant.Transparency < 1
		then
			table.insert(Parts, Descendant)
		end
	end
	return Parts
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

function PaintRenderer.GetOriginalAppearance(Model: Model, Part: BasePart, Template: Model?)
	local State = PaintStates[Part]
	if State then return State.OriginalAppearance end
	local ConfiguredAppearance = ConfiguredAppearances[Part]
	if ConfiguredAppearance then return ConfiguredAppearance end
	local TemplatePart = Template and GetCounterpart(Model, Template, Part)
	return if TemplatePart then CaptureAppearance(TemplatePart) else nil
end

function PaintRenderer.GetUnpaintedColor(Part: BasePart): Color3
	local State = PaintStates[Part]
	return if State then State.UnpolishedColor or State.DamagedColor else Part.Color
end

function PaintRenderer.ApplyUnpaintedPolish(Model: Model)
	for _, Part in PaintRenderer.GetPaintParts(Model) do
		local State = PaintStates[Part]
		local UnpolishedColor = if State then State.UnpolishedColor or State.DamagedColor else Part.Color
		local PolishedColor = GetCleanerColor(UnpolishedColor)
		if State then
			State.UnpolishedColor = UnpolishedColor
			State.DamagedColor = PolishedColor
		end
		Part.Color = PolishedColor
	end
end

function PaintRenderer.GetSuggestedCount(Model: Model): number
	return #PaintRenderer.GetPaintParts(Model)
end

function PaintRenderer.Add(Model: Model, Count: number, HP: number, DirtColor: Color3, MinimumAmount: number, MaximumAmount: number): { BasePart }
	local Parts = PaintRenderer.GetPaintParts(Model)
	local Targets = {}
	local RandomGenerator = Random.new((tonumber(string.byte(Model.Name, 1)) or 1) * 127)
	for Index, Part in Parts do
		if Index <= Count then
			local ExistingState = PaintStates[Part]
			local OriginalAppearance = if ExistingState then ExistingState.OriginalAppearance else CaptureAppearance(Part)
			ConfiguredAppearances[Part] = ConfiguredAppearances[Part] or OriginalAppearance
			local OriginalColor = OriginalAppearance.Color
			local DirtAmount = RandomGenerator:NextNumber(MinimumAmount, MaximumAmount)
			local Hue, Saturation, Value = OriginalColor:ToHSV()
			local FadedColor = Color3.fromHSV(
				Hue,
				Saturation * RandomGenerator:NextNumber(0.08, 0.24),
				math.clamp(Value * RandomGenerator:NextNumber(0.48, 0.7), 0.12, 0.68)
			)
			local WornTint = DirtColor:Lerp(Color3.fromRGB(58, 60, 54), RandomGenerator:NextNumber(0.18, 0.48))
			local DamagedColor = FadedColor:Lerp(WornTint, DirtAmount)
			PaintStates[Part] = {
				CurrentHealth = HP,
				DamagedColor = DamagedColor,
				MaximumHealth = HP,
				OriginalAppearance = OriginalAppearance,
				UnpolishedColor = DamagedColor,
			}
			Part.Color = DamagedColor
			table.insert(Targets, Part)
		end
	end
	return Targets
end

function PaintRenderer.Damage(Part: BasePart, Damage: number, _DirtColor: Color3): boolean
	local State = PaintStates[Part]
	if not State then return false end
	local OriginalColor = State.OriginalAppearance.Color
	local DamagedColor = State.DamagedColor
	local MaximumHP = State.MaximumHealth
	local HP = State.CurrentHealth
	local NewHP = math.max(0, HP - Damage)
	State.CurrentHealth = NewHP
	local RestoredAmount = 1 - NewHP / math.max(MaximumHP, 0.001)
	Part.Color = DamagedColor:Lerp(OriginalColor, RestoredAmount)
	if NewHP <= 0 then PaintRenderer.ApplyAppearance(Part, State.OriginalAppearance) end
	return HP > 0 and NewHP <= 0
end

function PaintRenderer.GetHealth(Part: BasePart): (number, number)
	local State = PaintStates[Part]

	if not State then
		return 0, 1
	end

	return State.CurrentHealth, State.MaximumHealth
end

function PaintRenderer.Clear(Targets: { BasePart }, KeepDull: boolean?)
	for _, Part in Targets do
		if Part.Parent then
			local State = PaintStates[Part]
			if State then
				PaintRenderer.ApplyAppearance(Part, State.OriginalAppearance)
				if KeepDull == true then Part.Color = PaintRenderer.GetDullColor(State.OriginalAppearance.Color) end
			end
			PaintStates[Part] = nil
		end
	end
end

return PaintRenderer
