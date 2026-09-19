local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)

local AnalyticsController = {}
local Network

function AnalyticsController.UpgradeMenuOpened()
	if Network then Network:fire("UpgradeMenuOpened") end
end

function AnalyticsController.UpgradeViewed(UpgradeId: string)
	if Network then Network:fire("UpgradeViewed", UpgradeId) end
end

function AnalyticsController.Init()
	Network = Networker.client.new("AnalyticsController", {})
end

return AnalyticsController
