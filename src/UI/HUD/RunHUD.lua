local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local localPlayer = Players.LocalPlayer
local PANEL = Color3.fromRGB(3, 24, 39)
local PANEL_LIGHT = Color3.fromRGB(3, 20, 33)
local MUTED = Color3.fromRGB(157, 180, 193)
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

local function getRunAbility(state, abilityId: string)
	for _, ability in state.abilities do
		if ability.id == abilityId then
			return ability
		end
	end
	return nil
end

local function getCooldownText(definition, level: number): string
	local stats = definition.GetStats and definition.GetStats(level) or nil
	local cooldown = stats and stats.Cooldown or definition.Combat and definition.Combat.Cooldown
	return if type(cooldown) == "number" then string.format("%.1fs", cooldown) else "PASSIVE"
end

local function abilitySlot(definition, state, tooltipId)
	local hovered = source(false)
	local runAbility = derive(function()
		return getRunAbility(state(), definition.Id)
	end)
	local visible = derive(function()
		return runAbility() ~= nil
	end)

	return create "Frame" {
		Name = definition.Id,
		BackgroundColor3 = function()
			return PANEL:Lerp(definition.Color, if hovered() then 0.2 else 0.1)
		end,
		BorderSizePixel = 0,
		LayoutOrder = table.find(AbilityDefinitions.List, definition) or 0,
		Size = UDim2.fromOffset(48, 48),
		Visible = visible,
		ZIndex = 102,
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		stroke(definition.Color:Lerp(Color3.new(0, 0, 0), 0.25), 2),
		StudTexture({ ZIndex = 103, ImageTransparency = 0.86, TileSize = UDim2.fromOffset(18, 18) }),
		create "ImageLabel" {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = definition.Icon,
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(30, 30),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 104,
		},
		create "TextLabel" {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.new(0, 4, 1, -2),
			Size = UDim2.new(0.58, 0, 0, 13),
			Text = function()
				local current = runAbility()
				return current and "LV." .. tostring(current.level) or ""
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 105,
			textStroke(),
		},
		create "TextLabel" {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.new(1, -3, 1, -2),
			Size = UDim2.new(0.42, 0, 0, 11),
			Text = function()
				local current = runAbility()
				return current and getCooldownText(definition, current.level) or ""
			end,
			TextColor3 = MUTED,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 105,
		},
		create "TextButton" {
			Active = visible,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = visible,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 110,
			MouseEnter = function()
				hovered(true)
				tooltipId(definition.Id)
			end,
			MouseLeave = function()
				hovered(false)
				if tooltipId() == definition.Id then
					tooltipId(nil)
				end
			end,
			Activated = function()
				tooltipId(if tooltipId() == definition.Id then nil else definition.Id)
			end,
		},
	}
end

return function()
	local initialState = RunProgressionController.GetState()
	local state = source(initialState)
	local coinBalance = source(CoinsController.Get())
	local topOffset = source(SafeArea.GetTopOffset(12))
	local progressTarget = source(
		if initialState.xpRequired > 0 then math.clamp(initialState.xp / initialState.xpRequired, 0, 1) else 1
	)
	local smoothProgress = spring(progressTarget, 0.18, 0.9)
	local tooltipId = source(nil :: string?)
	local viewportWidth = source(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1280)
	local gameMapPresent = source(Workspace:FindFirstChild("Game") ~= nil)
	local narrowViewport = derive(function()
		return viewportWidth() < 700
	end)
	local inGame = derive(function()
		-- Map replication is an independent fallback for the first server snapshot, so the XP
		-- amount cannot remain hidden after the Studio destination replaces the lobby map.
		return state().active or gameMapPresent()
	end)
	local stateConnection = RunProgressionController.GetStateChangedSignal():Connect(function(newState)
		state(newState)
		progressTarget(if newState.xpRequired > 0 then math.clamp(newState.xp / newState.xpRequired, 0, 1) else 1)
	end)
	local coinConnection = CoinsController.GetChangedSignal():Connect(function(newBalance)
		if type(newBalance) == "number" then
			coinBalance(newBalance)
		end
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end)
	local viewportConnection = if Workspace.CurrentCamera
		then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportWidth(Workspace.CurrentCamera.ViewportSize.X)
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
		coinConnection:Disconnect()
		safeAreaConnection:Disconnect()
		workspaceChildAddedConnection:Disconnect()
		workspaceChildRemovedConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local abilitySlots = {}
	for _, definition in AbilityDefinitions.List do
		table.insert(abilitySlots, abilitySlot(definition, state, tooltipId))
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
			BackgroundColor3 = Color3.fromRGB(38, 33, 24),
			BorderSizePixel = 0,
			Position = function()
				return UDim2.fromOffset(20, topOffset())
			end,
			Size = UDim2.new(0.1, 92, 0, 44),
			ZIndex = 80,
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(216, 163, 62), 2),
			StudTexture({ ZIndex = 81, ImageTransparency = 0.84 }),
			create "ImageLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Coin,
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				ZIndex = 82,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromOffset(46, 5),
				Size = UDim2.new(1, -54, 1, -10),
				Text = function()
					return FormatNumber(coinBalance()) or "0"
				end,
				TextColor3 = Color3.fromRGB(255, 231, 158),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
		},
		create "Frame" {
			Name = "XPBar",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(14, 20, 27),
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(0.46, 80, 0, 52),
			Visible = inGame,
			ZIndex = 90,
			create "UICorner" { CornerRadius = UDim.new(0, 4) },
			stroke(Color3.fromRGB(0, 139, 168), 2),
			StudTexture({ ZIndex = 91, ImageTransparency = 0.88 }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(0.34, 0, 0, 18),
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
				Position = UDim2.new(1, -10, 0, 4),
				Size = UDim2.new(0.38, 0, 0, 18),
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
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 17),
				ZIndex = 91,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
				create "Frame" {
					Name = "Fill",
					BackgroundColor3 = XP_GREEN,
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
					end,
					ZIndex = 92,
					create "UICorner" { CornerRadius = UDim.new(0, 3) },
					create "UIGradient" {
						Color = ColorSequence.new(XP_GREEN, Color3.fromRGB(184, 255, 106)),
					},
				},
			},
		},
		create "Frame" {
			Name = "AbilityHUD",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = function()
				return if narrowViewport() then UDim2.new(1, -12, 1, -132) else UDim2.new(1, -20, 1, -28)
			end,
			Size = UDim2.fromOffset(270, 106),
			Visible = inGame,
			ZIndex = 100,
			create "UIGridLayout" {
				CellPadding = UDim2.fromOffset(6, 6),
				CellSize = UDim2.fromOffset(48, 48),
				FillDirection = Enum.FillDirection.Horizontal,
				FillDirectionMaxCells = 5,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			},
			abilitySlots,
		},
		create "Frame" {
			Name = "AbilityTooltip",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = PANEL_LIGHT,
			BorderSizePixel = 0,
			Position = function()
				return if narrowViewport() then UDim2.new(1, -12, 1, -250) else UDim2.new(1, -20, 1, -146)
			end,
			Size = UDim2.fromOffset(290, 142),
			Visible = function()
				return inGame() and tooltipDefinition() ~= nil and tooltipAbility() ~= nil
			end,
			ZIndex = 120,
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
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -24, 0, 24),
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
				Position = UDim2.fromOffset(12, 38),
				Size = UDim2.new(1, -24, 0, 43),
				Text = function()
					local definition = tooltipDefinition()
					local current = tooltipAbility()
					return if definition and current then AbilityDefinitions.GetDescription(definition, current.level) else ""
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
				Position = UDim2.fromOffset(12, 86),
				Size = UDim2.new(1, -24, 1, -94),
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
