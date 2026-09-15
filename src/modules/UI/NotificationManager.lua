local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

local NotificationAdded = Signal.new()
local ActiveNotifications = {}

local NotificationManager = {}

function NotificationManager.Notify(Text: string, Duration: number?)
	if type(Text) ~= "string" or Text == "" then
		return
	end

	local ResolvedDuration = if type(Duration) == "number" and Duration > 0 then Duration else 3
	NotificationAdded:Fire(Text, ResolvedDuration)
end

function NotificationManager.SetActive(NotificationId: string, IsActive: boolean, Text: string, Duration: number?)
	local WasActive = ActiveNotifications[NotificationId] == true

	if IsActive then
		ActiveNotifications[NotificationId] = true
	else
		ActiveNotifications[NotificationId] = nil
	end

	if IsActive and not WasActive then
		NotificationManager.Notify(Text, Duration)
	end
end

function NotificationManager.IsActive(NotificationId: string): boolean
	return ActiveNotifications[NotificationId] == true
end

function NotificationManager.GetNotificationAddedSignal()
	return NotificationAdded
end

return NotificationManager
