local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local localPlayer = Players.LocalPlayer

local MonetizationController = {}

local monetizationNetwork: Networker.Client?
local state = { ownership = {}, runBoostActive = false }
local shopOpen = false
local shopCategory = MonetizationConfig.Shop.DefaultCategory
local productInfo = {}
local loadingInfo = {}
local pendingDeveloperProducts = {}
local pendingGamepasses = {}
local stateChanged = Signal.new()
local shopChanged = Signal.new()
local productInfoChanged = Signal.new()
local purchaseApplied = Signal.new()

local function findDeveloperProductKey(productId: number): string?
	for productKey, definition in MonetizationConfig.DeveloperProducts do
		if definition.ProductId == productId then
			return productKey
		end
	end
	return nil
end

local function findGamepassKey(gamepassId: number): string?
	for gamepassKey, definition in MonetizationConfig.Gamepasses do
		if definition.GamepassId == gamepassId then
			return gamepassKey
		end
	end
	return nil
end

local function requestProductInfo(productKey: string)
	if productInfo[productKey] or loadingInfo[productKey] then
		return
	end
	local definition = MonetizationConfig.GetProduct(productKey)
	if not definition then
		return
	end
	local assetId = definition.ProductId or definition.GamepassId
	if not MonetizationConfig.IsConfiguredId(assetId) then
		productInfo[productKey] = { configured = false }
		productInfoChanged:Fire(productKey, productInfo[productKey])
		return
	end
	loadingInfo[productKey] = true
	task.spawn(function()
		local infoType = if definition.ProductId then Enum.InfoType.Product else Enum.InfoType.GamePass
		local success, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, infoType)
		loadingInfo[productKey] = nil
		if success and type(info) == "table" then
			productInfo[productKey] = {
				configured = true,
				price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil,
				iconImageAssetId = if type(info.IconImageAssetId) == "number" then info.IconImageAssetId else nil,
			}
		else
			productInfo[productKey] = { configured = true, unavailable = true }
		end
		productInfoChanged:Fire(productKey, productInfo[productKey])
	end)
end

function MonetizationController.StateChanged(_, packet)
	if type(packet) == "table" and type(packet.ownership) == "table" and type(packet.runBoostActive) == "boolean" then
		state = packet
		stateChanged:Fire(state)
		for gamepassKey in pendingGamepasses do
			if packet.ownership[gamepassKey] == true then
				pendingGamepasses[gamepassKey] = nil
				-- Celebrate only ownership confirmed after this client opened a purchase prompt. Existing
				-- passes discovered during join-time verification must not replay purchase feedback.
				purchaseApplied:Fire(gamepassKey)
			end
		end
	end
end

function MonetizationController.PurchaseApplied(_, productKey)
	local definition = type(productKey) == "string" and MonetizationConfig.DeveloperProducts[productKey]
	if definition then
		-- Developer products celebrate only after ProcessReceipt has durably recorded and applied them.
		purchaseApplied:Fire(productKey)
	end
end

function MonetizationController.Init()
	monetizationNetwork = Networker.client.new("MonetizationController", MonetizationController)
	local snapshot = monetizationNetwork:fetch("GetSnapshot")
	if type(snapshot) == "table" and type(snapshot.ownership) == "table" then
		state = snapshot
	end
	for productKey, definition in MonetizationConfig.DeveloperProducts do
		if definition.ShopVisible then
			requestProductInfo(productKey)
		end
	end
	for gamepassKey, definition in MonetizationConfig.Gamepasses do
		if definition.ShopVisible then
			requestProductInfo(gamepassKey)
		end
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if userId ~= localPlayer.UserId then
			return
		end
		local productKey = findDeveloperProductKey(productId)
		if productKey then
			pendingDeveloperProducts[productKey] = nil
			if not purchased and monetizationNetwork then
				monetizationNetwork:fire("CancelProductPurchase", productKey)
			end
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		if player ~= localPlayer then
			return
		end
		local gamepassKey = findGamepassKey(gamepassId)
		if not gamepassKey then
			return
		end
		if not purchased then
			pendingGamepasses[gamepassKey] = nil
		elseif monetizationNetwork then
			monetizationNetwork:fire("RefreshGamepass", gamepassKey)
		end
	end)
end

function MonetizationController.GetState()
	return state
end

function MonetizationController.GetStateChangedSignal()
	return stateChanged
end

function MonetizationController.OwnsGamepass(gamepassKey: string): boolean
	return state.ownership[gamepassKey] == true
end

function MonetizationController.OwnsPremiumClass(classId: string): boolean
	return MonetizationConfig.GetPremiumClass(classId) ~= nil and MonetizationController.OwnsGamepass(classId)
end

function MonetizationController.GetAbilitySlotLimit(category: string): number
	local ownsExtraSlots = MonetizationController.OwnsGamepass("ExtraAbilitySlots")
	if category == "Weapon" then
		return MonetizationConfig.AbilitySlots.BaseWeapon
			+ (if ownsExtraSlots then MonetizationConfig.AbilitySlots.GamepassWeaponBonus else 0)
	end
	return MonetizationConfig.AbilitySlots.BasePassive
		+ (if ownsExtraSlots then MonetizationConfig.AbilitySlots.GamepassPassiveBonus else 0)
end

function MonetizationController.GetProductInfo(productKey: string)
	requestProductInfo(productKey)
	return productInfo[productKey]
end

function MonetizationController.GetProductInfoChangedSignal()
	return productInfoChanged
end

function MonetizationController.GetPurchaseAppliedSignal()
	return purchaseApplied
end

function MonetizationController.GetPriceText(productKey: string): string
	local definition = MonetizationConfig.GetProduct(productKey)
	if definition and definition.GamepassId and MonetizationController.OwnsGamepass(productKey) then
		return "OWNED"
	end
	local info = MonetizationController.GetProductInfo(productKey)
	if info and type(info.price) == "number" then
		return tostring(info.price)
	end
	return if info and info.configured == false then "SET ID" else "..."
end

function MonetizationController.GetImage(productKey: string): string
	local definition = MonetizationConfig.GetProduct(productKey)
	if definition and type(definition.ImageId) == "string" and definition.ImageId:match("^rbxassetid://[1-9]%d*$") then
		return definition.ImageId
	end
	local info = MonetizationController.GetProductInfo(productKey)
	if info and type(info.iconImageAssetId) == "number" and info.iconImageAssetId > 0 then
		return "rbxassetid://" .. tostring(info.iconImageAssetId)
	end
	return MonetizationConfig.GetImage(definition)
end

function MonetizationController.PromptDeveloperProduct(productKey: string)
	local definition = MonetizationConfig.DeveloperProducts[productKey]
	if not definition or pendingDeveloperProducts[productKey] or not monetizationNetwork then
		return
	end
	local authorization = monetizationNetwork:fetch("PrepareProductPurchase", productKey)
	if type(authorization) ~= "table" or authorization.allowed ~= true then
		if type(authorization) == "table" and authorization.applied == true then
			return
		end
		NotificationManager.Notify(
			type(authorization) == "table" and authorization.reason or "This purchase is unavailable.",
			2.5,
			UIStyle.Colors.Red
		)
		return
	end
	pendingDeveloperProducts[productKey] = true
	MarketplaceService:PromptProductPurchase(localPlayer, authorization.productId)
end

function MonetizationController.PromptGamepass(gamepassKey: string)
	local definition = MonetizationConfig.Gamepasses[gamepassKey]
	if not definition or not monetizationNetwork then
		return
	end
	if MonetizationController.OwnsGamepass(gamepassKey) then
		NotificationManager.Notify("Already owned.", 2, UIStyle.Colors.Green)
		return
	end
	local authorization = monetizationNetwork:fetch("PrepareGamepassPurchase", gamepassKey)
	if type(authorization) ~= "table" or authorization.allowed ~= true then
		NotificationManager.Notify(
			type(authorization) == "table" and authorization.reason or "This purchase is unavailable.",
			2.5,
			UIStyle.Colors.Red
		)
		return
	end
	pendingGamepasses[gamepassKey] = true
	MarketplaceService:PromptGamePassPurchase(localPlayer, authorization.gamepassId)
end

function MonetizationController.Prompt(productKey: string)
	local definition = MonetizationConfig.GetProduct(productKey)
	if not definition then
		return
	end
	if definition.ProductId then
		MonetizationController.PromptDeveloperProduct(productKey)
	else
		MonetizationController.PromptGamepass(productKey)
	end
end

function MonetizationController.SetShopOpen(open: boolean, category: string?)
	if type(open) ~= "boolean" then
		return
	end
	if category and table.find(MonetizationConfig.Shop.Categories, category) then
		shopCategory = category
	end
	if shopOpen == open and not category then
		return
	end
	shopOpen = open
	shopChanged:Fire(shopOpen, shopCategory)
end

function MonetizationController.IsShopOpen(): boolean
	return shopOpen
end

function MonetizationController.GetShopCategory(): string
	return shopCategory
end

function MonetizationController.SetShopCategory(category: string)
	if table.find(MonetizationConfig.Shop.Categories, category) then
		shopCategory = category
		shopChanged:Fire(shopOpen, shopCategory)
	end
end

function MonetizationController.GetShopChangedSignal()
	return shopChanged
end

return MonetizationController
