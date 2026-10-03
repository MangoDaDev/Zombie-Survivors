local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local LocalPlayer = Players.LocalPlayer
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
local SHOP_LAUNCHER_IMAGE = MonetizationConfig.GetImage(MonetizationConfig.DeveloperProducts.Backpack)

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

local function productCard(productKey: string, definition, shopState, infoRevision, portrait, variant: string, parentLayout)
	local owned = derive(function()
		shopState()
		return definition.GamepassId ~= nil and MonetizationController.OwnsGamepass(productKey)
	end)
	local image = derive(function()
		infoRevision()
		return MonetizationController.GetImage(productKey)
	end)
	local productType, typeColor = getProductType(definition)

	local layout = {}
	layout.Viewport = parentLayout
	layout.Frame = ResponsiveLayout.Child(UDim2.fromScale(1, 1), layout.Viewport)
	layout.ArtworkPanel = ResponsiveLayout.Child(function() return if portrait() then UDim2.new(0.31, -10, 1, -16) else UDim2.new(0, 150, 1, -16) end, layout.Frame)
	layout.TextLabel = ResponsiveLayout.Child(UDim2.fromOffset(82, 22), layout.ArtworkPanel)
	layout.Details = ResponsiveLayout.Child(function() return if portrait() then UDim2.new(0.69, -14, 1, -16) else UDim2.new(1, -174, 1, -16) end, layout.Frame)

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
			Position = layout.Frame.Scale(UDim2.new(0, 8, 0, 8)),
			Size = layout.ArtworkPanel.Size,
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
				Position = layout.ArtworkPanel.Scale(UDim2.new(0, 6, 0, 6)),
				Size = layout.TextLabel.Size,
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
			Position = layout.Frame.Scale(function() return if portrait() then UDim2.new(0.31, 6, 0, 8) else UDim2.new(0, 166, 0, 8) end),
			Size = layout.Details.Size,
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
						return if owned()
							then "OWNED"
							else UIStyle.RobuxSymbol .. " " .. MonetizationController.GetPriceText(productKey)
					end,
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
	local launcherHovered = source(false)
	local launcherPressed = source(false)
	local launcherIconTween
	local launcherScale = spring(derive(function()
		if launcherPressed() then return 0.92 end
		return if launcherHovered() then 1.08 else 1
	end), 0.14, 0.82)
	-- User invariant: preserve one composition at every screen size.
	local function portrait() return false end
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
			if isOpen then
				-- Hiding an hovered/pressed launcher must never leave its spring in a stuck state.
				launcherHovered(false)
				launcherPressed(false)
				scrollToCategory(category)
			else
				selectedCategory(category)
			end
		end),
		MonetizationController.GetStateChangedSignal():Connect(function(newState) shopState(newState) end),
		MonetizationController.GetProductInfoChangedSignal():Connect(function() infoRevision(infoRevision() + 1) end),
		SafeArea.GetChangedSignal():Connect(function() topOffset(SafeArea.GetTopOffset(10)) end),
	}
	cleanup(function()
		if launcherIconTween then launcherIconTween:Cancel() end
		if catalogScrollConnection then catalogScrollConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(viewportSize)
	layout.MonetizationShop = layout.Viewport
	layout.Launcher = ResponsiveLayout.Base(UDim2.fromOffset(96, 96), layout.MonetizationShop, 1)
	layout.Overlay = layout.MonetizationShop
	layout.BackdropSensor = layout.Overlay
	layout.Panel = ResponsiveLayout.Base(function()
		if portrait() then
			return UDim2.new(0.35, 230, 0.35, 465)
		end
		-- Keep growing on larger displays, but more slowly than a predominantly scale-sized panel.
		return UDim2.new(0.5, 380, 0.6, 220)
	end, layout.Overlay, function() return if portrait() then 0.72 else 1.7 end)
	layout.Header = ResponsiveLayout.Child(UDim2.new(1, -84, 0, 76), layout.Panel)
	layout.TextLabel = ResponsiveLayout.Child(UDim2.new(0.72, 0, 0, 39), layout.Header)
	layout.TextLabel2 = ResponsiveLayout.Child(UDim2.new(0.74, 0, 0, 17), layout.Header)
	layout.Close = ResponsiveLayout.Child(UDim2.fromOffset(62, 76), layout.Panel)
	layout.JumpBar = ResponsiveLayout.Child(UDim2.new(1, -20, 0, 48), layout.Panel)
	layout.Catalog = ResponsiveLayout.Child(UDim2.new(1, -20, 1, -164), layout.Panel)
	layout.Content = ResponsiveLayout.Child(function()
		local height = 0
		for _, category in MonetizationConfig.Shop.Categories do
			local rows = math.ceil(#collectProducts(category) / (if portrait() then 1 else 2))
			height += 52 + rows * ((if portrait() then 150 else 172) + 10)
		end
		return UDim2.new(1, -32, 0, math.max(height - 10, 1))
	end, layout.Catalog)

	local function catalogSection(category, sectionOrder, cards, parentLayout)
		local layout = {}
		layout.Viewport = parentLayout
		layout.Frame = ResponsiveLayout.Child(function() return UDim2.new(1, 0, 0, 52 + math.ceil(#cards / (if portrait() then 1 else 2)) * ((if portrait() then 150 else 172) + 10) - 10) end, layout.Viewport)
		layout.SectionTitle = ResponsiveLayout.Child(UDim2.new(1, 0, 0, 30), layout.Frame)
		layout.Products = ResponsiveLayout.Child(function() return UDim2.new(1, 0, 0, math.ceil(#cards / (if portrait() then 1 else 2)) * ((if portrait() then 150 else 172) + 10) - 10) end, layout.Frame)

		return create "Frame" {
			Name = category .. "Section",
			BackgroundTransparency = 1,
			LayoutOrder = sectionOrder,
			Size = layout.Frame.Size,
			ZIndex = 224,
			action(function(instance) sectionFrames[category] = instance :: Frame end),
			create "TextLabel" {
				Name = "SectionTitle",
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = layout.SectionTitle.Size,
				Text = if category == "Featured" then "FEATURED  •  RECOMMENDED UPGRADES" else string.upper(category),
				TextColor3 = GOLD_LIGHT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 225,
			},
			create "Frame" {
				Name = "Products",
				BackgroundTransparency = 1,
				Position = layout.Frame.Scale(UDim2.new(0, 0, 0, 38)),
				Size = layout.Products.Size,
				ZIndex = 225,
				create "UIGridLayout" {
					CellPadding = layout.Products.Scale(UDim2.fromOffset(10, 10)),
					CellSize = layout.Products.Scale(function()
						return if portrait() then UDim2.new(1, 0, 0, 150) else UDim2.new(0.5, -5, 0, 172)
					end),
					FillDirectionMaxCells = function() return if portrait() then 1 else 2 end,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				cards,
			},
		}
	end

	local sections = {}
	for sectionOrder, category in MonetizationConfig.Shop.Categories do
		local cards = {}
		for _, entry in collectProducts(category) do
			table.insert(cards, productCard(entry.key, entry.definition, shopState, infoRevision, portrait, category, ResponsiveLayout.Child(function() return if portrait() then UDim2.new(1, 0, 0, 150) else UDim2.new(0.5, -5, 0, 172) end, layout.Content)))
		end
		table.insert(sections, catalogSection(category, sectionOrder, cards, layout.Content))
	end

	local tabs = {}
	for order, category in MonetizationConfig.Shop.Categories do
		table.insert(tabs, create "Frame" {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = layout.JumpBar.Scale(function() return UDim2.new(0, if portrait() then 112 else 146, 1, 0) end),
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
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			-- User-requested fixed launcher location: centered vertically against the right safe edge.
			Position = layout.Launcher.Position(UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5)),
			Size = layout.Launcher.Size,
			Visible = function() return not open() end,
			ZIndex = 90,
			create "UIAspectRatioConstraint" {
				AspectRatio = layout.Launcher.AspectRatio,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "Frame" {
				Name = "LauncherVisual",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(91, 59, 13),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 91,
				create "UIScale" { Scale = launcherScale },
				create "UICorner" { CornerRadius = UDim.new(0, 10) },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(104, 68, 15), Thickness = 4 },
				create "ImageLabel" {
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = UIStyle.GlowTexture,
					ImageColor3 = GOLD_LIGHT,
					ImageTransparency = function() return if launcherHovered() then 0.7 else 0.84 end,
					Position = UDim2.fromScale(0.5, 0.46),
					Size = UDim2.fromScale(1.45, 1.45),
					ZIndex = 91,
				},
				create "Frame" {
					Name = "Face",
					BackgroundColor3 = GOLD,
					BorderSizePixel = 0,
					Position = function() return UDim2.fromScale(0, if launcherPressed() then 0.07 else 0) end,
					Size = function() return UDim2.fromScale(1, if launcherPressed() then 0.86 else 0.93) end,
					ZIndex = 92,
					create "UICorner" { CornerRadius = UDim.new(0, 9) },
					StudTexture({ ZIndex = 93, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UDim2.fromOffset(54, 54) }),
					create "ImageLabel" {
						Name = "ShopArtwork",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = SHOP_LAUNCHER_IMAGE,
						Position = UDim2.fromScale(0.5, 0.42),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.78, 0.72),
						ZIndex = 94,
						action(function(instance)
							local artwork = instance :: ImageLabel
							artwork.Rotation = -3
							launcherIconTween = TweenService:Create(
								artwork,
								TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
								{ Rotation = 3 }
							)
							launcherIconTween:Play()
						end),
					},
					create "Frame" {
						Name = "LabelBadge",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = PANEL,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.96),
						Size = UDim2.fromScale(0.78, 0.22),
						ZIndex = 95,
						create "UICorner" { CornerRadius = UDim.new(0, 4) },
						create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = GOLD_LIGHT, Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Size = UDim2.fromScale(1, 1),
							Text = "SHOP",
							TextColor3 = PAPER,
							TextScaled = true,
							ZIndex = 96,
							create "UITextSizeConstraint" { MaxTextSize = 18, MinTextSize = 10 },
						},
					},
				},
				create "TextButton" {
					Name = "Sensor",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					ZIndex = 100,
					MouseEnter = function()
						if not launcherHovered() then Sounds.Play("HoverStart", LocalPlayer.PlayerGui) end
						launcherHovered(true)
					end,
					MouseLeave = function()
						if launcherHovered() then Sounds.Play("HoverEnd", LocalPlayer.PlayerGui) end
						launcherHovered(false)
						launcherPressed(false)
					end,
					InputBegan = function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							launcherPressed(true)
							Sounds.Play("MouseDown", LocalPlayer.PlayerGui)
						end
					end,
					InputEnded = function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then launcherPressed(false) end
					end,
					Activated = function()
						launcherHovered(false)
						launcherPressed(false)
						Sounds.Play("Click", LocalPlayer.PlayerGui)
						MonetizationController.SetShopOpen(true)
					end,
				},
			},
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
				Position = layout.Panel.Position(function() return UDim2.new(0.5, 0, 0.5, topOffset() * 0.5) end, Vector2.new(0.5, 0.5)),
				Size = layout.Panel.Size,
				ZIndex = 215,
				create "UIAspectRatioConstraint" {
					AspectRatio = function() return if portrait() then 0.72 else 1.7 end,
					AspectType = Enum.AspectType.FitWithinMaxSize,
				},
				create "UIScale" { Scale = UIStyle.NonClassMenuScale },
				create "UICorner" { CornerRadius = UDim.new(0, 7) },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = GOLD, Thickness = 3 },
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = GOLD,
					BorderSizePixel = 0,
					Position = layout.Panel.Scale(UDim2.new(0, 10, 0, 10)),
					Size = layout.Header.Size,
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
						Position = layout.Header.Scale(UDim2.new(0, 18, 0, 5)),
						Size = layout.TextLabel.Size,
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
						Position = layout.Header.Scale(UDim2.new(0, 20, 0, 49)),
						Size = layout.TextLabel2.Size,
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
					Position = layout.Panel.Scale(UDim2.new(1, -10, 0, 10)),
					Size = layout.Close.Size,
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
					Position = layout.Panel.Scale(UDim2.new(0, 10, 0, 96)),
					ScrollBarThickness = 0,
					ScrollingDirection = Enum.ScrollingDirection.X,
					Size = layout.JumpBar.Size,
					ZIndex = 222,
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(54, 91, 111), Thickness = 2 },
					create "UIPadding" { PaddingLeft = layout.JumpBar.Padding(UDim.new(0, 6), "X"), PaddingRight = layout.JumpBar.Padding(UDim.new(0, 6), "X"), PaddingTop = layout.JumpBar.Padding(UDim.new(0, 6), "Y"), PaddingBottom = layout.JumpBar.Padding(UDim.new(0, 6), "Y")},
					create "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = layout.JumpBar.Padding(UDim.new(0, 7), "X"), SortOrder = Enum.SortOrder.LayoutOrder },
					tabs,
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(4, 24, 38),
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = layout.Panel.Scale(UDim2.new(0, 10, 0, 154)),
					ScrollBarImageColor3 = GOLD,
					ScrollBarThickness = 5,
					Size = layout.Catalog.Size,
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
			BackgroundTransparency = 1,
						Position = layout.Catalog.Scale(UDim2.new(0, 14, 0, 12)),
						Size = layout.Content.Size,
						ZIndex = 224,
						create "UIListLayout" { Padding = layout.Content.Padding(UDim.new(0, 10), "Y"), SortOrder = Enum.SortOrder.LayoutOrder },
						sections,
					},
				},
			},
		},
	}
end
