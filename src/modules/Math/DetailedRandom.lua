local defaultRandom = Random.new()

local function DetailedRandom(minimum: number, maximum: number, random: Random?): number
	return (random or defaultRandom):NextNumber(minimum, maximum)
end

return DetailedRandom
