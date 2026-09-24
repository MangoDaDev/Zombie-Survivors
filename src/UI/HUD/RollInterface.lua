local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RollController = require(ReplicatedStorage.Controllers.RollController)
local RollDefinitions = require(ReplicatedStorage.Modules.Game.Rolls.RollDefinitions)
local GetRandomFromWeightedTable = require(ReplicatedStorage.Modules.Math.GetRandomFromWeightedTable)
	.GetRandomFromWeightedTable
local Images = require(ReplicatedStorage.Modules.UI.Images)
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
local ENTRY_REST_SCALE = 0.82
local ENTRY_SELECTED_SCALE = 1.13

local CLOVER_VISUAL = {
	Name = "Clover",
	Image = Images.Luck,
	BaseOdds = 1,
	RarityRank = 6,
	Color = Color3.fromRGB(103, 255, 132),
}

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

local function createEntry(
	parent: Instance,
	item,
	index: number,
	isResult: boolean,
	cloverLuck: number?
): (Frame, UIScale)
	local entry = Instance.new("Frame")
	entry.Name = if isResult then "ServerResult" else "PassingItem"
	entry.AnchorPoint = Vector2.new(0.5, 0)
	entry.BackgroundTransparency = 1
	entry.BorderSizePixel = 0
	entry.Position = UDim2.fromScale(0.5, (index - 1) * ENTRY_STRIDE_SCALE)
	entry.Size = UDim2.fromScale(0.94, ENTRY_HEIGHT_SCALE)
	entry.ZIndex = 125
	entry.Parent = parent

	local visual = Instance.new("Frame")
	visual.Name = "Visual"
	visual.AnchorPoint = Vector2.new(0.5, 0.5)
	visual.BackgroundTransparency = 1
	visual.Position = UDim2.fromScale(0.5, 0.5)
	visual.Size = UDim2.fromScale(1, 1)
	visual.ZIndex = 125
	visual.Parent = entry

	local resultScale = Instance.new("UIScale")
	resultScale.Name = "ResultScale"
	resultScale.Scale = ENTRY_REST_SCALE
	resultScale.Parent = visual

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
	icon.Parent = visual
	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = icon

	local nameLabel = createText(visual, "ItemName", item.Name, 127)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.015)
	nameLabel.Size = UDim2.fromScale(0.9, 0.24)
	nameLabel.TextColor3 = item.Color
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Visible = cloverLuck == nil

	local oddsLabel = createText(visual, "Odds", formatOdds(item.BaseOdds), 127)
	oddsLabel.AnchorPoint = Vector2.new(0.5, 1)
	oddsLabel.Position = UDim2.fromScale(0.5, 0.985)
	oddsLabel.Size = UDim2.fromScale(0.72, 0.2)
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Center
	oddsLabel.Visible = cloverLuck == nil

	if cloverLuck then
		local luckLabel = createText(visual, "CloverLuck", string.format("x%d\nLUCK", cloverLuck), 129)
		luckLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		luckLabel.Position = UDim2.fromScale(0.5, 0.5)
		luckLabel.Size = UDim2.fromScale(0.54, 0.34)
		luckLabel.TextColor3 = UIStyle.Colors.Paper
		luckLabel.TextWrapped = true
	end
	return entry, resultScale
end

local function createReel(parent: Frame, packet)
	local isClover = packet.kind == "Clover"
	local resultItem = if isClover then CLOVER_VISUAL else RollDefinitions.ById[packet.itemId]
	if not resultItem then
		return nil
	end
	local reel = Instance.new("Frame")
	reel.Name = string.format("Reel%d", packet.reelIndex)
	reel.BackgroundTransparency = 1
	reel.BorderSizePixel = 0
	reel.LayoutOrder = packet.reelIndex
	reel.Size = UDim2.fromScale(1, 1)
	reel.ZIndex = 118
	reel.Parent = parent

	local isAbilityResult = not isClover and resultItem.AbilityId ~= nil
	local hasHeader = not isClover and (isAbilityResult or packet.luckMultiplier > 1)
	local multiplierText = if isAbilityResult
		then "NEW ABILITY"
		else string.format("x%d LUCK", packet.luckMultiplier)
	local multiplier = createText(reel, "Multiplier", multiplierText, 123)
	multiplier.AnchorPoint = Vector2.new(0.5, 0)
	multiplier.Position = UDim2.fromScale(0.5, 0)
	multiplier.Size = UDim2.fromScale(0.82, 0.075)
	multiplier.TextColor3 = if isAbilityResult
		then resultItem.Color
		else Color3.fromRGB(103, 255, 132)
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

	local selectionLine = Instance.new("Frame")
	selectionLine.Name = "SelectionLine"
	selectionLine.AnchorPoint = Vector2.new(0.5, 0.5)
	selectionLine.BackgroundColor3 = if isClover then CLOVER_VISUAL.Color else UIStyle.Colors.Gold
	selectionLine.BackgroundTransparency = 0.18
	selectionLine.BorderSizePixel = 0
	selectionLine.Position = UDim2.fromScale(0.5, 0.5)
	selectionLine.Size = UDim2.new(0.96, 0, 0, 4)
	selectionLine.ZIndex = 124
	selectionLine.Parent = window

	local centerY = 0.5
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromScale(0, centerY - ENTRY_HEIGHT_SCALE / 2)
	track.Size = UDim2.fromScale(1, 1)
	track.ZIndex = 124
	track.Parent = window

	local resultScale
	local entryScales = {}
	for index = 1, ENTRY_COUNT do
		-- Trailing decoys remain after the authoritative result so the stopped reel still shows what follows it.
		local item = if index == RESULT_INDEX
			then resultItem
			else GetRandomFromWeightedTable(RollDefinitions.Items, "Weight", visualRandom, 1)
		local _, entryScale = createEntry(
			track,
			item,
			index,
			index == RESULT_INDEX,
			if isClover and index == RESULT_INDEX then packet.luckMultiplier else nil
		)
		entryScales[index] = entryScale
		if index == RESULT_INDEX then
			resultScale = entryScale
		end
	end
	entryScales[1].Scale = ENTRY_SELECTED_SCALE

	return {
		frame = reel,
		track = track,
		resultItem = resultItem,
		resultScale = resultScale,
		entryScales = entryScales,
		selectedIndex = 1,
		selectionTweens = {},
		isClover = isClover,
		centerY = centerY,
	}
end

return function()
	local active = source(false)
	local sequenceRunning = false
	local currentRollId = 0
	local reels = {}
	local connections = {}
	local reelTweens = {}
	local root: Frame?
	local tint: Frame?
	local chain: Frame?
	local chainLayout: UIListLayout?

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
		local gapScale = 0.018
		local chainWidth = math.min(0.94, 0.38 * count + gapScale * (count - 1))
		chain.Position = UDim2.fromScale(0.5, 0.08)
		chain.Size = UDim2.fromScale(chainWidth, 0.8)
		chainLayout.Padding = UDim.new(gapScale, 0)
		local reelWidth = math.max((1 - gapScale * (count - 1)) / count, 0.08)
		for _, reelState in reels do
			reelState.frame.Size = UDim2.fromScale(reelWidth, 1)
		end

	end

	local function applyMode()
		if not root or not tint then
			return
		end
		local isActive = active()
		setHudVisible(not isActive)

		if isActive then
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
			if reelState.isClover or reelState.resultItem.RarityRank >= 6 then "NewRarest" else "ItemRevealComplete",
			localPlayer.PlayerGui
		)
		local punchOut = TweenService:Create(
			reelState.resultScale,
			TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if reelState.isClover or reelState.resultItem.RarityRank >= 5 then 1.32 else 1.24 }
		)
		local settle = TweenService:Create(
			reelState.resultScale,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.18 }
		)
		punchOut:Play()
		punchOut.Completed:Once(function()
			if reelState.frame.Parent then
				settle:Play()
			end
		end)
	end

	local function setSelectedEntry(reelState, selectedIndex: number)
		if selectedIndex == reelState.selectedIndex then
			return
		end
		for _, index in { reelState.selectedIndex, selectedIndex } do
			local scale = reelState.entryScales[index]
			local existingTween = reelState.selectionTweens[index]
			if existingTween then
				existingTween:Cancel()
			end
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = if index == selectedIndex then ENTRY_SELECTED_SCALE else ENTRY_REST_SCALE }
			)
			reelState.selectionTweens[index] = tween
			tween:Play()
		end
		reelState.selectedIndex = selectedIndex
	end

	local function animateReel(packet)
		if not chain then
			return
		end

		for _, oldReel in reels do
			TweenService:Create(
				oldReel.resultScale,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = ENTRY_REST_SCALE }
			):Play()
		end

		local reelState = createReel(chain, packet)
		if not reelState then
			return
		end
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
			setSelectedEntry(reelState, crossed)
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

	local rollStartedConnection = RollController.GetRollStartedSignal():Connect(function(packet)
		sequenceRunning = true
		if packet.rollId ~= currentRollId then
			currentRollId = packet.rollId
			clearReels()
		end
		active(true)
		applyMode()
		animateReel(packet)
	end)
	table.insert(connections, rollStartedConnection)
	table.insert(connections, RollController.GetRollFinishedSignal():Connect(function(rollId, willAutoRoll)
		if rollId ~= currentRollId then
			return
		end
		sequenceRunning = false
		if willAutoRoll then
			return
		end
		active(false)
		applyMode()
		clearReels()
	end))
	table.insert(connections, RollController.GetAutoRollChangedSignal():Connect(function(enabled)
		if not enabled and active() and not sequenceRunning then
			active(false)
			applyMode()
			clearReels()
		end
	end))
	cleanup(function()
		setHudVisible(true)
		clearReels()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

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
	}
end
