local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local ClassController = require(ReplicatedStorage.Controllers.ClassController)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local PartyTeleporterController = require(ReplicatedStorage.Controllers.PartyTeleporterController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local ClassDefinitions = require(ReplicatedStorage.Modules.Game.Classes.ClassDefinitions)
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
local PANEL_LIGHT = Color3.fromRGB(4, 29, 45)
local PAPER = Color3.fromRGB(235, 242, 247)
local CYAN = Color3.fromRGB(0, 184, 219)
local INK = Color3.fromRGB(24, 41, 52)

local function isOwned(state, classId: string): boolean
	return type(state) == "table" and type(state.Owned) == "table" and state.Owned[classId] == true
end

local function getAbility(definition)
	return AbilityDefinitions.ById[definition.AbilityId]
end

local function classCard(definition, order: number, props)
	local hovered = source(false)
	local owned = derive(function()
		return isOwned(props.state(), definition.Id)
	end)
	local selected = derive(function()
		return props.selectedId() == definition.Id
	end)
	local equipped = derive(function()
		return props.state().Equipped == definition.Id
	end)
	local scale = spring(function()
		return if hovered() then 1.015 else 1
	end, 0.16, 0.88)
	local ability = getAbility(definition)

	return create "Frame" {
		Name = definition.Id .. "Card",
		BackgroundColor3 = function()
			return if selected() then Color3.fromRGB(12, 73, 98) else Color3.fromRGB(18, 46, 61)
		end,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = function()
			return UDim2.new(1, -4, 0, if props.compactPortrait() then 70 elseif props.portrait() then 82 elseif props.shortLandscape() then 70 else 92)
		end,
		ZIndex = 365,
		create "UIScale" { Scale = scale },
		StudTexture({ ZIndex = 365, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(56, 56) }),
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if selected() then definition.Color else Color3.fromRGB(74, 121, 143)
			end,
			Thickness = function()
				return if selected() then 3 else 2
			end,
		},
		create "ImageLabel" {
			Name = "AbilityIcon",
			AnchorPoint = function() return if props.portrait() then Vector2.new(0, 0) else Vector2.new(0, 0.5) end,
			BackgroundTransparency = 1,
			Image = ability.Icon,
			Position = function()
				return if props.portrait() then UDim2.fromOffset(9, 7) else UDim2.new(0, if props.shortLandscape() then 8 else 12, 0.5, 0)
			end,
			ScaleType = Enum.ScaleType.Fit,
			Size = function()
				local iconSize = if props.portrait() then 34 elseif props.shortLandscape() then 38 else 58
				return UDim2.fromOffset(iconSize, iconSize)
			end,
			ZIndex = 366,
		},
		create "TextLabel" {
			Name = "ClassName",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = function()
				if props.portrait() then return UDim2.fromOffset(8, if props.compactPortrait() then 46 else 56) end
				return UDim2.fromOffset(if props.shortLandscape() then 58 else 82, if props.shortLandscape() then 9 else 14)
			end,
			Size = function()
				if props.portrait() then return UDim2.new(1, -16, 0, 20) end
				return UDim2.new(1, if props.shortLandscape() then -154 else -196, 0, if props.shortLandscape() then 24 else 31)
			end,
			Text = string.upper(definition.Name),
			TextColor3 = PAPER,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 367,
		},
		create "TextLabel" {
			Name = "StartingAbility",
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = function()
				return UDim2.fromOffset(if props.shortLandscape() then 58 else 82, if props.shortLandscape() then 39 else 53)
			end,
			Size = function() return UDim2.new(1, if props.shortLandscape() then -154 else -196, 0, if props.shortLandscape() then 18 else 22) end,
			Text = string.upper(ability.Name),
			TextColor3 = definition.Color,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = function() return not props.portrait() end,
			ZIndex = 367,
		},
		create "Frame" {
			Name = "StateBadge",
			AnchorPoint = function() return if props.portrait() then Vector2.new(1, 0) else Vector2.new(1, 0.5) end,
			BackgroundColor3 = function()
				return if equipped() then UIStyle.Colors.Green elseif owned() then Color3.fromRGB(28, 110, 143) else Color3.fromRGB(67, 55, 26)
			end,
			BorderSizePixel = 0,
			Position = function() return if props.portrait() then UDim2.new(1, -8, 0, 9) else UDim2.new(1, -9, 0.5, 0) end,
			Size = function()
				return UDim2.fromOffset(if props.portrait() then 70 elseif props.shortLandscape() then 74 else 92, if props.portrait() then 20 elseif props.shortLandscape() then 25 else 30)
			end,
			ZIndex = 367,
			StudTexture({ ZIndex = 367, ImageTransparency = 0.89, TileSize = UDim2.fromOffset(36, 36) }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.fromScale(1, 1),
				Text = function()
					if equipped() then return "EQUIPPED" end
					if owned() then return "OWNED" end
					return FormatNumber(definition.UnlockCost) or tostring(definition.UnlockCost)
				end,
				TextColor3 = function()
					return if owned() then PAPER else Color3.fromRGB(255, 224, 129)
				end,
				TextScaled = true,
				ZIndex = 368,
			},
		},
		create "TextButton" {
			Name = "Sensor",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 375,
			MouseEnter = function()
				hovered(true)
				Sounds.Play("HoverStart", localPlayer.PlayerGui)
			end,
			MouseLeave = function()
				hovered(false)
			end,
			Activated = function()
				ClassController.SetPreviewClassId(definition.Id)
				Sounds.Play("Click", localPlayer.PlayerGui)
			end,
		},
	}
end

return function()
	local state = source(ClassController.GetState())
	local abilityState = source(AbilityController.GetState())
	local balance = source(CoinsController.Get())
	local runState = source(RunProgressionController.GetState())
	local abilityShopOpen = source(AbilityController.IsInventoryOpen())
	local open = source(ClassController.IsOpen())
	local partyActive = source(PartyTeleporterController.GetState() ~= nil)
	local selectedId = source(ClassController.GetPreviewClassId())
	local viewportSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(12))
	local viewportConnection: RBXScriptConnection?
	local connections = {}

	local portrait = derive(function()
		local size = viewportSize()
		return size.X < 600 and size.X < size.Y
	end)
	local compactPortrait = derive(function()
		return portrait() and viewportSize().Y < 820
	end)
	local shortLandscape = derive(function()
		local size = viewportSize()
		return not portrait() and size.Y < 560
	end)
	local compactLauncher = derive(function()
		return viewportSize().X < 700
	end)
	local inRun = derive(function()
		return runState().active == true
	end)
	local headerHeight = derive(function()
		return if portrait() then 76 else if shortLandscape() then 64 else 80
	end)
	local contentTop = derive(function()
		return headerHeight() + 24
	end)
	local detailsHeight = derive(function()
		return if portrait() then 310 elseif shortLandscape() then 260 else 265
	end)
	local selectedDefinition = derive(function()
		return ClassDefinitions.ById[selectedId()] or ClassDefinitions.List[1]
	end)
	local selectedOwned = derive(function()
		return isOwned(state(), selectedDefinition().Id)
	end)
	local selectedEquipped = derive(function()
		return state().Equipped == selectedDefinition().Id
	end)
	local canAfford = derive(function()
		return balance() >= selectedDefinition().UnlockCost
	end)
	local prerequisiteMet = derive(function()
		local requiredAbilityId = selectedDefinition().RequiredAbilityId
		return requiredAbilityId == nil or (type(abilityState().Owned) == "table" and abilityState().Owned[requiredAbilityId] == true)
	end)

	table.insert(connections, ClassController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
	end))
	table.insert(connections, AbilityController.GetStateChangedSignal():Connect(function(newState)
		abilityState(newState)
	end))
	table.insert(connections, ClassController.GetOpenChangedSignal():Connect(function(isOpen)
		open(isOpen)
	end))
	table.insert(connections, PartyTeleporterController.GetStateChangedSignal():Connect(function(newState)
		partyActive(newState ~= nil)
	end))
	table.insert(connections, ClassController.GetPreviewChangedSignal():Connect(function(classId)
		selectedId(classId)
	end))
	table.insert(connections, CoinsController.GetChangedSignal():Connect(function(newBalance)
		if type(newBalance) == "number" then balance(newBalance) end
	end))
	table.insert(connections, RunProgressionController.GetStateChangedSignal():Connect(function(newState)
		runState(newState)
	end))
	table.insert(connections, AbilityController.GetInventoryOpenChangedSignal():Connect(function(isOpen)
		abilityShopOpen(isOpen)
		if isOpen then ClassController.SetOpen(false) end
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end))
	cleanup(function()
		for _, connection in connections do connection:Disconnect() end
		if viewportConnection then viewportConnection:Disconnect() end
	end)

	local cards = {}
	local previewIcons = {}
	-- The class menu deliberately reuses existing ability icons; do not restore generated character portraits.
	for order, definition in ClassDefinitions.List do
		table.insert(cards, classCard(definition, order, {
			state = state,
			selectedId = selectedId,
			portrait = portrait,
			compactPortrait = compactPortrait,
			shortLandscape = shortLandscape,
		}))
		table.insert(previewIcons, create "ImageLabel" {
			Name = definition.Id .. "AbilityIcon",
			BackgroundTransparency = 1,
			Image = getAbility(definition).Icon,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return selectedId() == definition.Id
			end,
			ZIndex = 367,
		})
	end

	return create "Frame" {
		Name = "ClassInterface",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 290,
		action(function(instance)
			local root = instance :: Frame
			viewportSize(root.AbsoluteSize)
			viewportConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				viewportSize(root.AbsoluteSize)
			end)
		end),
		create "Frame" {
			Name = "OpenButton",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = function()
				return UDim2.new(0.5, 0, 1, if compactLauncher() then -18 else -24)
			end,
			Size = function()
				return if compactLauncher() then UDim2.new(1 / 3, -12, 0, 48) else UDim2.fromOffset(176, 50)
			end,
			Visible = function()
				return not inRun() and not open() and not abilityShopOpen() and not partyActive()
			end,
			ZIndex = 55,
			Button({
				Text = "CLASSES",
				BackgroundColor3 = Color3.fromRGB(16, 155, 211),
				CornerRadius = UDim.new(0, 4),
				FontFace = HEAVY_FONT,
				MaxTextSize = 25,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function()
					ClassController.SetOpen(true)
				end,
			}),
		},
		create "Frame" {
			Name = "Overlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(2, 8, 14),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return open() and not inRun()
			end,
			ZIndex = 340,
			create "TextButton" {
				Name = "BackdropSensor",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 340,
				Activated = function()
					ClassController.SetOpen(false)
				end,
			},
			create "Frame" {
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = function()
					return UDim2.new(0.5, 0, 0.5, if compactPortrait() then topOffset() * 0.5 else 0)
				end,
				Size = function()
					if compactPortrait() then return UDim2.new(1, -16, 1, -(topOffset() + 20)) end
					if portrait() then return UDim2.new(1, -16, 1, -28) end
					return UDim2.new(0.95, 0, 0.94, 0)
				end,
				ZIndex = 345,
				create "UISizeConstraint" {
					MaxSize = function()
						return if portrait() then Vector2.new(420, 690) else Vector2.new(1280, 760)
					end,
				},
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = Color3.fromRGB(16, 168, 219),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(12, 12),
					Size = function()
						return if portrait() then UDim2.new(1, -76, 0, headerHeight()) else UDim2.new(0.445, -12, 0, headerHeight())
					end,
					ZIndex = 350,
					-- Keep every filled menu surface on the same shared stud treatment as the HUD and buttons.
					StudTexture({ ZIndex = 351, ImageTransparency = 0.82, TileSize = UDim2.fromOffset(96, 96) }),
					create "UIGradient" { Color = ColorSequence.new(Color3.fromRGB(34, 220, 250), Color3.fromRGB(18, 108, 191)), Rotation = 90 },
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(69, 229, 249), Thickness = 2 },
					create "TextLabel" {
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = UDim2.fromOffset(if portrait() then 10 else 20, 7),
						Size = function()
							return UDim2.new(if portrait() then 1 else 0.56, if portrait() then -20 else 0, 0, if portrait() then 36 else 44)
						end,
						Text = "CLASSES",
						TextColor3 = PAPER,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 352,
					},
					create "TextLabel" {
						Name = "Subtitle",
						BackgroundTransparency = 1,
						FontFace = BOLD_FONT,
						Position = UDim2.fromOffset(22, 54),
						Size = UDim2.new(0.65, 0, 0, 18),
						Text = "CHOOSE YOUR SPECIALTY",
						TextColor3 = Color3.fromRGB(2, 47, 72),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = function()
							return not portrait() and not shortLandscape()
						end,
						ZIndex = 352,
					},
					create "Frame" {
						Name = "Coins",
						AnchorPoint = function()
							return if portrait() then Vector2.new(0, 0) else Vector2.new(1, 0.5)
						end,
						BackgroundColor3 = Color3.fromRGB(37, 31, 20),
						BorderSizePixel = 0,
						Position = function()
							return if portrait() then UDim2.fromOffset(10, 47) else UDim2.new(1, -16, 0.5, 0)
						end,
						Size = function()
							return if portrait() then UDim2.new(1, -20, 0, 22) else UDim2.fromOffset(if shortLandscape() then 112 else 152, if shortLandscape() then 34 else 42)
						end,
						ZIndex = 352,
						StudTexture({ ZIndex = 352, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(44, 44) }),
						create "UIStroke" { Color = Color3.fromRGB(218, 164, 55), Thickness = 2 },
						create "ImageLabel" {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Image = Images.Coin,
							Position = UDim2.new(0, 8, 0.5, 0),
							Size = function()
								return UDim2.fromOffset(if portrait() then 19 else 28, if portrait() then 19 else 28)
							end,
							ZIndex = 353,
						},
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Position = function()
								return UDim2.fromOffset(if portrait() then 32 else 43, 3)
							end,
							Size = function()
								return UDim2.new(1, if portrait() then -38 else -48, 1, -6)
							end,
							Text = function()
								local amount = FormatNumber(balance()) or tostring(balance())
								return if portrait() then "COINS  " .. amount else amount
							end,
							TextColor3 = Color3.fromRGB(255, 228, 146),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 353,
						},
					},
				},
				create "Frame" {
					Name = "CloseSlot",
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Position = function()
						return if portrait() then UDim2.new(1, -12, 0, 12) else UDim2.new(1, -24, 0, 24)
					end,
					Size = function()
						return if portrait() then UDim2.fromOffset(52, headerHeight()) else UDim2.fromOffset(56, 56)
					end,
					ZIndex = 380,
					Button({ Text = "X", BackgroundColor3 = UIStyle.Colors.Red, FontFace = HEAVY_FONT, MaxTextSize = 44, Size = UDim2.fromScale(1, 1), OnActivated = function()
						ClassController.SetOpen(false)
					end }),
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = PANEL_LIGHT,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = function() return UDim2.fromOffset(12, contentTop()) end,
					ScrollBarImageColor3 = CYAN,
					ScrollBarThickness = 4,
					-- The list stays on the left while Workspace remains visible on the right.
					Size = function()
						return UDim2.new(if portrait() then 0.42 else 0.445, if portrait() then -16 else -12, 1, -(contentTop() + 12))
					end,
					ZIndex = 360,
					StudTexture({ ZIndex = 361, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(60, 60) }),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 120, 148), Thickness = 2 },
					create "UIPadding" { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) },
					create "UIListLayout" { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder },
					create "TextLabel" {
						Name = "CatalogTitle",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						LayoutOrder = 0,
						Size = function() return UDim2.new(1, -4, 0, if compactPortrait() or shortLandscape() then 22 else 24) end,
						Text = function()
							local count = 0
							for _, definition in ClassDefinitions.List do
								if isOwned(state(), definition.Id) then count += 1 end
							end
							return string.format(if portrait() then "CLASSES  %d/%d" else "YOUR CLASSES  %d/%d", count, #ClassDefinitions.List)
						end,
						TextColor3 = Color3.fromRGB(160, 214, 228),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 361,
					},
					cards,
				},
				create "ScrollingFrame" {
					Name = "Details",
					-- Keep the action/details under the 3D avatar, not stretched over its legs.
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = PAPER,
					BorderSizePixel = 0,
					CanvasSize = function() return UDim2.fromOffset(0, if portrait() then 310 else 260) end,
					Position = function()
						return UDim2.new(if portrait() then 0.42 else 0.445, if portrait() then 4 else 12, 1, -12)
					end,
					ScrollBarImageColor3 = CYAN,
					ScrollBarThickness = 4,
					Size = function()
						return UDim2.new(if portrait() then 0.58 else 0.555, if portrait() then -16 else -24, 0, detailsHeight())
					end,
					ZIndex = 360,
					StudTexture({
						ZIndex = 361,
						ImageColor3 = INK,
						ImageTransparency = 0.96,
						TileSize = UDim2.fromOffset(68, 68),
					}),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(96, 145, 171), Thickness = 2 },
					create "Frame" {
						Name = "AbilityPreview",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(12, 10),
						Size = function()
							local size = if portrait() then 42 else 58
							return UDim2.fromOffset(size, size)
						end,
						ZIndex = 366,
						previewIcons,
					},
					create "TextLabel" {
						Name = "ClassName",
						BackgroundTransparency = 1,
						FontFace = HEAVY_FONT,
						Position = function()
							return UDim2.fromOffset(if portrait() then 62 else 84, 10)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -72 else -96, 0, if portrait() then 24 else 31)
						end,
						Text = function()
							return string.upper(selectedDefinition().Name)
						end,
						TextColor3 = function()
							return selectedDefinition().Color:Lerp(Color3.fromRGB(25, 88, 106), 0.45)
						end,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 366,
					},
					create "TextLabel" {
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = function()
							return UDim2.fromOffset(if portrait() then 12 else 84, if portrait() then 58 else 45)
						end,
						Size = function()
							return UDim2.new(1, if portrait() then -24 else -96, 0, if portrait() then 53 else 45)
						end,
						Text = function()
							return selectedDefinition().Description
						end,
						TextColor3 = INK,
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 366,
					},
					create "Frame" {
						Name = "StartingAbility",
						BackgroundColor3 = Color3.fromRGB(205, 220, 229),
						BorderSizePixel = 0,
						Position = function() return UDim2.fromOffset(12, if portrait() then 116 else 100) end,
						Size = function()
							return if portrait() then UDim2.new(1, -24, 0, 50) else UDim2.new(0.33, -18, 0, 67)
						end,
						ZIndex = 365,
						StudTexture({
							ZIndex = 365,
							ImageColor3 = INK,
							ImageTransparency = 0.94,
							TileSize = UDim2.fromOffset(48, 48),
						}),
						create "UIStroke" { Color = Color3.fromRGB(110, 143, 160), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1, FontFace = HEAVY_FONT, Position = function() return UDim2.fromOffset(12, if compactPortrait() then 4 else 5) end, Size = function() return UDim2.new(1, -24, 0, if compactPortrait() then 17 else 21) end,
							Text = "STARTING ABILITY", TextColor3 = Color3.fromRGB(36, 92, 120), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 366,
						},
						create "TextLabel" {
							BackgroundTransparency = 1, FontFace = BOLD_FONT, Position = function() return UDim2.fromOffset(12, if compactPortrait() then 23 else 29) end, Size = function() return UDim2.new(1, -24, 0, if compactPortrait() then 18 else 20) end,
							Text = function() return string.upper(getAbility(selectedDefinition()).Name) end,
							TextColor3 = INK, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 366,
						},
					},
					create "Frame" {
						Name = "Perks",
						BackgroundColor3 = Color3.fromRGB(218, 239, 246),
						BorderSizePixel = 0,
						Position = function()
							return if portrait() then UDim2.fromOffset(12, 176) else UDim2.new(0.33, 4, 0, 100)
						end,
						Size = function()
							return if portrait() then UDim2.new(1, -24, 0, 70) else UDim2.new(0.67, -18, 0, 67)
						end,
						ZIndex = 365,
						StudTexture({
							ZIndex = 365,
							ImageColor3 = INK,
							ImageTransparency = 0.94,
							TileSize = UDim2.fromOffset(48, 48),
						}),
						create "UIStroke" { Color = Color3.fromRGB(78, 170, 193), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1, FontFace = HEAVY_FONT, Position = function() return UDim2.fromOffset(12, if compactPortrait() then 3 else 5) end, Size = function() return UDim2.new(1, -24, 0, if compactPortrait() then 16 else 21) end,
							Text = "CLASS PERKS", TextColor3 = Color3.fromRGB(17, 76, 96), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 366,
						},
						create "TextLabel" {
							BackgroundTransparency = 1, FontFace = BOLD_FONT, Position = function() return UDim2.fromOffset(12, if compactPortrait() then 20 else 28) end, Size = function() return UDim2.new(1, -24, 1, if compactPortrait() then -22 else -31) end,
							Text = function() return selectedDefinition().PerkText end,
							TextColor3 = INK, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 366,
						},
					},
					create "Frame" {
						Name = "Action",
						BackgroundTransparency = 1,
						Position = function() return UDim2.fromOffset(12, if portrait() then 256 else 199) end,
						Size = function()
							return UDim2.new(1, -24, 0, if portrait() then 42 else 48)
						end,
						ZIndex = 370,
						Button({
							Text = function()
								if selectedEquipped() then return "EQUIPPED" end
								if not prerequisiteMet() then return "UNLOCK SWORDS FIRST" end
								if selectedOwned() then return "EQUIP CLASS" end
								local cost = FormatNumber(selectedDefinition().UnlockCost) or tostring(selectedDefinition().UnlockCost)
								return if canAfford() then "UNLOCK FOR " .. cost .. " COINS" else "NEED " .. cost .. " COINS"
							end,
							Enabled = function() return prerequisiteMet() and not selectedEquipped() and (selectedOwned() or canAfford()) end,
							BackgroundColor3 = function()
								if selectedEquipped() then return UIStyle.Colors.Green end
								if not prerequisiteMet() then return UIStyle.Colors.Muted end
								if selectedOwned() then return Color3.fromRGB(16, 155, 211) end
								return if canAfford() then UIStyle.Colors.Gold else UIStyle.Colors.Muted
							end,
							FontFace = HEAVY_FONT,
							MaxTextSize = 30,
							Size = UDim2.fromScale(1, 1),
							OnActivated = function()
								if not prerequisiteMet() then return end
								local definition = selectedDefinition()
								if not isOwned(state(), definition.Id) then
									ClassController.UnlockClass(definition.Id)
								elseif state().Equipped ~= definition.Id then
									ClassController.EquipClass(definition.Id)
								end
							end,
						}),
					},
				},
			},
		},
	}
end
