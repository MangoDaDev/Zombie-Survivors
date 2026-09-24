local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RunRewardsController = require(ReplicatedStorage.Controllers.RunRewardsController)
local BackpackConfig = require(ReplicatedStorage.Modules.Game.BackpackConfig)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Button = require(script.Parent.Parent.Classes.Button)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local MINIMUM_FLOW_COINS = 8
local MAXIMUM_FLOW_COINS = 28
local COIN_STAGGER = 0.045

local localPlayer = Players.LocalPlayer
local random = Random.new()

local function getCenter(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize * 0.5
end

local function getBackpackOpeningOnScreen(): Vector2?
	local character = localPlayer.Character
	local backpack = character and character:FindFirstChild(BackpackConfig.ModelName)
	local opening = backpack and backpack:FindFirstChild(BackpackConfig.TargetPartName)
	local camera = Workspace.CurrentCamera
	if not opening or not opening:IsA("BasePart") or not camera then
		return nil
	end

	local worldPosition = opening.CFrame:PointToWorldSpace(Vector3.new(0, opening.Size.Y * 0.5, 0))
	local screenPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
	return if onScreen then Vector2.new(screenPosition.X, screenPosition.Y) else nil
end

return function()
	local pendingCoins = source(RunRewardsController.GetPendingCoins())
	local root: Frame?
	local flowLayer: Frame?
	local claimPrompt: Frame?
	local animationToken = 0
	local particles: { [GuiObject]: boolean } = {}
	local pulseScale: UIScale?

	local function trackParticle(particle: GuiObject)
		particles[particle] = true
		particle.Destroying:Once(function()
			particles[particle] = nil
		end)
	end

	local function clearAnimation()
		animationToken += 1
		local activeParticles = table.clone(particles)
		table.clear(particles)
		for particle in activeParticles do
			particle:Destroy()
		end
		if pulseScale then
			pulseScale:Destroy()
			pulseScale = nil
		end
	end

	local function pulseBalance(strength: number)
		local scale = pulseScale
		if not scale or scale.Parent == nil then
			return
		end

		scale.Scale = math.max(scale.Scale, strength)
		TweenService:Create(
			scale,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	local function burstAtTarget(layer: Frame, target: Vector2, token: number)
		for index = 1, 10 do
			local angle = math.pi * 2 * index / 10
			local sparkle = Instance.new("ImageLabel")
			sparkle.Name = "ClaimSparkle"
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.BackgroundTransparency = 1
			sparkle.Image = Images.Sparkle
			sparkle.ImageColor3 = if index % 2 == 0
				then Color3.fromRGB(255, 225, 76)
				else Color3.fromRGB(255, 255, 255)
			sparkle.Position = UDim2.fromOffset(target.X, target.Y)
			sparkle.Rotation = random:NextNumber(-35, 35)
			sparkle.Size = UDim2.fromOffset(20, 20)
			sparkle.ZIndex = 512
			sparkle.Parent = layer
			trackParticle(sparkle)

			local distance = random:NextNumber(42, 76)
			local destination = target + Vector2.new(math.cos(angle), math.sin(angle)) * distance
			local tween = TweenService:Create(
				sparkle,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					ImageTransparency = 1,
					Position = UDim2.fromOffset(destination.X, destination.Y),
					Rotation = sparkle.Rotation + 150,
					Size = UDim2.fromOffset(5, 5),
				}
			)
			tween.Completed:Once(function()
				if animationToken == token and sparkle.Parent then
					sparkle:Destroy()
				end
			end)
			tween:Play()
		end
	end

	local function beginCoinFlow(amount: number, token: number)
		local componentRoot = root
		local layer = flowLayer
		local prompt = claimPrompt
		local screenGui = componentRoot and componentRoot.Parent
		local coinsDisplay = screenGui and screenGui:FindFirstChild("CoinsDisplay")
		if animationToken ~= token
			or not layer
			or not prompt
			or not coinsDisplay
			or not coinsDisplay:IsA("GuiObject")
		then
			return
		end

		-- Prefer the authored GatheredNeck opening; the hidden prompt is only a fallback if the bag is off-screen.
		local start = getBackpackOpeningOnScreen() or getCenter(prompt)
		local visualCoinCount = math.clamp(
			math.ceil(math.sqrt(amount) * 2.5),
			MINIMUM_FLOW_COINS,
			MAXIMUM_FLOW_COINS
		)
		pulseScale = Instance.new("UIScale")
		pulseScale.Name = "ClaimPulseScale"
		pulseScale.Parent = coinsDisplay
		Sounds.Play("Reward1", localPlayer.PlayerGui)

		for index = 1, visualCoinCount do
			task.delay((index - 1) * COIN_STAGGER, function()
				if animationToken ~= token or layer.Parent == nil then
					return
				end

				local size = random:NextInteger(30, 43)
				local coin = Instance.new("ImageLabel")
				coin.Name = "ClaimCoin"
				coin.AnchorPoint = Vector2.new(0.5, 0.5)
				coin.BackgroundTransparency = 1
				coin.Image = Images.Coin
				coin.Position = UDim2.fromOffset(start.X, start.Y)
				coin.Rotation = random:NextNumber(-25, 25)
				coin.Size = UDim2.fromOffset(size, size)
				coin.ZIndex = 510
				coin.Parent = layer
				trackParticle(coin)

				local burstPosition = start
					+ Vector2.new(random:NextNumber(-94, 94), random:NextNumber(-122, -50))
				local burstTween = TweenService:Create(
					coin,
					TweenInfo.new(0.21, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{
						Position = UDim2.fromOffset(burstPosition.X, burstPosition.Y),
						Rotation = coin.Rotation + random:NextNumber(90, 190),
						Size = UDim2.fromOffset(size * 1.18, size * 1.18),
					}
				)
				burstTween.Completed:Once(function()
					if animationToken ~= token or coin.Parent == nil then
						return
					end

					local target = getCenter(coinsDisplay)
					local collectTween = TweenService:Create(
						coin,
						TweenInfo.new(random:NextNumber(0.38, 0.52), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{
							Position = UDim2.fromOffset(target.X, target.Y),
							Rotation = coin.Rotation + random:NextNumber(240, 420),
							Size = UDim2.fromOffset(12, 12),
						}
					)
					collectTween.Completed:Once(function()
						if animationToken ~= token then
							return
						end
						if coin.Parent then
							coin:Destroy()
						end
						if index % 4 == 0 or index == visualCoinCount then
							Sounds.Play("CoinCollect", localPlayer.PlayerGui)
							pulseBalance(if index == visualCoinCount then 1.18 else 1.08)
						end
						if index == visualCoinCount then
							burstAtTarget(layer, target, token)
							Sounds.Play("Kaching", localPlayer.PlayerGui)
							task.delay(0.55, function()
								if animationToken == token and pulseScale then
									pulseScale:Destroy()
									pulseScale = nil
								end
							end)
						end
					end)
					collectTween:Play()
				end)
				burstTween:Play()
			end)
		end
	end

	local function playClaimAnimation(amount: number)
		clearAnimation()
		local token = animationToken
		-- Let the camera settle after the authoritative return-to-base teleport before projecting the bag.
		task.delay(0.12, function()
			beginCoinFlow(amount, token)
		end)
	end

	local pendingConnection = RunRewardsController.GetPendingCoinsChangedSignal():Connect(function(value)
		pendingCoins(value)
	end)
	local claimedConnection = RunRewardsController.GetRewardsClaimedSignal():Connect(playClaimAnimation)

	cleanup(function()
		pendingConnection:Disconnect()
		claimedConnection:Disconnect()
		clearAnimation()
	end)

	return create "Frame" {
		Name = "RunRewardsDisplay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
		action(function(instance)
			root = instance :: Frame
		end),
		create "Frame" {
			Name = "CoinFlowLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 500,
			action(function(instance)
				flowLayer = instance :: Frame
			end),
		},
		create "Frame" {
			Name = "ClaimPrompt",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -24, 1, -30),
			Size = UDim2.new(0.12, 120, 0.05, 24),
			Visible = function()
				-- No pending run coins means no claim HUD at all.
				return pendingCoins() > 0
			end,
			ZIndex = 520,
			action(function(instance)
				claimPrompt = instance :: Frame
			end),
			create "ImageLabel" {
				Name = "Coin",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Coin,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(0.17, 0.78),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 521,
				create "UIAspectRatioConstraint" { AspectRatio = 1 },
			},
			create "TextLabel" {
				Name = "Amount",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.18, 0.5),
				Size = UDim2.fromScale(0.36, 0.66),
				Text = function()
					return "+" .. (FormatNumber(pendingCoins()) or "0")
				end,
				TextColor3 = Color3.fromRGB(255, 221, 79),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 521,
				create "UIStroke" {
					Color = Color3.fromRGB(62, 43, 17),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.065,
				},
			},
			create "Frame" {
				Name = "ClaimButton",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromScale(0.42, 0.72),
				ZIndex = 521,
				Button({
					Text = "CLAIM",
					BackgroundColor3 = UIStyle.Colors.Green,
					Size = UDim2.fromScale(1, 1),
					OnActivated = RunRewardsController.ReturnToBaseAndClaim,
				}),
			},
		},
	}
end
