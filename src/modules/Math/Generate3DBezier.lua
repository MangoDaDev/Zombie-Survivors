local function lerpVector3(from: Vector3, to: Vector3, alpha: number): Vector3
	return from + (to - from) * alpha
end

local function getBezierPoint(controlPoints: { Vector3 }, alpha: number): Vector3
	local points = table.clone(controlPoints)
	while #points > 1 do
		for index = 1, #points - 1 do
			points[index] = lerpVector3(points[index], points[index + 1], alpha)
		end
		points[#points] = nil
	end

	return points[1]
end

local function Generate3DBezier(controlPoints: { Vector3 }, segments: number): { Vector3 }
	assert(#controlPoints >= 2, "Bezier curve requires at least two control points")
	assert(segments >= 1 and segments % 1 == 0, "segments must be a positive integer")

	local curvePoints = table.create(segments + 1)
	for index = 0, segments do
		curvePoints[index + 1] = getBezierPoint(controlPoints, index / segments)
	end

	return curvePoints
end

return Generate3DBezier
