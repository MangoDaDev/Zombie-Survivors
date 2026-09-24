local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Classes.Button)
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

local REEL_WIDTH = 216
local REEL_HEIGHT = 330
local REEL_GAP = 12
local ENTRY_HEIGHT = 78
local ENTRY_STRIDE = 84
local ENTRY_COUNT = 28
local FULL_TINT_TRANSPARENCY = 0.34
local FULL_VERTICAL_FRACTION = 0.25

local function addCorner(parent: Instance, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UIStyle.CornerRadius
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function addStudTexture(parent: Instance, zIndex: number)
	local texture = Instance.new("ImageLabel")
	texture.Name = "StudTexture"
	texture.BackgroundTransparency = 1
	texture.Image = UIStyle.StudTexture
	texture.ImageTransparency = UIStyle.StudTransparency
	texture.ScaleType = Enum.ScaleType.Tile
	texture.Size = UDim2.fromScale(1, 1)
	texture.TileSize = UDim2.fromOffset(54, 54)
	texture.ZIndex = zIndex
	texture.Parent = parent
end

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
	return label
end

local function formatOdds(baseOdds: number): string
	return string.format("1 / %d", baseOdds)
end

local function createEntry(parent: Instance, item, index: number, isResult: boolean): Frame
	local entry = Instance.new("Frame")
	entry.Name = if isResult then "ServerResult" else "PassingItem"
	entry.BackgroundColor3 = item.Color:Lerp(UIStyle.Colors.Ink, 0.78)
	entry.BackgroundTransparency = if isResult then 0.08 else 0.24
	entry.BorderSizePixel = 0
	entry.Position = UDim2.fromOffset(7, (index - 1) * ENTRY_STRIDE)
	entry.Size = UDim2.new(1, -14, 0, ENTRY_HEIGHT)
	entry.ZIndex = 125
	entry.Parent = parent
	addCorner(entry, UIStyle.SmallCornerRadius)
	addStroke(entry, item.Color, if isResult then 3 else 1.5, if isResult then 0.05 else 0.52)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = item.Image
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(58, 58)
	icon.ZIndex = 126
	icon.Parent = entry

	local nameLabel = createText(entry, "ItemName", item.Name, 126)
	nameLabel.Position = UDim2.new(0, 74, 0, 8)
	nameLabel.Size = UDim2.new(1, -82, 0, 34)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = item.Color
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = UIStyle.Colors.Ink
	nameStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	nameStroke.Thickness = 0.055
	nameStroke.Parent = nameLabel

	local oddsLabel = createText(entry, "Odds", formatOdds(item.BaseOdds), 126)
	oddsLabel.Position = UDim2.new(0, 74, 0, 43)
	oddsLabel.Size = UDim2.new(1, -82, 0, 23)
	oddsLabel.TextTransparency = 0.13
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	return entry
end

local function createReel(parent: Frame, packet, resultItem)
	local reel = Instance.new("Frame")
	reel.Name = string.format("Reel%d", packet.reelIndex)
	reel.BackgroundColor3 = resultItem.Color:Lerp(UIStyle.Colors.Ink, 0.72)
	reel.BorderSizePixel = 0
	reel.LayoutOrder = packet.reelIndex
	reel.Size = UDim2.fromOffset(REEL_WIDTH, REEL_HEIGHT)
	reel.ZIndex = 118
	reel.Parent = parent
	addCorner(reel)
	local activeStroke = addStroke(reel, resultItem.Color, 3, 0.02)
	activeStroke.Name = "ActiveStroke"

	local punchScale = Instance.new("UIScale")
	punchScale.Name = "PunchScale"
	punchScale.Parent = reel

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 1
	glow.Image = UIStyle.GlowTexture
	glow.ImageColor3 = resultItem.Color
	glow.ImageTransparency = 0.78
	glow.Position = UDim2.fromScale(0.5, 0.52)
	glow.Size = UDim2.fromScale(1.28, 1.18)
	glow.ZIndex = 117
	glow.Parent = reel

	local multiplierText = if packet.multiplier == 1 then "ORIGINAL" else string.format("x%d", packet.multiplier)
	local multiplier = createText(reel, "Multiplier", multiplierText, 123)
	multiplier.AnchorPoint = Vector2.new(0.5, 0)
	multiplier.Position = UDim2.new(0.5, 0, 0, 8)
	multiplier.Size = UDim2.new(0.82, 0, 0, 35)
	multiplier.TextColor3 = if packet.multiplier == 1 then UIStyle.Colors.Paper else UIStyle.Colors.Gold
	addStroke(multiplier, UIStyle.Colors.Ink, 1.5, 0.08)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundColor3 = UIStyle.Colors.InkSoft
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Position = UDim2.fromOffset(10, 50)
	window.Size = UDim2.new(1, -20, 1, -62)
	window.ZIndex = 120
	window.Parent = reel
	addCorner(window)
	addStroke(window, UIStyle.Colors.Ink, 2)
	addStudTexture(window, 121)

	local centerY = math.floor((REEL_HEIGHT - 62) / 2)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(0, centerY - ENTRY_HEIGHT / 2)
	track.Size = UDim2.new(1, 0, 0, ENTRY_COUNT * ENTRY_STRIDE)
	track.ZIndex = 124
	track.Parent = window

	for index = 1, ENTRY_COUNT do
		-- Passing entries are cosmetic decoys; the last entry is always the server-selected result.
		local item = if index == ENTRY_COUNT
			then resultItem
			else GetRandomFromWeightedTable(RollDefinitions.Items, "Weight", visualRandom, 1)
		createEntry(track, item, index, index == ENTRY_COUNT)
	end

	local highlight = Instance.new("Frame")
	highlight.Name = "SelectionHighlight"
	highlight.BackgroundColor3 = resultItem.Color
	highlight.BackgroundTransparency = 0.88
	highlight.BorderSizePixel = 0
	highlight.Position = UDim2.fromOffset(0, centerY - ENTRY_HEIGHT / 2 - 3)
	highlight.Size = UDim2.new(1, 0, 0, ENTRY_HEIGHT + 6)
	highlight.ZIndex = 130
	highlight.Parent = window
	addStroke(highlight, resultItem.Color, 3, 0.08)

	for _, y in { centerY - ENTRY_HEIGHT / 2 - 5, centerY + ENTRY_HEIGHT / 2 + 3 } do
		local line = Instance.new("Frame")
		line.Name = "SelectionLine"
		line.BackgroundColor3 = UIStyle.Colors.Paper
		line.BorderSizePixel = 0
		line.Position = UDim2.fromOffset(4, y)
		line.Size = UDim2.new(1, -8, 0, 2)
		line.ZIndex = 131
		line.Parent = window
	end

	return {
		frame = reel,
		glow = glow,
		punchScale = punchScale,
		stroke = activeStroke,
		track = track,
		resultItem = resultItem,
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
	local chainScale: UIScale?
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
		for _, childName in { "CoinsDisplay", "Notifications" } do
			local child = screenGui:FindFirstChild(childName)
			if child and child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end

	local function getViewportSize(): Vector2
		local camera = Workspace.CurrentCamera
		return if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end

	local function layoutChain()
		if not chain or not chainScale or not root then
			return
		end
		local count = math.max(#reels, 1)
		local naturalWidth = count * REEL_WIDTH + (count - 1) * REEL_GAP
		local viewport = getViewportSize()
		local widthScale = (viewport.X * 0.9) / naturalWidth
		local scale
		if minimized then
			scale = math.min(0.46, widthScale)
			chain.Position = UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(10))
		else
			local heightScale = (viewport.Y * 0.56) / REEL_HEIGHT
			scale = math.min(1.05, widthScale, heightScale)
			chain.Position = UDim2.new(0.5, 0, FULL_VERTICAL_FRACTION, 0)
		end
		chain.Size = UDim2.fromOffset(naturalWidth, REEL_HEIGHT)
		chainScale.Scale = scale

		if minimizedControls then
			minimizedControls.Position = UDim2.new(
				0.5,
				0,
				0,
				SafeArea.GetTopOffset(16) + math.floor(REEL_HEIGHT * scale)
			)
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
			reelState.punchScale,
			TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if reelState.resultItem.RarityRank >= 5 then 1.12 else 1.07 }
		)
		local settle = TweenService:Create(
			reelState.punchScale,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		punchOut:Play()
		punchOut.Completed:Once(function()
			if reelState.frame.Parent then
				settle:Play()
			end
		end)
		TweenService:Create(
			reelState.glow,
			TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
			{ ImageTransparency = if reelState.resultItem.RarityRank >= 5 then 0.28 else 0.5 }
		):Play()
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
			oldReel.glow.ImageTransparency = 0.94
			oldReel.stroke.Transparency = 0.5
		end

		local reelState = createReel(chain, packet, resultItem)
		table.insert(reels, reelState)
		layoutChain()
		Sounds.Play("Rolling", localPlayer.PlayerGui)

		local lastCrossed = 1
		reelState.tickConnection = reelState.track:GetPropertyChangedSignal("Position"):Connect(function()
			local crossed = math.clamp(
				math.floor((reelState.centerY - ENTRY_HEIGHT / 2 - reelState.track.Position.Y.Offset) / ENTRY_STRIDE) + 1,
				1,
				ENTRY_COUNT
			)
			if crossed > lastCrossed then
				lastCrossed = crossed
				Sounds.Play("ItemRevealTick", localPlayer.PlayerGui)
			end
		end)

		local targetY = reelState.centerY - ENTRY_HEIGHT / 2 - (ENTRY_COUNT - 1) * ENTRY_STRIDE
		local tween = TweenService:Create(
			reelState.track,
			TweenInfo.new(RollDefinitions.Timing.ReelDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(0, targetY) }
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
		bonusIndicator.Size = if minimized then UDim2.fromOffset(180, 72) else UDim2.fromOffset(390, 145)
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

	local cameraConnection: RBXScriptConnection?
	local function connectCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		cameraConnection = camera and camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutChain) or nil
	end
	connectCamera()
	table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		connectCamera()
		layoutChain()
	end))

	cleanup(function()
		setHudVisible(true)
		clearReels()
		for _, connection in connections do
			connection:Disconnect()
		end
		if cameraConnection then
			cameraConnection:Disconnect()
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
			Size = UDim2.new(0.36, 190, 0.065, 24),
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
		},
		create "Frame" {
			Name = "ReelChain",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, FULL_VERTICAL_FRACTION, 0),
			Size = UDim2.fromOffset(REEL_WIDTH, REEL_HEIGHT),
			Visible = active,
			ZIndex = 115,
			action(function(instance)
				chain = instance :: Frame
				layoutChain()
			end),
			create "UIScale" {
				Scale = 1,
				action(function(instance)
					chainScale = instance :: UIScale
					layoutChain()
				end),
			},
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, REEL_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
		},
		create "Frame" {
			Name = "BonusIndicator",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromOffset(390, 145),
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
			Size = UDim2.new(0.32, 160, 0.058, 20),
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
		},
		create "Frame" {
			Name = "MinimizedControls",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(170)),
			Size = UDim2.fromOffset(360, 48),
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
		},
	}
end
