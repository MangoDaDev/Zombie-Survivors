local PaintRenderer = {}
local PaintStates = setmetatable({}, { __mode = "k" })

local function GetPaintParts(Model: Model): { BasePart }
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

function PaintRenderer.GetSuggestedCount(Model: Model): number
	return #GetPaintParts(Model)
end

function PaintRenderer.Add(Model: Model, Count: number, HP: number, DirtColor: Color3, MinimumAmount: number, MaximumAmount: number): { BasePart }
	local Parts = GetPaintParts(Model)
	local Targets = {}
	local RandomGenerator = Random.new((tonumber(string.byte(Model.Name, 1)) or 1) * 127)
	for Index, Part in Parts do
		if Index <= Count then
			local OriginalColor = Part.Color
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
				OriginalColor = OriginalColor,
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
	local OriginalColor = State.OriginalColor
	local DamagedColor = State.DamagedColor
	local MaximumHP = State.MaximumHealth
	local HP = State.CurrentHealth
	local NewHP = math.max(0, HP - Damage)
	State.CurrentHealth = NewHP
	local RestoredAmount = 1 - NewHP / math.max(MaximumHP, 0.001)
	Part.Color = DamagedColor:Lerp(OriginalColor, RestoredAmount)
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
			if State then Part.Color = State.OriginalColor end
			PaintStates[Part] = nil
		end
	end
end

return PaintRenderer
