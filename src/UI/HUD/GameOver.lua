local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Classes.Button)
local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local RETURN_DELAY = 15
local PANEL = Color3.fromRGB(3, 20, 33)
local PANEL_LIGHT = Color3.fromRGB(3, 24, 39)
local RED = Color3.fromRGB(231, 63, 69)
local MUTED = Color3.fromRGB(164, 174, 184)

local function formatDuration(seconds: number): string
	local total = math.max(math.floor(seconds + 0.5), 0)
	return string.format("%02d:%02d", math.floor(total / 60), total % 60)
end

local function statTile(name: string, label: string, value, order: number)
	return create "Frame" {
		Name = name,
		BackgroundColor3 = PANEL_LIGHT,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -6, 0, 72),
		ZIndex = 406,
		create "UICorner" { CornerRadius = UDim.new(0, 6) },
		StudTexture({ ZIndex = 407, ImageTransparency = 0.88 }),
		create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.07, 0.12),
			Size = UDim2.fromScale(0.86, 0.25),
			Text = label,
			TextColor3 = MUTED,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 407,
		},
		create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.07, 0.42),
			Size = UDim2.fromScale(0.86, 0.42),
			Text = value,
			TextColor3 = Color3.fromRGB(239, 243, 247),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 407,
		},
	}
end

return function()
	local initialState = RunSessionController.GetState()
	local state = source(initialState)
	local remaining = source(if initialState.active then math.max(initialState.returnAt - Workspace:GetServerTimeNow(), 0) else 0)
	local failureMessage = source("")
	local replayPending = source(false)
	local visible = derive(function()
		return state().active == true
	end)
	local stats = derive(function()
		return state().stats or {
			survivalTime = 0,
			zombiesKilled = 0,
			levelReached = 1,
			coinsCollected = 0,
			xpCollected = 0,
		}
	end)

	local stateConnection = RunSessionController.GetStateChangedSignal():Connect(function(packet)
		state(packet)
		failureMessage("")
		replayPending(false)
		remaining(if packet.active then math.max(packet.returnAt - Workspace:GetServerTimeNow(), 0) else 0)
	end)
	local failureConnection = RunSessionController.GetReturnFailedSignal():Connect(function(message)
		failureMessage(message)
	end)
	local replayFailureConnection = RunSessionController.GetReplayFailedSignal():Connect(function(message)
		replayPending(false)
		failureMessage(message)
	end)
	local elapsed = 0
	local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not state().active then
			return
		end
		elapsed += deltaTime
		if elapsed >= 0.1 then
			elapsed = 0
			remaining(math.max(state().returnAt - Workspace:GetServerTimeNow(), 0))
		end
	end)
	cleanup(function()
		stateConnection:Disconnect()
		failureConnection:Disconnect()
		replayFailureConnection:Disconnect()
		heartbeatConnection:Disconnect()
	end)

	return create "Frame" {
		Name = "GameOver",
		Active = visible,
		BackgroundColor3 = Color3.fromRGB(5, 7, 10),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		ZIndex = 400,
		create "Frame" {
			Name = "Vignette",
			BackgroundColor3 = Color3.fromRGB(61, 8, 12),
			BackgroundTransparency = 0.48,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 401,
			create "UIGradient" {
				Color = ColorSequence.new(Color3.fromRGB(102, 12, 17), Color3.fromRGB(4, 6, 9)),
				Rotation = 90,
			},
		},
		create "Frame" {
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.88, 0.78),
			ZIndex = 402,
			create "UISizeConstraint" {
				MaxSize = Vector2.new(520, 520),
			},
			create "UICorner" { CornerRadius = UDim.new(0, 10) },
			StudTexture({ ZIndex = 403, ImageTransparency = 0.9, TileSize = UDim2.fromOffset(56, 56) }),
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(113, 30, 35),
				Thickness = 3,
			},
			create "Frame" {
				Name = "Header",
				BackgroundColor3 = Color3.fromRGB(71, 18, 23),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 0.2),
				ZIndex = 403,
				create "UICorner" { CornerRadius = UDim.new(0, 10) },
				StudTexture({ ZIndex = 404, ImageTransparency = 0.78, TileSize = UDim2.fromOffset(68, 68) }),
				create "TextLabel" {
					BackgroundTransparency = 1,
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
					Position = UDim2.fromScale(0.07, 0.13),
					Size = UDim2.fromScale(0.86, 0.48),
					Text = "RUN OVER",
					TextColor3 = Color3.fromRGB(255, 235, 236),
					TextScaled = true,
					ZIndex = 404,
				},
				create "TextLabel" {
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.1, 0.66),
					Size = UDim2.fromScale(0.8, 0.2),
					Text = "THE HORDE CLAIMED YOU",
					TextColor3 = Color3.fromRGB(229, 143, 147),
					TextScaled = true,
					ZIndex = 404,
				},
			},
			create "TextLabel" {
				Name = "SurvivalLabel",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.08, 0.225),
				Size = UDim2.fromScale(0.84, 0.035),
				Text = "SURVIVAL TIME",
				TextColor3 = MUTED,
				TextScaled = true,
				ZIndex = 405,
			},
			create "TextLabel" {
				Name = "SurvivalTime",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.08, 0.263),
				Size = UDim2.fromScale(0.84, 0.105),
				Text = function()
					return formatDuration(stats().survivalTime)
				end,
				TextColor3 = Color3.fromRGB(247, 249, 251),
				TextScaled = true,
				ZIndex = 405,
			},
			create "Frame" {
				Name = "Stats",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.06, 0.39),
				Size = UDim2.fromScale(0.88, 0.31),
				ZIndex = 406,
				create "UIGridLayout" {
					CellPadding = UDim2.fromOffset(12, 12),
					CellSize = UDim2.new(0.5, -6, 0.5, -6),
					FillDirectionMaxCells = 2,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				statTile("Kills", "ZOMBIES DEFEATED", function()
					return FormatNumber(stats().zombiesKilled) or "0"
				end, 1),
				statTile("Level", "LEVEL REACHED", function()
					return tostring(stats().levelReached)
				end, 2),
				statTile("Coins", "COINS COLLECTED", function()
					return FormatNumber(stats().coinsCollected) or "0"
				end, 3),
				statTile("XP", "XP COLLECTED", function()
					return FormatNumber(stats().xpCollected) or "0"
				end, 4),
			},
			create "TextLabel" {
				Name = "ReturnStatus",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.08, 0.75),
				Size = UDim2.fromScale(0.84, 0.055),
				Text = function()
					if failureMessage() ~= "" then
						return failureMessage()
					end
					if replayPending() then
						return "RESTARTING RUN..."
					end
					return string.format("RETURNING TO LOBBY IN %d", math.ceil(remaining()))
				end,
				TextColor3 = function()
					return if failureMessage() == "" then Color3.fromRGB(230, 235, 240) else RED
				end,
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 405,
			},
			create "Frame" {
				Name = "CountdownTrack",
				BackgroundColor3 = Color3.fromRGB(39, 43, 49),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.08, 0.825),
				Size = UDim2.fromScale(0.84, 0.035),
				ZIndex = 405,
				create "UICorner" { CornerRadius = UDim.new(1, 0) },
				create "Frame" {
					Name = "Fill",
					BackgroundColor3 = RED,
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(math.clamp(remaining() / RETURN_DELAY, 0, 1), 1)
					end,
					ZIndex = 406,
					create "UICorner" { CornerRadius = UDim.new(1, 0) },
				},
			},
			create "TextLabel" {
				Name = "TeammateStatus",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.08, 0.705),
				Size = UDim2.fromScale(0.84, 0.03),
				Text = "YOUR TEAMMATES CAN KEEP FIGHTING",
				TextColor3 = Color3.fromRGB(126, 137, 147),
				TextScaled = true,
				ZIndex = 405,
			},
			create "Frame" {
				Name = "ReplayAction",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.08, 0.885),
				Size = UDim2.fromScale(0.84, 0.085),
				ZIndex = 405,
				Button({
					Text = function()
						return if replayPending() then "RESTARTING..." else "PLAY AGAIN"
					end,
					Enabled = function()
						return visible() and not replayPending()
					end,
					BackgroundColor3 = UIStyle.Colors.Green,
					CornerRadius = UIStyle.CornerRadius,
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
					MaxTextSize = 22,
					MinTextSize = 13,
					Size = UDim2.fromScale(1, 1),
					OnActivated = function()
						if replayPending() or not visible() then
							return
						end
						failureMessage("")
						replayPending(true)
						RunSessionController.RequestReplay()
					end,
				}),
			},
		},
	}
end
