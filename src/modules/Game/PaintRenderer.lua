local PaintRenderer = {}
local PaintStates = setmetatable({}, { __mode = "k" })

local function GetPaintParts(Model: Model): { BasePart }
	local Parts = {}
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart")
			and Descendant.Name ~= "BoundingBox"
			and Descendant.Name ~= "Dirt"
			and Descendant:FindFirstAncestor("Dirt") == nil
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
			PaintStates[Part] = {
				DirtAmount = DirtAmount,
				CurrentHealth = HP,
				MaximumHealth = HP,
				OriginalColor = OriginalColor,
			}
			Part.Color = OriginalColor:Lerp(DirtColor, DirtAmount)
			table.insert(Targets, Part)
		end
	end
	return Targets
end

function PaintRenderer.Damage(Part: BasePart, Damage: number, DirtColor: Color3): boolean
	local State = PaintStates[Part]
	if not State then return false end
	local OriginalColor = State.OriginalColor
	local DirtAmount = State.DirtAmount
	local MaximumHP = State.MaximumHealth
	local HP = State.CurrentHealth
	local NewHP = math.max(0, HP - Damage)
	State.CurrentHealth = NewHP
	Part.Color = OriginalColor:Lerp(DirtColor, DirtAmount * NewHP / math.max(MaximumHP, 0.001))
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
