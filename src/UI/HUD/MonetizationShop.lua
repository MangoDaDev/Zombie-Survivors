local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local GOLD = Color3.fromRGB(225, 157, 40)
local GOLD_LIGHT = Color3.fromRGB(255, 211, 91)
local PANEL = Color3.fromRGB(3, 18, 30)
local PANEL_MID = Color3.fromRGB(4, 29, 45)
local CARD = Color3.fromRGB(10, 41, 57)
local CARD_DARK = Color3.fromRGB(2, 15, 25)
local MUTED = Color3.fromRGB(162, 190, 204)
local PAPER = Color3.fromRGB(244, 249, 252)
local HEAVY_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy)
local BOLD_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)

local function getProductType(definition): (string, Color3)
	if definition.GamepassId ~= nil then
		return "PERMANENT", Color3.fromRGB(193, 137, 255)
	elseif definition.Category == "Coins" then
		return "INSTANT COINS", Color3.fromRGB(110, 203, 236)
	elseif definition.Key == "RunBoost" then
		return "CURRENT RUN ONLY", Color3.fromRGB(255, 191, 91)
	end
	return "REPEATABLE", Color3.fromRGB(110, 203, 236)
end

local function productCard(productKey: string, definition, shopState, infoRevision, portrait, variant: string)
	local owned = derive(function()
		shopState()
		return definition.GamepassId ~= nil and MonetizationController.OwnsGamepass(productKey)
	end)
	local image = derive(function()
		infoRevision()
		return MonetizationController.GetImage(productKey)
	end)
	local productType, typeColor = getProductType(definition)

	return create "Frame" {
		Name = productKey .. variant,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		LayoutOrder = definition.Order,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 225,
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function() return if definition.Featured then GOLD else Color3.fromRGB(62, 99, 118) end,
			Thickness = function() return if definition.Featured then 3 else 2 end,
		},
		create "Frame" {
			Name = "ArtworkPanel",
			BackgroundColor3 = CARD_DARK,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, 8),
			Size = function() return if portrait() then UDim2.new(0.31, -10, 1, -16) else UDim2.new(0, 150, 1, -16) end,
			ZIndex = 227,
			create "UICorner" { CornerRadius = UDim.new(0, 3) },
			create "ImageLabel" {
				Name = "ProductArtwork",
				BackgroundTransparency = 1,
				Image = image,
				Position = UDim2.fromScale(0.06, 0.06),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.88, 0.88),
				ZIndex = 228,
			},
			create "TextLabel" {
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				FontFace = BOLD_FONT,
				Position = UDim2.new(0, 6, 0, 6),
				Size = UDim2.fromOffset(82, 22),
				Text = "FEATURED",
				TextColor3 = Color3.fromRGB(58, 32, 5),
				TextScaled = true,
				Visible = definition.Featured,
				ZIndex = 229,
			},
		},
		create "Frame" {
			Name = "Details",
			BackgroundTransparency = 1,
			Position = function() return if portrait() then UDim2.new(0.31, 6, 0, 8) else UDim2.new(0, 166, 0, 8) end,
			Size = function() return if portrait() then UDim2.new(0.69, -14, 1, -16) else UDim2.new(1, -174, 1, -16) end,
			ZIndex = 228,
			create "TextLabel" {
				Name = "ProductName",
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.fromScale(1, 0.2),
				Text = string.upper(definition.DisplayName),
				TextColor3 = PAPER,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 228,
			},
			create "TextLabel" {
				Name = "ProductType",
				BackgroundTransparency = 1,
				FontFace = BOLD_FONT,
				Position = UDim2.fromScale(0, 0.22),
				Size = UDim2.fromScale(1, 0.11),
				Text = productType,
				TextColor3 = typeColor,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 228,
			},
			create "TextLabel" {
				Name = "Benefit",
				BackgroundTransparency = 1,
				FontFace = BOLD_FONT,
				Position = UDim2.fromScale(0, 0.37),
				Size = UDim2.fromScale(1, 0.23),
				Text = definition.Description,
				TextColor3 = MUTED,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 228,
			},
			create "Frame" {
				Name = "Buy",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0.27),
				ZIndex = 230,
				Button({
					Text = function()
						infoRevision()
						shopState()
						return if owned() then "OWNED" else MonetizationController.GetPriceText(productKey)
					end,
					LeftIcon = Images.Robux,
					LeftIconVisible = function() return not owned() end,
					Enabled = function() return not owned() end,
					BackgroundColor3 = function() return if owned() then UIStyle.Colors.Green else GOLD end,
					CornerRadius = UDim.new(0, 3),
					FontFace = HEAVY_FONT,
					MaxTextSize = 28,
					MinTextSize = 11,
					Size = UDim2.fromScale(1, 1),
					OnActivated = function() MonetizationController.Prompt(productKey) end,
				}),
			},
		},
	}
end

local function collectProducts(category: string)
	local products = {}
	local function consider(key: string, definition)
		if definition.ShopVisible and (category == "Featured" and definition.Featured or definition.Category == category) then
			table.insert(products, { key = key, definition = definition })
		end
	end
	for key, definition in MonetizationConfig.DeveloperProducts do consider(key, definition) end
	for key, definition in MonetizationConfig.Gamepasses do consider(key, definition) end
	table.sort(products, function(a, b) return a.definition.Order < b.definition.Order end)
	return products
end

return function()
	local open = source(MonetizationController.IsShopOpen())
	local selectedCategory = source(MonetizationController.GetShopCategory())
	local shopState = source(MonetizationController.GetState())
	local infoRevision = source(0)
	local viewportSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(10))
	local portrait = derive(function() return viewportSize().X < viewportSize().Y * 0.9 end)
	local catalog: ScrollingFrame?
	local sectionFrames: { [string]: Frame } = {}
	local catalogScrollConnection: RBXScriptConnection?

	local function scrollToCategory(category: string)
		selectedCategory(category)
		task.defer(function()
			local currentCatalog = catalog
			local section = sectionFrames[category]
			if not currentCatalog or not section then return end
			-- Category controls navigate one continuous catalog. They must never hide or replace sections.
			local targetY = currentCatalog.CanvasPosition.Y + section.AbsolutePosition.Y - currentCatalog.AbsolutePosition.Y - 8
			local maximumY = math.max(currentCatalog.AbsoluteCanvasSize.Y - currentCatalog.AbsoluteWindowSize.Y, 0)
			currentCatalog.CanvasPosition = Vector2.new(0, math.clamp(targetY, 0, maximumY))
		end)
	end

	local connections = {
		MonetizationController.GetShopChangedSignal():Connect(function(isOpen, category)
			open(isOpen)
			if isOpen then scrollToCategory(category) else selectedCategory(category) end
		end),
		MonetizationController.GetStateChangedSignal():Connect(function(newState) shopState(newState) end),
		MonetizationController.GetProductInfoChangedSignal():Connect(function() infoRevision(infoRevision() + 1) end),
		SafeArea.GetChangedSignal():Connect(function() topOffset(SafeArea.GetTopOffset(10)) end),
	}
	cleanup(function()
		if catalogScrollConnection then catalogScrollConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end)

	local sections = {}
	for sectionOrder, category in MonetizationConfig.Shop.Categories do
		local cards = {}
		for _, entry in collectProducts(category) do
			table.insert(cards, productCard(entry.key, entry.definition, shopState, infoRevision, portrait, category))
		end
		table.insert(sections, create "Frame" {
			Name = category .. "Section",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = sectionOrder,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 224,
			action(function(instance) sectionFrames[category] = instance :: Frame end),
			create "TextLabel" {
				Name = "SectionTitle",
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.new(1, 0, 0, 30),
				Text = if category == "Featured" then "FEATURED  •  RECOMMENDED UPGRADES" else string.upper(category),
				TextColor3 = GOLD_LIGHT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 225,
			},
			create "Frame" {
				Name = "Products",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 38),
				Size = UDim2.new(1, 0, 0, 0),
				ZIndex = 225,
				create "UIGridLayout" {
					CellPadding = UDim2.fromOffset(10, 10),
					CellSize = function()
						return if portrait() then UDim2.new(1, 0, 0, 150) else UDim2.new(0.5, -5, 0, 172)
					end,
					FillDirectionMaxCells = function() return if portrait() then 1 else 2 end,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				cards,
			},
			create "UIPadding" { PaddingBottom = UDim.new(0, 14) },
		})
	end

	local tabs = {}
	for order, category in MonetizationConfig.Shop.Categories do
		table.insert(tabs, create "Frame" {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = function() return UDim2.new(0, if portrait() then 112 else 146, 1, 0) end,
			ZIndex = 223,
			Button({
				Text = string.upper(category),
				BackgroundColor3 = function() return if selectedCategory() == category then GOLD else Color3.fromRGB(19, 49, 65) end,
				CornerRadius = UDim.new(0, 3),
				FontFace = if category == "Featured" then HEAVY_FONT else BOLD_FONT,
				MaxTextSize = 20,
				MinTextSize = 10,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					MonetizationController.SetShopCategory(category)
					scrollToCategory(category)
				end,
			}),
		})
	end

	return create "Frame" {
		Name = "MonetizationShop",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 200,
		action(function(instance)
			local root = instance :: Frame
			viewportSize(root.AbsoluteSize)
			table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				viewportSize(root.AbsoluteSize)
			end))
		end),
		create "Frame" {
			Name = "Launcher",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 18, 1, -22),
			Size = UDim2.fromOffset(142, 50),
			Visible = function() return not open() end,
			ZIndex = 90,
			Button({
				Text = "SHOP",
				LeftIcon = Images.Coin,
				BackgroundColor3 = GOLD,
				CornerRadius = UDim.new(0, 5),
				FontFace = HEAVY_FONT,
				MaxTextSize = 26,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function() MonetizationController.SetShopOpen(true) end,
			}),
		},
		create "Frame" {
			Name = "Overlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(1, 7, 13),
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = open,
			ZIndex = 210,
			create "TextButton" {
				Name = "BackdropSensor",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 210,
				Activated = function() MonetizationController.SetShopOpen(false) end,
			},
			create "Frame" {
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PANEL,
				BorderSizePixel = 0,
				Position = function() return UDim2.new(0.5, 0, 0.5, topOffset() * 0.5) end,
				Size = function() return if portrait() then UDim2.fromScale(0.94, 0.9) else UDim2.fromScale(0.92, 0.9) end,
				ZIndex = 215,
				create "UIAspectRatioConstraint" {
					AspectRatio = function() return if portrait() then 0.72 else 1.7 end,
					AspectType = Enum.AspectType.FitWithinMaxSize,
				},
				create "UICorner" { CornerRadius = UDim.new(0, 7) },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = GOLD, Thickness = 3 },
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = GOLD,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 10, 0, 10),
					Size = UDim2.new(1, -84, 0, 76),
					ZIndex = 218,
					create "UIGradient" {
						Color = ColorSequence.new(Color3.fromRGB(255, 212, 90), Color3.fromRGB(215, 142, 29)),
						Rotation = 90,
					},
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = GOLD_LIGHT, Thickness = 2 },
					StudTexture({ ZIndex = 219, ImageColor3 = Color3.fromRGB(90, 49, 8), ImageTransparency = 0.84 }),
					create "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = UDim2.new(0, 18, 0, 5),
						Size = UDim2.new(0.72, 0, 0, 39),
						Text = "SURVIVOR SHOP",
						TextColor3 = PAPER,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 220,
						create "UIStroke" { Color = Color3.fromRGB(70, 39, 7), Thickness = 4 },
					},
					create "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = BOLD_FONT,
						Position = UDim2.new(0, 20, 0, 49),
						Size = UDim2.new(0.74, 0, 0, 17),
						Text = "COINS, PERMANENT PERKS & RUN UPGRADES",
						TextColor3 = Color3.fromRGB(79, 47, 8),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 220,
					},
				},
				create "Frame" {
					Name = "Close",
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -10, 0, 10),
					Size = UDim2.fromOffset(62, 76),
					ZIndex = 221,
					Button({
						Text = "X",
						BackgroundColor3 = UIStyle.Colors.Red,
						CornerRadius = UDim.new(0, 4),
						FontFace = HEAVY_FONT,
						MaxTextSize = 40,
						Size = UDim2.fromScale(1, 1),
						OnActivated = function() MonetizationController.SetShopOpen(false) end,
					}),
				},
				create "ScrollingFrame" {
					Name = "JumpBar",
					AutomaticCanvasSize = Enum.AutomaticSize.X,
					BackgroundColor3 = PANEL_MID,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = UDim2.new(0, 10, 0, 96),
					ScrollBarThickness = 0,
					ScrollingDirection = Enum.ScrollingDirection.X,
					Size = UDim2.new(1, -20, 0, 48),
					ZIndex = 222,
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(54, 91, 111), Thickness = 2 },
					create "UIPadding" { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) },
					create "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder },
					tabs,
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(4, 24, 38),
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = UDim2.new(0, 10, 0, 154),
					ScrollBarImageColor3 = GOLD,
					ScrollBarThickness = 5,
					Size = UDim2.new(1, -20, 1, -164),
					ZIndex = 222,
					action(function(instance)
						catalog = instance :: ScrollingFrame
						if catalogScrollConnection then catalogScrollConnection:Disconnect() end
						catalogScrollConnection = catalog:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
							local currentCategory = MonetizationConfig.Shop.Categories[1]
							local probeY = catalog.CanvasPosition.Y + 34
							for _, category in MonetizationConfig.Shop.Categories do
								local section = sectionFrames[category]
								if section then
									local sectionY = catalog.CanvasPosition.Y + section.AbsolutePosition.Y - catalog.AbsolutePosition.Y
									if sectionY <= probeY then currentCategory = category end
								end
							end
							selectedCategory(currentCategory)
						end)
						task.defer(function() scrollToCategory(selectedCategory()) end)
					end),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(38, 80, 101), Thickness = 2 },
					create "Frame" {
						Name = "Content",
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 14, 0, 12),
						Size = UDim2.new(1, -32, 0, 0),
						ZIndex = 224,
						create "UIListLayout" { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder },
						sections,
					},
				},
			},
		},
	}
end
