local PlayerFreezeState = require(script.Parent._PlayerFreezeState)

local function FreezePlayer(target: CFrame?): boolean
	return PlayerFreezeState.Freeze(target)
end

return FreezePlayer
