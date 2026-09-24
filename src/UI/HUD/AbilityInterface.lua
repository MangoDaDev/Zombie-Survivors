local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Classes.Button)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
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
local DISCOVERY_DURATION = 5

local function isOwned(state, abilityId: string): boolean
	return type(state.Owned) == "table" and state.Owned[abilityId] == true
end

local function getLevel(state, abilityId: string): number
	local level = type(state.Levels) == "table" and state.Levels[abilityId]
	return if type(level) == "number" then level else 1
end

local function getEquipped(state, category: string)
	local equipped = type(state.Equipped) == "table" and state.Equipped[category]
	return if type(equipped) == "table" then equipped else {}
end

local function isEquipped(state, ability): boolean
	return table.find(getEquipped(state, ability.Category), ability.Id) ~= nil
end

local function textStroke(color: Color3?, thickness: number?)
	return create "UIStroke" {
		Color = color or UIStyle.Colors.Ink,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness or 0.05,
	}
end

local function studTexture(zIndex: number)
	return create "ImageLabel" {
		Name = "StudTexture",
		BackgroundTransparency = 1,
		Image = UIStyle.StudTexture,
		ImageTransparency = UIStyle.StudTransparency,
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = UDim2.fromOffset(56, 56),
		ZIndex = zIndex,
	}
end

local function abilityIcon(ability, zIndex: number, visible)
	return create "ImageLabel" {
		Name = ability.Name .. "Icon",
		BackgroundTransparency = 1,
		Image = ability.Icon,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Visible = if visible == nil then true else visible,
		ZIndex = zIndex,
	}
end

local function abilityCard(ability, state, category, selectedId)
	local hovered = source(false)
	local selected = derive(function()
		return selectedId() == ability.Id
	end)
	local owned = derive(function()
		return isOwned(state(), ability.Id)
	end)
	local equipped = derive(function()
		return isEquipped(state(), ability)
	end)
	local cardScale = spring(function()
		return if hovered() then 1.018 else 1
	end, 0.16, 0.88)

	return create "Frame" {
		Name = ability.Id .. "Card",
		BackgroundColor3 = function()
			if equipped() then
				return UIStyle.Colors.Green:Lerp(UIStyle.Colors.Ink, 0.42)
			end
			return ability.Color:Lerp(UIStyle.Colors.Ink, if selected() then 0.55 else 0.72)
		end,
		BackgroundTransparency = function()
			return if owned() then 0 else 0.22
		end,
		BorderSizePixel = 0,
		LayoutOrder = ability.Roll.RarityRank,
		Size = UDim2.new(1, -10, 0, 118),
		Visible = function()
			return category() == ability.Category
		end,
		ZIndex = 325,
		create "UICorner" { CornerRadius = UIStyle.CornerRadius },
		create "UIScale" { Scale = cardScale },
		create "UIStroke" {
			Color = function()
				return if equipped() then Color3.fromRGB(137, 255, 158) else ability.Color
			end,
			Thickness = function()
				return if equipped() or selected() then 4 else 2
			end,
			Transparency = function()
				return if owned() then 0.08 else 0.58
			end,
		},
		studTexture(326),
		create "Frame" {
			Name = "Preview",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(9, 9),
			Size = UDim2.fromOffset(100, 100),
			ZIndex = 328,
			abilityIcon(ability, 328),
		},
		create "TextLabel" {
			Name = "AbilityName",
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.new(0, 120, 0, 10),
			Size = UDim2.new(1, -130, 0, 33),
			Text = ability.Name,
			TextColor3 = ability.Color,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 329,
			textStroke(),
		},
		create "TextLabel" {
			Name = "Level",
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.new(0, 120, 0, 49),
			Size = UDim2.new(1, -130, 0, 23),
			Text = function()
				return if owned() then string.format("LEVEL %d", getLevel(state(), ability.Id)) else "NOT DISCOVERED"
			end,
			TextColor3 = function()
				return if owned() then UIStyle.Colors.Paper else UIStyle.Colors.Muted
			end,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 329,
			textStroke(),
		},
		create "TextLabel" {
			Name = "Category",
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.new(0, 120, 0, 78),
			Size = UDim2.new(1, -130, 0, 23),
			Text = ability.Category:upper() .. " ABILITY",
			TextColor3 = UIStyle.Colors.PaperShadow,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 329,
		},
		create "Frame" {
			Name = "EquippedBadge",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = UIStyle.Colors.Green,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -7, 0, 7),
			Size = UDim2.fromOffset(86, 25),
			Visible = equipped,
			ZIndex = 332,
			create "UICorner" { CornerRadius = UIStyle.SmallCornerRadius },
			create "UIStroke" { Color = Color3.fromRGB(28, 93, 47), Thickness = 2 },
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Size = UDim2.fromScale(1, 1),
				Text = "EQUIPPED",
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				ZIndex = 333,
				textStroke(Color3.fromRGB(28, 93, 47)),
			},
		},
		create "ImageLabel" {
			Name = "Locked",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Image = Images.Lock,
			ImageColor3 = UIStyle.Colors.Muted,
			Position = UDim2.new(1, -9, 1, -9),
			Size = UDim2.fromOffset(28, 28),
			Visible = function()
				return not owned()
			end,
			ZIndex = 333,
		},
		create "TextButton" {
			Name = "Sensor",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 340,
			MouseEnter = function()
				hovered(true)
				Sounds.Play("HoverStart", localPlayer.PlayerGui)
			end,
			MouseLeave = function()
				hovered(false)
			end,
			Activated = function()
				selectedId(ability.Id)
				Sounds.Play("Click", localPlayer.PlayerGui)
			end,
		},
	}
end

return function()
	local state = source(AbilityController.GetState())
	local open = source(AbilityController.IsInventoryOpen())
	local category = source(AbilityDefinitions.Categories.Weapon)
	local topOffset = source(SafeArea.GetTopOffset(0))
	local selectedId = source(AbilityDefinitions.List[1].Id)
	local discoveryId = source(nil :: string?)
	local discoveryAutoPaused = source(false)
	local statusText = source("")
	local statusColor = source(UIStyle.Colors.Green)
	local discoveryToken = 0
	local statusToken = 0
	local discoveryCard: Frame?
	local discoveryScale: UIScale?
	local connections = {}

	local function selectedAbility()
		return AbilityDefinitions.ById[selectedId()] or AbilityDefinitions.List[1]
	end

	local function dismissDiscovery()
		local abilityId = discoveryId()
		if not abilityId then
			return
		end
		discoveryToken += 1
		discoveryId(nil)
		discoveryAutoPaused(false)
		AbilityController.AcknowledgeDiscovery(abilityId)
	end

	local function animateDiscovery()
		if not discoveryCard or not discoveryScale then
			return
		end
		discoveryScale.Scale = 0.22
		discoveryCard.Rotation = -3
		TweenService:Create(
			discoveryScale,
			TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		TweenService:Create(
			discoveryCard,
			TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Rotation = 0 }
		):Play()

		for index = 1, 12 do
			local angle = math.pi * 2 * index / 12
			local sparkle = Instance.new("ImageLabel")
			sparkle.Name = "DiscoverySparkle"
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.BackgroundTransparency = 1
			sparkle.Image = Images.Sparkle
			sparkle.ImageColor3 = Color3.fromRGB(166, 224, 255)
			sparkle.Position = UDim2.fromScale(0.5, 0.5)
			sparkle.Size = UDim2.fromOffset(24, 24)
			sparkle.ZIndex = 430
			sparkle.Parent = discoveryCard
			local distance = 150 + (index % 3) * 18
			local tween = TweenService:Create(
				sparkle,
				TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
					ImageTransparency = 1,
					Rotation = 180,
				}
			)
			tween.Completed:Once(function()
				sparkle:Destroy()
			end)
			tween:Play()
		end
	end

	local function showDiscovery(abilityId: string, autoRollWasPaused: boolean)
		discoveryToken += 1
		local token = discoveryToken
		discoveryId(abilityId)
		discoveryAutoPaused(autoRollWasPaused)
		Sounds.Play("NewRarest", localPlayer.PlayerGui)
		task.defer(animateDiscovery)
		task.delay(DISCOVERY_DURATION, function()
			if discoveryToken == token and discoveryId() == abilityId then
				dismissDiscovery()
			end
		end)
	end

	table.insert(connections, AbilityController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
	end))
	table.insert(connections, AbilityController.GetInventoryOpenChangedSignal():Connect(function(isOpen)
		open(isOpen)
	end))
	table.insert(connections, AbilityController.GetAbilityDiscoveredSignal():Connect(showDiscovery))
	table.insert(connections, AbilityController.GetActionResultSignal():Connect(function(success, message, milestone)
		statusToken += 1
		local token = statusToken
		statusText(message)
		statusColor(if milestone then UIStyle.Colors.Gold elseif success then UIStyle.Colors.Green else UIStyle.Colors.Red)
		task.delay(if milestone then 4 else 2.5, function()
			if statusToken == token then
				statusText("")
			end
		end)
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(0))
	end))
	cleanup(function()
		discoveryToken += 1
		statusToken += 1
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	local detailStatsText = function()
		local ability = selectedAbility()
		if not isOwned(state(), ability.Id) then
			return "Roll to discover this ability and reveal its stats."
		end
		local level = getLevel(state(), ability.Id)
		return ability.GetStatsText(level)
	end

	local milestoneText = function()
		local ability = selectedAbility()
		local milestone = AbilityDefinitions.GetNextMilestone(ability, getLevel(state(), ability.Id))
		return if milestone
			then string.format("NEXT MILESTONE - LEVEL %d\n%s", milestone.Level, milestone.Description)
			else "ALL MILESTONES UNLOCKED"
	end

	local upgradeText = function()
		local ability = selectedAbility()
		if not isOwned(state(), ability.Id) then
			return "LOCKED"
		end
		local cost = AbilityDefinitions.GetUpgradeCost(ability, getLevel(state(), ability.Id))
		return if cost then string.format("UPGRADE - %d COINS", cost) else "MAX LEVEL"
	end

	local cards = {}
	local detailPreviews = {}
	local discoveryPreviews = {}
	for _, ability in AbilityDefinitions.List do
		table.insert(cards, abilityCard(ability, state, category, selectedId))
		table.insert(detailPreviews, abilityIcon(ability, 324, function()
			return selectedId() == ability.Id
		end))
		table.insert(discoveryPreviews, abilityIcon(ability, 416, function()
			return discoveryId() == ability.Id
		end))
	end

	return create "Frame" {
		Name = "AbilityInterface",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		create "Frame" {
			Name = "InventoryOverlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(7, 12, 24),
			BackgroundTransparency = 0.22,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = open,
			ZIndex = 300,
			create "Frame" {
				Name = "InventoryPanel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(28, 42, 65),
				BorderSizePixel = 0,
				Position = function()
					return UDim2.new(0.5, 0, 0.5, topOffset() * 0.2)
				end,
				Size = UDim2.new(0.78, 40, 0.76, 40),
				ZIndex = 305,
				create "UICorner" { CornerRadius = UDim.new(0, 10) },
				create "UIStroke" { Color = Color3.fromRGB(80, 159, 222), Thickness = 4 },
				studTexture(306),
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = UIStyle.Colors.Blue,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 66),
					ZIndex = 310,
					create "UICorner" { CornerRadius = UDim.new(0, 10) },
					studTexture(311),
					create "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = UDim2.fromOffset(20, 8),
						Size = UDim2.new(1, -100, 1, -16),
						Text = "ABILITIES",
						TextColor3 = UIStyle.Colors.Paper,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 313,
						textStroke(),
					},
					create "Frame" {
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(62, 46),
						ZIndex = 314,
						Button({
							Text = "X",
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = UIStyle.Colors.Red,
							OnActivated = function()
								AbilityController.SetInventoryOpen(false)
							end,
						}),
					},
				},
				create "Frame" {
					Name = "Tabs",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(18, 78),
					Size = UDim2.new(0.44, -28, 0, 48),
					ZIndex = 315,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					Button({
						Text = "WEAPON",
						Size = UDim2.new(0.47, -5, 1, 0),
						BackgroundColor3 = function()
							return if category() == AbilityDefinitions.Categories.Weapon then UIStyle.Colors.Blue else UIStyle.Colors.InkSoft
						end,
						LayoutOrder = 1,
						OnActivated = function()
							category(AbilityDefinitions.Categories.Weapon)
						end,
					}),
					Button({
						Text = "PASSIVE",
						Size = UDim2.new(0.47, -5, 1, 0),
						BackgroundColor3 = function()
							return if category() == AbilityDefinitions.Categories.Passive then UIStyle.Colors.Gold else UIStyle.Colors.InkSoft
						end,
						LayoutOrder = 2,
						OnActivated = function()
							category(AbilityDefinitions.Categories.Passive)
						end,
					}),
				},
				create "TextLabel" {
					Name = "SlotCount",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.new(0.44, -2, 0, 86),
					Size = UDim2.new(0.2, 0, 0, 32),
					Text = function()
						return string.format(
							"%d / %d EQUIPPED",
							#getEquipped(state(), category()),
							AbilityDefinitions.EquipLimits[category()]
						)
					end,
					TextColor3 = UIStyle.Colors.PaperShadow,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 316,
				},
				create "ScrollingFrame" {
					Name = "AbilityList",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(16, 25, 41),
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = UDim2.fromOffset(18, 136),
					ScrollBarImageColor3 = UIStyle.Colors.Blue,
					ScrollBarThickness = 6,
					Size = UDim2.new(0.44, -28, 1, -154),
					ZIndex = 320,
					create "UICorner" { CornerRadius = UIStyle.CornerRadius },
					create "UIPadding" {
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						PaddingTop = UDim.new(0, 8),
					},
					create "UIListLayout" { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder },
					cards,
					create "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						LayoutOrder = 1000,
						Size = UDim2.new(1, -10, 0, 70),
						Text = "No passive abilities are available yet.",
						TextColor3 = UIStyle.Colors.Muted,
						TextScaled = true,
						TextWrapped = true,
						Visible = function()
							return category() == AbilityDefinitions.Categories.Passive
						end,
						ZIndex = 325,
					},
				},
				create "Frame" {
					Name = "Details",
					BackgroundColor3 = Color3.fromRGB(246, 248, 252),
					BorderSizePixel = 0,
					Position = UDim2.new(0.44, 4, 0, 78),
					Size = UDim2.new(0.56, -22, 1, -96),
					Visible = function()
						return category() == selectedAbility().Category
					end,
					ZIndex = 320,
					create "UICorner" { CornerRadius = UIStyle.CornerRadius },
					create "UIStroke" { Color = UIStyle.Colors.Paper, Thickness = 3, Transparency = 0.25 },
					studTexture(321),
					create "Frame" {
						Name = "LargePreview",
						BackgroundTransparency = 1,
						Position = UDim2.new(0.04, 0, 0.05, 0),
						Size = UDim2.new(0.36, 0, 0.33, 0),
						ZIndex = 324,
						detailPreviews,
					},
					create "TextLabel" {
						Name = "Name",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = UDim2.new(0.43, 0, 0.05, 0),
						Size = UDim2.new(0.53, 0, 0.1, 0),
						Text = function()
							return selectedAbility().Name
						end,
						TextColor3 = function()
							return selectedAbility().Color
						end,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 325,
						textStroke(),
					},
					create "TextLabel" {
						Name = "CategoryAndLevel",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = UDim2.new(0.43, 0, 0.16, 0),
						Size = UDim2.new(0.53, 0, 0.055, 0),
						Text = function()
							local ability = selectedAbility()
							return string.format("%s ABILITY  -  LEVEL %d", ability.Category:upper(), getLevel(state(), ability.Id))
						end,
						TextColor3 = UIStyle.Colors.InkSoft,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 325,
					},
					create "TextLabel" {
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = UDim2.new(0.43, 0, 0.23, 0),
						Size = UDim2.new(0.53, 0, 0.14, 0),
						Text = function()
							local ability = selectedAbility()
							return ability.Description .. "\n" .. ability.UpgradeDescription
						end,
						TextColor3 = UIStyle.Colors.Ink,
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 325,
					},
					create "Frame" {
						Name = "Stats",
						BackgroundColor3 = Color3.fromRGB(214, 225, 239),
						BorderSizePixel = 0,
						Position = UDim2.new(0.04, 0, 0.42, 0),
						Size = UDim2.new(0.92, 0, 0.24, 0),
						ZIndex = 324,
						create "UICorner" { CornerRadius = UIStyle.SmallCornerRadius },
						create "UIStroke" { Color = Color3.fromRGB(126, 154, 186), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = UIStyle.Font,
							Position = UDim2.fromScale(0.035, 0.08),
							Size = UDim2.fromScale(0.93, 0.84),
							Text = detailStatsText,
							TextColor3 = UIStyle.Colors.Ink,
							TextScaled = true,
							TextWrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 325,
						},
					},
					create "Frame" {
						Name = "Milestone",
						BackgroundColor3 = Color3.fromRGB(255, 225, 137),
						BorderSizePixel = 0,
						Position = UDim2.new(0.04, 0, 0.69, 0),
						Size = UDim2.new(0.92, 0, 0.12, 0),
						ZIndex = 324,
						create "UICorner" { CornerRadius = UIStyle.SmallCornerRadius },
						create "UIStroke" { Color = Color3.fromRGB(172, 116, 31), Thickness = 2 },
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = UIStyle.Font,
							Position = UDim2.fromScale(0.03, 0.1),
							Size = UDim2.fromScale(0.94, 0.8),
							Text = milestoneText,
							TextColor3 = Color3.fromRGB(92, 57, 16),
							TextScaled = true,
							TextWrapped = true,
							ZIndex = 325,
						},
					},
					create "Frame" {
						Name = "Actions",
						BackgroundTransparency = 1,
						Position = UDim2.new(0.04, 0, 0.84, 0),
						Size = UDim2.new(0.92, 0, 0.11, 0),
						ZIndex = 330,
						create "UIListLayout" {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 12),
							SortOrder = Enum.SortOrder.LayoutOrder,
						},
						Button({
							Text = function()
								return if isEquipped(state(), selectedAbility()) then "UNEQUIP" else "EQUIP"
							end,
							Size = UDim2.new(0.48, -6, 1, 0),
							Enabled = function()
								return isOwned(state(), selectedAbility().Id)
							end,
							BackgroundColor3 = function()
								return if isEquipped(state(), selectedAbility()) then UIStyle.Colors.Red else UIStyle.Colors.Green
							end,
							LayoutOrder = 1,
							OnActivated = function()
								local ability = selectedAbility()
								if isEquipped(state(), ability) then
									AbilityController.UnequipAbility(ability.Id)
								else
									AbilityController.EquipAbility(ability.Id)
								end
							end,
						}),
						Button({
							Text = upgradeText,
							Size = UDim2.new(0.48, -6, 1, 0),
							Enabled = function()
								local ability = selectedAbility()
								return isOwned(state(), ability.Id) and getLevel(state(), ability.Id) < ability.MaxLevel
							end,
							BackgroundColor3 = UIStyle.Colors.Gold,
							LayoutOrder = 2,
							OnActivated = function()
								AbilityController.UpgradeAbility(selectedAbility().Id)
							end,
						}),
					},
					create "TextLabel" {
						Name = "ActionStatus",
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = UIStyle.Font,
						Position = UDim2.fromScale(0.5, 0.805),
						Size = UDim2.fromScale(0.86, 0.035),
						Text = statusText,
						TextColor3 = statusColor,
						TextScaled = true,
						Visible = function()
							return statusText() ~= ""
						end,
						ZIndex = 331,
						textStroke(),
					},
				},
				create "TextLabel" {
					Name = "EmptyCategory",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.new(0.48, 0, 0.36, 0),
					Size = UDim2.new(0.46, 0, 0.22, 0),
					Text = "No abilities in this category yet.\nFuture discoveries will appear here.",
					TextColor3 = UIStyle.Colors.PaperShadow,
					TextScaled = true,
					TextWrapped = true,
					Visible = function()
						return category() ~= selectedAbility().Category
					end,
					ZIndex = 322,
				},
			},
		},
		create "Frame" {
			Name = "DiscoveryOverlay",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(4, 8, 18),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return discoveryId() ~= nil
			end,
			ZIndex = 400,
			create "Frame" {
				Name = "DiscoveryCard",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(30, 65, 96),
				BorderSizePixel = 0,
				Position = function()
					return UDim2.new(0.5, 0, 0.5, topOffset() * 0.2)
				end,
				Size = UDim2.new(0.62, 60, 0.58, 60),
				ZIndex = 410,
				create "UICorner" { CornerRadius = UDim.new(0, 12) },
				create "UIStroke" { Color = Color3.fromRGB(126, 211, 255), Thickness = 5 },
				create "UIScale" {
					Scale = 1,
					action(function(instance)
						discoveryScale = instance :: UIScale
					end),
				},
				studTexture(411),
				action(function(instance)
					discoveryCard = instance :: Frame
				end),
				create "ImageLabel" {
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = UIStyle.GlowTexture,
					ImageColor3 = Color3.fromRGB(102, 202, 255),
					ImageTransparency = 0.54,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.35, 1.35),
					ZIndex = 409,
				},
				create "TextLabel" {
					Name = "DiscoveryTitle",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.05, 0.035),
					Size = UDim2.fromScale(0.9, 0.12),
					Text = "NEW ABILITY DISCOVERED",
					TextColor3 = Color3.fromRGB(181, 231, 255),
					TextScaled = true,
					ZIndex = 415,
					textStroke(Color3.fromRGB(17, 59, 89), 0.06),
				},
				create "Frame" {
					Name = "Preview",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.24, 0.18),
					Size = UDim2.fromScale(0.52, 0.43),
					ZIndex = 416,
					discoveryPreviews,
				},
				create "TextLabel" {
					Name = "AbilityName",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.08, 0.63),
					Size = UDim2.fromScale(0.84, 0.1),
					Text = function()
						local ability = discoveryId() and AbilityDefinitions.ById[discoveryId()]
						return ability and ability.Name or ""
					end,
					TextColor3 = Color3.fromRGB(160, 221, 255),
					TextScaled = true,
					ZIndex = 416,
					textStroke(),
				},
				create "TextLabel" {
					Name = "CategoryAndDescription",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.08, 0.735),
					Size = UDim2.fromScale(0.84, 0.095),
					Text = function()
						local ability = discoveryId() and AbilityDefinitions.ById[discoveryId()]
						return ability and (ability.Category:upper() .. " ABILITY  -  " .. ability.Description) or ""
					end,
					TextColor3 = UIStyle.Colors.Paper,
					TextScaled = true,
					TextWrapped = true,
					ZIndex = 416,
				},
				create "TextLabel" {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.5, 0.855),
					Size = UDim2.fromScale(0.8, 0.038),
					Text = function()
						return if discoveryAutoPaused()
							then "Auto Roll resumes automatically in 5 seconds"
							else "Continue now or this closes automatically in 5 seconds"
					end,
					TextColor3 = UIStyle.Colors.PaperShadow,
					TextScaled = true,
					ZIndex = 416,
				},
				create "Frame" {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.965),
					Size = UDim2.fromScale(0.5, 0.105),
					ZIndex = 420,
					Button({
						Text = "CONTINUE",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = UIStyle.Colors.Green,
						OnActivated = dismissDiscovery,
					}),
				},
			},
		},
	}
end
