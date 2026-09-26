local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local localPlayer = Players.LocalPlayer
local HEAVY_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy)
local BOLD_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)
local PANEL = Color3.fromRGB(3, 18, 30)
local PANEL_LIGHT = Color3.fromRGB(4, 29, 45)
local PAPER = Color3.fromRGB(235, 242, 247)
local PAPER_INSET = Color3.fromRGB(205, 220, 229)
local CYAN = Color3.fromRGB(0, 184, 219)
local CYAN_LIGHT = Color3.fromRGB(34, 220, 250)
local INK = Color3.fromRGB(24, 41, 52)

local function textStroke(color: Color3?, thickness: number?)
	return create "UIStroke" {
		Color = color or Color3.fromRGB(0, 12, 22),
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness or 0.055,
	}
end

local function isOwned(state, abilityId: string): boolean
	return type(state) == "table"
		and type(state.Owned) == "table"
		and state.Owned[abilityId] == true
end

local function countCategory(state, category: string): (number, number)
	local unlocked = 0
	local total = 0
	for _, ability in AbilityDefinitions.List do
		if ability.Category == category then
			total += 1
			if isOwned(state, ability.Id) then
				unlocked += 1
			end
		end
	end
	return unlocked, total
end

local function firstAbilityId(category: string): string
	for _, ability in AbilityDefinitions.List do
		if ability.Category == category then
			return ability.Id
		end
	end
	return AbilityDefinitions.List[1].Id
end

local function abilityCard(ability, order: number, props)
	local hovered = source(false)
	local owned = derive(function()
		return isOwned(props.state(), ability.Id)
	end)
	local selected = derive(function()
		return props.selectedId() == ability.Id
	end)
	local scale = spring(function()
		return if hovered() then 1.018 else 1
	end, 0.16, 0.88)
	local unlockCost = AbilityDefinitions.GetUnlockCost(ability) or 0

	return create "Frame" {
		Name = ability.Id .. "Card",
		BackgroundColor3 = function()
			if selected() then
				return Color3.fromRGB(12, 73, 98)
			end
			return if owned() then Color3.fromRGB(13, 50, 63) else Color3.fromRGB(18, 38, 50)
		end,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = function()
			return UDim2.new(1, -10, 0, if props.portrait() then 76 else 86)
		end,
		Visible = function()
			return props.category() == ability.Category
		end,
		ZIndex = 325,
		create "UIScale" { Scale = scale },
		StudTexture({ ZIndex = 325, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(56, 56) }),
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if selected() then ability.Color else Color3.fromRGB(67, 104, 122)
			end,
			Thickness = function()
				return if selected() then 3 else 2
			end,
		},
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = ability.Icon,
			ImageColor3 = function()
				return if owned() or selected() then Color3.new(1, 1, 1) else Color3.fromRGB(169, 178, 183)
			end,
			Position = UDim2.new(0, 10, 0.5, 0),
			ScaleType = Enum.ScaleType.Fit,
			Size = function()
				local size = if props.portrait() then 50 else 58
				return UDim2.fromOffset(size, size)
			end,
			ZIndex = 327,
		},
		create "TextLabel" {
			Name = "AbilityName",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = function()
				return UDim2.fromOffset(if props.portrait() then 68 else 78, if props.portrait() then 9 else 12)
			end,
			Size = UDim2.new(1, -190, 0, 28),
			Text = string.upper(ability.Name),
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 327,
		},
		create "TextLabel" {
			Name = "Rarity",
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = function()
				return UDim2.fromOffset(if props.portrait() then 68 else 78, if props.portrait() then 43 else 49)
			end,
			Size = UDim2.new(1, -190, 0, 20),
			Text = string.upper(ability.Roll.Rarity .. " " .. ability.Category),
			TextColor3 = ability.Color:Lerp(Color3.new(1, 1, 1), 0.32),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 327,
		},
		create "Frame" {
			Name = "UnlockedBadge",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = UIStyle.Colors.Green,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(98, 30),
			Visible = owned,
			ZIndex = 328,
			StudTexture({ ZIndex = 328, ImageTransparency = 0.88, TileSize = UDim2.fromOffset(40, 40) }),
			create "UIStroke" { Color = Color3.fromRGB(14, 70, 37), Thickness = 2 },
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.fromScale(1, 1),
				Text = "UNLOCKED",
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				ZIndex = 329,
				textStroke(Color3.fromRGB(14, 70, 37), 0.04),
			},
		},
		create "Frame" {
			Name = "UnlockCost",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(67, 55, 26),
			BorderSizePixel = 0,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(104, 34),
			Visible = function()
				return not owned()
			end,
			ZIndex = 328,
			StudTexture({ ZIndex = 328, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(40, 40) }),
			create "UIStroke" { Color = Color3.fromRGB(210, 157, 47), Thickness = 2 },
			create "ImageLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Coin,
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(23, 23),
				ZIndex = 329,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Position = UDim2.fromOffset(36, 4),
				Size = UDim2.new(1, -42, 1, -8),
				Text = FormatNumber(unlockCost) or tostring(unlockCost),
				TextColor3 = Color3.fromRGB(255, 224, 129),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 329,
			},
		},
		create "TextButton" {
			Name = "Sensor",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 335,
			MouseEnter = function()
				hovered(true)
				Sounds.Play("HoverStart", localPlayer.PlayerGui)
			end,
			MouseLeave = function()
				hovered(false)
			end,
			Activated = function()
				props.selectedId(ability.Id)
				Sounds.Play("Click", localPlayer.PlayerGui)
			end,
		},
	}
end

return function()
	local state = source(AbilityController.GetState())
	local balance = source(CoinsController.Get())
	local runState = source(RunProgressionController.GetState())
	local open = source(AbilityController.IsInventoryOpen())
	local category = source(AbilityDefinitions.Categories.Weapon)
	local selectedId = source(firstAbilityId(AbilityDefinitions.Categories.Weapon))
	local viewportSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(12))
	local statusText = source("")
	local statusColor = source(UIStyle.Colors.Green)
	local statusToken = 0
	local viewportConnection: RBXScriptConnection?
	local connections = {}

	local portrait = derive(function()
		local size = viewportSize()
		return size.X < 600 and size.X < size.Y
	end)
	local shortLandscape = derive(function()
		local size = viewportSize()
		return not portrait() and size.Y < 560
	end)
	local inRun = derive(function()
		return runState().active == true
	end)

	local function selectedAbility()
		return AbilityDefinitions.ById[selectedId()] or AbilityDefinitions.List[1]
	end

	local function selectCategory(nextCategory: string)
		category(nextCategory)
		if selectedAbility().Category ~= nextCategory then
			selectedId(firstAbilityId(nextCategory))
		end
	end

	table.insert(connections, AbilityController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
	end))
	table.insert(connections, AbilityController.GetInventoryOpenChangedSignal():Connect(function(isOpen)
		open(isOpen)
	end))
	table.insert(connections, CoinsController.GetChangedSignal():Connect(function(newBalance)
		if type(newBalance) == "number" then
			balance(newBalance)
		end
	end))
	table.insert(connections, RunProgressionController.GetStateChangedSignal():Connect(function(newState)
		runState(newState)
		if newState.active then
			-- Purchases are deliberately lobby-only; starting a run closes every remaining shop input.
			AbilityController.SetInventoryOpen(false)
		end
	end))
	table.insert(connections, AbilityController.GetActionResultSignal():Connect(function(success, message)
		statusToken += 1
		local token = statusToken
		statusText(message)
		statusColor(if success then UIStyle.Colors.Green else UIStyle.Colors.Red)
		task.delay(3, function()
			if statusToken == token then
				statusText("")
			end
		end)
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end))
	cleanup(function()
		statusToken += 1
		for _, connection in connections do
			connection:Disconnect()
		end
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local cards = {}
	local previewIcons = {}
	for order, ability in AbilityDefinitions.List do
		table.insert(cards, abilityCard(ability, order, {
			state = state,
			category = category,
			selectedId = selectedId,
			portrait = portrait,
		}))
		table.insert(previewIcons, create "ImageLabel" {
			Name = ability.Id .. "Preview",
			BackgroundTransparency = 1,
			Image = ability.Icon,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return selectedId() == ability.Id
			end,
			ZIndex = 327,
		})
	end

	local headerHeight = derive(function()
		return if portrait() then 82 else if shortLandscape() then 72 else 94
	end)
	local contentTop = derive(function()
		return headerHeight() + 64
	end)
	local selectedOwned = derive(function()
		return isOwned(state(), selectedAbility().Id)
	end)
	local selectedCost = derive(function()
		return AbilityDefinitions.GetUnlockCost(selectedAbility()) or 0
	end)
	local canAfford = derive(function()
		return balance() >= selectedCost()
	end)

	local function categoryTab(tabCategory: string, label: string, activeColor: Color3, layoutOrder: number)
		return create "Frame" {
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
			Size = UDim2.new(0.5, -5, 1, 0),
			ZIndex = 318,
			Button({
				Text = function()
					local unlocked, total = countCategory(state(), tabCategory)
					return string.format("%s  %d/%d", label, unlocked, total)
				end,
				BackgroundColor3 = function()
					return if category() == tabCategory then activeColor else Color3.fromRGB(29, 48, 62)
				end,
				FontFace = HEAVY_FONT,
				MaxTextSize = 25,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					selectCategory(tabCategory)
				end,
			}),
		}
	end

	return create "Frame" {
		Name = "AbilityInterface",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 290,
		action(function(instance)
			local root = instance :: Frame
			local function updateViewport()
				viewportSize(root.AbsoluteSize)
			end
			updateViewport()
			viewportConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateViewport)
		end),
		create "Frame" {
			Name = "OpenButton",
			BackgroundTransparency = 1,
			Position = function()
				return UDim2.fromOffset(if portrait() then 10 else 18, topOffset())
			end,
			Size = UDim2.fromOffset(if portrait() then 142 else 176, if portrait() then 48 else 54),
			Visible = function()
				return not inRun() and not open()
			end,
			ZIndex = 55,
			Button({
				Text = "ABILITIES",
				BackgroundColor3 = Color3.fromRGB(16, 155, 211),
				CornerRadius = UDim.new(0, 4),
				FontFace = HEAVY_FONT,
				MaxTextSize = 25,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					AbilityController.SetInventoryOpen(true)
				end,
			}),
		},
		create "Frame" {
			Name = "ShopOverlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(2, 8, 14),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return open() and not inRun()
			end,
			ZIndex = 300,
			create "TextButton" {
				Name = "BackdropSensor",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 300,
				Activated = function()
					AbilityController.SetInventoryOpen(false)
				end,
			},
			create "Frame" {
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PANEL,
				BorderSizePixel = 0,
				Position = function()
					return UDim2.new(0.5, 0, 0.5, topOffset() * 0.08)
				end,
				Size = function()
					if portrait() then
						return UDim2.new(1, -18, 1, -30)
					elseif shortLandscape() then
						return UDim2.new(0.94, 0, 0.94, 0)
					end
					return UDim2.new(0.78, 40, 0.82, 30)
				end,
				ZIndex = 305,
				-- Every filled menu surface uses the shared stud layer; light content panels tint it dark below.
				StudTexture({ ZIndex = 306, ImageTransparency = 0.92, TileSize = UDim2.fromOffset(76, 76) }),
				create "UISizeConstraint" {
					MaxSize = function()
						return if portrait() then Vector2.new(420, 880) else Vector2.new(980, 620)
					end,
				},
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 5, 10), Thickness = 7 },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = CYAN, Thickness = 3 },
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = Color3.fromRGB(16, 168, 219),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(12, 12),
					Size = function()
						return UDim2.new(1, if portrait() then -76 else -96, 0, headerHeight())
					end,
					ZIndex = 310,
					create "UIGradient" {
						Color = ColorSequence.new(CYAN_LIGHT, Color3.fromRGB(18, 108, 191)),
						Rotation = 90,
					},
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(69, 229, 249), Thickness = 2 },
					StudTexture({ ZIndex = 311, ImageTransparency = 0.82, TileSize = UDim2.fromOffset(104, 104) }),
					create "TextLabel" {
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = UDim2.fromOffset(if portrait() then 10 else 20, if portrait() then 5 else 8),
						Size = function()
							return UDim2.new(if portrait() then 1 else 0.58, if portrait() then -20 else 0, 0, if portrait() then 42 else 50)
						end,
						Text = "ABILITY ARSENAL",
						TextColor3 = UIStyle.Colors.Paper,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 313,
						textStroke(nil, 0.065),
					},
					create "TextLabel" {
						Name = "Subtitle",
						BackgroundTransparency = 1,
						FontFace = BOLD_FONT,
						Position = UDim2.fromOffset(22, 64),
						Size = UDim2.new(0.66, 0, 0, 20),
						Text = "UNLOCK ABILITIES TO ADD THEM TO YOUR RUN CHOICES",
						TextColor3 = Color3.fromRGB(2, 47, 72),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = function()
							return not portrait() and not shortLandscape()
						end,
						ZIndex = 313,
					},
					create "Frame" {
						Name = "CoinBalance",
						AnchorPoint = function()
							return if portrait() then Vector2.new(0, 0) else Vector2.new(1, 0.5)
						end,
						BackgroundColor3 = Color3.fromRGB(37, 31, 20),
						BorderSizePixel = 0,
						Position = function()
							return if portrait() then UDim2.fromOffset(10, 51) else UDim2.new(1, -16, 0.5, 0)
						end,
						Size = function()
							return if portrait() then UDim2.new(1, -20, 0, 24) else UDim2.fromOffset(174, 50)
						end,
						ZIndex = 313,
						StudTexture({ ZIndex = 313, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(48, 48) }),
						create "UIStroke" { Color = Color3.fromRGB(218, 164, 55), Thickness = 2 },
						create "ImageLabel" {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Image = Images.Coin,
							Position = UDim2.new(0, if portrait() then 6 else 10, 0.5, 0),
							Size = function()
								local size = if portrait() then 20 else 34
								return UDim2.fromOffset(size, size)
							end,
							ZIndex = 314,
						},
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Position = function()
								return UDim2.fromOffset(if portrait() then 30 else 52, if portrait() then 2 else 5)
							end,
							Size = function()
								return UDim2.new(1, if portrait() then -34 else -58, 1, if portrait() then -4 else -10)
							end,
							Text = function()
								local formatted = FormatNumber(balance()) or tostring(balance())
								return if portrait() then "COINS  " .. formatted else formatted
							end,
							TextColor3 = Color3.fromRGB(255, 228, 146),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 314,
						},
					},
				},
				create "Frame" {
					Name = "CloseSlot",
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -12, 0, 12),
					Size = function()
						return UDim2.fromOffset(if portrait() then 52 else 64, headerHeight())
					end,
					ZIndex = 315,
					Button({
						Text = "X",
						BackgroundColor3 = UIStyle.Colors.Red,
						FontFace = HEAVY_FONT,
						MaxTextSize = 44,
						Size = UDim2.fromScale(1, 1),
						OnActivated = function()
							AbilityController.SetInventoryOpen(false)
						end,
					}),
				},
				create "Frame" {
					Name = "Tabs",
					BackgroundTransparency = 1,
					Position = function()
						return UDim2.fromOffset(12, headerHeight() + 20)
					end,
					Size = function()
						return UDim2.new(if portrait() then 1 else 0.41, if portrait() then -24 else -18, 0, if portrait() then 42 else 48)
					end,
					ZIndex = 317,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					categoryTab(AbilityDefinitions.Categories.Weapon, "WEAPONS", Color3.fromRGB(16, 155, 211), 1),
					categoryTab(AbilityDefinitions.Categories.Passive, "PASSIVES", Color3.fromRGB(176, 119, 34), 2),
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = PANEL_LIGHT,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = function()
						return UDim2.fromOffset(12, contentTop())
					end,
					ScrollBarImageColor3 = CYAN,
					ScrollBarThickness = 5,
					Size = function()
						if portrait() then
							return UDim2.new(1, -24, 0, 202)
						end
						return UDim2.new(0.41, -18, 1, -(contentTop() + 12))
					end,
					ZIndex = 320,
					StudTexture({ ZIndex = 321, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(60, 60) }),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 120, 148), Thickness = 2 },
					create "UIPadding" {
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 7),
						PaddingRight = UDim.new(0, 7),
						PaddingTop = UDim.new(0, 7),
					},
					create "UIListLayout" { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder },
					cards,
				},
				create "Frame" {
					Name = "Details",
					BackgroundColor3 = PAPER,
					BorderSizePixel = 0,
					Position = function()
						if portrait() then
							return UDim2.fromOffset(12, contentTop() + 212)
						end
						return UDim2.new(0.41, 2, 0, contentTop())
					end,
					Size = function()
						if portrait() then
							return UDim2.new(1, -24, 1, -(contentTop() + 224))
						end
						return UDim2.new(0.59, -14, 1, -(contentTop() + 12))
					end,
					ZIndex = 320,
					StudTexture({
						ZIndex = 321,
						ImageColor3 = INK,
						ImageTransparency = 0.96,
						TileSize = UDim2.fromOffset(68, 68),
					}),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(96, 145, 171), Thickness = 2 },
					create "Frame" {
						Name = "Preview",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(
							if portrait() then 14 elseif shortLandscape() then 18 else 28,
							if portrait() then 14 elseif shortLandscape() then 16 else 28
						),
						Size = function()
							local size = if portrait() then 92 elseif shortLandscape() then 110 else 176
							return UDim2.fromOffset(size, size)
						end,
						ZIndex = 326,
						previewIcons,
						create "ImageLabel" {
							Name = "Lock",
							AnchorPoint = Vector2.new(1, 1),
							BackgroundTransparency = 1,
							Image = Images.Lock,
							ImageColor3 = Color3.fromRGB(55, 74, 86),
							Position = UDim2.fromScale(1, 1),
							Size = UDim2.fromOffset(if portrait() then 32 else 46, if portrait() then 32 else 46),
							Visible = function()
								return not selectedOwned()
							end,
							ZIndex = 328,
						},
					},
					create "TextLabel" {
						Name = "Name",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = function()
							return UDim2.fromOffset(
								if portrait() then 116 elseif shortLandscape() then 145 else 224,
								if portrait() then 12 elseif shortLandscape() then 16 else 28
							)
						end,
						Size = function()
							return UDim2.new(
								1,
								if portrait() then -128 elseif shortLandscape() then -160 else -246,
								0,
								if portrait() then 38 elseif shortLandscape() then 34 else 46
							)
						end,
						Text = function()
							return string.upper(selectedAbility().Name)
						end,
						TextColor3 = function()
							return selectedAbility().Color:Lerp(Color3.fromRGB(30, 95, 139), 0.36)
						end,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 326,
					},
					create "TextLabel" {
						Name = "Rarity",
						BackgroundTransparency = 1,
						FontFace = BOLD_FONT,
						Position = function()
							return UDim2.fromOffset(
								if portrait() then 117 elseif shortLandscape() then 145 else 224,
								if portrait() then 55 elseif shortLandscape() then 56 else 82
							)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -128 elseif shortLandscape() then -160 else -246, 0, 25)
						end,
						Text = function()
							local ability = selectedAbility()
							return string.upper(ability.Roll.Rarity .. " " .. ability.Category)
						end,
						TextColor3 = Color3.fromRGB(67, 92, 108),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 326,
					},
					create "TextLabel" {
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = function()
							return UDim2.fromOffset(
								if portrait() then 117 elseif shortLandscape() then 145 else 224,
								if portrait() then 82 elseif shortLandscape() then 86 else 118
							)
						end,
						Size = function()
							return UDim2.new(
								1,
								if portrait() then -128 elseif shortLandscape() then -160 else -246,
								0,
								if portrait() or shortLandscape() then 54 else 86
							)
						end,
						Text = function()
							return AbilityDefinitions.GetDescription(selectedAbility(), 1)
						end,
						TextColor3 = INK,
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 326,
					},
					create "Frame" {
						Name = "Stats",
						BackgroundColor3 = PAPER_INSET,
						BorderSizePixel = 0,
						Position = function()
							return UDim2.new(
								0,
								if portrait() then 14 elseif shortLandscape() then 18 else 28,
								0,
								if portrait() or shortLandscape() then 150 else 224
							)
						end,
						Size = function()
							return UDim2.new(
								1,
								if portrait() then -28 elseif shortLandscape() then -36 else -56,
								0,
								if portrait() then 122 elseif shortLandscape() then 90 else 132
							)
						end,
						ZIndex = 325,
						StudTexture({
							ZIndex = 325,
							ImageColor3 = INK,
							ImageTransparency = 0.94,
							TileSize = UDim2.fromOffset(56, 56),
						}),
						create "UIStroke" { Color = Color3.fromRGB(110, 143, 160), Thickness = 2 },
						create "TextLabel" {
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Position = UDim2.fromOffset(12, 8),
							Size = UDim2.new(1, -24, 0, if portrait() then 25 elseif shortLandscape() then 22 else 30),
							Text = "STARTING RUN STATS",
							TextColor3 = Color3.fromRGB(36, 92, 120),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 326,
						},
						create "TextLabel" {
							Name = "StatsText",
							BackgroundTransparency = 1,
							FontFace = BOLD_FONT,
							Position = UDim2.fromOffset(12, if portrait() then 39 elseif shortLandscape() then 34 else 44),
							Size = UDim2.new(1, -24, 1, if portrait() then -47 elseif shortLandscape() then -40 else -52),
							Text = function()
								local ability = selectedAbility()
								return ability.GetStatsText and ability.GetStatsText(1) or ability.Description
							end,
							TextColor3 = INK,
							TextScaled = true,
							TextWrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 326,
						},
					},
					create "Frame" {
						Name = "RunAvailability",
						BackgroundColor3 = Color3.fromRGB(218, 239, 246),
						BorderSizePixel = 0,
						Position = function()
							return UDim2.new(0, if portrait() then 14 else 28, 0, if portrait() then 284 else 372)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -28 else -56, 0, if portrait() then 58 else 60)
						end,
						Visible = portrait,
						ZIndex = 325,
						StudTexture({
							ZIndex = 325,
							ImageColor3 = INK,
							ImageTransparency = 0.95,
							TileSize = UDim2.fromOffset(52, 52),
						}),
						create "UIStroke" { Color = Color3.fromRGB(78, 170, 193), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = BOLD_FONT,
							Position = UDim2.fromOffset(10, 7),
							Size = UDim2.new(1, -20, 1, -14),
							Text = function()
								return if selectedOwned()
									then "UNLOCKED  -  CAN APPEAR IN EVERY FUTURE RUN"
									else "PERMANENT UNLOCK  -  ADDED TO FUTURE RUN CHOICES"
							end,
							TextColor3 = Color3.fromRGB(17, 76, 96),
							TextScaled = true,
							TextWrapped = true,
							ZIndex = 326,
						},
					},
					create "TextLabel" {
						Name = "Status",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						FontFace = BOLD_FONT,
						Position = function()
							return UDim2.new(0.5, 0, 1, if shortLandscape() then -60 else -72)
						end,
						Size = UDim2.new(1, -42, 0, 24),
						Text = statusText,
						TextColor3 = statusColor,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Visible = function()
							return statusText() ~= ""
						end,
						ZIndex = 332,
					},
					create "Frame" {
						Name = "Action",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Position = UDim2.new(0.5, 0, 1, -14),
						Size = UDim2.new(
							1,
							if portrait() then -28 elseif shortLandscape() then -36 else -56,
							0,
							if portrait() then 54 elseif shortLandscape() then 46 else 58
						),
						ZIndex = 330,
						Button({
							Text = function()
								if selectedOwned() then
									return "UNLOCKED - AVAILABLE IN RUNS"
								end
								local costText = FormatNumber(selectedCost()) or tostring(selectedCost())
								if not canAfford() then
									return "NEED " .. costText .. " COINS"
								end
								return "UNLOCK FOR " .. costText .. " COINS"
							end,
							Enabled = function()
								return not selectedOwned() and selectedCost() > 0 and canAfford()
							end,
							BackgroundColor3 = function()
								return if selectedOwned() then UIStyle.Colors.Green elseif canAfford() then UIStyle.Colors.Gold else UIStyle.Colors.Muted
							end,
							FontFace = HEAVY_FONT,
							MaxTextSize = 32,
							Size = UDim2.fromScale(1, 1),
							OnActivated = function()
								local ability = selectedAbility()
								if not isOwned(state(), ability.Id) then
									AbilityController.UnlockAbility(ability.Id)
								end
							end,
						}),
					},
				},
			},
		},
	}
end
