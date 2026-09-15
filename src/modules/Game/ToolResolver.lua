local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BatInfo = require(ReplicatedStorage.Modules.Game.BatInfo)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local ItemsInfo = require(ReplicatedStorage.Modules.Game.ItemsInfo)

local ToolResolver = {}
local BatsByName = {}
local CleaningToolsByName = {}
local ItemsByName = {}
local ItemsByTag = {}

for _, Info in BatInfo do
	BatsByName[Info.DisplayName] = Info
end

for _, Info in CleaningConfig.Tools do
	CleaningToolsByName[Info.DisplayName] = Info
end

for _, Info in ItemsInfo do
	ItemsByName[Info.Name] = Info
	ItemsByTag[`Item_{Info.Id}`] = Info
end

function ToolResolver.GetBatInfo(Tool)
	return Tool and Tool:IsA("Tool") and BatsByName[Tool.Name] or nil
end

function ToolResolver.GetCleaningToolInfo(Tool)
	return Tool and Tool:IsA("Tool") and CleaningToolsByName[Tool.Name] or nil
end

function ToolResolver.GetItemInfo(Tool)
	if not Tool or not Tool:IsA("Tool") then
		return nil
	end
	for Tag, Info in ItemsByTag do
		if Tool:HasTag(Tag) then
			return Info
		end
	end
	return ItemsByName[Tool.Name]
end

return ToolResolver
