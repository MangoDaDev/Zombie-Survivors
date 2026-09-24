local function GetDisplayName(player: Player?): string
	if player == nil then
		return "Unknown"
	end

	return player.DisplayName
end

return GetDisplayName
