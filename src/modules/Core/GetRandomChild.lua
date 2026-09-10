local defaultRandom = Random.new()

local function GetRandomChild(instance: Instance, random: Random?): Instance?
	local children = instance:GetChildren()
	if #children == 0 then
		return nil
	end

	local generator = random or defaultRandom
	return children[generator:NextInteger(1, #children)]
end

return GetRandomChild
