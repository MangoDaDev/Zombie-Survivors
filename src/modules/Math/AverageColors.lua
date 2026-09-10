local function AverageColors(colors: { [any]: any }): Color3
	local red = 0
	local green = 0
	local blue = 0
	local totalWeight = 0

	for key, value in colors do
		local color = if typeof(key) == "Color3" then key else value
		local weight = if typeof(key) == "Color3" then value else 1

		if typeof(color) == "Color3" and type(weight) == "number" then
			red += color.R * weight
			green += color.G * weight
			blue += color.B * weight
			totalWeight += weight
		end
	end

	if totalWeight == 0 then
		return Color3.new()
	end

	return Color3.new(red / totalWeight, green / totalWeight, blue / totalWeight)
end

return AverageColors
