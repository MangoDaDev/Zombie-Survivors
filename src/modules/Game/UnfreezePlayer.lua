local PlayerFreezeState = require(script.Parent._PlayerFreezeState)

local function UnfreezePlayer()
	PlayerFreezeState.Unfreeze()
end

return UnfreezePlayer
