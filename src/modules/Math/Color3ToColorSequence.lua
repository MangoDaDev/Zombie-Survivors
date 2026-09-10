local function Color3ToColorSequence(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

return Color3ToColorSequence
