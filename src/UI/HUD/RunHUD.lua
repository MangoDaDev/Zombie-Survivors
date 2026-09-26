local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local GameReadyController = require(ReplicatedStorage.Controllers.GameReadyController)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local RoundController = require(ReplicatedStorage.Controllers.RoundController)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)
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

local function abilitySlot(category: string, slotIndex: number, state, tooltipId)
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

	return create "Frame" {
		Name = (if category == AbilityDefinitions.Categories.Passive then "Passive" else "Active")
			.. "Slot"
			.. tostring(slotIndex),
		BackgroundColor3 = function()
			local currentDefinition = definition()
			return if currentDefinition
				then PANEL:Lerp(currentDefinition.Color, if hovered() then 0.2 else 0.1)
				else Color3.new(0, 0, 0)
		end,
		BackgroundTransparency = function()
			return if occupied() then 0 else 0.48
		end,
		BorderSizePixel = 0,
		LayoutOrder = slotIndex,
		Size = UDim2.fromOffset(48, 48),
		ZIndex = 102,
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		create "UIStroke" {
			Color = function()
				local currentDefinition = definition()
				return if currentDefinition
					then currentDefinition.Color:Lerp(Color3.new(0, 0, 0), 0.25)
					else Color3.fromRGB(70, 78, 84)
			end,
			Thickness = 2,
			Transparency = function()
				return if occupied() then 0 else 0.45
			end,
		},
		create "ImageLabel" {
			Name = "StudTexture",
			BackgroundTransparency = 1,
			Image = UIStyle.StudTexture,
			ImageTransparency = 0.86,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(36, 36),
			Visible = occupied,
			ZIndex = 103,
		},
		create "ImageLabel" {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = function()
				local currentDefinition = definition()
				return currentDefinition and currentDefinition.Icon or ""
			end,
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(30, 30),
			ScaleType = Enum.ScaleType.Fit,
			Visible = occupied,
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
				local currentDefinition = definition()
				return current and currentDefinition and getCooldownText(currentDefinition, current.level) or ""
			end,
			TextColor3 = MUTED,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 105,
		},
		create "TextButton" {
			Active = occupied,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = occupied,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 110,
			MouseEnter = function()
				local currentDefinition = definition()
				if currentDefinition then
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
				local currentDefinition = definition()
				if currentDefinition then
					tooltipId(if tooltipId() == currentDefinition.Id then nil else currentDefinition.Id)
				end
			end,
		},
	}
end

local function abilityCategoryLabel(category: string, state)
	local displayName = if category == AbilityDefinitions.Categories.Passive then "PASSIVE" else "ACTIVE"
	return create "TextLabel" {
		Name = displayName .. "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(72, 48),
		FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
		Text = function()
			return string.format("%s\n%d / %d", displayName, #getRunAbilitiesInCategory(state(), category), AbilityDefinitions.EquipLimits[category])
		end,
		TextColor3 = MUTED,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 102,
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
	local coinBalance = source(CoinsController.Get())
	local topOffset = source(SafeArea.GetTopOffset(12))
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
		return viewportSize().X < 700
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
		timerConnection:Disconnect()
		coinConnection:Disconnect()
		safeAreaConnection:Disconnect()
		workspaceChildAddedConnection:Disconnect()
		workspaceChildRemovedConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local weaponAbilitySlots = {}
	local passiveAbilitySlots = {}
	for slotIndex = 1, AbilityDefinitions.EquipLimits.Weapon do
		table.insert(
			weaponAbilitySlots,
			abilitySlot(AbilityDefinitions.Categories.Weapon, slotIndex, state, tooltipId)
		)
	end
	for slotIndex = 1, AbilityDefinitions.EquipLimits.Passive do
		table.insert(
			passiveAbilitySlots,
			abilitySlot(AbilityDefinitions.Categories.Passive, slotIndex, state, tooltipId)
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
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Color3.fromRGB(38, 33, 24),
			BorderSizePixel = 0,
			Position = function()
				-- On narrow game viewports the large round/ready panel owns the top band, so currency sits below it.
				return UDim2.fromOffset(
					if narrowViewport() then 12 else 20,
					topOffset() + (if narrowViewport() and inGame() then 84 else 0)
				)
			end,
			Size = function()
				return if narrowViewport() then UDim2.fromOffset(142, 42) else UDim2.fromOffset(160, 44)
			end,
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
			Name = "ReadyPrompt",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = function()
				return UDim2.new(0.5, 0, 0, topOffset())
			end,
			Size = UDim2.fromOffset(360, 78),
			Visible = function()
				return inGame() and readyState().active
			end,
			ZIndex = 85,
			create "UIAspectRatioConstraint" {
				AspectRatio = 360 / 78,
				DominantAxis = Enum.DominantAxis.Width,
			},
			create "UIScale" { Scale = readyScale },
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(0, 183, 211), 2),
			StudTexture({ ZIndex = 86, ImageTransparency = 0.84, TileSize = UDim2.fromOffset(30, 30) }),
			create "TextLabel" {
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = UDim2.fromOffset(12, 7),
				Size = UDim2.fromOffset(208, 27),
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
				Position = UDim2.fromOffset(12, 42),
				Size = UDim2.fromOffset(208, 22),
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
				Position = UDim2.new(1, -11, 0.5, 0),
				Size = UDim2.fromOffset(118, 56),
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
			Position = function()
				return UDim2.new(0.5, 0, 0, topOffset())
			end,
			Size = UDim2.fromOffset(396, 68),
			Visible = function()
				local currentSession = sessionState()
				return inGame()
					and roundState().active
					and (currentSession.active or type(currentSession.startedAt) == "number")
			end,
			ZIndex = 80,
			create "UIAspectRatioConstraint" {
				AspectRatio = 396 / 68,
				DominantAxis = Enum.DominantAxis.Width,
			},
			create "UIScale" { Scale = roundScale },
			create "UICorner" { CornerRadius = UDim.new(0, 5) },
			stroke(Color3.fromRGB(0, 139, 168), 2),
			StudTexture({ ZIndex = 81, ImageTransparency = 0.84 }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.fromOffset(112, 52),
				Text = function()
					return "ROUND " .. tostring(roundState().round)
				end,
				TextColor3 = Color3.fromRGB(80, 221, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
				textStroke(),
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromOffset(132, 9),
				Size = UDim2.fromOffset(88, 22),
				Text = function()
					return tostring(roundState().remaining) .. " THIS ROUND"
				end,
				TextColor3 = Color3.fromRGB(229, 240, 247),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromOffset(132, 37),
				Size = UDim2.fromOffset(88, 18),
				Text = function()
					return formatSurvivalTime(survivedSeconds())
				end,
				TextColor3 = MUTED,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
			create "Frame" {
				Name = "SkipRoundButton",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(156, 50),
				ZIndex = 82,
				Button({
					Text = function()
						local current = roundState()
						if not current.hasVoted and not current.canVote then
							return "SKIP COOLDOWN"
						end
						return string.format(
							"%s  %d / %d",
							if current.hasVoted then "VOTED" else "SKIP",
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
					Size = UDim2.fromScale(1, 1),
					TextBounds = UDim2.fromScale(0.86, 0.56),
					OnActivated = RoundController.VoteToSkip,
				}),
			},
		},
		create "Frame" {
			Name = "XPBar",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(14, 20, 27),
			BorderSizePixel = 0,
			Position = function()
				return UDim2.new(0.5, 0, 1, if narrowViewport() then -14 else -16)
			end,
			Size = function()
				return if narrowViewport() then UDim2.new(1, -24, 0, 50) else UDim2.new(0.46, 80, 0, 52)
			end,
			Visible = inGame,
			ZIndex = 90,
			create "UISizeConstraint" { MaxSize = Vector2.new(640, 52) },
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
			AnchorPoint = function()
				return if narrowViewport() then Vector2.new(0.5, 1) else Vector2.new(1, 1)
			end,
			BackgroundTransparency = 1,
			Position = function()
				return if narrowViewport() then UDim2.new(0.5, 0, 1, -138) else UDim2.new(1, -20, 1, -136)
			end,
			Size = function()
				-- Five slots per category remain full-sized on desktop and only step down slightly on narrow screens.
				return if compactAbilityHud() then UDim2.fromOffset(308, 106) else UDim2.fromOffset(342, 106)
			end,
			Visible = inGame,
			ZIndex = 100,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			},
			create "Frame" {
				Name = "WeaponAbilities",
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 48),
				-- Always render the configured active capacity so the owning player can read every remaining slot.
				abilityCategoryLabel(AbilityDefinitions.Categories.Weapon, state),
				create "Frame" {
					Name = "Slots",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(78, 0),
					Size = function()
						return if compactAbilityHud() then UDim2.fromOffset(230, 48) else UDim2.fromOffset(264, 48)
					end,
					create "UIGridLayout" {
						CellPadding = function()
							return if compactAbilityHud() then UDim2.fromOffset(5, 0) else UDim2.fromOffset(6, 0)
						end,
						CellSize = function()
							return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(48, 48)
						end,
						FillDirectionMaxCells = AbilityDefinitions.EquipLimits.Weapon,
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
				Size = UDim2.new(1, 0, 0, 48),
				-- Always render the configured passive capacity independently from every other player's loadout.
				abilityCategoryLabel(AbilityDefinitions.Categories.Passive, state),
				create "Frame" {
					Name = "Slots",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(78, 0),
					Size = function()
						return if compactAbilityHud() then UDim2.fromOffset(230, 48) else UDim2.fromOffset(264, 48)
					end,
					create "UIGridLayout" {
						CellPadding = function()
							return if compactAbilityHud() then UDim2.fromOffset(5, 0) else UDim2.fromOffset(6, 0)
						end,
						CellSize = function()
							return if compactAbilityHud() then UDim2.fromOffset(42, 42) else UDim2.fromOffset(48, 48)
						end,
						FillDirectionMaxCells = AbilityDefinitions.EquipLimits.Passive,
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
				return if narrowViewport() then Vector2.new(0.5, 1) else Vector2.new(1, 1)
			end,
			BackgroundColor3 = PANEL_LIGHT,
			BorderSizePixel = 0,
			Position = function()
				return if narrowViewport() then UDim2.new(0.5, 0, 1, -252) else UDim2.new(1, -20, 1, -252)
			end,
			Size = function()
				return if narrowViewport() then UDim2.new(0.82, 0, 0, 142) else UDim2.fromOffset(290, 142)
			end,
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
