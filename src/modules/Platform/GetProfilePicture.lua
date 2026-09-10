local Players = game:GetService("Players")

local function GetProfilePicture(playerOrUserId: Player | number): string?
	local userId = if typeof(playerOrUserId) == "Instance" then playerOrUserId.UserId else playerOrUserId
	if type(userId) ~= "number" then
		return nil
	end

	local success, url = pcall(
		Players.GetUserThumbnailAsync,
		Players,
		userId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)
	if not success then
		warn("Failed to get profile picture for user", userId)
		return nil
	end

	return url
end

return GetProfilePicture
