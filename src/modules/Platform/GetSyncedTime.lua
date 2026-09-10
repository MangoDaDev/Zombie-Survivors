local Workspace = game:GetService("Workspace")

local function GetSyncedTime(): number
	return Workspace:GetServerTimeNow()
end

return GetSyncedTime
