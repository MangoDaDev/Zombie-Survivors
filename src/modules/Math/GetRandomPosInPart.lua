local defaultRandom = Random.new()

local function GetRandomPosInPart(part: BasePart, random: Random?): Vector3
	local generator = random or defaultRandom
	local halfSize = part.Size * 0.5
	local localOffset = Vector3.new(
		generator:NextNumber(-halfSize.X, halfSize.X),
		generator:NextNumber(-halfSize.Y, halfSize.Y),
		generator:NextNumber(-halfSize.Z, halfSize.Z)
	)

	return part.CFrame:PointToWorldSpace(localOffset)
end

return GetRandomPosInPart
