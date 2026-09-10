local Ranks = require(script.Parent.Ranks)

local VERIFIED_BADGE = utf8.char(0xE000)
local PREMIUM_BADGE = utf8.char(0xE001)

local function GetDisplayName(player: Player?): string
	if player == nil then
		return "Unknown"
	end

	local prefixes = {}
	for _, rank in Ranks do
		if table.find(rank.Users, player.UserId) then
			table.insert(prefixes, rank.Emoji)
		end
	end

	if player.MembershipType == Enum.MembershipType.Premium then
		table.insert(prefixes, PREMIUM_BADGE)
	end

	local suffix = if player.HasVerifiedBadge then VERIFIED_BADGE else ""
	return table.concat(prefixes) .. player.DisplayName .. suffix
end

return GetDisplayName
