local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local SocialService = game:GetService "SocialService"
local GroupService = game:GetService "GroupService"

local TopbarPlus = require(ReplicatedStorage.Packages.topbarplus)
local Images = require(ReplicatedStorage.Modules.UI.Images)

local GROUP_ID = 376357709

local localPlayer = Players.LocalPlayer
local inviteButton
local groupButton

local TopbarController = {}

function TopbarController:Toggle(enabled: boolean)
	if inviteButton then
		inviteButton:setEnabled(enabled)
	end

	if groupButton then
		groupButton:setEnabled(enabled)
	end
end

function TopbarController:Init()
	inviteButton = TopbarPlus.new():setName("Invite"):setLabel("Invite"):setWidth(44):setImage(Images.Invite):notify()

	inviteButton:bindEvent("selected", function()
		inviteButton:deselect()
		SocialService:PromptGameInvite(localPlayer)
	end)

	groupButton = TopbarPlus.new():setName("Group"):setLabel("Group"):setWidth(44):setImage(Images.Group)

	task.spawn(function()
		local success, isInGroup = pcall(localPlayer.IsInGroupAsync, localPlayer, GROUP_ID)
		if success and not isInGroup then
			groupButton:notify()
		end
	end)

	groupButton:bindEvent("selected", function()
		groupButton:deselect()
		pcall(GroupService.PromptJoinAsync, GroupService, GROUP_ID)
	end)
end

return TopbarController
