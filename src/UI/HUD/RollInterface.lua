local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Classes.Button)
local AbilityController = require(ReplicatedStorage.Controllers.AbilityController)
local RollController = require(ReplicatedStorage.Controllers.RollController)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
	.GetRandomFromWeightedTable
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local localPlayer = Players.LocalPlayer
local visualRandom = Random.new()

local ENTRY_HEIGHT_SCALE = 0.29
local ENTRY_STRIDE_SCALE = 0.34
local ENTRY_COUNT = 31
local RESULT_INDEX = 27
local FULL_TINT_TRANSPARENCY = 0.34

local function createText(parent: Instance, name: string, text: string, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = UIStyle.Font
	label.Text = text
	label.TextColor3 = UIStyle.Colors.Paper
	label.TextScaled = true
	label.ZIndex = zIndex
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIStyle.Colors.Ink
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.065
	stroke.Transparency = 0.04
	stroke.Parent = label
	return label
end

local function formatOdds(baseOdds: number): string
	return string.format("1 / %d", baseOdds)
end

local function createEntry(parent: Instance, item, index: number, isResult: boolean): (Frame, UIScale)
	local entry = Instance.new("Frame")
	entry.Name = if isResult then "ServerResult" else "PassingItem"
	entry.AnchorPoint = Vector2.new(0.5, 0)
	entry.BackgroundTransparency = 1
	entry.BorderSizePixel = 0
	entry.Position = UDim2.fromScale(0.5, (index - 1) * ENTRY_STRIDE_SCALE)
	entry.Size = UDim2.fromScale(0.94, ENTRY_HEIGHT_SCALE)
	entry.ZIndex = 125
	entry.Parent = parent

	local resultScale = Instance.new("UIScale")
	resultScale.Name = "ResultScale"
	resultScale.Scale = if isResult then 1.12 else 1
	resultScale.Parent = entry

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = item.Image
	icon.ImageTransparency = if isResult then 0 else 0.08
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.78, 0.92)
	icon.ZIndex = 126
	icon.Parent = entry
	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = icon

	local nameLabel = createText(entry, "ItemName", item.Name, 127)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.015)
	nameLabel.Size = UDim2.fromScale(0.9, 0.24)
	nameLabel.TextColor3 = item.Color
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center

	local oddsLabel = createText(entry, "Odds", formatOdds(item.BaseOdds), 127)
	oddsLabel.AnchorPoint = Vector2.new(0.5, 1)
	oddsLabel.Position = UDim2.fromScale(0.5, 0.985)
	oddsLabel.Size = UDim2.fromScale(0.72, 0.2)
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Center
	return entry, resultScale
end

local function createReel(parent: Frame, packet, resultItem)
	local reel = Instance.new("Frame")
	reel.Name = string.format("Reel%d", packet.reelIndex)
	reel.BackgroundTransparency = 1
	reel.BorderSizePixel = 0
	reel.LayoutOrder = packet.reelIndex
	reel.Size = UDim2.fromScale(1, 1)
	reel.ZIndex = 118
	reel.Parent = parent

	local reelScale = Instance.new("UIScale")
	reelScale.Name = "ReelScale"
	reelScale.Parent = reel

	local isAbilityResult = resultItem.AbilityId ~= nil
	local hasHeader = isAbilityResult or packet.multiplier > 1
	local multiplierText = if isAbilityResult
		then "NEW ABILITY"
		elseif packet.multiplier == 1 then "ORIGINAL"
		else string.format("x%d", packet.multiplier)
	local multiplier = createText(reel, "Multiplier", multiplierText, 123)
	multiplier.AnchorPoint = Vector2.new(0.5, 0)
	multiplier.Position = UDim2.fromScale(0.5, 0)
	multiplier.Size = UDim2.fromScale(0.82, 0.075)
	multiplier.TextColor3 = if isAbilityResult
		then resultItem.Color
		elseif packet.multiplier == 1 then UIStyle.Colors.Paper
		else UIStyle.Colors.Gold
	multiplier.Visible = hasHeader

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Position = UDim2.fromScale(0, if hasHeader then 0.075 else 0)
	window.Size = UDim2.fromScale(1, if hasHeader then 0.925 else 1)
	window.ZIndex = 120
	window.Parent = reel

	local centerY = 0.5
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromScale(0, centerY - ENTRY_HEIGHT_SCALE / 2)
	track.Size = UDim2.fromScale(1, 1)
	track.ZIndex = 124
	track.Parent = window

	local resultScale
	for index = 1, ENTRY_COUNT do
		-- Trailing decoys remain after the authoritative result so the stopped reel still shows what follows it.
		local item = if index == RESULT_INDEX
			then resultItem
			else GetRandomFromWeightedTable(RollDefinitions.Items, "Weight", visualRandom, 1)
		local _, entryScale = createEntry(track, item, index, index == RESULT_INDEX)
		if index == RESULT_INDEX then
			resultScale = entryScale
		end
	end

	return {
		frame = reel,
		reelScale = reelScale,
		track = track,
		resultItem = resultItem,
		resultScale = resultScale,
		centerY = centerY,
	}
end

return function()
	local active = source(false)
	local autoEnabled = source(RollController.IsAutoRollEnabled())
	local minimized = false
	local currentRollId = 0
	local reels = {}
	local connections = {}
	local reelTweens = {}
	local root: Frame?
	local tint: Frame?
	local chain: Frame?
	local chainLayout: UIListLayout?
	local expandedControls: Frame?
	local minimizedControls: Frame?
	local bonusIndicator: Frame?
	local bonusScale: UIScale?
	local bonusIcon: ImageLabel?
	local bonusText: TextLabel?

	local function setHudVisible(visible: boolean)
		local screenGui = root and root.Parent
		if not screenGui then
			return
		end
		for _, childName in { "CoinsDisplay", "Notifications", "RageBar" } do
			local child = screenGui:FindFirstChild(childName)
			if child and child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end

	local function layoutChain()
		if not chain or not chainLayout or not root then
			return
		end
		local count = math.max(#reels, 1)
		local gapScale = if minimized then 0.014 else 0.018
		local chainWidth
		if minimized then
			chainWidth = math.min(0.76, 0.22 * count + gapScale * (count - 1))
			chain.Position = UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(6))
			chain.Size = UDim2.fromScale(chainWidth, 0.28)
		else
			chainWidth = math.min(0.94, 0.38 * count + gapScale * (count - 1))
			chain.Position = UDim2.fromScale(0.5, 0.08)
			chain.Size = UDim2.fromScale(chainWidth, 0.8)
		end
		chainLayout.Padding = UDim.new(gapScale, 0)
		local reelWidth = math.max((1 - gapScale * (count - 1)) / count, 0.08)
		for _, reelState in reels do
			reelState.frame.Size = UDim2.fromScale(reelWidth, 1)
		end

		if minimizedControls then
			minimizedControls.Position = UDim2.new(0.5, 0, 0.3, SafeArea.GetTopOffset(8))
		end
	end

	local function applyMode()
		if not root or not tint or not expandedControls or not minimizedControls then
			return
		end
		local isActive = active()
		expandedControls.Visible = isActive and not minimized
		minimizedControls.Visible = isActive and minimized
		setHudVisible(not isActive or minimized)

		if isActive and not minimized then
			tint.Visible = true
			TweenService:Create(
				tint,
				TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ BackgroundTransparency = FULL_TINT_TRANSPARENCY }
			):Play()
		else
			tint.BackgroundTransparency = 1
			tint.Visible = false
		end
		layoutChain()
	end

	local function clearReels()
		for _, tween in reelTweens do
			tween:Cancel()
		end
		table.clear(reelTweens)
		for _, reelState in reels do
			if reelState.tickConnection then
				reelState.tickConnection:Disconnect()
			end
			reelState.frame:Destroy()
		end
		table.clear(reels)
		layoutChain()
	end

	local function finishReel(reelState)
		if not reelState.frame.Parent then
			return
		end
		Sounds.Play(
			if reelState.resultItem.RarityRank >= 6 then "NewRarest" else "ItemRevealComplete",
			localPlayer.PlayerGui
		)
		local punchOut = TweenService:Create(
			reelState.resultScale,
			TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if reelState.resultItem.RarityRank >= 5 then 1.28 else 1.2 }
		)
		local settle = TweenService:Create(
			reelState.resultScale,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.12 }
		)
		punchOut:Play()
		punchOut.Completed:Once(function()
			if reelState.frame.Parent then
				settle:Play()
			end
		end)
	end

	local function animateReel(packet)
		if not chain then
			return
		end
		local resultItem = RollDefinitions.ById[packet.itemId]
		if not resultItem then
			return
		end

		for _, oldReel in reels do
			oldReel.reelScale.Scale = 0.92
			oldReel.resultScale.Scale = 1
		end

		local reelState = createReel(chain, packet, resultItem)
		table.insert(reels, reelState)
		layoutChain()
		Sounds.Play("Rolling", localPlayer.PlayerGui)

		local lastCrossed = 1
		reelState.tickConnection = reelState.track:GetPropertyChangedSignal("Position"):Connect(function()
			local crossed = math.clamp(
				math.floor(
					(reelState.centerY - ENTRY_HEIGHT_SCALE / 2 - reelState.track.Position.Y.Scale)
						/ ENTRY_STRIDE_SCALE
				) + 1,
				1,
				ENTRY_COUNT
			)
			if crossed > lastCrossed then
				lastCrossed = crossed
				Sounds.Play("ItemRevealTick", localPlayer.PlayerGui)
			end
		end)

		local targetY = reelState.centerY
			- ENTRY_HEIGHT_SCALE / 2
			- (RESULT_INDEX - 1) * ENTRY_STRIDE_SCALE
		local tween = TweenService:Create(
			reelState.track,
			TweenInfo.new(RollDefinitions.Timing.ReelDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0, targetY) }
		)
		table.insert(reelTweens, tween)
		tween.Completed:Once(function(playbackState)
			if reelState.tickConnection then
				reelState.tickConnection:Disconnect()
				reelState.tickConnection = nil
			end
			if playbackState == Enum.PlaybackState.Completed then
				finishReel(reelState)
			end
		end)
		tween:Play()
	end

	local function spawnBonusParticles()
		if not bonusIndicator then
			return
		end
		for index = 1, 9 do
			local angle = math.pi * 2 * index / 9
			local particle = Instance.new("ImageLabel")
			particle.Name = "CloverParticle"
			particle.AnchorPoint = Vector2.new(0.5, 0.5)
			particle.BackgroundTransparency = 1
			particle.Image = Images.Luck
			particle.ImageColor3 = Color3.fromRGB(103, 255, 132)
			particle.Position = UDim2.fromScale(0.5, 0.55)
			particle.Size = UDim2.fromOffset(if minimized then 18 else 30, if minimized then 18 else 30)
			particle.ZIndex = 164
			particle.Parent = bonusIndicator
			local distance = if minimized then 58 else 110
			local target = UDim2.new(0.5, math.cos(angle) * distance, 0.55, math.sin(angle) * distance)
			local particleTween = TweenService:Create(
				particle,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = target, ImageTransparency = 1, Rotation = 120 }
			)
			particleTween.Completed:Once(function()
				particle:Destroy()
			end)
			particleTween:Play()
		end
	end

	local function showBonus(packet)
		if not bonusIndicator or not bonusScale or not bonusIcon or not bonusText then
			return
		end
		bonusIndicator.Visible = true
		bonusIndicator.Position = if minimized
			then UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(18))
			else UDim2.fromScale(0.5, 0.08)
		bonusIndicator.Size = if minimized then UDim2.fromScale(0.3, 0.1) else UDim2.fromScale(0.42, 0.18)
		bonusIcon.ImageTransparency = 0
		bonusText.TextTransparency = 0
		bonusText.Text = string.format("BONUS!  x%d", packet.multiplier)
		bonusScale.Scale = 0.05
		Sounds.Play("SlotsJackpot", localPlayer.PlayerGui)
		spawnBonusParticles()

		if tint and not minimized then
			TweenService:Create(
				tint,
				TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
				{ BackgroundTransparency = 0.1 }
			):Play()
		end

		local pop = TweenService:Create(
			bonusScale,
			TweenInfo.new(0.23, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if minimized then 0.78 else 1.18 }
		)
		local settle = TweenService:Create(
			bonusScale,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = if minimized then 0.66 else 1 }
		)
		pop:Play()
		pop.Completed:Once(function()
			settle:Play()
		end)
		task.delay(RollDefinitions.Timing.BonusActivationDuration * 0.76, function()
			if not bonusIndicator or not bonusIndicator.Parent then
				return
			end
			TweenService:Create(bonusIcon, TweenInfo.new(0.12), { ImageTransparency = 1 }):Play()
			local fadeText = TweenService:Create(bonusText, TweenInfo.new(0.12), { TextTransparency = 1 })
			fadeText.Completed:Once(function()
				if bonusIndicator then
					bonusIndicator.Visible = false
				end
			end)
			fadeText:Play()
		end)
	end

	local function setMinimized(value: boolean)
		if not active() or minimized == value then
			return
		end
		minimized = value
		applyMode()
	end

	local rollStartedConnection = RollController.GetRollStartedSignal():Connect(function(packet)
		if packet.rollId ~= currentRollId then
			local wasActive = active()
			currentRollId = packet.rollId
			clearReels()
			if not wasActive then
				minimized = false
			end
		end
		active(true)
		applyMode()
		animateReel(packet)
	end)
	table.insert(connections, rollStartedConnection)
	table.insert(connections, RollController.GetBonusActivatedSignal():Connect(showBonus))
	table.insert(connections, RollController.GetRollFinishedSignal():Connect(function(rollId, willAutoRoll)
		if rollId ~= currentRollId or willAutoRoll then
			return
		end
		active(false)
		minimized = false
		applyMode()
	end))
	table.insert(connections, RollController.GetAutoRollChangedSignal():Connect(function(enabled)
		autoEnabled(enabled)
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(layoutChain))

	cleanup(function()
		setHudVisible(true)
		clearReels()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	local function toggleAuto()
		RollController.SetAutoRoll(not autoEnabled())
	end

	return create "Frame" {
		Name = "RollInterface",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		action(function(instance)
			root = instance :: Frame
			applyMode()
		end),
		create "Frame" {
			Name = "Tint",
			Active = true,
			BackgroundColor3 = Color3.fromRGB(9, 13, 25),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 100,
			action(function(instance)
				tint = instance :: Frame
			end),
		},
		create "Frame" {
			Name = "IdleControls",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(0.5, 220, 0.065, 24),
			Visible = function()
				return not active()
			end,
			ZIndex = 105,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.055, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
			Button({
				Text = "ROLL",
				BackgroundColor3 = UIStyle.Colors.Blue,
				LayoutOrder = 1,
				OnActivated = RollController.RequestRoll,
			}),
			Button({
				Text = function()
					return if autoEnabled() then "AUTO: ON" else "AUTO: OFF"
				end,
				BackgroundColor3 = function()
					return if autoEnabled() then UIStyle.Colors.Green else UIStyle.Colors.Red
				end,
				LayoutOrder = 2,
				OnActivated = toggleAuto,
			}),
			Button({
				Text = "ABILITIES",
				BackgroundColor3 = UIStyle.Colors.Gold,
				LayoutOrder = 3,
				OnActivated = function()
					AbilityController.SetInventoryOpen(true)
				end,
			}),
		},
		create "Frame" {
			Name = "ReelChain",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.38, 0.8),
			Visible = active,
			ZIndex = 115,
			action(function(instance)
				chain = instance :: Frame
				layoutChain()
			end),
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.018, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				action(function(instance)
					chainLayout = instance :: UIListLayout
					layoutChain()
				end),
			},
		},
		create "Frame" {
			Name = "BonusIndicator",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.42, 0.18),
			Visible = false,
			ZIndex = 160,
			action(function(instance)
				bonusIndicator = instance :: Frame
			end),
			create "UIScale" {
				Scale = 1,
				action(function(instance)
					bonusScale = instance :: UIScale
				end),
			},
			create "ImageLabel" {
				Name = "Clover",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Luck,
				ImageColor3 = Color3.fromRGB(103, 255, 132),
				Position = UDim2.fromScale(0.02, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.3, 0.82),
				ZIndex = 162,
				action(function(instance)
					bonusIcon = instance :: ImageLabel
				end),
			},
			create "TextLabel" {
				Name = "Multiplier",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.3, 0.1),
				Size = UDim2.fromScale(0.68, 0.8),
				Text = "BONUS!  x2",
				TextColor3 = Color3.fromRGB(121, 255, 142),
				TextScaled = true,
				ZIndex = 162,
				action(function(instance)
					bonusText = instance :: TextLabel
				end),
				create "UIStroke" {
					Color = Color3.fromRGB(25, 84, 39),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				},
			},
		},
		create "Frame" {
			Name = "ExpandedControls",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(0.46, 200, 0.058, 20),
			Visible = false,
			ZIndex = 150,
			action(function(instance)
				expandedControls = instance :: Frame
			end),
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.055, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Button({
				Text = "HIDE",
				LayoutOrder = 1,
				OnActivated = function()
					setMinimized(true)
				end,
			}),
			Button({
				Text = function()
					return if autoEnabled() then "AUTO: ON" else "AUTO: OFF"
				end,
				BackgroundColor3 = function()
					return if autoEnabled() then UIStyle.Colors.Green else UIStyle.Colors.Red
				end,
				LayoutOrder = 2,
				OnActivated = toggleAuto,
			}),
			Button({
				Text = "ABILITIES",
				BackgroundColor3 = UIStyle.Colors.Gold,
				LayoutOrder = 3,
				OnActivated = function()
					AbilityController.SetInventoryOpen(true)
				end,
			}),
		},
		create "Frame" {
			Name = "MinimizedControls",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.3, SafeArea.GetTopOffset(8)),
			Size = UDim2.new(0.48, 180, 0.052, 16),
			Visible = false,
			ZIndex = 150,
			action(function(instance)
				minimizedControls = instance :: Frame
				layoutChain()
			end),
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.055, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Button({
				Text = "SHOW",
				LayoutOrder = 1,
				OnActivated = function()
					setMinimized(false)
				end,
			}),
			Button({
				Text = function()
					return if autoEnabled() then "AUTO: ON" else "AUTO: OFF"
				end,
				BackgroundColor3 = function()
					return if autoEnabled() then UIStyle.Colors.Green else UIStyle.Colors.Red
				end,
				LayoutOrder = 2,
				OnActivated = toggleAuto,
			}),
			Button({
				Text = "ABILITIES",
				BackgroundColor3 = UIStyle.Colors.Gold,
				LayoutOrder = 3,
				OnActivated = function()
					AbilityController.SetInventoryOpen(true)
				end,
			}),
		},
	}
end
