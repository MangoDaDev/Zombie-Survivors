local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Classes.Button)
local RageController = require(ReplicatedStorage.Controllers.RageController)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local function textStroke()
	return create "UIStroke" {
		Color = UIStyle.Colors.Ink,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = 0.055,
	}
end

return function()
	local initialState = RageController.GetState()
	local state = source(initialState)
	local displayRage = source(initialState.rage)
	local progressTarget = source(displayRage() / RageConfig.Maximum)
	local remaining = source(RageController.GetRemainingDuration())
	local smoothProgress = spring(progressTarget, 0.2, 0.88)
	local flash: Frame?
	local glow: ImageLabel?
	local barScale: UIScale?
	local progressRenderConnection: RBXScriptConnection?
	local readyTween: Tween?
	local connections = {}

	local ready = derive(function()
		return not state().active and displayRage() >= RageConfig.Maximum
	end)

	local function stopActiveRender()
		if progressRenderConnection then
			progressRenderConnection:Disconnect()
			progressRenderConnection = nil
		end
	end

	local function updateReadyPulse()
		if readyTween then
			readyTween:Cancel()
			readyTween = nil
		end
		if glow then
			local chargeAlpha = math.clamp(displayRage() / RageConfig.Maximum, 0, 1)
			-- The aura steadily strengthens with charge, then becomes an unmistakable pulse at full Rage.
			glow.ImageTransparency = if ready()
				then 0.42
				elseif state().active then 0.5
				else 0.88 - chargeAlpha * 0.36
			if ready() then
				readyTween = TweenService:Create(
					glow,
					TweenInfo.new(0.62, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ ImageTransparency = 0.68 }
				)
				readyTween:Play()
			end
		end
	end

	local function applyState(newState)
		state(newState)
		displayRage(newState.rage)
		stopActiveRender()
		progressRenderConnection = RunService.RenderStepped:Connect(function()
			if newState.active then
				local durationRemaining = RageController.GetRemainingDuration()
				remaining(durationRemaining)
				progressTarget(math.clamp(durationRemaining / RageConfig.Duration, 0, 1))
			else
				local wasReady = displayRage() >= RageConfig.Maximum
				local currentRage = RageController.GetCurrentRage()
				displayRage(currentRage)
				remaining(0)
				progressTarget(currentRage / RageConfig.Maximum)
				if not wasReady and currentRage >= RageConfig.Maximum then
					updateReadyPulse()
				elseif not ready() and glow then
					glow.ImageTransparency = 0.88 - math.clamp(currentRage / RageConfig.Maximum, 0, 1) * 0.36
				end
			end
		end)
		updateReadyPulse()
	end

	table.insert(connections, RageController.GetStateChangedSignal():Connect(applyState))
	table.insert(connections, RageController.GetActivatedSignal():Connect(function()
		if flash then
			flash.BackgroundTransparency = 0.76
			TweenService:Create(
				flash,
				TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end
		if barScale then
			barScale.Scale = 1.13
			TweenService:Create(
				barScale,
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end))
	table.insert(connections, RageController.GetEndedSignal():Connect(function()
		if barScale then
			barScale.Scale = 0.97
			TweenService:Create(barScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end
	end))
	applyState(initialState)
	cleanup(function()
		stopActiveRender()
		if readyTween then
			readyTween:Cancel()
		end
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	return create "Frame" {
		Name = "RageBar",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 75,
		create "Frame" {
			Name = "ActivationFlash",
			BackgroundColor3 = Color3.fromRGB(255, 92, 36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 74,
			action(function(instance)
				flash = instance :: Frame
			end),
		},
		create "Frame" {
			Name = "Content",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -106),
			-- Keep Rage readable without competing with the primary bottom controls.
			Size = UDim2.new(0.42, 140, 0.024, 8),
			ZIndex = 76,
			create "UIScale" {
				Scale = 1,
				action(function(instance)
					barScale = instance :: UIScale
				end),
			},
			create "Frame" {
				Name = "BarBacking",
				BackgroundColor3 = Color3.fromRGB(65, 31, 28),
				BorderSizePixel = 0,
				Size = UDim2.new(0.78, -8, 1, 0),
				ZIndex = 77,
				create "UICorner" { CornerRadius = UIStyle.CornerRadius },
				create "UIStroke" {
					Color = Color3.fromRGB(36, 22, 22),
					Thickness = UIStyle.OutlineThickness,
				},
				create "ImageLabel" {
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = UIStyle.GlowTexture,
					ImageColor3 = function()
						return if state().active then Color3.fromRGB(255, 72, 34) else Color3.fromRGB(255, 176, 58)
					end,
					ImageTransparency = 0.78,
					Position = UDim2.fromScale(0.5, 0.48),
					Size = UDim2.fromScale(1.15, 2.05),
					ZIndex = 76,
					action(function(instance)
						glow = instance :: ImageLabel
						task.defer(updateReadyPulse)
					end),
				},
				create "Frame" {
					Name = "Track",
					BackgroundColor3 = Color3.fromRGB(33, 35, 42),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.015, 0.12),
					Size = UDim2.fromScale(0.97, 0.68),
					ZIndex = 78,
					create "UICorner" { CornerRadius = UIStyle.SmallCornerRadius },
					create "Frame" {
						Name = "Fill",
						BackgroundColor3 = Color3.fromRGB(244, 86, 44),
						BorderSizePixel = 0,
						Size = function()
							return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
						end,
						ZIndex = 79,
						create "UICorner" { CornerRadius = UIStyle.SmallCornerRadius },
						create "UIGradient" {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(218, 55, 42)),
								ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 115, 42)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 221, 78)),
							}),
						},
						create "ImageLabel" {
							BackgroundTransparency = 1,
							Image = UIStyle.StudTexture,
							ImageTransparency = 0.8,
							ScaleType = Enum.ScaleType.Tile,
							Size = UDim2.fromScale(1, 1),
							TileSize = UDim2.fromOffset(46, 46),
							ZIndex = 80,
						},
					},
				},
				create "TextLabel" {
					Name = "Status",
					BackgroundTransparency = 1,
					FontFace = UIStyle.Font,
					Position = UDim2.fromScale(0.03, 0.03),
					Size = UDim2.fromScale(0.94, 0.82),
					Text = function()
						if state().active then
							return string.format("RAGE MODE  %.1fs", remaining())
						elseif ready() then
							return "RAGE READY  -  PRESS R"
						end
						return string.format("RAGE  %d%%", math.floor(displayRage() + 0.5))
					end,
					TextColor3 = UIStyle.Colors.Paper,
					TextScaled = true,
					ZIndex = 82,
					textStroke(),
				},
			},
			create "Frame" {
				Name = "ActivateButton",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.22, -4, 1, 0),
				ZIndex = 77,
				Button({
					Text = function()
						return if state().active then "ACTIVE" elseif ready() then "RAGE [R]" else "CHARGING"
					end,
					Enabled = ready,
					BackgroundColor3 = function()
						return if ready() then Color3.fromRGB(238, 78, 42) else Color3.fromRGB(116, 66, 54)
					end,
					Size = UDim2.fromScale(1, 1),
					OnActivated = RageController.Activate,
				}),
			},
		},
	}
end
