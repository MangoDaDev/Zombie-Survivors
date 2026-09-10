local function getTargetCFrame(target: CFrame | BasePart): CFrame
	return if typeof(target) == "Instance" then target.CFrame else target
end

local function TeleportPlayer(playerOrCharacter: Player | Model, target: CFrame | BasePart): boolean
	local character = if playerOrCharacter:IsA("Player") then playerOrCharacter.Character else playerOrCharacter
	if character == nil then
		return false
	end

	character:PivotTo(getTargetCFrame(target))
	return true
end

return TeleportPlayer
