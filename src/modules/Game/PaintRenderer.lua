local PaintRenderer = {}
local PaintStates = setmetatable({}, { __mode = "k" })

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
			and Descendant.Name ~= "Dirt"
			and Descendant.Name ~= "Grease"
			and Descendant:FindFirstAncestor("Dirt") == nil
			and Descendant:FindFirstAncestor("Grease") == nil
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
	local TemplatePart = Template and GetCounterpart(Model, Template, Part)
	return if TemplatePart then CaptureAppearance(TemplatePart) else nil
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

function PaintRenderer.Clear(Targets: { BasePart })
	for _, Part in Targets do
		if Part.Parent then
			local State = PaintStates[Part]
			if State then PaintRenderer.ApplyAppearance(Part, State.OriginalAppearance) end
			PaintStates[Part] = nil
		end
	end
end

return PaintRenderer
