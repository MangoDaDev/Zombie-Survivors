local PaintRenderer = {}

local function GetPaintParts(Model: Model): { BasePart }
	local Parts = {}
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart")
			and Descendant.Name ~= "BoundingBox"
			and Descendant.Name ~= "Dirt"
			and Descendant:FindFirstAncestor("Dirt") == nil
			and Descendant.Transparency < 1
			and Descendant:GetAttribute("NoPaint") ~= true
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
			Part:SetAttribute("PaintOriginalColor", OriginalColor)
			local DirtAmount = RandomGenerator:NextNumber(MinimumAmount, MaximumAmount)
			Part:SetAttribute("PaintDirtAmount", DirtAmount)
			Part:SetAttribute("PaintHP", HP)
			Part:SetAttribute("PaintMaxHP", HP)
			Part.Color = OriginalColor:Lerp(DirtColor, DirtAmount)
			table.insert(Targets, Part)
		end
	end
	return Targets
end

function PaintRenderer.Damage(Part: BasePart, Damage: number, DirtColor: Color3): boolean
	local OriginalColor = Part:GetAttribute("PaintOriginalColor")
	local DirtAmount = Part:GetAttribute("PaintDirtAmount")
	local MaximumHP = Part:GetAttribute("PaintMaxHP")
	local HP = Part:GetAttribute("PaintHP")
	if typeof(OriginalColor) ~= "Color3" or type(DirtAmount) ~= "number" or type(MaximumHP) ~= "number" or type(HP) ~= "number" then return false end
	local NewHP = math.max(0, HP - Damage)
	Part:SetAttribute("PaintHP", NewHP)
	Part.Color = OriginalColor:Lerp(DirtColor, DirtAmount * NewHP / math.max(MaximumHP, 0.001))
	return HP > 0 and NewHP <= 0
end

function PaintRenderer.Clear(Targets: { BasePart })
	for _, Part in Targets do
		if Part.Parent then
			local OriginalColor = Part:GetAttribute("PaintOriginalColor")
			if typeof(OriginalColor) == "Color3" then Part.Color = OriginalColor end
			Part:SetAttribute("PaintOriginalColor", nil)
			Part:SetAttribute("PaintDirtAmount", nil)
			Part:SetAttribute("PaintHP", nil)
			Part:SetAttribute("PaintMaxHP", nil)
		end
	end
end

return PaintRenderer
