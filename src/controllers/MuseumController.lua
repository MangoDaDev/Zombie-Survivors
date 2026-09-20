local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Confirmation = require(ReplicatedStorage.UI.Classes.Confirmation)
local Networker = require(ReplicatedStorage.Packages.networker)

local MuseumController = {}
local Network

function MuseumController.ShowSaleConfirmation(_, ItemName, SlotId, ItemId)
	if type(ItemName) ~= "string" or type(SlotId) ~= "number" or type(ItemId) ~= "number" then return end
	Confirmation.Show(`Sell {ItemName}?`, function()
		if Network then Network:fire("ConfirmSale", SlotId, ItemId) end
	end)
end

function MuseumController.Init()
	Network = Networker.client.new("MuseumController", MuseumController)
end

return MuseumController
