local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create

local localPlayer = Players.LocalPlayer
local visualRandom = Random.new()

local CARD_COUNT = 3
local ENTRY_COUNT = 21
local RESULT_INDEX = 18
local ENTRY_HEIGHT = 0.26
local ENTRY_STRIDE = 0.29
-- Keep each reel readable long enough to follow before its punchy landing sequence begins.
local REEL_DURATIONS = { 1.15, 1.4, 1.65 }
local ROLLING_PRESENTATION_SCALE = 1.45
local LEVEL_UP_TOP_PADDING = 8
local CAMERA_SHAKE_BINDING = "LevelUpChoiceShake_" .. tostring(localPlayer and localPlayer.UserId or "Edit")
local CARD_COLORS = {
	Color3.fromRGB(67, 190, 255),
	Color3.fromRGB(177, 91, 255),
	Color3.fromRGB(255, 174, 59),
}

type CardView = {
	frame: CanvasGroup,
	visualScale: UIScale,
	details: CanvasGroup,
	window: CanvasGroup,
	track: Frame,
	selectionLine: Frame,
	button: TextButton,
	header: TextLabel,
	icon: ImageLabel,
	name: TextLabel,
	level: TextLabel,
	summary: TextLabel,
	entryScales: { UIScale },
	connections: { RBXScriptConnection },
	tweens: { Tween },
	choice: any?,
}

local function makeCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number)
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = color
	border.Thickness = thickness
	border.Parent = parent
	return border
end

local function makeStudTexture(parent: Instance, zIndex: number, transparency: number)
	local texture = Instance.new("ImageLabel")
	texture.Name = "StudTexture"
	texture.BackgroundTransparency = 1
	texture.Image = UIStyle.StudTexture
	texture.ImageTransparency = transparency
	texture.ScaleType = Enum.ScaleType.Tile
	texture.Size = UDim2.fromScale(1, 1)
	texture.TileSize = UDim2.fromOffset(22, 22)
	texture.ZIndex = zIndex
	texture.Parent = parent
	return texture
end

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = UIStyle.Font
	label.Position = position
	label.Size = size
	label.TextColor3 = Color3.fromRGB(230, 239, 244)
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function randomDefinition()
	return AbilityDefinitions.List[visualRandom:NextInteger(1, #AbilityDefinitions.List)]
end

local NEW_ABILITY_SUMMARIES = {
	Dagger = "AUTO-THROWN DAGGERS",
	OrbitingSwords = "SWORDS ORBIT YOU",
	Fireball = "EXPLODING FIREBALLS",
	Lightning = "CHAIN LIGHTNING",
	Boomerang = "RETURNING BOOMERANGS",
	Aura = "DAMAGE NEARBY ZOMBIES",
	Ball = "RICOCHETING BALL",
	Drill = "DIRECTIONAL PIERCING DRILL",
	Mine = "EXPLOSIVE GROUND TRAPS",
	Poison = "PERSISTENT TOXIC PUDDLES",
	Heart = "MORE MAX HEALTH",
	Boots = "FASTER MOVEMENT",
	Blast = "KILLS CAN EXPLODE",
	Burn = "ATTACKS CAN BURN",
	Thorns = "REFLECTS DAMAGE",
}

local UPGRADE_SUMMARIES = {
	Dagger = "DAMAGE INCREASED",
	OrbitingSwords = "SWORD POWER INCREASED",
	Fireball = "DAMAGE + BLAST INCREASED",
	Lightning = "DAMAGE + CHAINS INCREASED",
	Boomerang = "DAMAGE + SIZE INCREASED",
	Aura = "DAMAGE + RADIUS INCREASED",
	Ball = "DAMAGE + BOUNCE POWER",
	Drill = "DAMAGE + RANGE INCREASED",
	Mine = "EXPLOSION POWER INCREASED",
	Poison = "TOXIC FIELD INCREASED",
	Heart = "MAX HEALTH INCREASED",
	Boots = "MOVE SPEED INCREASED",
	Blast = "BLAST POWER INCREASED",
	Burn = "BURN POWER INCREASED",
	Thorns = "REFLECTION INCREASED",
}

local function getChoiceSummary(definition, choice): string
	local nextStats = definition.GetStats and definition.GetStats(math.max(choice.nextLevel, 1)) or nil
	-- Counts are the only numbers worth surfacing here: the card intentionally communicates the
	-- upgrade's identity at a glance instead of reproducing the detailed tooltip stat table.
	if definition.Id == "OrbitingSwords" and nextStats and nextStats.MainSwordCount then
		return string.format("%d SWORDS", nextStats.MainSwordCount)
	elseif definition.Id == "Dagger" and nextStats and nextStats.DaggerCount and nextStats.DaggerCount > 1 then
		return string.format("%d DAGGERS", nextStats.DaggerCount)
	end
	local summaries = if choice.kind == "New" then NEW_ABILITY_SUMMARIES else UPGRADE_SUMMARIES
	return summaries[definition.Id] or (if choice.kind == "New" then "NEW ABILITY" else "POWER INCREASED")
end

local function disconnectCard(card: CardView)
	for _, tween in card.tweens do
		tween:Cancel()
	end
	table.clear(card.tweens)
	for _, connection in card.connections do
		connection:Disconnect()
	end
	table.clear(card.connections)
end

local function createCard(parent: Frame, index: number): CardView
	local accent = CARD_COLORS[index]
	local slot = Instance.new("Frame")
	slot.Name = "Choice" .. index
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = index
	slot.Size = UDim2.new(1 / CARD_COUNT, -12, 1, 0)
	slot.ZIndex = 302
	slot.Parent = parent

	local frame = Instance.new("CanvasGroup")
	frame.Name = "Card"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(17, 23, 30)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 302
	frame.Parent = slot
	makeCorner(frame, 8)
	makeStroke(frame, accent, 3)
	makeStudTexture(frame, 303, 0.86)

	local visualScale = Instance.new("UIScale")
	visualScale.Scale = 1
	visualScale.Parent = frame

	-- The reward type is intentionally a quiet footer: the ability artwork and name must lead the card hierarchy.
	local header = makeLabel(frame, "Header", UDim2.fromScale(0.1, 0.935), UDim2.fromScale(0.8, 0.035), 306)
	header.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Medium)
	header.TextColor3 = accent:Lerp(Color3.fromRGB(145, 156, 164), 0.72)
	header.TextTransparency = 0.2
	header.TextXAlignment = Enum.TextXAlignment.Center

	local details = Instance.new("CanvasGroup")
	details.Name = "RewardDetails"
	details.BackgroundTransparency = 1
	details.GroupTransparency = 1
	details.Position = UDim2.fromScale(0, 0)
	details.Size = UDim2.fromScale(1, 0.92)
	details.ZIndex = 304
	details.Parent = frame

	local iconPanel = Instance.new("Frame")
	iconPanel.Name = "IconPanel"
	iconPanel.AnchorPoint = Vector2.new(0.5, 0)
	iconPanel.BackgroundColor3 = Color3.fromRGB(8, 12, 17)
	iconPanel.BorderSizePixel = 0
	iconPanel.Position = UDim2.fromScale(0.5, 0.025)
	iconPanel.Size = UDim2.fromScale(0.88, 0.6)
	iconPanel.ZIndex = 304
	iconPanel.Parent = details
	makeCorner(iconPanel, 6)
	makeStudTexture(iconPanel, 305, 0.9)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.84, 0.86)
	icon.ZIndex = 306
	icon.Parent = iconPanel

	local nameLabel = makeLabel(details, "AbilityName", UDim2.fromScale(0.06, 0.65), UDim2.fromScale(0.88, 0.1), 306)
	nameLabel.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy)
	local levelLabel = makeLabel(details, "Level", UDim2.fromScale(0.06, 0.755), UDim2.fromScale(0.88, 0.055), 306)
	levelLabel.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)
	levelLabel.TextColor3 = accent

	local statsPanel = Instance.new("Frame")
	statsPanel.Name = "SummaryPanel"
	statsPanel.BackgroundColor3 = Color3.fromRGB(9, 14, 19)
	statsPanel.BorderSizePixel = 0
	statsPanel.Position = UDim2.fromScale(0.055, 0.825)
	statsPanel.Size = UDim2.fromScale(0.89, 0.15)
	statsPanel.ZIndex = 304
	statsPanel.Parent = details
	makeCorner(statsPanel, 5)
	makeStudTexture(statsPanel, 305, 0.9)
	local summary = makeLabel(statsPanel, "Summary", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.76), 306)
	summary.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)
	summary.TextColor3 = accent

	local window = Instance.new("CanvasGroup")
	window.Name = "ReelWindow"
	window.BackgroundColor3 = Color3.fromRGB(9, 14, 19)
	window.BackgroundTransparency = 0.08
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Position = UDim2.fromScale(0.05, 0.12)
	window.Size = UDim2.fromScale(0.9, 0.76)
	window.ZIndex = 310
	window.Parent = frame
	makeCorner(window, 6)

	local selectionLine = Instance.new("Frame")
	selectionLine.Name = "SelectionLine"
	selectionLine.AnchorPoint = Vector2.new(0.5, 0.5)
	selectionLine.BackgroundColor3 = accent
	selectionLine.BackgroundTransparency = 0.16
	selectionLine.BorderSizePixel = 0
	selectionLine.Position = UDim2.fromScale(0.5, 0.5)
	selectionLine.Size = UDim2.new(0.82, 0, 0, 4)
	selectionLine.ZIndex = 312
	selectionLine.Parent = window

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromScale(0, 0.5 - ENTRY_HEIGHT / 2)
	track.Size = UDim2.fromScale(1, 1)
	track.ZIndex = 311
	track.Parent = window

	local button = Instance.new("TextButton")
	button.Name = "Sensor"
	button.Active = false
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Selectable = false
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.ZIndex = 320
	button.Parent = frame

	local card: CardView = {
		frame = frame,
		visualScale = visualScale,
		details = details,
		window = window,
		track = track,
		selectionLine = selectionLine,
		button = button,
		header = header,
		icon = icon,
		name = nameLabel,
		level = levelLabel,
		summary = summary,
		entryScales = {},
		connections = {},
		tweens = {},
		choice = nil,
	}

	table.insert(card.connections, button.MouseEnter:Connect(function()
		if button.Active then
			Sounds.Play("HoverStart", localPlayer.PlayerGui)
			TweenService:Create(visualScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.045 }):Play()
		end
	end))
	table.insert(card.connections, button.MouseLeave:Connect(function()
		if button.Active then
			TweenService:Create(visualScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end
	end))
	return card
end

local function fillReel(card: CardView, resultDefinition)
	for _, child in card.track:GetChildren() do
		child:Destroy()
	end
	table.clear(card.entryScales)
	for entryIndex = 1, ENTRY_COUNT do
		local definition = if entryIndex == RESULT_INDEX then resultDefinition else randomDefinition()
		local entry = Instance.new("Frame")
		entry.AnchorPoint = Vector2.new(0.5, 0)
		entry.BackgroundTransparency = 1
		entry.Position = UDim2.fromScale(0.5, (entryIndex - 1) * ENTRY_STRIDE)
		entry.Size = UDim2.fromScale(0.94, ENTRY_HEIGHT)
		entry.ZIndex = 313
		entry.Parent = card.track
		local entryScale = Instance.new("UIScale")
		entryScale.Scale = 0.72
		entryScale.Parent = entry
		table.insert(card.entryScales, entryScale)
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = definition.Icon
		icon.Position = UDim2.fromScale(0.5, 0.42)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(0.58, 0.63)
		icon.ZIndex = 313
		icon.Parent = entry
		local label = makeLabel(entry, "Name", UDim2.fromScale(0.08, 0.74), UDim2.fromScale(0.84, 0.2), 314)
		label.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)
		label.Text = string.upper(definition.Name)
		label.TextColor3 = definition.Color
	end
end

local function updateEntryScales(card: CardView): number
	local trackY = card.track.Position.Y.Scale
	local closestIndex = 1
	local closestDistance = math.huge
	for index, entryScale in card.entryScales do
		local center = trackY + (index - 1) * ENTRY_STRIDE + ENTRY_HEIGHT * 0.5
		local distance = math.abs(0.5 - center)
		if distance < closestDistance then
			closestIndex = index
			closestDistance = distance
		end
		local normalized = math.clamp(distance / (ENTRY_STRIDE * 2.1), 0, 1)
		local smooth = normalized * normalized * (3 - 2 * normalized)
		entryScale.Scale = 1.18 + (0.68 - 1.18) * smooth
	end
	return closestIndex
end

local function emitCardBurst(card: CardView, accent: Color3, isFinalLanding: boolean)
	local ring = Instance.new("Frame")
	ring.Name = "LandingRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.22, 0.22)
	ring.ZIndex = 324
	ring.Parent = card.frame
	makeCorner(ring, 999)
	local ringStroke = makeStroke(ring, accent, if isFinalLanding then 4 else 3)
	local ringTween = TweenService:Create(
		ring,
		TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1.12, 1.12), Rotation = 34 }
	)
	TweenService:Create(ringStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	ringTween.Completed:Once(function()
		ring:Destroy()
	end)
	ringTween:Play()

	local sparkleCount = if isFinalLanding then 12 else 7
	for sparkleIndex = 1, sparkleCount do
		local angle = math.pi * 2 * sparkleIndex / sparkleCount + visualRandom:NextNumber(-0.18, 0.18)
		local distance = visualRandom:NextNumber(if isFinalLanding then 54 else 38, if isFinalLanding then 82 else 60)
		local sparkle = Instance.new("ImageLabel")
		sparkle.Name = "LandingSparkle"
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.BackgroundTransparency = 1
		sparkle.Image = Images.Sparkle
		sparkle.ImageColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.3)
		sparkle.Position = UDim2.fromScale(0.5, 0.5)
		sparkle.Rotation = visualRandom:NextNumber(-30, 30)
		sparkle.Size = UDim2.fromOffset(if isFinalLanding then 15 else 11, if isFinalLanding then 15 else 11)
		sparkle.ZIndex = 325
		sparkle.Parent = card.frame
		local sparkleTween = TweenService:Create(
			sparkle,
			TweenInfo.new(visualRandom:NextNumber(0.28, 0.42), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				ImageTransparency = 1,
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
				Rotation = sparkle.Rotation + visualRandom:NextNumber(100, 220),
				Size = UDim2.fromOffset(3, 3),
			}
		)
		sparkleTween.Completed:Once(function()
			sparkle:Destroy()
		end)
		sparkleTween:Play()
	end
end

return function()
	local root: Frame?
	local chain: Frame?
	local rowScale: UIScale?
	local prompt: TextLabel?
	local impactFlash: Frame?
	local cards: { CardView } = {}
	local activeSetId = 0
	local landedCount = 0
	local generation = 0
	local presentationPhase = "Idle"
	local pendingPresentationState = nil
	local topOffset = SafeArea.GetTopOffset(LEVEL_UP_TOP_PADDING)
	local shakeMagnitude = 0
	local shakeBound = false
	local baseFieldOfView: number? = nil
	local fieldOfViewTween: Tween? = nil

	local function stopCameraShake()
		if shakeBound then
			RunService:UnbindFromRenderStep(CAMERA_SHAKE_BINDING)
			shakeBound = false
		end
		shakeMagnitude = 0
	end

	local function ensureCameraShake()
		if shakeBound then
			return
		end
		shakeBound = true
		-- No other project system currently writes a camera shake. Apply this after Roblox's camera update
		-- so the short impulse never becomes accumulated camera state or interferes with player control.
		RunService:BindToRenderStep(CAMERA_SHAKE_BINDING, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
			local camera = Workspace.CurrentCamera
			shakeMagnitude *= math.exp(-12 * deltaTime)
			if not camera or shakeMagnitude < 0.008 then
				stopCameraShake()
				return
			end
			local translation = Vector3.new(
				visualRandom:NextNumber(-1, 1),
				visualRandom:NextNumber(-1, 1),
				0
			) * shakeMagnitude
			local rotation = math.rad(visualRandom:NextNumber(-1, 1) * shakeMagnitude * 2.6)
			camera.CFrame *= CFrame.new(translation) * CFrame.Angles(0, 0, rotation)
		end)
	end

	local function playLandingFeedback(accent: Color3, isFinalLanding: boolean)
		shakeMagnitude = math.min(shakeMagnitude + (if isFinalLanding then 0.24 else 0.09), 0.32)
		ensureCameraShake()

		if impactFlash then
			impactFlash.BackgroundColor3 = accent
			impactFlash.BackgroundTransparency = if isFinalLanding then 0.86 else 0.93
			TweenService:Create(
				impactFlash,
				TweenInfo.new(if isFinalLanding then 0.2 else 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end

		local camera = Workspace.CurrentCamera
		if camera and baseFieldOfView then
			if fieldOfViewTween then
				fieldOfViewTween:Cancel()
			end
			fieldOfViewTween = TweenService:Create(
				camera,
				TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ FieldOfView = baseFieldOfView + (if isFinalLanding then 4 else 1.25) }
			)
			fieldOfViewTween.Completed:Once(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed and camera.Parent and baseFieldOfView then
					fieldOfViewTween = TweenService:Create(
						camera,
						TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ FieldOfView = baseFieldOfView }
					)
					fieldOfViewTween:Play()
				end
			end)
			fieldOfViewTween:Play()
		end

		if isFinalLanding then
			local blur = Instance.new("BlurEffect")
			blur.Name = "LevelUpLandingBlur"
			blur.Size = 0
			blur.Parent = Lighting
			local grow = TweenService:Create(blur, TweenInfo.new(0.05), { Size = 2.4 })
			grow.Completed:Once(function()
				if blur.Parent then
					TweenService:Create(blur, TweenInfo.new(0.14), { Size = 0 }):Play()
				end
			end)
			grow:Play()
			Debris:AddItem(blur, 0.25)
		end
	end

	local function setSensors(enabled: boolean)
		for _, card in cards do
			card.button.Active = enabled
			card.button.Selectable = enabled
		end
	end

	local function hidePresentation()
		if root then
			root.Visible = false
		end
		setSensors(false)
	end

	local startPresentation
	local function advancePresentation()
		local nextState = pendingPresentationState or RunProgressionController.GetState()
		pendingPresentationState = nil
		if type(nextState.choices) == "table" and #nextState.choices > 0 then
			startPresentation(nextState)
		else
			presentationPhase = "Idle"
			hidePresentation()
		end
	end

	startPresentation = function(runState)
		if not root or not chain or type(runState.choices) ~= "table" or #runState.choices == 0 then
			return
		end
		generation += 1
		local thisGeneration = generation
		activeSetId = runState.choiceSetId
		landedCount = 0
		presentationPhase = "Rolling"
		pendingPresentationState = nil
		baseFieldOfView = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or nil
		root.Visible = true
		chain.Position = UDim2.new(0.5, 0, 0, topOffset)
		if rowScale then
			-- Enlarge the complete reel so card spacing scales with it; scaling individual layout children
			-- would make the three rolling cards overlap and remain difficult to read.
			rowScale.Scale = ROLLING_PRESENTATION_SCALE
		end
		if prompt then
			prompt.Text = if runState.pendingChoices > 1
				then string.format("LEVEL UP  -  CHOOSE ONE  -  %d QUEUED", runState.pendingChoices)
				else "LEVEL UP  -  CHOOSE ONE"
		end
		setSensors(false)

		for index, card in cards do
			disconnectCard(card)
			-- Reconnect the permanent input handlers after cancelling the prior reel's transient listeners.
			table.insert(card.connections, card.button.MouseEnter:Connect(function()
				if card.button.Active then
					Sounds.Play("HoverStart", localPlayer.PlayerGui)
					TweenService:Create(card.visualScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.045 }):Play()
				end
			end))
			table.insert(card.connections, card.button.MouseLeave:Connect(function()
				if card.button.Active then
					TweenService:Create(card.visualScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
				end
			end))
			table.insert(card.connections, card.button.Activated:Connect(function()
				if presentationPhase ~= "Choosing" or landedCount < #runState.choices or not card.choice then
					return
				end
				presentationPhase = "Selecting"
				setSensors(false)
				Sounds.Play("Click", localPlayer.PlayerGui)
				Sounds.Play("Reward3", localPlayer.PlayerGui)
				RunProgressionController.SelectChoice(activeSetId, index)
				for otherIndex, otherCard in cards do
					local targetScale = if otherIndex == index then 1.04 else 0.82
					local targetTransparency = if otherIndex == index then 0 else 1
					TweenService:Create(otherCard.visualScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = targetScale }):Play()
					TweenService:Create(otherCard.frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { GroupTransparency = targetTransparency }):Play()
					TweenService:Create(otherCard.details, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { GroupTransparency = targetTransparency }):Play()
				end
				task.delay(0.48, function()
					if generation ~= thisGeneration then
						return
					end
					advancePresentation()
				end)
			end))

			local choice = runState.choices[index]
			card.choice = choice
			card.frame.Visible = choice ~= nil
			if not choice then
				continue
			end
			local definition = AbilityDefinitions.ById[choice.abilityId]
			if not definition then
				continue
			end
			card.frame.BackgroundTransparency = 0
			card.frame.GroupTransparency = 0
			card.frame.Rotation = 0
			card.visualScale.Scale = 1
			card.details.GroupTransparency = 1
			card.window.GroupTransparency = 0
			card.window.Visible = true
			card.track.Position = UDim2.fromScale(0, 0.5 - ENTRY_HEIGHT / 2)
			card.header.Text = if choice.kind == "New" then "NEW ABILITY" else "UPGRADE"
			card.icon.Image = definition.Icon
			card.name.Text = string.upper(definition.Name)
			card.level.Text = if choice.kind == "New"
				then "STARTS AT LEVEL 1"
				else string.format("LEVEL %d  >  %d", choice.currentLevel, choice.nextLevel)
			card.summary.Text = getChoiceSummary(definition, choice)
			fillReel(card, definition)
			local lastCrossed = 1
			table.insert(card.connections, card.track:GetPropertyChangedSignal("Position"):Connect(function()
				local crossed = updateEntryScales(card)
				if crossed > lastCrossed then
					lastCrossed = crossed
					Sounds.Play("ItemRevealTick", localPlayer.PlayerGui)
				end
			end))
			updateEntryScales(card)
			Sounds.Play("Rolling", localPlayer.PlayerGui)
			local targetY = 0.5 - ENTRY_HEIGHT / 2 - (RESULT_INDEX - 1) * ENTRY_STRIDE
			local reelTween = TweenService:Create(
				card.track,
				TweenInfo.new(REEL_DURATIONS[index], Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(0, targetY) }
			)
			table.insert(card.tweens, reelTween)
			reelTween.Completed:Once(function(playbackState)
				if generation ~= thisGeneration or playbackState ~= Enum.PlaybackState.Completed then
					return
				end
				landedCount += 1
				local finalLanding = landedCount >= #runState.choices
				local revealSound = Sounds.Play("ItemRevealComplete", localPlayer.PlayerGui)
				if revealSound then
					-- Rising pitch makes the left-to-right sequence build toward the stronger final impact.
					revealSound.PlaybackSpeed = 0.92 + index * 0.08
					revealSound.Volume *= if finalLanding then 1.18 else 1
				end
				Sounds.Play("Swoosh", localPlayer.PlayerGui)
				if finalLanding then
					Sounds.Play("NewRarest", localPlayer.PlayerGui)
				end
				playLandingFeedback(CARD_COLORS[index], finalLanding)
				emitCardBurst(card, CARD_COLORS[index], finalLanding)
				local linePulse = TweenService:Create(card.selectionLine, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
					BackgroundTransparency = 0,
					Size = UDim2.new(0.94, 0, 0, 8),
				})
				linePulse:Play()
				TweenService:Create(card.window, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
				TweenService:Create(card.details, TweenInfo.new(0.24, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
				card.frame.Rotation = if index % 2 == 0 then 1.6 else -1.6
				local expand = TweenService:Create(card.visualScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
				expand:Play()
				expand.Completed:Once(function()
					if generation == thisGeneration then
						card.window.Visible = false
						TweenService:Create(card.visualScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
						TweenService:Create(card.frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
					end
				end)
				if finalLanding then
					if rowScale then
						TweenService:Create(
							rowScale,
							TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{ Scale = 1 }
						):Play()
					end
					presentationPhase = "Choosing"
					setSensors(true)
				end
			end)
			reelTween:Play()
		end
	end

	local initialState = RunProgressionController.GetState()
	local stateConnection = RunProgressionController.GetStateChangedSignal():Connect(function(runState)
		if not runState.active then
			pendingPresentationState = nil
			presentationPhase = "Idle"
			hidePresentation()
			return
		end
		if type(runState.choices) == "table" and #runState.choices > 0 then
			if presentationPhase == "Idle" then
				startPresentation(runState)
			elseif runState.choiceSetId ~= activeSetId or presentationPhase == "Selecting" then
				-- Preserve the newest authoritative set while the current reel or selection animation finishes.
				pendingPresentationState = runState
			elseif prompt then
				prompt.Text = if runState.pendingChoices > 1
					then string.format("LEVEL UP  -  CHOOSE ONE  -  %d QUEUED", runState.pendingChoices)
					else "LEVEL UP  -  CHOOSE ONE"
			end
		elseif presentationPhase == "Selecting" then
			-- An accepted choice with no next token clears any stale same-set packet received before the response.
			pendingPresentationState = nil
		elseif presentationPhase == "Idle" then
			hidePresentation()
		end
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset = SafeArea.GetTopOffset(LEVEL_UP_TOP_PADDING)
		if chain then
			chain.Position = UDim2.new(0.5, 0, 0, topOffset)
		end
	end)
	cleanup(function()
		generation += 1
		stopCameraShake()
		if fieldOfViewTween then
			fieldOfViewTween:Cancel()
		end
		if baseFieldOfView and Workspace.CurrentCamera then
			Workspace.CurrentCamera.FieldOfView = baseFieldOfView
		end
		stateConnection:Disconnect()
		safeAreaConnection:Disconnect()
		for _, card in cards do
			disconnectCard(card)
		end
	end)

	return create "Frame" {
		Name = "LevelUpChoices",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 295,
		action(function(instance)
			root = instance :: Frame
			task.defer(function()
				if type(initialState.choices) == "table" and #initialState.choices > 0 then
					startPresentation(initialState)
				end
			end)
		end),
		create "Frame" {
			Name = "TopFade",
			BackgroundColor3 = Color3.fromRGB(5, 8, 12),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.35),
			ZIndex = 295,
			create "UIGradient" {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.72, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			},
		},
		create "Frame" {
			Name = "ImpactFlash",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.35),
			ZIndex = 296,
			action(function(instance)
				impactFlash = instance :: Frame
			end),
		},
		create "Frame" {
			Name = "ChoiceChain",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.07),
			-- A wide responsive slot keeps mobile cards tappable; the pixel cap keeps desktop presentation compact.
			Size = UDim2.new(0.92, 0, 0.32, 0),
			ZIndex = 300,
			action(function(instance)
				chain = instance :: Frame
				local title = makeLabel(chain, "Prompt", UDim2.fromScale(0.05, 0), UDim2.fromScale(0.9, 0.09), 301)
				title.FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold)
				title.Text = "LEVEL UP  -  CHOOSE ONE"
				local titleStroke = Instance.new("UIStroke")
				titleStroke.Name = "TextStroke"
				titleStroke.Color = Color3.fromRGB(3, 6, 9)
				titleStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
				titleStroke.Thickness = 0.065
				titleStroke.Transparency = 0.05
				titleStroke.Parent = title
				prompt = title
				local row = Instance.new("Frame")
				row.Name = "Cards"
				row.BackgroundTransparency = 1
				row.AnchorPoint = Vector2.new(0.5, 0)
				row.Position = UDim2.fromScale(0.5, 0.105)
				row.Size = UDim2.fromScale(1, 0.895)
				row.ZIndex = 302
				row.Parent = chain
				local scale = Instance.new("UIScale")
				scale.Scale = 1
				scale.Parent = row
				rowScale = scale
				local sizeConstraint = Instance.new("UISizeConstraint")
				sizeConstraint.MaxSize = Vector2.new(510, 230)
				sizeConstraint.Parent = row
				local layout = Instance.new("UIListLayout")
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout.Padding = UDim.new(0, 12)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = row
				for index = 1, CARD_COUNT do
					table.insert(cards, createCard(row, index))
				end
			end),
		},
	}
end
