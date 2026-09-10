local function AdvancedRound(number: number, roundTo: number?, offset: number?): number
	local interval = roundTo or 1
	assert(interval ~= 0, "roundTo must not be zero")

	local roundingOffset = offset or 0
	return math.floor((number - roundingOffset) / interval + 0.5) * interval + roundingOffset
end

return AdvancedRound
