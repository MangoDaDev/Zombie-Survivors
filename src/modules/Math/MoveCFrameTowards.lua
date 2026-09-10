local function MoveCFrameTowards(from: CFrame, to: CFrame, distance: number): CFrame
	local direction = to.Position - from.Position
	local length = direction.Magnitude
	if length == 0 then
		return from
	end

	return from + direction.Unit * math.min(math.max(distance, 0), length)
end

return MoveCFrameTowards
