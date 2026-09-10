local function MultiplyUDim2(measure: UDim2, multiplier: number): UDim2
	return UDim2.new(
		measure.X.Scale * multiplier,
		measure.X.Offset * multiplier,
		measure.Y.Scale * multiplier,
		measure.Y.Offset * multiplier
	)
end

return MultiplyUDim2
