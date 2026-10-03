local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local GOLD = Color3.fromRGB(225, 157, 40)
local PANEL = Color3.fromRGB(3, 18, 30)
local CARD = Color3.fromRGB(10, 41, 57)
local CARD_DARK = Color3.fromRGB(2, 15, 25)
local MUTED = Color3.fromRGB(139, 177, 195)
local HEAVY_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy)
local BOLD_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)

-- These proportions come from the authored 1280x720 composition. Keep the dock's bands and
-- offer contents proportional: fixed vertical pixels collapse the purchase button when the
-- dock's wide aspect ratio is fitted inside a short landscape viewport.
local SPECTATE_POSITION = UDim2.fromScale(12 / 880, 12 / 218)
local SPECTATE_SIZE = UDim2.fromScale(856 / 880, 62 / 218)
local OFFERS_POSITION = UDim2.fromScale(12 / 880, 87 / 218)
local OFFERS_SIZE = UDim2.fromScale(856 / 880, 118 / 218)
local OFFER_GAP = UDim.new(10 / 856, 0)
local OFFER_SIZE = UDim2.fromScale(423 / 856, 1)
local ARTWORK_POSITION = UDim2.fromScale(10 / 423, 10 / 118)
local ARTWORK_SIZE = UDim2.fromScale(96 / 423, 98 / 118)
local DETAILS_POSITION = UDim2.fromScale(116 / 423, 9 / 118)
local DETAILS_SIZE = UDim2.fromScale(297 / 423, 100 / 118)

local function offer(productKey: string, label, detail: string, visible, infoRevision, portrait, teamOffer: boolean, parentLayout)
	local layout = {}
	layout.Viewport = parentLayout
	layout.Frame = ResponsiveLayout.Child(function() return if portrait() then UDim2.new(1, 0, 0.5, -5) else OFFER_SIZE end, layout.Viewport)

	return create "Frame" {
		Name = productKey,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Size = layout.Frame.Size,
		Visible = visible,
		ZIndex = 412,
		create "UICorner" { CornerRadius = UDim.new(0, 4) },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = if teamOffer then Color3.fromRGB(67, 154, 105) else GOLD,
			Thickness = 2,
		},
		create "Frame" {
			Name = "ArtworkPanel",
			BackgroundColor3 = CARD_DARK,
			BorderSizePixel = 0,
			Position = ARTWORK_POSITION,
			Size = ARTWORK_SIZE,
			ZIndex = 413,
			create "ImageLabel" {
				Name = productKey .. "Artwork",
				BackgroundTransparency = 1,
				Image = function()
					infoRevision()
					return MonetizationController.GetImage(productKey)
				end,
				Position = UDim2.fromScale(0.06, 0.06),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.88, 0.88),
				ZIndex = 414,
			},
		},
		create "Frame" {
			Name = "Details",
			BackgroundTransparency = 1,
			Position = DETAILS_POSITION,
			Size = DETAILS_SIZE,
			ZIndex = 414,
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Size = UDim2.fromScale(1, 0.24),
				Text = label,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 414,
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = BOLD_FONT,
				Position = UDim2.fromScale(0, 0.27),
				Size = UDim2.fromScale(1, 0.14),
				Text = detail,
				TextColor3 = MUTED,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 414,
			},
			create "Frame" {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0.4),
				ZIndex = 415,
				Button({
					Text = function()
						infoRevision()
						return UIStyle.RobuxSymbol .. " " .. MonetizationController.GetPriceText(productKey)
					end,
					BackgroundColor3 = if teamOffer then UIStyle.Colors.Green else GOLD,
					CornerRadius = UDim.new(0, 3),
					FontFace = HEAVY_FONT,
					MaxTextSize = 26,
					MinTextSize = 11,
					Size = UDim2.fromScale(1, 1),
					OnActivated = function() MonetizationController.PromptDeveloperProduct(productKey) end,
				}),
			},
		},
	}
end

return function()
	local state = source(RunSessionController.GetState())
	local spectateName = source("NO LIVING TEAMMATE")
	local infoRevision = source(0)
	local countdownRevision = source(0)
	local viewportSize = source(Vector2.new(1280, 720))
	-- User invariant: preserve one composition at every screen size.
	local function portrait() return false end
	local visible = derive(function() return state().dead == true and state().active ~= true end)
	local function refreshSpectate(player)
		spectateName(if player then string.upper(player.DisplayName) else "NO LIVING TEAMMATE")
	end
	refreshSpectate(RunSessionController.GetSpectatePlayer())
	local countdownAccumulator = 0
	local connections = {
		RunSessionController.GetStateChangedSignal():Connect(function(packet) state(packet) end),
		RunSessionController.GetSpectateChangedSignal():Connect(refreshSpectate),
		MonetizationController.GetProductInfoChangedSignal():Connect(function(key)
			if key == "Revive" or key == "ReviveTeam" then infoRevision(infoRevision() + 1) end
		end),
		RunService.Heartbeat:Connect(function(deltaTime)
			if not visible() or not state().teamWipeAt then return end
			countdownAccumulator += deltaTime
			if countdownAccumulator >= 0.2 then
				countdownAccumulator = 0
				countdownRevision(countdownRevision() + 1)
			end
		end),
	}
	cleanup(function() for _, connection in connections do connection:Disconnect() end end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(viewportSize)
	layout.DownedOverlay = layout.Viewport
	layout.StatusBanner = ResponsiveLayout.Base(function() return if portrait() then UDim2.new(0.9, 0, 0, 72) else UDim2.new(0.41, 0, 0, 76) end, layout.DownedOverlay, function() return if portrait() then 4.5 else 6.84 end)
	layout.TextLabel2 = ResponsiveLayout.Child(function() return UDim2.fromScale(0.92, if portrait() then 0.34 else 0.24) end, layout.StatusBanner)
	layout.Dock = ResponsiveLayout.Base(function() return if portrait() then UDim2.fromScale(0.92, 0.46) else UDim2.fromScale(0.86, 0.31) end, layout.DownedOverlay, function() return if portrait() then 1 else 4.04 end)
	layout.Spectate = ResponsiveLayout.Child(SPECTATE_SIZE, layout.Dock)
	layout.TextButton = ResponsiveLayout.Child(UDim2.fromOffset(60, 62), layout.Spectate)
	layout.TextLabel3 = ResponsiveLayout.Child(function() return if portrait() then UDim2.new(1, -156, 0, 18) else UDim2.new(0.3, 0, 0, 18) end, layout.Spectate)
	layout.TextLabel4 = ResponsiveLayout.Child(function() return if portrait() then UDim2.new(1, -156, 0, 28) else UDim2.new(0.36, 0, 0, 28) end, layout.Spectate)
	layout.TextLabel5 = ResponsiveLayout.Child(UDim2.new(0.42, 0, 0, 32), layout.Spectate)
	layout.TextButton2 = ResponsiveLayout.Child(UDim2.fromOffset(60, 62), layout.Spectate)
	layout.TextLabel6 = ResponsiveLayout.Child(UDim2.new(1, -36, 0, 22), layout.Dock)
	layout.Offers = ResponsiveLayout.Child(OFFERS_SIZE, layout.Dock)

	return create "Frame" {
		Name = "DownedOverlay",
		Active = visible,
		BackgroundColor3 = Color3.fromRGB(14, 2, 4),
		BackgroundTransparency = 0.76,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		ZIndex = 400,
		action(function(instance)
			local root = instance :: Frame
			viewportSize(root.AbsoluteSize)
			table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				viewportSize(root.AbsoluteSize)
			end))
		end),
		create "UIGradient" {
			Color = ColorSequence.new(Color3.fromRGB(55, 6, 10), Color3.fromRGB(2, 7, 11)),
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.46),
				NumberSequenceKeypoint.new(0.5, 0.92),
				NumberSequenceKeypoint.new(1, 0.28),
			}),
		},
		create "Frame" {
			Name = "StatusBanner",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(73, 20, 24),
			BorderSizePixel = 0,
			Position = layout.StatusBanner.Position(UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0)),
			Size = layout.StatusBanner.Size,
			ZIndex = 405,
			create "UIAspectRatioConstraint" {
				AspectRatio = function() return if portrait() then 4.5 else 6.84 end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(202, 72, 70), Thickness = 2 },
			StudTexture({ ZIndex = 406, ImageTransparency = 0.88, TileSize = UDim2.fromOffset(72, 72) }),
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Position = UDim2.fromScale(0.04, 0.08),
				Size = UDim2.fromScale(0.92, 0.48),
				Text = "YOU'RE DOWN",
				TextColor3 = Color3.fromRGB(255, 245, 242),
				TextScaled = true,
				ZIndex = 408,
				create "UIStroke" { Color = Color3.fromRGB(25, 4, 6), Thickness = 3 },
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = BOLD_FONT,
				Position = function() return UDim2.fromScale(0.04, if portrait() then 0.58 else 0.62) end,
				Size = layout.TextLabel2.Size,
				Text = function() return if portrait() then "BUY A REVIVE OR WAIT\nFOR A TEAMMATE TO REVIVE YOU" else "BUY A REVIVE OR WAIT FOR A TEAMMATE TO REVIVE YOU" end,
				TextColor3 = Color3.fromRGB(235, 153, 149),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 408,
			},
		},
		create "Frame" {
			Name = "Dock",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = layout.Dock.Position(UDim2.new(0.5, 0, 1, -28), Vector2.new(0.5, 1)),
			Size = layout.Dock.Size,
			ZIndex = 405,
			create "UIAspectRatioConstraint" {
				AspectRatio = function() return if portrait() then 1 else 4.04 end,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(98, 122, 137), Thickness = 2 },
			create "Frame" {
				Name = "Spectate",
				BackgroundColor3 = Color3.fromRGB(4, 29, 45),
				BorderSizePixel = 0,
				Position = SPECTATE_POSITION,
				Size = layout.Spectate.Size,
				ZIndex = 408,
				create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(55, 93, 114), Thickness = 2 },
				create "TextButton" {
					BackgroundColor3 = Color3.fromRGB(14, 57, 78),
					BorderSizePixel = 0,
					FontFace = HEAVY_FONT,
					Size = layout.TextButton.Size,
					Text = "<",
					TextColor3 = Color3.fromRGB(255, 208, 92),
					TextScaled = true,
					ZIndex = 410,
					Activated = function() RunSessionController.CycleSpectate(-1) end,
				},
				create "TextLabel" {
					BackgroundTransparency = 1,
					FontFace = BOLD_FONT,
					Position = layout.Spectate.Scale(UDim2.new(0, 78, 0, 8)),
					Size = layout.TextLabel3.Size,
					Text = "SPECTATING",
					TextColor3 = Color3.fromRGB(131, 159, 174),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 409,
				},
				create "TextLabel" {
					BackgroundTransparency = 1,
					FontFace = HEAVY_FONT,
					Position = layout.Spectate.Scale(UDim2.new(0, 78, 0, 27)),
					Size = layout.TextLabel4.Size,
					Text = spectateName,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 409,
				},
				create "TextLabel" {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = BOLD_FONT,
					Position = layout.Spectate.Scale(UDim2.new(1, -72, 0.5, 0)),
					Size = layout.TextLabel5.Size,
					Text = function()
						countdownRevision()
						local current = state()
						if current.teamWipeAt then
							return string.format("TEAM WIPE IN %d — REVIVE TO SAVE THE RUN", math.max(math.ceil(current.teamWipeAt - Workspace:GetServerTimeNow()), 0))
						end
						return "WAIT FOR A TEAMMATE - HOLD 1.5s TO REVIVE"
					end,
					TextColor3 = function() return if state().teamWipeAt then Color3.fromRGB(255, 121, 112) else Color3.fromRGB(255, 207, 102) end,
					TextScaled = true,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
					Visible = function() return not portrait() end,
					ZIndex = 409,
				},
				create "TextButton" {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Color3.fromRGB(14, 57, 78),
					BorderSizePixel = 0,
					FontFace = HEAVY_FONT,
					Position = UDim2.fromScale(1, 0),
					Size = layout.TextButton2.Size,
					Text = ">",
					TextColor3 = Color3.fromRGB(255, 208, 92),
					TextScaled = true,
					ZIndex = 410,
					Activated = function() RunSessionController.CycleSpectate(1) end,
				},
			},
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = BOLD_FONT,
				Position = layout.Dock.Scale(UDim2.new(0, 18, 0, 80)),
				Size = layout.TextLabel6.Size,
				Text = function()
					countdownRevision()
					local current = state()
					if current.teamWipeAt then
						return string.format("TEAM WIPE IN %d — REVIVE TO SAVE THE RUN", math.max(math.ceil(current.teamWipeAt - Workspace:GetServerTimeNow()), 0))
					end
					return "WAIT FOR A TEAMMATE - HOLD 1.5s TO REVIVE"
				end,
				TextColor3 = function() return if state().teamWipeAt then Color3.fromRGB(255, 121, 112) else Color3.fromRGB(255, 207, 102) end,
				TextScaled = true,
				Visible = portrait,
				ZIndex = 409,
			},
			create "Frame" {
				Name = "Offers",
				BackgroundTransparency = 1,
				Position = OFFERS_POSITION,
				Size = layout.Offers.Size,
				ZIndex = 411,
				create "UIListLayout" {
					FillDirection = function() return if portrait() then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal end,
					Padding = function() return if portrait() then UDim.new(10 / layout.Offers.ReferenceSize().Y, 0) else OFFER_GAP end,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				offer("Revive", "BUY A REVIVE", "RETURN IMMEDIATELY", visible, infoRevision, portrait, false, layout.Offers),
				offer(
					"ReviveTeam",
					function()
						local count = state().eligibleTeamRevives or 0
						return string.format("REVIVE %d TEAMMATE%s", count, if count == 1 then "" else "S")
					end,
					"BRING THE TEAM BACK",
					function() return visible() and (state().eligibleTeamRevives or 0) > 0 end,
					infoRevision,
					portrait,
					true,
					layout.Offers
				),
			},
		},
	}
end
