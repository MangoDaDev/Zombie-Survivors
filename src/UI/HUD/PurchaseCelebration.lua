local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MonetizationController = require(ReplicatedStorage.Controllers.MonetizationController)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local ResponsiveViewport = require(script.Parent.Parent.ResponsiveViewport)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create

local localPlayer = Players.LocalPlayer
local GOLD_DARK = Color3.fromRGB(102, 57, 8)
local GOLD = Color3.fromRGB(241, 180, 67)
local GOLD_LIGHT = Color3.fromRGB(255, 224, 126)
local PAPER = Color3.fromRGB(255, 252, 238)

return function()
	local responsiveViewport = ResponsiveViewport()
	local panel: CanvasGroup?
	local panelScale: UIScale?
	local productName: TextLabel?
	local benefitType: TextLabel?
	local activeTweens: { Tween } = {}
	local hideThread: thread?
	local generation = 0

	local function cancelActiveAnimation()
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
		if hideThread then
			task.cancel(hideThread)
			hideThread = nil
		end
	end

	local function show(productKey: string)
		local definition = MonetizationConfig.GetProduct(productKey)
		if not definition or not panel or not panelScale or not productName or not benefitType then
			return
		end

		cancelActiveAnimation()
		generation += 1
		local thisGeneration = generation
		local isGamepass = definition.GamepassId ~= nil
		productName.Text = string.upper(definition.DisplayName)
		benefitType.Text = if isGamepass then "PERMANENT UNLOCK" else "PURCHASE APPLIED"
		panel.GroupTransparency = 1
		panel.Position = UDim2.fromScale(0.5, 0.85)
		panel.Visible = true
		panelScale.Scale = 0.78

		local fadeIn = TweenService:Create(
			panel,
			TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.82) }
		)
		local popIn = TweenService:Create(
			panelScale,
			TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		table.insert(activeTweens, fadeIn)
		table.insert(activeTweens, popIn)
		fadeIn:Play()
		popIn:Play()

		-- Take All already celebrates all three cards in-place; avoid stacking the same reward sounds.
		if productKey ~= "TakeAll" then
			Sounds.Play("Reward3", localPlayer.PlayerGui, nil, { PlaybackSpeed = if isGamepass then 1.08 else 1 })
			if isGamepass then
				Sounds.Play("NewRarest", localPlayer.PlayerGui, nil, { Volume = 0.7 })
			end
		end

		hideThread = task.delay(2.15, function()
			hideThread = nil
			if generation ~= thisGeneration or not panel or not panelScale then
				return
			end
			local fadeOut = TweenService:Create(
				panel,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.79) }
			)
			local shrink = TweenService:Create(
				panelScale,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.94 }
			)
			table.insert(activeTweens, fadeOut)
			table.insert(activeTweens, shrink)
			fadeOut.Completed:Once(function(playbackState)
				if generation == thisGeneration and playbackState == Enum.PlaybackState.Completed and panel then
					panel.Visible = false
				end
			end)
			fadeOut:Play()
			shrink:Play()
		end)
	end

	local purchaseConnection = MonetizationController.GetPurchaseAppliedSignal():Connect(show)
	cleanup(function()
		generation += 1
		purchaseConnection:Disconnect()
		cancelActiveAnimation()
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(responsiveViewport)
	layout.PurchaseCelebration = layout.Viewport
	layout.Banner = ResponsiveLayout.Base(UDim2.new(0.6, 100, 0.1, 28), layout.PurchaseCelebration, 4.25)

	return create "Frame" {
		Name = "PurchaseCelebration",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 400,
		create "CanvasGroup" {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.82),
			Size = layout.Banner.Size,
			Visible = false,
			ZIndex = 400,
			action(function(instance)
				panel = instance :: CanvasGroup
			end),
			create "UIAspectRatioConstraint" {
				AspectRatio = 4.25,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UIScale" {
				Scale = 1,
				action(function(instance)
					panelScale = instance :: UIScale
				end),
			},
			create "UICorner" { CornerRadius = UDim.new(0, 7) },
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = GOLD_LIGHT,
				Thickness = 3,
			},
			create "UIGradient" {
				Color = ColorSequence.new(GOLD_LIGHT, Color3.fromRGB(211, 132, 25)),
				Rotation = 90,
			},
			create "ImageLabel" {
				Name = "StudTexture",
				BackgroundTransparency = 1,
				Image = UIStyle.StudTexture,
				ImageColor3 = GOLD_DARK,
				ImageTransparency = 0.84,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(42, 42),
				ZIndex = 401,
			},
			create "Frame" {
				Name = "Status",
				BackgroundColor3 = GOLD_DARK,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.025, 0.13),
				Size = UDim2.fromScale(0.25, 0.74),
				ZIndex = 402,
				create "UICorner" { CornerRadius = UDim.new(0, 4) },
				create "TextLabel" {
					BackgroundTransparency = 1,
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
					Position = UDim2.fromScale(0.08, 0.12),
					Size = UDim2.fromScale(0.84, 0.76),
					Text = "SUCCESS",
					TextColor3 = GOLD_LIGHT,
					TextScaled = true,
					ZIndex = 403,
				},
			},
			create "TextLabel" {
				Name = "ProductName",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Position = UDim2.fromScale(0.3, 0.14),
				Size = UDim2.fromScale(0.67, 0.43),
				Text = "PURCHASE",
				TextColor3 = PAPER,
				TextScaled = true,
				TextStrokeColor3 = GOLD_DARK,
				TextStrokeTransparency = 0.3,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 403,
				action(function(instance)
					productName = instance :: TextLabel
				end),
			},
			create "TextLabel" {
				Name = "BenefitType",
				BackgroundTransparency = 1,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.3, 0.6),
				Size = UDim2.fromScale(0.67, 0.22),
				Text = "PURCHASE APPLIED",
				TextColor3 = GOLD_DARK,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 403,
				action(function(instance)
					benefitType = instance :: TextLabel
				end),
			},
		},
	}
end
