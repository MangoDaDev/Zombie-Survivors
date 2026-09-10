local FALLOFF_STRENGTH = 0.33
local defaultRandom = Random.new()

local function getWeights(items: { [any]: any }, propertyName: string): ({ [any]: number }, number)
	local weights = {}
	local total = 0

	for index, item in items do
		local weight = type(item) == "table" and item[propertyName] or nil
		if type(weight) == "number" and weight > 0 then
			weights[index] = weight
			total += weight
		end
	end

	return weights, total
end

local function getAdjustedChances(
	items: { [any]: any },
	propertyName: string?,
	luck: number?
): ({ [any]: number }?, { [any]: number }?)
	local weights, total = getWeights(items, propertyName or "Weight")
	if total <= 0 then
		return nil, nil
	end

	local baseChances = {}
	for index, weight in weights do
		baseChances[index] = weight / total
	end

	local luckValue = math.max(luck or 0, 0)
	if luckValue <= 1 then
		return baseChances, baseChances
	end

	local biggest = 0
	for _, weight in weights do
		biggest = math.max(biggest, weight)
	end

	local adjusted = {}
	local adjustedTotal = 0
	local logBase = 1 / FALLOFF_STRENGTH
	for index, weight in weights do
		local normalized = weight / biggest
		local distance = math.log(normalized * luckValue, logBase)
		if distance >= 0 then
			normalized /= (logBase + 2) ^ distance
		end

		adjusted[index] = normalized
		adjustedTotal += normalized
	end

	for index, weight in adjusted do
		adjusted[index] = weight / adjustedTotal
	end

	return adjusted, baseChances
end

local function GetRandomFromWeightedTable(
	items: { [any]: any },
	propertyName: string?,
	random: Random?,
	luck: number?
): (any?, number?, { [any]: number }?)
	local chances = getAdjustedChances(items, propertyName, luck)
	if chances == nil then
		return nil, nil, nil
	end

	local roll = (random or defaultRandom):NextNumber()
	local lastIndex
	for index, chance in chances do
		lastIndex = index
		roll -= chance
		if roll <= 0 then
			return items[index], chance, chances
		end
	end

	return items[lastIndex], chances[lastIndex], chances
end

local function GetRelativeChance(
	items: { [any]: any },
	propertyName: string?,
	targetIndex: any,
	luck: number?
): (number?, number?, boolean?, number?)
	local adjustedChances, baseChances = getAdjustedChances(items, propertyName, luck)
	if adjustedChances == nil or baseChances == nil or adjustedChances[targetIndex] == nil then
		return nil, nil, nil, nil
	end

	local adjustedChance = adjustedChances[targetIndex]
	local baseChance = baseChances[targetIndex]
	local delta = adjustedChance - baseChance
	return adjustedChance, baseChance, delta > 0, delta
end

return {
	GetRandomFromWeightedTable = GetRandomFromWeightedTable,
	GetRelativeChance = GetRelativeChance,
}
