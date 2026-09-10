local defaultRandom = Random.new()

local function GaussianRandom(mean: number, standardDeviation: number, random: Random?): number
	local generator = random or defaultRandom
	local firstRoll = math.max(generator:NextNumber(), 1e-12)
	local secondRoll = generator:NextNumber()
	local normal = math.sqrt(-2 * math.log(firstRoll)) * math.cos(2 * math.pi * secondRoll)

	return mean + normal * standardDeviation
end

return GaussianRandom
