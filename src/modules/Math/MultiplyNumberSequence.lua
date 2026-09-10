local function MultiplyNumberSequence(
	sequence: NumberSequence,
	factor: number,
	minimum: number?,
	maximum: number?,
	opacityMode: boolean?
): NumberSequence
	if opacityMode then
		assert(factor ~= 0, "factor must not be zero in opacity mode")
	end

	local keypoints = table.create(#sequence.Keypoints)

	for index, keypoint in sequence.Keypoints do
		local value = if opacityMode then 1 - (1 - keypoint.Value) / factor else keypoint.Value * factor
		if minimum ~= nil then
			value = math.max(value, minimum)
		end
		if maximum ~= nil then
			value = math.min(value, maximum)
		end

		keypoints[index] = NumberSequenceKeypoint.new(keypoint.Time, value, keypoint.Envelope)
	end

	return NumberSequence.new(keypoints)
end

return MultiplyNumberSequence
