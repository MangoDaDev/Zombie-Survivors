local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local PartyTeleporterController = require(ReplicatedStorage.Controllers.PartyTeleporterController)
local PartyTeleporterConfig = require(ReplicatedStorage.Modules.Game.PartyTeleporterConfig)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local BLACK = Color3.fromRGB(1, 7, 13)
local DEEP_NAVY = Color3.fromRGB(3, 24, 39)
local PANEL_NAVY = Color3.fromRGB(3, 20, 33)
local CYAN = Color3.fromRGB(0, 218, 238)
local CYAN_BUTTON = Color3.fromRGB(11, 176, 214)
local CYAN_TEXT = Color3.fromRGB(55, 218, 251)
local RED = Color3.fromRGB(244, 48, 58)
local HEAVY_FONT = Font.fromName("Ubuntu", Enum.FontWeight.Heavy)
local BOLD_FONT = Font.fromName("Ubuntu", Enum.FontWeight.Bold)

type PartyState = {
	teleporterId: string,
	memberCount: number,
	maxSize: number,
	leaderUserId: number,
	leaderName: string,
	friendsOnly: boolean,
	configuring: boolean,
	countdown: number?,
	isLeader: boolean,
	locked: boolean,
	loading: boolean,
}

type Reactive<T> = T | (() -> T)

local function textStroke(thickness: number?)
	return create "UIStroke" {
		Color = BLACK,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness or 0.055,
	}
end

local function studTexture(tileSize: Reactive<UDim2>, transparency: number, zIndex: number)
	return create "ImageLabel" {
		Name = "StudTexture",
		BackgroundTransparency = 1,
		Image = UIStyle.StudTexture,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = tileSize,
		ZIndex = zIndex,
	}
end

-- The shared Button owns interaction feedback and sounds. This overlay keeps this menu's
-- display type explicitly heavy and avoids the shared component's intentionally compact label cap.
local function actionButton(props)
	return create "Frame" {
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex or 72,
		Button({
			Text = "",
			Enabled = props.Enabled,
			BackgroundColor3 = props.BackgroundColor3,
			CornerRadius = UDim.new(0, 0),
			Size = UDim2.fromScale(1, 1),
			OnActivated = props.OnActivated,
		}),
		create "TextLabel" {
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = UDim2.fromScale(0.5, 0.46),
			Size = props.TextBounds or UDim2.fromScale(0.88, 0.72),
			Text = props.Text,
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
			textStroke(props.StrokeThickness),
		},
	}
end

local function createHeader(props)
	return create "Frame" {
		Name = "Header",
		BackgroundColor3 = Color3.fromRGB(18, 196, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = function()
			return UDim2.new(1, -(props.exitWidth() + 36), 0, props.headerHeight())
		end,
		Visible = props.showConfiguration,
		ZIndex = 64,
		create "UIGradient" {
			Color = ColorSequence.new(Color3.fromRGB(40, 232, 255), Color3.fromRGB(20, 123, 255)),
			Rotation = 90,
		},
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(121, 244, 255),
			Thickness = 2,
		},
		studTexture(function()
			local tile = if props.portrait() then 44 else 48
			return UDim2.fromOffset(tile, tile)
		end, 0.77, 65),
		create "TextLabel" {
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = UDim2.fromScale(0.035, 0.06),
			Size = UDim2.fromScale(0.93, 0.58),
			Text = function()
				local state = props.partyState()
				if state and state.loading then
					return "LOADING..."
				elseif state and state.locked then
					return "PARTY LOCKED"
				elseif state and not state.configuring then
					return "PARTY READY"
				end
				return "CREATE PARTY"
			end,
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 66,
			textStroke(0.075),
		},
		create "TextLabel" {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = UDim2.fromScale(0.04, 0.69),
			Size = UDim2.fromScale(0.92, 0.2),
			Text = function()
				local state = props.partyState()
				if not state then
					return ""
				end
				local prefix = if props.portrait() then "LIFT " else "TELEPORTER "
				return prefix .. state.teleporterId .. "  •  " .. props.badgeText()
			end,
			TextColor3 = Color3.fromRGB(1, 44, 78),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 66,
		},
	}
end

local function createSummary(props)
	return create "Frame" {
		Name = "Summary",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(2, 14, 24),
		BorderSizePixel = 0,
		Position = function()
			return UDim2.new(0.5, 0, 0, if props.short() then 10 else if props.portrait() then 12 else 14)
		end,
		Size = function()
			return UDim2.new(1, if props.portrait() then -22 else -28, 0, if props.short() then 54 else if props.portrait() then 66 else 62)
		end,
		ZIndex = 68,
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(0, 104, 132),
			Thickness = 3,
		},
		create "TextLabel" {
			Name = "LeaderLabel",
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = UDim2.fromScale(0.025, 0.1),
			Size = UDim2.fromScale(0.45, 0.28),
			Text = "PARTY LEADER",
			TextColor3 = CYAN_TEXT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 69,
		},
		create "TextLabel" {
			Name = "LeaderName",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = UDim2.fromScale(0.025, 0.43),
			Size = UDim2.fromScale(0.55, 0.43),
			Text = function()
				local state = props.partyState()
				return state and state.leaderName or ""
			end,
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 69,
			textStroke(),
		},
		create "TextLabel" {
			Name = "Occupancy",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = UDim2.fromScale(0.975, 0.5),
			Size = UDim2.fromScale(0.38, 0.56),
			Text = function()
				local state = props.partyState()
				if not state then
					return ""
				end
				local suffix = if props.portrait() then "" else " PLAYERS"
				return string.format("%d / %d%s", state.memberCount, state.maxSize, suffix)
			end,
			TextColor3 = CYAN_TEXT,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 69,
			textStroke(),
		},
	}
end

local function createSettings(props)
	return create "Frame" {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = PANEL_NAVY,
		BorderSizePixel = 0,
		Position = function()
			return UDim2.new(0.5, 0, 0, if props.short() then 74 else if props.portrait() then 90 else 88)
		end,
		Size = function()
			return UDim2.new(1, if props.portrait() then -22 else -28, 0, if props.short() then 130 else if props.portrait() then 184 else 142)
		end,
		ZIndex = 68,
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(0, 139, 168),
			Thickness = 3,
		},
		create "TextLabel" {
			Name = "PartySizeLabel",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = function()
				return UDim2.new(0, if props.portrait() then 12 else 18, 0, if props.short() then 15 else if props.portrait() then 8 else 20)
			end,
			Size = function()
				return UDim2.new(if props.portrait() then 1 else 0.42, if props.portrait() then -24 else 0, 0, if props.portrait() then 27 else 30)
			end,
			Text = "PARTY SIZE",
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 69,
			textStroke(),
		},
		actionButton({
			Name = "Decrease",
			Position = function()
				if props.portrait() then
					return UDim2.fromOffset(12, 39)
				end
				return UDim2.new(1, if props.short() then -174 else -192, 0, if props.short() then 6 else 11)
			end,
			AnchorPoint = function()
				return if props.portrait() then Vector2.zero else Vector2.new(1, 0)
			end,
			Size = function()
				return UDim2.fromOffset(if props.portrait() then 54 else 52, if props.short() then 44 else 48)
			end,
			Text = "−",
			Enabled = props.canDecreasePartySize,
			BackgroundColor3 = CYAN_BUTTON,
			OnActivated = function()
				props.changePartySize(-1)
			end,
			TextBounds = UDim2.fromScale(0.56, 0.56),
		}),
		create "Frame" {
			Name = "PartySizeValue",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(1, 10, 18),
			BorderSizePixel = 0,
			Position = function()
				if props.portrait() then
					return UDim2.new(0.5, 0, 0, 39)
				end
				return UDim2.new(1, if props.short() then -112 else -124, 0, if props.short() then 6 else 11)
			end,
			Size = function()
				return UDim2.fromOffset(if props.portrait() then 70 else 68, if props.short() then 44 else 48)
			end,
			ZIndex = 72,
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(0, 105, 132),
				Thickness = 3,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.fromScale(1, 1),
				Text = function()
					local state = props.partyState()
					return state and tostring(state.maxSize) or "−"
				end,
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				ZIndex = 73,
				textStroke(),
			},
		},
		actionButton({
			Name = "Increase",
			AnchorPoint = Vector2.new(1, 0),
			Position = function()
				return UDim2.new(1, if props.portrait() then -12 else -18, 0, if props.portrait() then 39 else if props.short() then 6 else 11)
			end,
			Size = function()
				return UDim2.fromOffset(if props.portrait() then 54 else 52, if props.short() then 44 else 48)
			end,
			Text = "+",
			Enabled = props.canIncreasePartySize,
			BackgroundColor3 = CYAN_BUTTON,
			OnActivated = function()
				props.changePartySize(1)
			end,
			TextBounds = UDim2.fromScale(0.56, 0.56),
		}),
		create "Frame" {
			Name = "Divider",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(0, 83, 105),
			BorderSizePixel = 0,
			Position = function()
				return UDim2.new(0.5, 0, 0, if props.short() then 60 else if props.portrait() then 96 else 70)
			end,
			Size = UDim2.new(1, -32, 0, 2),
			ZIndex = 69,
		},
		create "TextLabel" {
			Name = "PrivacyLabel",
			BackgroundTransparency = 1,
			FontFace = HEAVY_FONT,
			Position = function()
				return UDim2.new(0, if props.portrait() then 12 else 18, 0, if props.short() then 78 else if props.portrait() then 104 else 91)
			end,
			Size = function()
				return UDim2.new(if props.portrait() then 1 else 0.42, if props.portrait() then -24 else 0, 0, if props.portrait() then 24 else 30)
			end,
			Text = "WHO CAN JOIN?",
			TextColor3 = UIStyle.Colors.Paper,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 69,
			textStroke(),
		},
		actionButton({
			Name = "Privacy",
			AnchorPoint = function()
				return if props.portrait() then Vector2.zero else Vector2.new(1, 0)
			end,
			Position = function()
				if props.portrait() then
					return UDim2.new(0, 12, 0, 132)
				end
				return UDim2.new(1, -18, 0, if props.short() then 68 else 82)
			end,
			Size = function()
				if props.portrait() then
					return UDim2.new(1, -24, 0, 44)
				end
				return UDim2.fromOffset(if props.short() then 220 else 250, if props.short() then 44 else 48)
			end,
			Text = function()
				local state = props.partyState()
				return if state and state.friendsOnly then "FRIENDS ONLY" else "OPEN TO EVERYONE"
			end,
			Enabled = props.canConfigure,
			BackgroundColor3 = CYAN_BUTTON,
			OnActivated = props.togglePrivacy,
			TextBounds = UDim2.fromScale(0.9, 0.58),
		}),
	}
end

local function createBody(props)
	return create "Frame" {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = DEEP_NAVY,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = function()
			return UDim2.new(1, if props.portrait() then -20 else -24, 1, -(props.headerHeight() + 36))
		end,
		Visible = props.showConfiguration,
		ZIndex = 64,
		create "UIGradient" {
			Color = ColorSequence.new(Color3.fromRGB(7, 54, 79), DEEP_NAVY),
			Rotation = 90,
		},
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(0, 160, 187),
			Thickness = 3,
		},
		studTexture(function()
			local tile = if props.portrait() then 48 else 56
			return UDim2.fromOffset(tile, tile)
		end, 0.88, 65),
		createSummary(props),
		createSettings(props),
		create "TextLabel" {
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = BOLD_FONT,
			Position = function()
				return UDim2.new(0.5, 0, 0, if props.short() then 211 else if props.portrait() then 284 else 239)
			end,
			Size = UDim2.new(1, -34, 0, 28),
			Text = props.statusText,
			TextColor3 = CYAN_TEXT,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 68,
		},
		actionButton({
			Name = "Confirm",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if props.portrait() then -12 else -14),
			Size = function()
				return UDim2.new(1, if props.portrait() then -22 else -28, 0, if props.short() then 54 else 58)
			end,
			Text = props.confirmText,
			Enabled = props.canConfigure,
			BackgroundColor3 = UIStyle.Colors.Green,
			OnActivated = props.confirmParty,
			TextBounds = UDim2.fromScale(0.9, 0.62),
			StrokeThickness = 0.065,
		}),
	}
end

return function()
	local partyState = source(PartyTeleporterController.GetState() :: PartyState?)
	local viewportSize = source(Vector2.new(1280, 720))
	local viewportConnection: RBXScriptConnection?
	local stateConnection = PartyTeleporterController.GetStateChangedSignal():Connect(function(state)
		partyState(state :: PartyState?)
	end)

	cleanup(function()
		stateConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	local portrait = derive(function()
		local size = viewportSize()
		return size.X < 560 and size.X < size.Y
	end)
	local short = derive(function()
		local size = viewportSize()
		return not portrait() and size.Y < 500
	end)
	local headerHeight = derive(function()
		return if short() then 78 else if portrait() then 90 else 94
	end)
	local exitWidth = derive(function()
		return if short() then 70 else if portrait() then 72 else 86
	end)

	local canConfigure = derive(function()
		local state = partyState()
		-- Only the configuring, unlocked leader may change or confirm party settings.
		return state ~= nil and state.isLeader and state.configuring and not state.locked
	end)
	local showConfiguration = derive(function()
		local state = partyState()
		-- Members only need an exit affordance. The leader's configuration surface also closes as
		-- soon as the authoritative server acknowledges confirmation.
		return state ~= nil and state.isLeader and state.configuring and not state.locked
	end)
	local canDecreasePartySize = derive(function()
		local state = partyState()
		if not state or not canConfigure() then
			return false
		end
		return state.maxSize > math.max(PartyTeleporterConfig.MinimumPartySize, state.memberCount)
	end)
	local canIncreasePartySize = derive(function()
		local state = partyState()
		return state ~= nil and canConfigure() and state.maxSize < PartyTeleporterConfig.MaximumPartySize
	end)
	local canLeave = derive(function()
		local state = partyState()
		-- Departure is irreversible once locked, so all exit affordances disable at that boundary.
		return state ~= nil and not state.locked
	end)

	local badgeText = derive(function()
		local state = partyState()
		if not state then
			return ""
		elseif state.loading then
			return "LOADING"
		elseif state.locked then
			return "LOCKED"
		elseif state.configuring then
			return if state.isLeader then "SETTINGS OPEN" else "LEADER SETUP"
		elseif state.countdown ~= nil then
			return string.format("%ds", math.max(0, math.ceil(state.countdown)))
		end
		return "READY"
	end)
	local statusText = derive(function()
		local state = partyState()
		if not state then
			return ""
		elseif state.loading then
			return "LOADING THE GAME..."
		elseif state.locked then
			return "PARTY LOCKED • DEPARTING NOW"
		elseif state.configuring then
			if state.isLeader and state.countdown ~= nil then
				return string.format("CONFIRM WITHIN %ds", math.max(0, math.ceil(state.countdown)))
			end
			return if state.isLeader then "READY TO CONFIRM" else "WAITING FOR PARTY LEADER"
		elseif state.countdown ~= nil then
			return string.format("DEPARTING IN %ds", math.max(0, math.ceil(state.countdown)))
		end
		return "READY TO DEPART"
	end)
	local confirmText = derive(function()
		local state = partyState()
		if state and state.configuring and state.isLeader then
			return "CONFIRM PARTY"
		elseif state and state.configuring then
			return "WAITING FOR LEADER"
		elseif state and state.loading then
			return "LOADING..."
		end
		return "PARTY READY"
	end)

	local function changePartySize(offset: number)
		local state = partyState()
		if not state or not canConfigure() then
			return
		end

		local nextSize = math.clamp(
			state.maxSize + offset,
			math.max(PartyTeleporterConfig.MinimumPartySize, state.memberCount),
			PartyTeleporterConfig.MaximumPartySize
		)
		if nextSize ~= state.maxSize then
			PartyTeleporterController.SetMaxPartySize(nextSize)
		end
	end

	local function togglePrivacy()
		local state = partyState()
		if state and canConfigure() then
			PartyTeleporterController.SetFriendsOnly(not state.friendsOnly)
		end
	end

	local function confirmParty()
		if canConfigure() then
			PartyTeleporterController.ConfirmParty()
		end
	end

	local function exitParty()
		local state = partyState()
		if not state or not canLeave() then
			return
		end

		-- Leaders cancel the entire party; non-leaders leave only themselves.
		if state.isLeader then
			PartyTeleporterController.CancelParty()
		else
			PartyTeleporterController.LeaveParty()
		end
	end

	local componentProps = {
		partyState = partyState,
		portrait = portrait,
		short = short,
		headerHeight = headerHeight,
		exitWidth = exitWidth,
		badgeText = badgeText,
		statusText = statusText,
		confirmText = confirmText,
		showConfiguration = showConfiguration,
		canConfigure = canConfigure,
		canDecreasePartySize = canDecreasePartySize,
		canIncreasePartySize = canIncreasePartySize,
		changePartySize = changePartySize,
		togglePrivacy = togglePrivacy,
		confirmParty = confirmParty,
	}

	return create "Frame" {
		Name = "PartyTeleporterMenu",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = function()
			return partyState() ~= nil
		end,
		ZIndex = 60,
		action(function(instance)
			local root = instance :: Frame
			local function updateViewportSize()
				viewportSize(root.AbsoluteSize)
			end

			if viewportConnection then
				viewportConnection:Disconnect()
			end
			updateViewportSize()
			viewportConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateViewportSize)
		end),
		create "Frame" {
			Name = "Panel",
			AnchorPoint = function()
				return if showConfiguration() then Vector2.new(0.5, 0.5) else Vector2.new(1, 0)
			end,
			BackgroundColor3 = Color3.fromRGB(2, 10, 18),
			BackgroundTransparency = function()
				return if showConfiguration() then 0 else 1
			end,
			BorderSizePixel = 0,
			Position = function()
				return if showConfiguration() then UDim2.fromScale(0.5, 0.5) else UDim2.new(1, -24, 0, 24)
			end,
			Size = function()
				if not showConfiguration() then
					return UDim2.fromOffset(exitWidth(), headerHeight())
				end
				if portrait() then
					return UDim2.new(1, -20, 1, -24)
				elseif short() then
					return UDim2.new(0.88, 0, 1, -20)
				end
				return UDim2.new(0.54, 0, 0.78, 0)
			end,
			ZIndex = 61,
			create "UISizeConstraint" {
				MaxSize = function()
					if portrait() then
						return Vector2.new(360, 510)
					elseif short() then
						return Vector2.new(660, 430)
					end
					return Vector2.new(660, 470)
				end,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = BLACK,
				Thickness = 8,
				Transparency = function()
					return if showConfiguration() then 0 else 1
				end,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = CYAN,
				Thickness = 4,
				Transparency = function()
					return if showConfiguration() then 0 else 1
				end,
			},
			createHeader(componentProps),
			actionButton({
				Name = "Exit",
				AnchorPoint = Vector2.new(1, 0),
				Position = function()
					return if showConfiguration() then UDim2.new(1, -12, 0, 12) else UDim2.new(1, 0, 0, 0)
				end,
				Size = function()
					return UDim2.fromOffset(exitWidth(), headerHeight())
				end,
				Text = "X",
				Enabled = canLeave,
				BackgroundColor3 = RED,
				OnActivated = exitParty,
				TextBounds = UDim2.fromScale(0.7, 0.7),
				StrokeThickness = 0.075,
				ZIndex = 67,
			}),
			createBody(componentProps),
		},
	}
end
