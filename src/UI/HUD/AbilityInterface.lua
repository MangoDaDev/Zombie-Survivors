local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local PartyTeleporterController = require(ReplicatedStorage.Controllers.PartyTeleporterController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
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

local function isEquipped(state, ability): boolean
	local equippedByCategory = type(state) == "table" and state.Equipped
	local equipped = type(equippedByCategory) == "table" and equippedByCategory[ability.Category]
	return type(equipped) == "table" and table.find(equipped, ability.Id) ~= nil
end

local function getShopTier(state, ability): number
	if isEquipped(state, ability) then return 1 end
	if isOwned(state, ability.Id) then return 2 end
	return 3
end

local function getShopLayoutOrder(state, ability, authoredOrder: number): number
	local tier = getShopTier(state, ability)
	local cost = AbilityDefinitions.GetUnlockCost(ability) or 0
	local order = 1
	for otherOrder, otherAbility in AbilityDefinitions.List do
		if otherAbility.Category == ability.Category then
			local otherTier = getShopTier(state, otherAbility)
			local otherCost = AbilityDefinitions.GetUnlockCost(otherAbility) or 0
			if otherTier < tier
				or (otherTier == tier and otherCost < cost)
				or (otherTier == tier and otherCost == cost and otherOrder < authoredOrder)
			then
				order += 1
			end
		end
	end
	return order
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

	local layout = {}
	layout.Viewport = props.parentLayout
	layout.Frame = ResponsiveLayout.Child(function()
		return UDim2.new(1, -10, 0, if props.portrait() then 76 else 86)
	end, layout.Viewport)
	layout.Icon = ResponsiveLayout.Child(function()
		local size = if props.portrait() then 50 else 58
		return UDim2.fromOffset(size, size)
	end, layout.Frame)
	layout.AbilityName = ResponsiveLayout.Child(UDim2.new(1, -190, 0, 28), layout.Frame)
	layout.Rarity = ResponsiveLayout.Child(UDim2.new(1, -190, 0, 20), layout.Frame)
	layout.UnlockedBadge = ResponsiveLayout.Child(UDim2.fromOffset(98, 30), layout.Frame)
	layout.UnlockCost = ResponsiveLayout.Child(UDim2.fromOffset(104, 34), layout.Frame)
	layout.ImageLabel = ResponsiveLayout.Child(UDim2.fromOffset(23, 23), layout.UnlockCost)
	layout.TextLabel2 = ResponsiveLayout.Child(UDim2.new(1, -42, 1, -8), layout.UnlockCost)

	return create "Frame" {
		Name = ability.Id .. "Card",
		BackgroundColor3 = function()
			if selected() then
				return Color3.fromRGB(12, 73, 98)
			end
			return if owned() then Color3.fromRGB(13, 50, 63) else Color3.fromRGB(18, 38, 50)
		end,
		BorderSizePixel = 0,
		-- Every non-premium catalog keeps the actionable progression order: equipped, unlocked, then price.
		LayoutOrder = function()
			return getShopLayoutOrder(props.state(), ability, order)
		end,
		Size = layout.Frame.Size,
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
			Position = layout.Frame.Scale(UDim2.new(0, 10, 0.5, 0)),
			ScaleType = Enum.ScaleType.Fit,
			Size = layout.Icon.Size,
			ZIndex = 327,
		},
		create "TextLabel" {
			Name = "AbilityName",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = layout.Frame.Scale(function()
				return UDim2.fromOffset(if props.portrait() then 68 else 78, if props.portrait() then 9 else 12)
			end),
			Size = layout.AbilityName.Size,
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
			Position = layout.Frame.Scale(function()
				return UDim2.fromOffset(if props.portrait() then 68 else 78, if props.portrait() then 43 else 49)
			end),
			Size = layout.Rarity.Size,
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
			Position = layout.Frame.Scale(UDim2.new(1, -10, 0.5, 0)),
			Size = layout.UnlockedBadge.Size,
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
			Position = layout.Frame.Scale(UDim2.new(1, -10, 0.5, 0)),
			Size = layout.UnlockCost.Size,
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
				Position = layout.UnlockCost.Scale(UDim2.new(0, 8, 0.5, 0)),
				Size = layout.ImageLabel.Size,
				ZIndex = 329,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Position = layout.UnlockCost.Scale(UDim2.fromOffset(36, 4)),
				Size = layout.TextLabel2.Size,
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
				AbilityController.SelectShopItem(ability.Id)
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
	local shopOpen = source(MonetizationController.IsShopOpen())
	local partyActive = source(PartyTeleporterController.GetState() ~= nil)
	local category = source(AbilityDefinitions.Categories.Weapon)
	local selectedId = source(firstAbilityId(AbilityDefinitions.Categories.Weapon))
	local viewportSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(12))
	local statusText = source("")
	local statusColor = source(UIStyle.Colors.Green)
	local statusToken = 0
	local viewportConnection: RBXScriptConnection?
	local connections = {}

	-- User invariant: screen size may scale this interface, but it must never select a
	-- separate mobile, portrait, short-screen, or compact composition.
	local function portrait() return false end
	local function compactPortrait() return false end
	local function shortLandscape() return false end
	local function compactLauncher() return false end
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
	table.insert(connections, MonetizationController.GetShopChangedSignal():Connect(function(isOpen)
		shopOpen(isOpen)
	end))
	table.insert(connections, PartyTeleporterController.GetStateChangedSignal():Connect(function(newState)
		partyActive(newState ~= nil)
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

	local headerHeight = derive(function()
		return if portrait() then 82 else if shortLandscape() then 72 else 94
	end)
	local contentTop = derive(function()
		return headerHeight() + 64
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(viewportSize)
	layout.AbilityInterface = layout.Viewport
	layout.LauncherDock = ResponsiveLayout.Base(function()
		return if compactLauncher() then UDim2.new(1, -20, 0, 60) else UDim2.fromOffset(556, 62)
	end, layout.AbilityInterface)
	layout.OpenButton = ResponsiveLayout.Base(function()
		return if compactLauncher() then UDim2.new(1 / 3, -12, 0, 48) else UDim2.fromOffset(176, 50)
	end, layout.AbilityInterface)
	layout.ShopOverlay = layout.AbilityInterface
	layout.BackdropSensor = layout.ShopOverlay
	layout.Panel = ResponsiveLayout.Base(function()
		if compactPortrait() then
			return UDim2.new(0.5, 170, 0.55, 240)
		elseif portrait() then
			return UDim2.new(0.4, 220, 0.4, 450)
		elseif shortLandscape() then
			return UDim2.new(0.8, 40, 0.85, 20)
		end
		-- Scale plus a fixed base keeps the menu growing with resolution while reducing its relative footprint.
		return UDim2.new(0.5, 320, 0.6, 200)
	end, layout.ShopOverlay, function()
						-- Short phones use their own envelope so the constraint does not make an
						-- already narrow portrait layout unnecessarily narrower.
						return if compactPortrait() then 0.56 elseif portrait() then 420 / 880 else 980 / 620
					end)
	layout.Header = ResponsiveLayout.Child(function()
		return UDim2.new(1, if portrait() then -76 else -96, 0, headerHeight())
	end, layout.Panel)
	layout.Title = ResponsiveLayout.Child(function()
		return UDim2.new(if portrait() then 1 else 0.58, if portrait() then -20 else 0, 0, if portrait() then 42 else 50)
	end, layout.Header)
	layout.Subtitle = ResponsiveLayout.Child(UDim2.new(0.66, 0, 0, 20), layout.Header)
	layout.CoinBalance = ResponsiveLayout.Child(function()
		return if portrait() then UDim2.new(1, -20, 0, 24) else UDim2.fromOffset(174, 50)
	end, layout.Header)
	layout.ImageLabel = ResponsiveLayout.Child(function()
		local size = if portrait() then 20 else 34
		return UDim2.fromOffset(size, size)
	end, layout.CoinBalance)
	layout.TextLabel = ResponsiveLayout.Child(function()
		return UDim2.new(1, if portrait() then -34 else -58, 1, if portrait() then -4 else -10)
	end, layout.CoinBalance)
	layout.CloseSlot = ResponsiveLayout.Child(function()
		return UDim2.fromOffset(if portrait() then 52 else 64, headerHeight())
	end, layout.Panel)
	layout.Tabs = ResponsiveLayout.Child(function()
		return UDim2.new(if portrait() then 1 else 0.41, if portrait() then -24 else -18, 0, if portrait() then 42 else 48)
	end, layout.Panel)
	layout.Catalog = ResponsiveLayout.Child(function()
		if portrait() then
			return UDim2.new(1, -24, 0, 202)
		end
		return UDim2.new(0.41, -18, 1, -(contentTop() + 12))
	end, layout.Panel)
	layout.Content = ResponsiveLayout.Child(function()
		local _, count = countCategory(state(), category())
		return UDim2.new(1, 0, 0, count * ((if portrait() then 76 else 86) + 9) + 6)
	end, layout.Catalog)
	layout.Details = ResponsiveLayout.Child(function()
		if portrait() then
			return UDim2.new(1, -24, 1, -(contentTop() + 224))
		end
		return UDim2.new(0.59, -14, 1, -(contentTop() + 12))
	end, layout.Panel)
	layout.Preview = ResponsiveLayout.Child(function()
		local size = if portrait() then 92 elseif shortLandscape() then 110 else 176
		return UDim2.fromOffset(size, size)
	end, layout.Details)
	layout.Lock = ResponsiveLayout.Child(UDim2.fromOffset(if portrait() then 32 else 46, if portrait() then 32 else 46), layout.Preview)
	layout.Name = ResponsiveLayout.Child(function()
		return UDim2.new(
			1,
			if portrait() then -128 elseif shortLandscape() then -160 else -246,
			0,
			if portrait() then 38 elseif shortLandscape() then 34 else 46
		)
	end, layout.Details)
	layout.Rarity = ResponsiveLayout.Child(function()
		return UDim2.new(1, if portrait() then -128 elseif shortLandscape() then -160 else -246, 0, 25)
	end, layout.Details)
	layout.Description = ResponsiveLayout.Child(function()
		return UDim2.new(
			1,
			if portrait() then -128 elseif shortLandscape() then -160 else -246,
			0,
			if portrait() or shortLandscape() then 54 else 86
		)
	end, layout.Details)
	layout.Stats = ResponsiveLayout.Child(function()
		return UDim2.new(
			1,
			if portrait() then -28 elseif shortLandscape() then -36 else -56,
			0,
			if portrait() then 122 elseif shortLandscape() then 90 else 132
		)
	end, layout.Details)
	layout.Title2 = ResponsiveLayout.Child(UDim2.new(1, -24, 0, if portrait() then 25 elseif shortLandscape() then 22 else 30), layout.Stats)
	layout.StatsText = ResponsiveLayout.Child(UDim2.new(1, -24, 1, if portrait() then -47 elseif shortLandscape() then -40 else -52), layout.Stats)
	layout.RunAvailability = ResponsiveLayout.Child(function()
		return UDim2.new(1, if portrait() then -28 else -56, 0, if portrait() then 58 else 60)
	end, layout.Details)
	layout.TextLabel2 = ResponsiveLayout.Child(UDim2.new(1, -20, 1, -14), layout.RunAvailability)
	layout.Status = ResponsiveLayout.Child(UDim2.new(1, -42, 0, 24), layout.Details)
	layout.Action = ResponsiveLayout.Child(UDim2.new(
							1,
							if portrait() then -28 elseif shortLandscape() then -36 else -56,
							0,
							if portrait() then 54 elseif shortLandscape() then 46 else 58
						), layout.Details)

	local cards = {}
	local previewIcons = {}
	for order, ability in AbilityDefinitions.List do
		table.insert(cards, abilityCard(ability, order, {
			parentLayout = layout.Content,
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

	local selectedOwned = derive(function()
		return isOwned(state(), selectedAbility().Id)
	end)
	local selectedCost = derive(function()
		return AbilityDefinitions.GetUnlockCost(selectedAbility()) or 0
	end)
	local canAfford = derive(function()
		return balance() >= selectedCost()
	end)

	local function categoryTab(tabCategory: string, label: string, activeColor: Color3, layoutOrder: number, parentLayout)
		local layout = {}
		layout.Viewport = parentLayout
		layout.Frame = ResponsiveLayout.Child(UDim2.new(0.5, -5, 1, 0), layout.Viewport)

		return create "Frame" {
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
			Size = layout.Frame.Size,
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
			Name = "LauncherDock",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(4, 20, 30),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = layout.LauncherDock.Position(function()
				return UDim2.new(0.5, 0, 1, if compactLauncher() then -12 else -18)
			end, Vector2.new(0.5, 1)),
			Size = layout.LauncherDock.Size,
			Visible = function()
				-- The shared lobby launcher dock must sit behind the modal shop, not over its catalog.
				return not inRun() and not open() and not shopOpen() and not partyActive()
			end,
			ZIndex = 50,
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			create "UIStroke" { Color = Color3.fromRGB(58, 94, 111), Thickness = 2 },
			StudTexture({ ZIndex = 51, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(56, 56) }),
		},
		create "Frame" {
			Name = "OpenButton",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = layout.OpenButton.Position(function()
				-- All lobby launchers share one bottom dock so they cannot collide with topbar-safe HUD content.
				return if compactLauncher() then UDim2.new(1 / 6, 4, 1, -18) else UDim2.new(0.5, -188, 1, -24)
			end, Vector2.new(0.5, 1)),
			Size = layout.OpenButton.Size,
			Visible = function()
				return not inRun() and not open() and not shopOpen() and not partyActive()
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
				Position = layout.Panel.Position(function()
					return UDim2.new(0.5, 0, 0.5, topOffset() * 0.08)
				end, Vector2.new(0.5, 0.5)),
				Size = layout.Panel.Size,
				ZIndex = 305,
				-- Every filled menu surface uses the shared stud layer; light content panels tint it dark below.
				StudTexture({ ZIndex = 306, ImageTransparency = 0.92, TileSize = UDim2.fromOffset(76, 76) }),
				create "UIAspectRatioConstraint" {
					-- Preserve the authored menu proportions when the viewport changes; portrait and
					-- landscape use different content arrangements and therefore different ratios.
					AspectRatio = function()
						-- Short phones use their own envelope so the constraint does not make an
						-- already narrow portrait layout unnecessarily narrower.
						return if compactPortrait() then 0.56 elseif portrait() then 420 / 880 else 980 / 620
					end,
					-- Fit inside both responsive axes. A fixed dominant axis can overflow on phones or ultrawide screens.
					AspectType = Enum.AspectType.FitWithinMaxSize,
				},
				create "UIScale" { Scale = UIStyle.NonClassMenuScale },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 5, 10), Thickness = 7 },
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = CYAN, Thickness = 3 },
				create "Frame" {
					Name = "Header",
					BackgroundColor3 = Color3.fromRGB(16, 168, 219),
					BorderSizePixel = 0,
					Position = layout.Panel.Scale(UDim2.fromOffset(12, 12)),
					Size = layout.Header.Size,
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
						Position = layout.Header.Scale(UDim2.fromOffset(if portrait() then 10 else 20, if portrait() then 5 else 8)),
						Size = layout.Title.Size,
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
						Position = layout.Header.Scale(UDim2.fromOffset(22, 64)),
						Size = layout.Subtitle.Size,
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
						Position = layout.Header.Scale(function()
							return if portrait() then UDim2.fromOffset(10, 51) else UDim2.new(1, -16, 0.5, 0)
						end),
						Size = layout.CoinBalance.Size,
						ZIndex = 313,
						StudTexture({ ZIndex = 313, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(48, 48) }),
						create "UIStroke" { Color = Color3.fromRGB(218, 164, 55), Thickness = 2 },
						create "ImageLabel" {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Image = Images.Coin,
							Position = layout.CoinBalance.Scale(UDim2.new(0, if portrait() then 6 else 10, 0.5, 0)),
							Size = layout.ImageLabel.Size,
							ZIndex = 314,
						},
						create "TextLabel" {
							BackgroundTransparency = 1,
							FontFace = HEAVY_FONT,
							Position = layout.CoinBalance.Scale(function()
								return UDim2.fromOffset(if portrait() then 30 else 52, if portrait() then 2 else 5)
							end),
							Size = layout.TextLabel.Size,
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
					Position = layout.Panel.Scale(UDim2.new(1, -12, 0, 12)),
					Size = layout.CloseSlot.Size,
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
					Position = layout.Panel.Scale(function()
						return UDim2.fromOffset(12, headerHeight() + 20)
					end),
					Size = layout.Tabs.Size,
					ZIndex = 317,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = layout.Tabs.Padding(UDim.new(0, 10), "X"),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					categoryTab(AbilityDefinitions.Categories.Weapon, "WEAPONS", Color3.fromRGB(16, 155, 211), 1, layout.Tabs),
					categoryTab(AbilityDefinitions.Categories.Passive, "PASSIVES", Color3.fromRGB(176, 119, 34), 2, layout.Tabs),
				},
				create "ScrollingFrame" {
					Name = "Catalog",
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = PANEL_LIGHT,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(0, 0),
					Position = layout.Panel.Scale(function()
						return UDim2.fromOffset(12, contentTop())
					end),
					ScrollBarImageColor3 = CYAN,
					ScrollBarThickness = 5,
					Size = layout.Catalog.Size,
					ZIndex = 320,
					StudTexture({ ZIndex = 321, ImageTransparency = 0.93, TileSize = UDim2.fromOffset(60, 60) }),
					create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(0, 120, 148), Thickness = 2 },
					create "Frame" {
						Name = "Content",
			BackgroundTransparency = 1,
						Size = layout.Content.Size,
						ZIndex = 322,
						-- Keep layout-managed entries in their own container so the catalog's decorative
						-- texture never consumes a list slot and creates a viewport-sized blank buffer.
						create "UIPadding" {
							PaddingBottom = layout.Content.Padding(UDim.new(0, 8), "Y"),
							PaddingLeft = layout.Content.Padding(UDim.new(0, 7), "X"),
							PaddingRight = layout.Content.Padding(UDim.new(0, 7), "X"),
							PaddingTop = layout.Content.Padding(UDim.new(0, 7), "Y"),
						},
						create "UIListLayout" { Padding = layout.Content.Padding(UDim.new(0, 9), "Y"), SortOrder = Enum.SortOrder.LayoutOrder },
						cards,
					},
				},
				create "Frame" {
					Name = "Details",
					BackgroundColor3 = PAPER,
					BorderSizePixel = 0,
					Position = layout.Panel.Scale(function()
						if portrait() then
							return UDim2.fromOffset(12, contentTop() + 212)
						end
						return UDim2.new(0.41, 2, 0, contentTop())
					end),
					Size = layout.Details.Size,
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
						Position = layout.Details.Scale(UDim2.fromOffset(
							if portrait() then 14 elseif shortLandscape() then 18 else 28,
							if portrait() then 14 elseif shortLandscape() then 16 else 28
						)),
						Size = layout.Preview.Size,
						ZIndex = 326,
						previewIcons,
						create "ImageLabel" {
							Name = "Lock",
							AnchorPoint = Vector2.new(1, 1),
							BackgroundTransparency = 1,
							Image = Images.Lock,
							ImageColor3 = Color3.fromRGB(55, 74, 86),
							Position = UDim2.fromScale(1, 1),
							Size = layout.Lock.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.fromOffset(
								if portrait() then 116 elseif shortLandscape() then 145 else 224,
								if portrait() then 12 elseif shortLandscape() then 16 else 28
							)
						end),
						Size = layout.Name.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.fromOffset(
								if portrait() then 117 elseif shortLandscape() then 145 else 224,
								if portrait() then 55 elseif shortLandscape() then 56 else 82
							)
						end),
						Size = layout.Rarity.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.fromOffset(
								if portrait() then 117 elseif shortLandscape() then 145 else 224,
								if portrait() then 82 elseif shortLandscape() then 86 else 118
							)
						end),
						Size = layout.Description.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.new(
								0,
								if portrait() then 14 elseif shortLandscape() then 18 else 28,
								0,
								if portrait() or shortLandscape() then 150 else 224
							)
						end),
						Size = layout.Stats.Size,
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
							Position = layout.Stats.Scale(UDim2.fromOffset(12, 8)),
							Size = layout.Title2.Size,
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
							Position = layout.Stats.Scale(UDim2.fromOffset(12, if portrait() then 39 elseif shortLandscape() then 34 else 44)),
							Size = layout.StatsText.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.new(0, if portrait() then 14 else 28, 0, if portrait() then 284 else 372)
						end),
						Size = layout.RunAvailability.Size,
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
							Position = layout.RunAvailability.Scale(UDim2.fromOffset(10, 7)),
							Size = layout.TextLabel2.Size,
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
						Position = layout.Details.Scale(function()
							return UDim2.new(0.5, 0, 1, if shortLandscape() then -60 else -72)
						end),
						Size = layout.Status.Size,
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
						Position = layout.Details.Scale(UDim2.new(0.5, 0, 1, -14)),
						Size = layout.Action.Size,
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
							LeftIcon = Images.Coin,
							LeftIconVisible = function()
								return not selectedOwned() and selectedCost() > 0
							end,
							Enabled = function()
								return not selectedOwned() and selectedCost() > 0
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
									if canAfford() then
										AbilityController.UnlockAbility(ability.Id)
									else
										AbilityController.SetInventoryOpen(false)
										MonetizationController.SetShopOpen(true, "Coins")
									end
								end
							end,
						}),
					},
				},
			},
		},
	}
end
