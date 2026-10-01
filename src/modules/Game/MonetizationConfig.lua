local Images = require(script.Parent.Parent.UI.Images)

local MonetizationConfig = {}

MonetizationConfig.DataKey = "Monetization"

-- =====================================================
-- PASTE YOUR ROBLOX IDS HERE
-- =====================================================
-- Keep every commerce ID and standalone Roblox Image asset ID in this block. The UI never
-- reads local file paths: upload each matching PNG in assets/monetization/ and paste its
-- Image asset ID here. Zero deliberately falls back to Marketplace or existing game art.
MonetizationConfig.DeveloperProducts = {
	Revive = { ProductId = 0, ImageId = "rbxassetid://89417655945879" },
	ReviveTeam = { ProductId = 0, ImageId = "rbxassetid://99546721866961" },
	CoinPouch = { ProductId = 0, ImageId = "rbxassetid://89123200158797" },
	Satchel = { ProductId = 0, ImageId = "rbxassetid://106239575713076" },
	Backpack = { ProductId = 0, ImageId = "rbxassetid://106238814627516" },
	Crate = { ProductId = 0, ImageId = "rbxassetid://99551113347473" },
	Vault = { ProductId = 0, ImageId = "rbxassetid://134073528439823" },
	Arsenal = { ProductId = 0, ImageId = "rbxassetid://136569567654381" },
	RunBoost = { ProductId = 0, ImageId = "rbxassetid://115042318829702" },
	TakeAll = { ProductId = 0, ImageId = "rbxassetid://78132252015827" },
}

MonetizationConfig.Gamepasses = {
	DoubleCoins = { GamepassId = 0, ImageId = "rbxassetid://137469471318620" },
	ExtraAbilitySlots = { GamepassId = 0, ImageId = "rbxassetid://98670548332619" },
	Gunslinger = { GamepassId = 0, ImageId = "rbxassetid://85121530170006" },
	Cryomancer = { GamepassId = 0, ImageId = "rbxassetid://77756967607151" },
	Starcaller = { GamepassId = 0, ImageId = "rbxassetid://79173867158968" },
	Titan = { GamepassId = 0, ImageId = "rbxassetid://123215563164795" },
	VoidEmperor = { GamepassId = 0, ImageId = "rbxassetid://89807556450385" },
}
-- =====================================================
-- END ROBLOX ID SECTION
-- =====================================================

local function configureProduct(key: string, definition)
	local product = MonetizationConfig.DeveloperProducts[key]
	for field, value in definition do
		product[field] = value
	end
	return product
end

local function configureGamepass(key: string, definition)
	local gamepass = MonetizationConfig.Gamepasses[key]
	for field, value in definition do
		gamepass[field] = value
	end
	return gamepass
end

configureProduct("Revive", {
	Key = "Revive", DisplayName = "Revive", Description = "Return to the current run.",
	Category = "Featured", Order = 10, Featured = true, ShopVisible = false, RecommendedRobux = 39,
	Contextual = true, FallbackImageId = Images.Abilities.Heart,
})
configureProduct("ReviveTeam", {
	Key = "ReviveTeam", DisplayName = "Revive Team", Description = "Revive every eligible dead teammate.",
	Category = "Featured", Order = 20, Featured = true, ShopVisible = false, RecommendedRobux = 79,
	Contextual = true, FallbackImageId = Images.Group,
})

local coinPacks = {
	CoinPouch = { "Coin Pouch", 500, 19, 110 },
	Satchel = { "Satchel", 1_800, 49, 120 },
	Backpack = { "Backpack", 5_000, 99, 130 },
	Crate = { "Crate", 12_500, 199, 140 },
	Vault = { "Vault", 30_000, 399, 150 },
	Arsenal = { "Arsenal", 75_000, 799, 160 },
}
for key, values in coinPacks do
	configureProduct(key, {
		Key = key,
		DisplayName = values[1],
		Description = string.format("Receive %s Coins immediately.", tostring(values[2])),
		Coins = values[2],
		RecommendedRobux = values[3],
		Category = "Coins",
		Order = values[4],
		Featured = key == "Backpack" or key == "Vault",
		ShopVisible = true,
		FallbackImageId = Images.Coin,
	})
end

configureProduct("RunBoost", {
	Key = "RunBoost", DisplayName = "Run Boost", Description = "Current run: x2 Coins and x1.5 XP.",
	Category = "Boosts", Order = 210, Featured = true, ShopVisible = true, RecommendedRobux = 49,
	Contextual = true, FallbackImageId = Images.Luck,
})
configureProduct("TakeAll", {
	Key = "TakeAll", DisplayName = "Take All", Description = "Claim all eligible cards from this choice.",
	Category = "Boosts", Order = 220, Featured = false, ShopVisible = false, RecommendedRobux = 3,
	Contextual = true, FallbackImageId = Images.Abilities.Overcharge,
})

configureGamepass("DoubleCoins", {
	Key = "DoubleCoins", DisplayName = "x2 Coins", Description = "Permanently doubles eligible Coin pickups.",
	Category = "Gamepasses", Order = 310, Featured = true, ShopVisible = true, RecommendedRobux = 499,
	FallbackImageId = Images.Coin,
})
configureGamepass("ExtraAbilitySlots", {
	Key = "ExtraAbilitySlots", DisplayName = "+2 Ability Slots",
	Description = "Permanently adds 1 Weapon and 1 Passive slot.",
	Category = "Gamepasses", Order = 320, Featured = true, ShopVisible = true, RecommendedRobux = 399,
	FallbackImageId = Images.Lock,
})

local premiumClasses = {
	Gunslinger = { "Gunslinger", "Shotgun", 299, 410 },
	Cryomancer = { "Cryomancer", "FrostNova", 499, 420 },
	Starcaller = { "Starcaller", "Meteor", 799, 430 },
	Titan = { "Titan", "Turret", 1_499, 440 },
	VoidEmperor = { "Void Emperor", "Vortex", 2_499, 450 },
}
for key, values in premiumClasses do
	configureGamepass(key, {
		Key = key,
		DisplayName = values[1],
		Description = "Permanently unlock this premium class and its starting ability.",
		Category = "Classes",
		ClassId = key,
		AbilityId = values[2],
		RecommendedRobux = values[3],
		Order = values[4],
		Featured = key == "Gunslinger" or key == "VoidEmperor",
		ShopVisible = true,
		FallbackImageId = Images.Abilities[values[2]],
	})
end

MonetizationConfig.Shop = {
	Enabled = true,
	Categories = { "Featured", "Coins", "Gamepasses", "Boosts", "Classes" },
	DefaultCategory = "Featured",
	MaximumReceiptHistory = 100,
}

MonetizationConfig.Run = {
	BoostCoinMultiplier = 2,
	BoostXPMultiplier = 1.5,
	PermanentCoinMultiplier = 2,
	TeamWipeGraceSeconds = 15,
	CheckpointRespawnInterval = 5,
}

MonetizationConfig.AbilitySlots = {
	BaseWeapon = 5,
	BasePassive = 5,
	GamepassWeaponBonus = 1,
	GamepassPassiveBonus = 1,
}

local function validAssetId(value: any): boolean
	return type(value) == "string" and value:match("^rbxassetid://[1-9]%d*$") ~= nil
end

function MonetizationConfig.GetProduct(key: string)
	return MonetizationConfig.DeveloperProducts[key] or MonetizationConfig.Gamepasses[key]
end

function MonetizationConfig.GetImage(definition)
	if definition and validAssetId(definition.ImageId) then
		return definition.ImageId
	end
	return (definition and definition.FallbackImageId) or Images.Coin
end

function MonetizationConfig.GetPremiumClass(classId: string)
	local gamepass = MonetizationConfig.Gamepasses[classId]
	return if gamepass and gamepass.ClassId == classId then gamepass else nil
end

function MonetizationConfig.IsConfiguredId(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0
end

return table.freeze(MonetizationConfig)
