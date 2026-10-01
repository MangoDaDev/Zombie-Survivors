local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)

local AnalyticsController = {}

local analyticsNetwork

function AnalyticsController.Init()
	analyticsNetwork = Networker.client.new("AnalyticsController", AnalyticsController)
end

function AnalyticsController.OpenShop(shopKind: string)
	if analyticsNetwork and (shopKind == "Ability" or shopKind == "Class") then
		-- Opening is reported only after the owning controller has accepted and applied its open state.
		analyticsNetwork:fire("ShopOpened", shopKind)
	end
end

function AnalyticsController.SelectShopItem(shopKind: string, itemId: string)
	if analyticsNetwork
		and (shopKind == "Ability" or shopKind == "Class")
		and type(itemId) == "string"
		and itemId ~= ""
	then
		analyticsNetwork:fire("ShopItemSelected", shopKind, itemId)
	end
end

return AnalyticsController
