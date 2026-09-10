local function ToPercentage(value: number): string
	local rounded = math.floor(value * 1000 + 0.5) / 10
	if rounded % 1 == 0 then
		return string.format("%d%%", rounded)
	end

	return string.format("%.1f%%", rounded)
end

return ToPercentage
