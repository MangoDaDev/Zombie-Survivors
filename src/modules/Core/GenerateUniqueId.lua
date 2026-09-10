local HttpService = game:GetService("HttpService")

local function GenerateUniqueId(): string
	return HttpService:GenerateGUID(false)
end

return GenerateUniqueId
