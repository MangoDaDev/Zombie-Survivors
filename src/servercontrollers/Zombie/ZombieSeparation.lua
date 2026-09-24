local MINIMUM_CELL_SIZE = 4
local MAX_SEPARATION_SPEED = 6

local ZombieSeparation = {}

local function getCell(grid, cellX, cellZ)
	local xColumn = grid[cellX]
	return xColumn and xColumn[cellZ]
end

local function getFallbackDirection(firstId, secondId)
	-- Exact overlaps have no geometric direction, so use stable IDs to split the pair deterministically.
	local degrees = (firstId * 73 + secondId * 151) % 360
	local angle = math.rad(degrees)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

function ZombieSeparation.Apply(zombies, deltaTime)
	local maximumRadius = 0
	for _, zombie in zombies do
		maximumRadius = math.max(maximumRadius, zombie.definition.SeparationRadius * zombie.scale)
	end

	if maximumRadius <= 0 then
		return
	end

	-- A cell is at least one full separation diameter, so only the surrounding 3x3 cells can overlap.
	local cellSize = math.max(MINIMUM_CELL_SIZE, maximumRadius * 2)
	local grid = {}
	local offsets = {}

	for id, zombie in zombies do
		local position = zombie.cframe.Position
		local cellX = math.floor(position.X / cellSize)
		local cellZ = math.floor(position.Z / cellSize)
		local xColumn = grid[cellX]
		if not xColumn then
			xColumn = {}
			grid[cellX] = xColumn
		end
		local cell = xColumn[cellZ]
		if not cell then
			cell = {}
			xColumn[cellZ] = cell
		end
		table.insert(cell, zombie)
		offsets[id] = Vector3.zero
	end

	for id, zombie in zombies do
		local position = zombie.cframe.Position
		local cellX = math.floor(position.X / cellSize)
		local cellZ = math.floor(position.Z / cellSize)

		for xOffset = -1, 1 do
			for zOffset = -1, 1 do
				local cell = getCell(grid, cellX + xOffset, cellZ + zOffset)
				if cell then
					for _, other in cell do
						if other.id > id then
							local difference = Vector3.new(
								position.X - other.cframe.Position.X,
								0,
								position.Z - other.cframe.Position.Z
							)
							local distance = difference.Magnitude
							local minimumDistance = zombie.definition.SeparationRadius * zombie.scale
								+ other.definition.SeparationRadius * other.scale
							if distance < minimumDistance then
								local direction = if distance > 0.001
									then difference / distance
									else getFallbackDirection(id, other.id)
								local correction = direction * ((minimumDistance - distance) * 0.5)
								offsets[id] += correction
								offsets[other.id] -= correction
							end
						end
					end
				end
			end
		end
	end

	local maximumDisplacement = MAX_SEPARATION_SPEED * deltaTime
	for id, offset in offsets do
		local magnitude = offset.Magnitude
		if magnitude > 0 then
			zombies[id]:ApplySeparation(offset.Unit * math.min(magnitude, maximumDisplacement))
		end
	end
end

return ZombieSeparation
