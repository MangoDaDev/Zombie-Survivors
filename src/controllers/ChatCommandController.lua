local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Networker = require(ReplicatedStorage.Packages.networker)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)

local ChatCommandController = {}

local function getSystemChannel(): TextChannel?
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then
		return nil
	end

	local generalChannel = channels:FindFirstChild("RBXGeneral")
	if generalChannel and generalChannel:IsA("TextChannel") then
		return generalChannel
	end
	for _, child in channels:GetChildren() do
		if child:IsA("TextChannel") then
			return child
		end
	end
	return nil
end

function ChatCommandController.CommandFeedback(_, message, tone)
	if type(message) ~= "string" or message == "" or #message > 1000 then
		return
	end

	local channel = getSystemChannel()
	if channel then
		channel:DisplaySystemMessage("[Commands] " .. message)
		return
	end

	local color
	if tone == "Error" then
		color = Color3.fromRGB(255, 110, 110)
	elseif tone == "Success" then
		color = Color3.fromRGB(110, 255, 160)
	end
	NotificationManager.Notify(message, 5, color)
end

function ChatCommandController.Init()
	Networker.client.new("ChatCommandController", ChatCommandController)
end

return ChatCommandController
