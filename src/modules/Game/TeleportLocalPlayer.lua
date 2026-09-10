local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function TeleportLocalPlayer(target: CFrame | BasePart): boolean
	if not RunService:IsClient() then
		return false
	end

	local character = Players.LocalPlayer.Character
	if character == nil then
		return false
	end

	character:PivotTo(if typeof(target) == "Instance" then target.CFrame else target)
	return true
end

return TeleportLocalPlayer
