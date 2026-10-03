local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local GameReadyController = require(ReplicatedStorage.Controllers.GameReadyController)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local RoundController = require(ReplicatedStorage.Controllers.RoundController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local localPlayer = Players.LocalPlayer
local PANEL = Color3.fromRGB(3, 24, 39)
local PANEL_LIGHT = Color3.fromRGB(3, 20, 33)
local MUTED = Color3.fromRGB(165, 180, 192)
local XP_GREEN = Color3.fromRGB(67, 222, 143)

local function stroke(color: Color3, thickness: number?)
	return create "UIStroke" {
		Color = color,
		Thickness = thickness or 2,
	}
end

local function textStroke()
	return create "UIStroke" {
		Color = Color3.fromRGB(4, 7, 10),
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = 0.05,
	}
end

local function contextualOffer(productKey: string, title, detail: string, yOffset: number, visible, productInfoRevision, narrowViewport, accentColor: Color3, parentLayout, compactHud, portrait, topOffset)
	local layout = {}
	layout.Viewport = parentLayout
	local function shortLandscape() return not portrait() and parentLayout.ReferenceSize().Y < 360 end
	local function offerHeight() return if shortLandscape() then 44 elseif narrowViewport() then 54 else 58 end
	local function offerRatio() return (if narrowViewport() then 200 else 220) / offerHeight() end
	layout.Frame = ResponsiveLayout.Base(function() return UDim2.fromOffset(if narrowViewport() then 200 else 220, offerHeight()) end, layout.Viewport, offerRatio)
	layout.ArtworkPanel = ResponsiveLayout.Child(UDim2.new(0, 34, 1, -12), layout.Frame)
	layout.TextLabel = ResponsiveLayout.Child(UDim2.new(1, -112, 0.32, 0), layout.Frame)
	layout.TextLabel2 = ResponsiveLayout.Child(UDim2.new(1, -112, 0.22, 0), layout.Frame)
	layout.Price = ResponsiveLayout.Child(UDim2.new(0, 54, 1, -12), layout.Frame)

	return create "Frame" {
		Name = productKey .. "Offer",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		-- User-requested middle-left commerce group; compact screens retain their safe top dock.
		Position = function()
			if compactHud() then
				local rowOffset = if portrait() then 128 else 44
				return UDim2.new(0, 12, 0, topOffset() + rowOffset + (if productKey == "ReviveTeam" then (if shortLandscape() then 50 else 66) else 0) + offerHeight())
			end
			return UDim2.new(0, 20, 0.5, yOffset)
		end,
		Size = layout.Frame.Size,
		Visible = visible,
		ZIndex = 80,
		create "UIAspectRatioConstraint" {
			-- Offer cards have breakpoint-specific authored dimensions; preserve each silhouette.
			AspectRatio = offerRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		},
		create "UICorner" { CornerRadius = UDim.new(0, 4) },
		stroke(accentColor, 2),
		StudTexture({ ZIndex = 81, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UIStyle.CombatStudTileSize }),
		create "Frame" {
			Name = "ArtworkPanel",
			BackgroundColor3 = Color3.fromRGB(2, 15, 25),
			BorderSizePixel = 0,
			Position = layout.Frame.Scale(UDim2.new(0, 6, 0, 6)),
			Size = layout.ArtworkPanel.Size,
			ZIndex = 81,
			create "ImageLabel" {
				BackgroundTransparency = 1,
				Image = function()
					productInfoRevision()
					return MonetizationController.GetImage(productKey)
				end,
				Position = UDim2.fromScale(0.06, 0.06),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.88, 0.88),
				ZIndex = 82,
			},
		},
		create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
			Position = layout.Frame.Scale(UDim2.new(0, 46, 0.14, 0)),
			Size = layout.TextLabel.Size,
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 82,
		},
		create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = layout.Frame.Scale(UDim2.new(0, 46, 0.61, 0)),
			Size = layout.TextLabel2.Size,
			Text = detail,
			TextColor3 = accentColor:Lerp(Color3.new(1, 1, 1), 0.28),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 82,
		},
		create "Frame" {
			Name = "Price",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Position = layout.Frame.Scale(UDim2.new(1, -6, 0, 6)),
			Size = layout.Price.Size,
			ZIndex = 83,
			Button({
				Text = function()
					productInfoRevision()
					return UIStyle.RobuxSymbol .. " " .. MonetizationController.GetPriceText(productKey)
				end,
				BackgroundColor3 = accentColor,
				CornerRadius = UDim.new(0, 3),
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				MaxTextSize = 21,
				BorderThickness = 3,
				StudTransparency = UIStyle.CombatStudTransparency,
				MinTextSize = 9,
				Size = UDim2.fromScale(1, 1),
				OnActivated = function() MonetizationController.PromptDeveloperProduct(productKey) end,
			}),
		},
	}
end

local function getRunAbility(state, abilityId: string)
	for _, ability in state.abilities do
		if ability.id == abilityId then
			return ability
		end
	end
	return nil
end

local function getRunAbilitiesInCategory(state, category: string)
	local abilities = {}
	for _, ability in state.abilities do
		if ability.category == category then
			table.insert(abilities, ability)
		end
	end
	return abilities
end

local function getCooldownText(definition, level: number): string
	local stats = definition.GetStats and definition.GetStats(level) or nil
	local cooldown = stats and stats.Cooldown or definition.Combat and definition.Combat.Cooldown
	return if type(cooldown) == "number" then string.format("%.1fs", cooldown) else "PASSIVE"
end

local function formatSurvivalTime(seconds: number): string
	local total = math.max(math.floor(seconds), 0)
	return string.format("%02d:%02d", math.floor(total / 60), total % 60)
end

local function abilitySlot(category: string, slotIndex: number, state, tooltipId, slotLimit, parentLayout)
	local hovered = source(false)
	local runAbility = derive(function()
		return getRunAbilitiesInCategory(state(), category)[slotIndex]
	end)
	local definition = derive(function()
		local current = runAbility()
		return current and AbilityDefinitions.ById[current.id] or nil
	end)
	local occupied = derive(function()
		return definition() ~= nil
	end)
	local locked = derive(function() return slotIndex > slotLimit() end)

	local layout = {}
	layout.Viewport = parentLayout
	layout.Frame = layout.Viewport
	layout.ImageLabel = ResponsiveLayout.Child(UDim2.fromScale(0.68, 0.68), layout.Frame)
	layout.TextLabel = ResponsiveLayout.Child(UDim2.fromScale(0.85, 0.23), layout.Frame)

	return create "Frame" {
		Name = (if category == AbilityDefinitions.Categories.Passive then "Passive" else "Active")
			.. "Slot"
			.. tostring(slotIndex),
		BackgroundColor3 = function()
			local currentDefinition = definition()
			return if locked()
				then PANEL_LIGHT:Lerp(UIStyle.Colors.Gold, if hovered() then 0.16 else 0.07)
			elseif currentDefinition
				then PANEL:Lerp(currentDefinition.Color, if hovered() then 0.2 else 0.1)
				else PANEL_LIGHT
		end,
		BackgroundTransparency = function()
			return if locked() then 0 elseif occupied() then 0 else 0.12
		end,
		BorderSizePixel = 0,
		LayoutOrder = slotIndex,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 102,
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		create "UIStroke" {
			Color = function()
				local currentDefinition = definition()
				return if locked() then Color3.fromRGB(91, 82, 63) elseif currentDefinition
					then currentDefinition.Color:Lerp(Color3.new(0, 0, 0), 0.25)
					else Color3.fromRGB(70, 78, 84)
			end,
			Thickness = 2,
			Transparency = function()
				return if occupied() then 0 else 0.65
			end,
		},
		create "ImageLabel" {
			Name = "StudTexture",
			BackgroundTransparency = 1,
			Image = UIStyle.StudTexture,
			-- Empty capacity stays subdued, but never erase the requested stud surface.
			ImageTransparency = function() return if occupied() or locked() then UIStyle.CombatStudTransparency else 0.86 end,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(48, 48),
			Visible = true,
			ZIndex = 103,
		},
		create "ImageLabel" {
			Name = "LockedSlot", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
			Image = Images.Lock, ImageColor3 = Color3.fromRGB(185, 162, 114), Position = UDim2.fromScale(0.5, 0.36),
			ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.42, 0.42), Visible = locked, ZIndex = 106,
		},
		create "TextLabel" {
			Name = "UnlockLabel", AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold), Position = UDim2.fromScale(0.5, 0.96),
			Size = UDim2.fromScale(0.9, 0.23), Text = "+ SLOT", TextColor3 = Color3.fromRGB(185, 162, 114),
			TextScaled = true, Visible = locked, ZIndex = 106,
		},
		create "ImageLabel" {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = function()
				local currentDefinition = definition()
				return currentDefinition and currentDefinition.Icon or ""
			end,
			Position = UDim2.fromScale(0.5, 0.07),
			Size = layout.ImageLabel.Size,
			ScaleType = Enum.ScaleType.Fit,
			Visible = occupied,
			ZIndex = 104,
		},
		create "TextLabel" {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.5, 0.96),
			Size = layout.TextLabel.Size,
			Text = function()
				local current = runAbility()
				return current and "LV." .. tostring(current.level) or ""
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 105,
			textStroke(),
		},
		create "TextButton" {
			Active = function() return occupied() or locked() end,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = function() return occupied() or locked() end,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 110,
			MouseEnter = function()
				local currentDefinition = definition()
				if locked() then
					hovered(true)
				elseif currentDefinition then
					hovered(true)
					tooltipId(currentDefinition.Id)
				end
			end,
			MouseLeave = function()
				hovered(false)
				local currentDefinition = definition()
				if currentDefinition and tooltipId() == currentDefinition.Id then
					tooltipId(nil)
				end
			end,
			Activated = function()
				if locked() then
					MonetizationController.PromptGamepass("ExtraAbilitySlots")
					return
				end
				local currentDefinition = definition()
				if currentDefinition then
					tooltipId(if tooltipId() == currentDefinition.Id then nil else currentDefinition.Id)
				end
			end,
		},
	}
end

local function abilityCategoryLabel(category: string, state, slotLimit, parentLayout)
	local displayName = if category == AbilityDefinitions.Categories.Passive then "PASSIVES" else "WEAPONS"
	local layout = {}
	layout.Viewport = parentLayout
	layout.TextLabel = ResponsiveLayout.Child(UDim2.fromOffset(72, 48), layout.Viewport)

	return create "Frame" {
		Name = displayName .. "Slots",
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Size = layout.TextLabel.Size,
		ZIndex = 102,
		create "TextLabel" {
			Name = "Category", BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.04, 0.14), Size = UDim2.fromScale(0.92, 0.3),
			Text = displayName, TextColor3 = MUTED, TextScaled = true, ZIndex = 103,
		},
		create "TextLabel" {
			Name = "Count", BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.16, 0.54), Size = UDim2.fromScale(0.68, 0.4),
			Text = function() return string.format("%d / %d", #getRunAbilitiesInCategory(state(), category), slotLimit()) end,
			TextColor3 = Color3.new(1, 1, 1), TextScaled = true, ZIndex = 103,
		},
	}
end

return function()
	local initialState = RunProgressionController.GetState()
	local initialSessionState = RunSessionController.GetState()
	local initialReadyState = GameReadyController.GetState()
	local initialRoundState = RoundController.GetState()
	local state = source(initialState)
	local sessionState = source(initialSessionState)
	local readyState = source(initialReadyState)
	local roundState = source(initialRoundState)
	local monetizationState = source(MonetizationController.GetState())
	local productInfoRevision = source(0)
	local readySeconds = source(
		if initialReadyState.active and type(initialReadyState.deadline) == "number"
			then math.max(initialReadyState.deadline - Workspace:GetServerTimeNow(), 0)
			else 0
	)
	local survivedSeconds = source(
		if type(initialSessionState.startedAt) == "number"
			then math.max(Workspace:GetServerTimeNow() - initialSessionState.startedAt, 0)
			else 0
	)
	local skipSeconds = source(
		if type(initialRoundState.skipEndsAt) == "number"
			then math.max(initialRoundState.skipEndsAt - Workspace:GetServerTimeNow(), 0)
			else 0
	)
	local coinBalance = source(CoinsController.Get())
	-- Keep the combat stack flush with the dynamic top safe area; extra padding pushes both rows too low.
	local topOffset = source(SafeArea.GetTopOffset())
	local progressTarget = source(
		if initialState.xpRequired > 0 then math.clamp(initialState.xp / initialState.xpRequired, 0, 1) else 1
	)
	local smoothProgress = spring(progressTarget, 0.18, 0.9)
	local tooltipId = source(nil :: string?)
	local viewportSize = source(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720))
	local gameMapPresent = source(Workspace:FindFirstChild("Game") ~= nil)
	local narrowViewport = derive(function()
		return viewportSize().X < 700
	end)
	local readyScale = derive(function()
		return math.min(1, math.max((viewportSize().X - 24) / 360, 0.1))
	end)
	local roundScale = derive(function()
		return math.min(1, math.max((viewportSize().X - 24) / 396, 0.1))
	end)
	local compactAbilityHud = derive(function()
		return viewportSize().X < UIStyle.CompactCombatWidth
	end)
	local portrait = derive(function()
		return viewportSize().Y > viewportSize().X
	end)
	local inGame = derive(function()
		-- Map replication is an independent fallback for the first server snapshot, so the XP
		-- amount cannot remain hidden after the Studio destination replaces the lobby map.
		return state().active or gameMapPresent()
	end)
	local weaponSlotLimit = derive(function()
		monetizationState()
		return MonetizationController.GetAbilitySlotLimit(AbilityDefinitions.Categories.Weapon)
	end)
	local passiveSlotLimit = derive(function()
		monetizationState()
		return MonetizationController.GetAbilitySlotLimit(AbilityDefinitions.Categories.Passive)
	end)
	local stateConnection = RunProgressionController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
		progressTarget(if newState.xpRequired > 0 then math.clamp(newState.xp / newState.xpRequired, 0, 1) else 1)
	end)
	local sessionConnection = RunSessionController.GetStateChangedSignal():Connect(function(newState)
		sessionState(newState)
		if newState.active and newState.stats then
			survivedSeconds(newState.stats.survivalTime)
		elseif type(newState.startedAt) == "number" then
			survivedSeconds(math.max(Workspace:GetServerTimeNow() - newState.startedAt, 0))
		end
	end)
	local readyConnection = GameReadyController.GetStateChangedSignal():Connect(function(newState)
		readyState(newState)
		readySeconds(
			if newState.active and type(newState.deadline) == "number"
				then math.max(newState.deadline - Workspace:GetServerTimeNow(), 0)
				else 0
		)
	end)
	local roundConnection = RoundController.GetStateChangedSignal():Connect(function(newState)
		roundState(newState)
		skipSeconds(
			if type(newState.skipEndsAt) == "number"
				then math.max(newState.skipEndsAt - Workspace:GetServerTimeNow(), 0)
				else 0
		)
	end)
	local monetizationConnection = MonetizationController.GetStateChangedSignal():Connect(function(newState)
		monetizationState(newState)
	end)
	local productInfoConnection = MonetizationController.GetProductInfoChangedSignal():Connect(function()
		productInfoRevision(productInfoRevision() + 1)
	end)
	local timerAccumulator = 0
	local timerConnection = RunService.Heartbeat:Connect(function(deltaTime)
		timerAccumulator += deltaTime
		if timerAccumulator < 0.1 then
			return
		end
		timerAccumulator = 0

		local currentReadyState = readyState()
		if currentReadyState.active and type(currentReadyState.deadline) == "number" then
			readySeconds(math.max(currentReadyState.deadline - Workspace:GetServerTimeNow(), 0))
		end
		local currentSession = sessionState()
		if not currentSession.active and type(currentSession.startedAt) == "number" then
			survivedSeconds(math.max(Workspace:GetServerTimeNow() - currentSession.startedAt, 0))
		end
		local currentRoundState = roundState()
		if type(currentRoundState.skipEndsAt) == "number" and currentRoundState.skipEndsAt > 0 then
			skipSeconds(math.max(currentRoundState.skipEndsAt - Workspace:GetServerTimeNow(), 0))
		end
	end)
	local coinConnection = CoinsController.GetChangedSignal():Connect(function(newBalance)
		if type(newBalance) == "number" then
			coinBalance(newBalance)
		end
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset())
	end)
	local viewportConnection = if Workspace.CurrentCamera
		then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportSize(Workspace.CurrentCamera.ViewportSize)
		end)
		else nil
	local workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Game" then
			gameMapPresent(true)
		end
	end)
	local workspaceChildRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Game" then
			gameMapPresent(false)
		end
	end)
	cleanup(function()
		stateConnection:Disconnect()
		sessionConnection:Disconnect()
		readyConnection:Disconnect()
		roundConnection:Disconnect()
		monetizationConnection:Disconnect()
		productInfoConnection:Disconnect()
		timerConnection:Disconnect()
		coinConnection:Disconnect()
		safeAreaConnection:Disconnect()
		workspaceChildAddedConnection:Disconnect()
		workspaceChildRemovedConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(viewportSize)
	layout.RunHUD = layout.Viewport
	layout.Coins = ResponsiveLayout.Base(function()
		return if narrowViewport() then UDim2.fromOffset(200, 42) else UDim2.fromOffset(220, 44)
	end, layout.RunHUD, function() return if narrowViewport() then 200 / 42 else 220 / 44 end)
	layout.ImageLabel = ResponsiveLayout.Child(UDim2.fromOffset(30, 30), layout.Coins, 1)
	layout.TextLabel = ResponsiveLayout.Child(UDim2.new(1, -54, 1, -10), layout.Coins)
	layout.DoubleCoinsBadge = ResponsiveLayout.Child(UDim2.fromOffset(30, 14), layout.Coins)
	layout.ReadyPrompt = ResponsiveLayout.Base(UDim2.fromScale(0.78, 0.11), layout.RunHUD, 360 / 78)
	layout.Title = ResponsiveLayout.Child(UDim2.fromOffset(208, 27), layout.ReadyPrompt)
	layout.Status = ResponsiveLayout.Child(UDim2.fromOffset(208, 22), layout.ReadyPrompt)
	layout.ReadyButton = ResponsiveLayout.Child(UDim2.fromOffset(118, 56), layout.ReadyPrompt)
	layout.RoundStatus = ResponsiveLayout.Base(function() return if narrowViewport() then UDim2.fromOffset(152, 36) else UDim2.fromScale(0.9, 0.08) end, layout.RunHUD, function() return if narrowViewport() then 152 / 36 else UIStyle.RoundStatusAspectRatio end)
	-- Round columns remain proportional to the fitted panel, including short landscape phones.
	layout.TextLabel2 = ResponsiveLayout.Child(UDim2.fromScale(0.26, 0.64), layout.RoundStatus)
	layout.TextLabel3 = ResponsiveLayout.Child(UDim2.fromScale(0.34, 0.28), layout.RoundStatus)
	layout.TextLabel4 = ResponsiveLayout.Child(UDim2.fromScale(0.34, 0.26), layout.RoundStatus)
	layout.SkipRoundButton = ResponsiveLayout.Child(UDim2.fromScale(0.27, 0.66), layout.RoundStatus)
	layout.XPBar = ResponsiveLayout.Base(function()
		return if narrowViewport() then UDim2.new(1, -24, 0, UIStyle.CombatMeterSize.Y.Offset) else UIStyle.CombatMeterSize
	end, layout.RunHUD, function()
					return if narrowViewport()
						then math.max(layout.Viewport.ReferenceSize().X - 24, 1) / UIStyle.CombatMeterSize.Y.Offset
						else (layout.Viewport.ReferenceSize().X * UIStyle.CombatMeterSize.X.Scale + UIStyle.CombatMeterSize.X.Offset) / UIStyle.CombatMeterSize.Y.Offset
				end)
	layout.TextLabel5 = ResponsiveLayout.Child(UDim2.new(0.34, 0, 0, 18), layout.XPBar)
	layout.TextLabel6 = ResponsiveLayout.Child(UDim2.new(0.38, 0, 0, 18), layout.XPBar)
	layout.Track = ResponsiveLayout.Child(UDim2.new(1, -20, 0, 16), layout.XPBar)
	layout.Fill = ResponsiveLayout.Child(function()
						return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
					end, layout.Track)
	layout.AbilityHUD = ResponsiveLayout.Base(function()
		-- Render the locked sixth slot beside the five free slots without making mobile taps too small.
		if narrowViewport() and not portrait() then return UDim2.new(0.55, 0, 0, 106) end
		return if compactAbilityHud() then UDim2.new(1, -24, 0, 106) else UDim2.fromOffset(432, 118)
	end, layout.RunHUD, function() return if compactAbilityHud() then 370 / 106 else 432 / 118 end)
	layout.WeaponAbilities = ResponsiveLayout.Child(function() return UDim2.new(1, 0, 0, if compactAbilityHud() then 48 else 54) end, layout.AbilityHUD)
	layout.Slots = ResponsiveLayout.Child(function()
		return if compactAbilityHud() then UDim2.fromOffset(292, 48) else UDim2.fromOffset(354, 54)
	end, layout.WeaponAbilities)
	layout.PassiveAbilities = ResponsiveLayout.Child(function() return UDim2.new(1, 0, 0, if compactAbilityHud() then 48 else 54) end, layout.AbilityHUD)
	layout.Slots2 = ResponsiveLayout.Child(function()
		return if compactAbilityHud() then UDim2.fromOffset(292, 48) else UDim2.fromOffset(354, 54)
	end, layout.PassiveAbilities)
	layout.AbilityTooltip = ResponsiveLayout.Base(function()
		return if narrowViewport() then UDim2.new(0.82, 0, 0, 142) else UDim2.fromOffset(290, 142)
	end, layout.RunHUD, function()
					return if narrowViewport() then math.max(layout.Viewport.ReferenceSize().X * 0.82, 1) / 142 else 290 / 142
				end)
	layout.TextLabel7 = ResponsiveLayout.Child(UDim2.new(1, -24, 0, 24), layout.AbilityTooltip)
	layout.TextLabel8 = ResponsiveLayout.Child(UDim2.new(1, -24, 0, 43), layout.AbilityTooltip)
	layout.TextLabel9 = ResponsiveLayout.Child(UDim2.new(1, -24, 1, -94), layout.AbilityTooltip)

	local weaponAbilitySlots = {}
	local passiveAbilitySlots = {}
	for slotIndex = 1, AbilityDefinitions.MaximumEquipLimits.Weapon do
		table.insert(
			weaponAbilitySlots,
			abilitySlot(AbilityDefinitions.Categories.Weapon, slotIndex, state, tooltipId, weaponSlotLimit, ResponsiveLayout.Child(function() return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(54, 54) end, layout.Slots))
		)
	end
	for slotIndex = 1, AbilityDefinitions.MaximumEquipLimits.Passive do
		table.insert(
			passiveAbilitySlots,
			abilitySlot(AbilityDefinitions.Categories.Passive, slotIndex, state, tooltipId, passiveSlotLimit, ResponsiveLayout.Child(function() return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(54, 54) end, layout.Slots2))
		)
	end

	local tooltipDefinition = derive(function()
		return tooltipId() and AbilityDefinitions.ById[tooltipId()] or nil
	end)
	local tooltipAbility = derive(function()
		return tooltipId() and getRunAbility(state(), tooltipId()) or nil
	end)


	return create "Frame" {
		Name = "RunHUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		-- Coins are permanent account currency and stay readable in both the lobby and a run.
		Visible = true,
		create "Frame" {
			Name = "Coins",
			AnchorPoint = function() return if inGame() then Vector2.new(0, 1) else Vector2.new(0, 0.5) end,
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = function()
				if not inGame() then return UDim2.new(0, if narrowViewport() then 12 else 20, 0.5, 0) end
				if compactAbilityHud() then
					return UDim2.new(0, 12, 0, topOffset() + (if portrait() then 80 else 0) + (if narrowViewport() then 42 else 44))
				end
				return UDim2.new(0, 20, 0.5, 59)
			end,
			Size = layout.Coins.Size,
			ZIndex = 80,
			create "UIAspectRatioConstraint" {
				-- Permanent currency must retain its compact chip shape at every HUD breakpoint.
				AspectRatio = function() return if narrowViewport() then 200 / 42 else 220 / 44 end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(42, 79, 102), 2),
			StudTexture({ ZIndex = 81, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UIStyle.CombatStudTileSize }),
			create "ImageLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Coin,
				Position = layout.Coins.Scale(UDim2.new(0, 8, 0.5, 0)),
				Size = layout.ImageLabel.Size,
				ZIndex = 82,
				create "UIAspectRatioConstraint" { AspectRatio = 1 },
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = layout.Coins.Scale(UDim2.fromOffset(46, 5)),
				Size = layout.TextLabel.Size,
				Text = function()
					return FormatNumber(coinBalance()) or "0"
				end,
				TextColor3 = Color3.fromRGB(255, 231, 158),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
			create "TextButton" {
				Name = "OpenCoinShop", AutoButtonColor = false, BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 84,
				Activated = function() MonetizationController.SetShopOpen(true, "Coins") end,
			},
			create "TextLabel" {
				Name = "DoubleCoinsBadge", AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = UIStyle.Colors.Gold,
				BorderSizePixel = 0, FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = layout.Coins.Scale(UDim2.new(1, -3, 0, 3)), Size = layout.DoubleCoinsBadge.Size, Text = "x2",
				TextColor3 = Color3.fromRGB(53, 34, 8), TextScaled = true,
				Visible = function() monetizationState(); return MonetizationController.OwnsGamepass("DoubleCoins") end,
				ZIndex = 85, create "UICorner" { CornerRadius = UDim.new(0, 3) },
			},
		},
		contextualOffer(
			"RunBoost",
			"RUN BOOST",
			"THIS RUN",
			1,
			function() return inGame() and not sessionState().dead and not monetizationState().runBoostActive end,
			productInfoRevision,
			narrowViewport,
			UIStyle.Colors.Gold,
			layout.RunHUD, compactAbilityHud, portrait, topOffset
		),
		contextualOffer(
			"ReviveTeam",
			function() return string.format("REVIVE %d", sessionState().eligibleTeamRevives or 0) end,
			"TEAMMATES",
			-65,
			function() return inGame() and not sessionState().dead and (sessionState().eligibleTeamRevives or 0) > 0 end,
			productInfoRevision,
			narrowViewport,
			UIStyle.Colors.Green,
			layout.RunHUD, compactAbilityHud, portrait, topOffset
		),
		create "Frame" {
			Name = "ReadyPrompt",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = layout.ReadyPrompt.Position(function()
				return UDim2.new(0.5, 0, 0, topOffset())
			end, Vector2.new(0.5, 0)),
			Size = layout.ReadyPrompt.Size,
			Visible = function()
				return inGame() and readyState().active
			end,
			ZIndex = 85,
			create "UIAspectRatioConstraint" {
				AspectRatio = 360 / 78,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIScale" { Scale = readyScale },
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(42, 79, 102), 2),
			StudTexture({ ZIndex = 86, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UDim2.fromOffset(30, 30) }),
			create "TextLabel" {
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = layout.ReadyPrompt.Scale(UDim2.fromOffset(12, 7)),
				Size = layout.Title.Size,
				Text = "READY UP",
				TextColor3 = Color3.fromRGB(229, 240, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 87,
				textStroke(),
			},
			create "TextLabel" {
				Name = "Status",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = layout.ReadyPrompt.Scale(UDim2.fromOffset(12, 42)),
				Size = layout.Status.Size,
				Text = function()
					local current = readyState()
					return string.format(
						"%d / %d READY  |  STARTS IN %ds",
						current.readyCount,
						current.requiredCount,
						math.max(0, math.ceil(readySeconds()))
					)
				end,
				TextColor3 = Color3.fromRGB(80, 221, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 87,
			},
			create "Frame" {
				Name = "ReadyButton",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = layout.ReadyPrompt.Scale(UDim2.new(1, -11, 0.5, 0)),
				Size = layout.ReadyButton.Size,
				ZIndex = 87,
				Button({
					Text = function()
						return if readyState().isReady then "READY!" else "READY"
					end,
					Enabled = function()
						local current = readyState()
						return current.active and not current.isReady
					end,
					BackgroundColor3 = UIStyle.Colors.Green,
					CornerRadius = UDim.new(0, 4),
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
					MaxTextSize = 32,
					BorderThickness = 3,
					StudTransparency = UIStyle.CombatStudTransparency,
					Size = UDim2.fromScale(1, 1),
					TextBounds = UDim2.fromScale(0.82, 0.62),
					OnActivated = GameReadyController.ReadyUp,
				}),
			},
		},
		create "Frame" {
			Name = "RoundStatus",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = layout.RoundStatus.Position(function()
				return UDim2.new(0.5, if narrowViewport() and not portrait() then 8 else 0, 0, topOffset())
			end, Vector2.new(0.5, 0)),
			Size = layout.RoundStatus.Size,
			Visible = function()
				local currentSession = sessionState()
				return inGame()
					and roundState().active
					and (currentSession.active or type(currentSession.startedAt) == "number")
			end,
			ZIndex = 80,
			create "UIAspectRatioConstraint" {
				-- The desktop silhouette intentionally reserves a full text column between the round
				-- number and skip button. Preserve the compact mobile envelope where horizontal room
				-- is limited, while ensuring desktop labels never render underneath the button.
				AspectRatio = layout.RoundStatus.AspectRatio,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIScale" { Scale = roundScale },
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(42, 79, 102), 2),
			StudTexture({ ZIndex = 81, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UIStyle.CombatStudTileSize }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = UDim2.fromScale(0.025, 0.18),
				Size = layout.TextLabel2.Size,
				Text = function()
					return (if narrowViewport() then "ROUND\n" else "ROUND ") .. tostring(roundState().round)
				end,
				TextColor3 = Color3.fromRGB(237, 243, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
				textStroke(),
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.32, 0.18),
				Size = layout.TextLabel3.Size,
				Text = function()
					return tostring(roundState().remaining) .. (if narrowViewport() then " LEFT" else " REMAINING")
				end,
				TextColor3 = MUTED,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.32, 0.55),
				Size = layout.TextLabel4.Size,
				Text = function()
					return formatSurvivalTime(survivedSeconds())
				end,
				TextColor3 = Color3.fromRGB(237, 243, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
			create "Frame" {
				Name = "SkipRoundButton",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.975, 0.5),
				Size = layout.SkipRoundButton.Size,
				ZIndex = 82,
				Button({
					Text = function()
						local current = roundState()
						if current.skipEndsAt > 0 then
							local seconds = math.max(math.ceil(skipSeconds()), 0)
							return if current.hasVoted
								then string.format("CANCEL  %ds", seconds)
								else string.format("SKIPPING  %ds", seconds)
						end
						if not current.hasVoted and not current.canVote then
							return "SKIP COOLDOWN"
						end
						return string.format(
							if narrowViewport() then "%s\n%d/%d" else "%s  %d / %d",
							if current.hasVoted then "CANCEL" else "SKIP",
							current.voteCount,
							current.requiredVotes
						)
					end,
					Enabled = function()
						local current = roundState()
						return current.active and current.canVote
					end,
					BackgroundColor3 = Color3.fromRGB(219, 112, 45),
					CornerRadius = UDim.new(0, 4),
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
					MaxTextSize = 22,
					BorderThickness = 3,
					StudTransparency = UIStyle.CombatStudTransparency,
					Size = UDim2.fromScale(1, 1),
					TextBounds = UDim2.fromScale(0.86, 0.56),
					OnActivated = RoundController.VoteToSkip,
				}),
			},
		},
		create "Frame" {
			Name = "XPBar",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = layout.XPBar.Position(function()
				return UDim2.new(0.5, 0, 1, if narrowViewport() then -14 else -16)
			end, Vector2.new(0.5, 1)),
			Size = layout.XPBar.Size,
			Visible = inGame,
			ZIndex = 90,
			create "UIAspectRatioConstraint" {
				-- The XP panel intentionally has fluid width, so derive the authored ratio from its
				-- breakpoint size instead of forcing desktop proportions onto a narrow viewport.
				AspectRatio = function()
					-- This intentionally fluid-width HUD bar keeps a fixed-height envelope;
					-- constrain the mixed base size, not the undamped viewport width.
					local size = layout.XPBar.Size()
					local viewport = viewportSize()
					return (size.X.Scale * viewport.X + size.X.Offset) / (size.Y.Scale * viewport.Y + size.Y.Offset)
				end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UICorner" { CornerRadius = UDim.new(0, 4) },
			stroke(Color3.fromRGB(42, 79, 102), 2),
			StudTexture({ ZIndex = 91, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UIStyle.CombatStudTileSize }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = layout.XPBar.Scale(UDim2.fromOffset(10, 4)),
				Size = layout.TextLabel5.Size,
				Text = function()
					return "LEVEL " .. tostring(state().level)
				end,
				TextColor3 = Color3.fromRGB(229, 240, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 92,
			},
			create "TextLabel" {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = layout.XPBar.Scale(UDim2.new(1, -10, 0, 4)),
				Size = layout.TextLabel6.Size,
				Text = function()
					return if state().xpRequired > 0
						then string.format("%d / %d XP", state().xp, state().xpRequired)
						else "MAX LEVEL"
				end,
				TextColor3 = MUTED,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 92,
			},
			create "Frame" {
				Name = "Track",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(28, 39, 46),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = layout.XPBar.Scale(UDim2.new(0.5, 0, 1, -8)),
				Size = layout.Track.Size,
				ZIndex = 91,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
				create "Frame" {
					Name = "Fill",
					BackgroundColor3 = XP_GREEN,
					BorderSizePixel = 0,
					Size = layout.Fill.Size,
					ZIndex = 92,
					create "UICorner" { CornerRadius = UDim.new(0, 3) },
				},
			},
		},
		create "Frame" {
			Name = "AbilityHUD",
			AnchorPoint = function()
				return if portrait() then Vector2.new(0.5, 1) elseif compactAbilityHud() then Vector2.new(1, 0) else Vector2.new(1, 1)
			end,
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			-- Edge positions stay exact: damping an edge with a zero anchor previously pulled the tray into combat.
			Position = function()
				return if portrait() then UDim2.new(0.5, 0, 1, -122)
					elseif compactAbilityHud() then UDim2.new(1, -20, 0, topOffset() + 50)
					else UDim2.new(1, -20, 1, -16)
			end,
			Size = layout.AbilityHUD.Size,
			Visible = inGame,
			ZIndex = 100,
			create "UIAspectRatioConstraint" {
				AspectRatio = function() return if compactAbilityHud() then 370 / 106 else 432 / 118 end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = layout.AbilityHUD.Padding(UDim.new(0, 6), "Y"),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			},
			create "Frame" {
				Name = "WeaponAbilities",
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = layout.WeaponAbilities.Size,
				-- Always render the configured active capacity so the owning player can read every remaining slot.
				abilityCategoryLabel(AbilityDefinitions.Categories.Weapon, state, weaponSlotLimit, layout.WeaponAbilities),
				create "Frame" {
					Name = "Slots",
					BackgroundTransparency = 1,
					Position = layout.WeaponAbilities.Scale(UDim2.fromOffset(78, 0)),
					Size = layout.Slots.Size,
					create "UIGridLayout" {
						CellPadding = layout.Slots.Scale(function()
							return if compactAbilityHud() then UDim2.fromOffset(5, 0) else UDim2.fromOffset(6, 0)
						end),
						CellSize = layout.Slots.Scale(function()
							return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(54, 54)
						end),
						FillDirectionMaxCells = AbilityDefinitions.MaximumEquipLimits.Weapon,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					weaponAbilitySlots,
				},
			},
			create "Frame" {
				Name = "PassiveAbilities",
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = layout.PassiveAbilities.Size,
				-- Always render the configured passive capacity independently from every other player's loadout.
				abilityCategoryLabel(AbilityDefinitions.Categories.Passive, state, passiveSlotLimit, layout.PassiveAbilities),
				create "Frame" {
					Name = "Slots",
					BackgroundTransparency = 1,
					Position = layout.PassiveAbilities.Scale(UDim2.fromOffset(78, 0)),
					Size = layout.Slots2.Size,
					create "UIGridLayout" {
						CellPadding = layout.Slots2.Scale(function()
							return if compactAbilityHud() then UDim2.fromOffset(5, 0) else UDim2.fromOffset(6, 0)
						end),
						CellSize = layout.Slots2.Scale(function()
							return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(54, 54)
						end),
						FillDirectionMaxCells = AbilityDefinitions.MaximumEquipLimits.Passive,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					passiveAbilitySlots,
				},
			},
		},
		create "Frame" {
			Name = "AbilityTooltip",
			AnchorPoint = function()
				return if portrait() then Vector2.new(0.5, 1) else Vector2.new(1, 1)
			end,
			BackgroundColor3 = PANEL_LIGHT,
			BorderSizePixel = 0,
			Position = function()
				return if portrait() then UDim2.new(0.5, 0, 1, -240)
					elseif compactAbilityHud() then UDim2.new(1, -20, 0, topOffset() + 310)
					else UDim2.new(1, -20, 1, -134)
			end,
			Size = layout.AbilityTooltip.Size,
			Visible = function()
				return inGame() and tooltipDefinition() ~= nil and tooltipAbility() ~= nil
			end,
			ZIndex = 120,
			create "UIAspectRatioConstraint" {
				-- Mobile gives this tooltip fluid width; matching that responsive envelope keeps
				-- its text regions proportional without narrowing the desktop card.
				AspectRatio = function()
					return if narrowViewport() then math.max(layout.Viewport.ReferenceSize().X * 0.82, 1) / 142 else 290 / 142
				end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			StudTexture({ ZIndex = 121, ImageTransparency = 0.86 }),
			create "UIStroke" {
				Color = function()
					local definition = tooltipDefinition()
					return definition and definition.Color or UIStyle.Colors.Blue
				end,
				Thickness = 2,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = layout.AbilityTooltip.Scale(UDim2.fromOffset(12, 8)),
				Size = layout.TextLabel7.Size,
				Text = function()
					local definition = tooltipDefinition()
					local current = tooltipAbility()
					return if definition and current
						then string.format("%s  -  LEVEL %d", string.upper(definition.Name), current.level)
						else ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 121,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = layout.AbilityTooltip.Scale(UDim2.fromOffset(12, 38)),
				Size = layout.TextLabel8.Size,
				Text = function()
					local definition = tooltipDefinition()
					local current = tooltipAbility()
					-- Keep cooldown details in the readable tooltip instead of squeezing them beside card levels.
					return if definition and current then getCooldownText(definition, current.level) .. "  |  " .. AbilityDefinitions.GetDescription(definition, current.level) else ""
				end,
				TextColor3 = Color3.fromRGB(215, 225, 231),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 121,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = layout.AbilityTooltip.Scale(UDim2.fromOffset(12, 86)),
				Size = layout.TextLabel9.Size,
				Text = function()
					local definition = tooltipDefinition()
					local current = tooltipAbility()
					return if definition and current and definition.GetStatsText
						then (if current.level < definition.MaxLevel then "NEXT LEVEL\n" else "MAX LEVEL\n")
							.. definition.GetStatsText(current.level)
						else ""
				end,
				TextColor3 = MUTED,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 121,
			},
		},
	}
end
