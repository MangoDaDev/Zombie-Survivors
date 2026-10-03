local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)

local GetProfilePicture = require(ReplicatedStorage.Modules.Platform.GetProfilePicture)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local indexes = Vide.indexes
local source = Vide.source

local localPlayer = Players.LocalPlayer

local MINIMUM_INDICATOR_SIZE = 48
local MAXIMUM_INDICATOR_SIZE = 64
local VIEWPORT_SIZE_FRACTION = 0.075
local EDGE_PADDING = 10
local PLAYER_AIM_HEIGHT = 2.5

type IndicatorState = {
	player: Player,
	position: any,
	rotation: any,
	size: any,
	thumbnail: any,
	visible: any,
	downed: any,
	onScreen: any,
	root: BasePart?,
	humanoid: Humanoid?,
	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
	characterChildConnection: RBXScriptConnection?,
	thumbnailThread: thread?,
}

local function bindCharacter(state: IndicatorState, character: Model?)
	if state.characterChildConnection then
		state.characterChildConnection:Disconnect()
		state.characterChildConnection = nil
	end
	state.root = nil
	state.humanoid = nil
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		state.root = root
	end
	state.humanoid = character:FindFirstChildOfClass("Humanoid")
	if state.root and state.humanoid then
		return
	end

	-- Characters do not replicate atomically, so retain the player entry and wait for either
	-- required descendant instead of dropping their indicator during character creation.
	state.characterChildConnection = character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			state.root = child
		elseif child:IsA("Humanoid") then
			state.humanoid = child
		end
		if state.root and state.humanoid and state.characterChildConnection then
			state.characterChildConnection:Disconnect()
			state.characterChildConnection = nil
		end
	end)
end

local function destroyState(state: IndicatorState)
	if state.characterAddedConnection then
		state.characterAddedConnection:Disconnect()
	end
	if state.characterRemovingConnection then
		state.characterRemovingConnection:Disconnect()
	end
	if state.characterChildConnection then
		state.characterChildConnection:Disconnect()
	end
	if state.thumbnailThread and coroutine.status(state.thumbnailThread) ~= "dead" then
		task.cancel(state.thumbnailThread)
	end
end

local function hideIndicator(state: IndicatorState)
	if state.visible() then
		state.visible(false)
	end
end

local function updateIndicator(state: IndicatorState, camera: Camera?, gameMapPresent: boolean, topOffset: number, downedLookup)
	local root = state.root
	local humanoid = state.humanoid
	if not gameMapPresent
		or state.player.Parent ~= Players
		or not camera
		or not root
		or not root.Parent
		or not humanoid
		or (humanoid.Health <= 0 and not downedLookup[state.player.UserId])
	then
		hideIndicator(state)
		return
	end

	local viewportSize = camera.ViewportSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		hideIndicator(state)
		return
	end

	local projected, onScreen = camera:WorldToViewportPoint(root.Position + Vector3.yAxis * PLAYER_AIM_HEIGHT)
	local downed = downedLookup[state.player.UserId] == true
	state.downed(downed)
	state.onScreen(onScreen)
	if onScreen and not downed then
		hideIndicator(state)
		return
	end

	local center = viewportSize * 0.5
	local direction = Vector2.new(projected.X, projected.Y) - center
	-- Roblox mirrors projections behind the camera; reverse those points so the arrow still aims
	-- toward the player's actual world direction instead of the opposite screen edge.
	if projected.Z < 0 then
		direction = -direction
	end
	if direction.Magnitude < 0.001 then
		direction = Vector2.new(0, -1)
	else
		direction = direction.Unit
	end

	local indicatorSize = math.clamp(
		math.min(viewportSize.X, viewportSize.Y) * VIEWPORT_SIZE_FRACTION,
		MINIMUM_INDICATOR_SIZE,
		MAXIMUM_INDICATOR_SIZE
	)
	local margin = indicatorSize * 0.5 + EDGE_PADDING
	-- The downed badge is wider than the headshot and must also remain inside the safe screen edges.
	local horizontalMargin = if downed then indicatorSize * 0.9 + EDGE_PADDING else margin
	local minimum = Vector2.new(horizontalMargin, math.max(margin, topOffset + margin))
	local maximum = Vector2.new(viewportSize.X - horizontalMargin, viewportSize.Y - margin - (if downed then indicatorSize * 0.38 else 0))
	if maximum.X <= minimum.X or maximum.Y <= minimum.Y then
		hideIndicator(state)
		return
	end

	-- Intersect the direction ray with the safe viewport rectangle. This keeps every headshot fully
	-- visible while the arrow remains aligned with its teammate on any supported aspect ratio.
	local horizontalDistance = if direction.X >= 0 then maximum.X - center.X else minimum.X - center.X
	local verticalDistance = if direction.Y >= 0 then maximum.Y - center.Y else minimum.Y - center.Y
	local horizontalScale = if math.abs(direction.X) > 0.0001
		then horizontalDistance / direction.X
		else math.huge
	local verticalScale = if math.abs(direction.Y) > 0.0001 then verticalDistance / direction.Y else math.huge
	local edgeScale = math.min(horizontalScale, verticalScale)
	local edgePosition = center + direction * edgeScale
	if onScreen then
		edgePosition = Vector2.new(math.clamp(projected.X, minimum.X, maximum.X), math.clamp(projected.Y, minimum.Y, maximum.Y))
	end

	state.size(indicatorSize)
	state.position(UDim2.fromOffset(edgePosition.X, edgePosition.Y))
	-- ObjectiveArrow is authored pointing upward; screen-space angles increase clockwise in Roblox UI.
	state.rotation(math.deg(math.atan2(direction.Y, direction.X)) + 90)
	state.visible(true)
end

local function playerIndicator(state: IndicatorState)
	return create "Frame" {
		Name = `Player_{state.player.UserId}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = state.position,
		Size = function()
			return UDim2.fromOffset(state.size(), state.size())
		end,
		Visible = state.visible,
		ZIndex = 70,
		create "UIAspectRatioConstraint" {
			AspectRatio = 1,
			DominantAxis = Enum.DominantAxis.Width,
		},
		create "ImageLabel" {
			Name = "DirectionArrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Images.ObjectiveArrow,
			ImageColor3 = function() return if state.downed() then Color3.fromRGB(255, 104, 94) else UIStyle.Colors.Gold end,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = state.rotation,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1.32, 1.32),
			ZIndex = 70,
			Visible = function() return not state.onScreen() end,
		},
		create "ImageLabel" {
			Name = "Headshot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = UIStyle.Colors.Ink,
			BorderSizePixel = 0,
			Image = state.thumbnail,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(0.68, 0.68),
			ZIndex = 71,
			create "UIAspectRatioConstraint" { AspectRatio = 1 },
			create "UICorner" { CornerRadius = UDim.new(1, 0) },
			create "UIStroke" {
				Color = function() return if state.downed() then Color3.fromRGB(255, 104, 94) else Color3.new(1, 1, 1) end,
				Thickness = 2,
			},
		},
		create "Frame" {
			Name = "DownedStatus",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(73, 20, 24),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.88),
			Size = UDim2.fromScale(1.8, 0.48),
			Visible = state.downed,
			ZIndex = 72,
			create "UIStroke" { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 104, 94), Thickness = 1 },
			create "TextLabel" {
				Name = "Status",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.5),
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
				Text = "DOWNED",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 73,
			},
			create "TextLabel" {
				Name = "ReviveHelp",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1, 0.5),
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Text = "REVIVE ME",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 73,
			},
		},
	}
end

return function()
	local states: { [Player]: IndicatorState } = {}
	local indicatorStates = source({} :: { [Player]: IndicatorState })
	local gameMapPresent = Workspace:FindFirstChild("Game") ~= nil
	local topOffset = SafeArea.GetTopOffset(0)
	local downedLookup = {}
	local function updateDowned(packet)
		table.clear(downedLookup)
		for _, userId in packet.downedUserIds or {} do downedLookup[userId] = true end
	end
	updateDowned(RunSessionController.GetState())
	local sessionConnection = RunSessionController.GetStateChangedSignal():Connect(updateDowned)

	local function publishStates()
		local currentStates = {}
		for player, state in states do
			currentStates[player] = state
		end
		indicatorStates(currentStates)
	end

	local function addPlayer(player: Player)
		if player == localPlayer or states[player] then
			return
		end
		local state: IndicatorState = {
			player = player,
			position = source(UDim2.fromScale(0.5, 0.5)),
			rotation = source(0),
			size = source(MINIMUM_INDICATOR_SIZE),
			thumbnail = source(""),
			visible = source(false),
			downed = source(false),
			onScreen = source(false),
			root = nil,
			humanoid = nil,
			characterAddedConnection = nil,
			characterRemovingConnection = nil,
			characterChildConnection = nil,
			thumbnailThread = nil,
		}
		states[player] = state
		state.characterAddedConnection = player.CharacterAdded:Connect(function(character)
			bindCharacter(state, character)
		end)
		state.characterRemovingConnection = player.CharacterRemoving:Connect(function()
			bindCharacter(state, nil)
		end)
		bindCharacter(state, player.Character)
		state.thumbnailThread = task.spawn(function()
			local image = GetProfilePicture(player)
			if image and states[player] == state then
				state.thumbnail(image)
			end
		end)
		publishStates()
	end

	local function removePlayer(player: Player)
		local state = states[player]
		if not state then
			return
		end
		destroyState(state)
		states[player] = nil
		publishStates()
	end

	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	local playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	local playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	local workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Game" then
			gameMapPresent = true
		end
	end)
	local workspaceChildRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Game" then
			gameMapPresent = false
		end
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset = SafeArea.GetTopOffset(0)
	end)
	-- All teammate projections share one render callback; adding players never adds per-player frame loops.
	local renderConnection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		for _, state in states do
			updateIndicator(state, camera, gameMapPresent, topOffset, downedLookup)
		end
	end)

	cleanup(function()
		renderConnection:Disconnect()
		sessionConnection:Disconnect()
		playerAddedConnection:Disconnect()
		playerRemovingConnection:Disconnect()
		workspaceChildAddedConnection:Disconnect()
		workspaceChildRemovedConnection:Disconnect()
		safeAreaConnection:Disconnect()
		for _, state in states do
			destroyState(state)
		end
		table.clear(states)
	end)

	return create "Frame" {
		Name = "OffscreenPlayerIndicators",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		indexes(indicatorStates, function(state)
			return playerIndicator(state())
		end),
	}
end
