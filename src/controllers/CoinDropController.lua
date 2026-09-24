local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local COIN_STUD_SIZE = 1
local IDLE_BOB_HEIGHT = 0.14
local IDLE_BOB_SPEED = 2.8
local MERGE_EASE_POWER = 2.4
local MAGNET_EASE_POWER = 3.4
local MAGNET_INITIAL_PULL = 0.22
local MAGNET_DURATION_FALLBACK = 0.4
local COLLECTED_POP_DURATION = 0.16

type CoinView = {
	id: number,
	value: number,
	scale: number,
	displayScale: number,
	holder: BasePart,
	gui: BillboardGui,
	image: ImageLabel,
	valueLabel: TextLabel,
	trail: Trail,
	phase: string,
	position: Vector3,
	targetPosition: Vector3,
	startPosition: Vector3,
	startAt: number,
	duration: number,
	arcHeight: number,
	playerUserId: number?,
	bobOffset: number,
}

local CoinDropController = {}

local coinNetwork
local renderConnection
local effectsFolder
local coinViews: { [number]: CoinView } = {}

local function easeOutCubic(alpha: number): number
	local inverse = 1 - alpha
	return 1 - inverse * inverse * inverse
end

local function setGuiScale(view: CoinView, scale: number)
	view.displayScale = scale
	local size = COIN_STUD_SIZE * scale
	view.gui.Size = UDim2.fromScale(size, size)
end

local function updateValuePresentation(view: CoinView, value: number, scale: number?)
	view.value = value
	view.scale = scale or view.scale
	view.valueLabel.Visible = value > 1
	view.valueLabel.Text = "x" .. tostring(value)
end

local function destroyView(id: number)
	local view = coinViews[id]
	if not view then
		return
	end
	coinViews[id] = nil
	view.holder:Destroy()
end

local function createView(id: number, value: number, position: Vector3, scale: number): CoinView
	local existing = coinViews[id]
	if existing then
		updateValuePresentation(existing, value, scale)
		existing.position = position
		existing.targetPosition = position
		return existing
	end

	local holder = Instance.new("Part")
	holder.Name = "Coin_" .. tostring(id)
	holder.Size = Vector3.new(0.08, 0.08, 0.08)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Position = position
	holder.Parent = effectsFolder

	local light = Instance.new("PointLight")
	light.Name = "CoinLight"
	light.Brightness = 1.35
	light.Color = Color3.fromRGB(255, 190, 55)
	light.Range = 6
	light.Shadows = false
	light.Parent = holder

	local trailStart = Instance.new("Attachment")
	trailStart.Position = Vector3.new(0, 0.15, 0)
	trailStart.Parent = holder
	local trailEnd = Instance.new("Attachment")
	trailEnd.Position = Vector3.new(0, -0.15, 0)
	trailEnd.Parent = holder

	local trail = Instance.new("Trail")
	trail.Name = "GoldTrail"
	trail.Attachment0 = trailStart
	trail.Attachment1 = trailEnd
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 249, 164)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 166, 25)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.Lifetime = 0.2
	trail.MinLength = 0.04
	trail.Enabled = false
	trail.Parent = holder

	local gui = Instance.new("BillboardGui")
	gui.Name = "CoinBillboard"
	gui.Adornee = holder
	-- Coins use world-sized, occluded billboards so walls and other geometry can hide them naturally.
	gui.AlwaysOnTop = false
	gui.LightInfluence = 1
	gui.MaxDistance = 180
	gui.Size = UDim2.fromScale(COIN_STUD_SIZE, COIN_STUD_SIZE)
	gui.Parent = holder

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.42, 1.42)
	glow.BackgroundTransparency = 1
	glow.Image = Images.Sparkle
	glow.ImageColor3 = Color3.fromRGB(255, 206, 54)
	glow.ImageTransparency = 0.45
	glow.ZIndex = 1
	glow.Parent = gui

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.86, 0.86)
	image.BackgroundTransparency = 1
	image.Image = Images.Coin
	image.ZIndex = 2
	image.Parent = gui

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.AnchorPoint = Vector2.new(0.5, 1)
	valueLabel.Position = UDim2.fromScale(0.5, 1.08)
	valueLabel.Size = UDim2.fromScale(1.1, 0.38)
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = Font.new(
		"rbxasset://fonts/families/ComicNeueAngular.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	valueLabel.TextColor3 = Color3.fromRGB(255, 244, 145)
	valueLabel.TextScaled = true
	valueLabel.ZIndex = 3
	valueLabel.Parent = gui

	local valueStroke = Instance.new("UIStroke")
	valueStroke.Color = Color3.fromRGB(91, 48, 5)
	valueStroke.Thickness = 2
	valueStroke.Parent = valueLabel

	local view: CoinView = {
		id = id,
		value = value,
		scale = scale,
		displayScale = scale,
		holder = holder,
		gui = gui,
		image = image,
		valueLabel = valueLabel,
		trail = trail,
		phase = "Idle",
		position = position,
		targetPosition = position,
		startPosition = position,
		startAt = 0,
		duration = 0,
		arcHeight = 0,
		playerUserId = nil,
		bobOffset = (id % 11) * 0.47,
	}
	coinViews[id] = view
	updateValuePresentation(view, value, scale)
	setGuiScale(view, scale)
	return view
end

local function getPlayerRoot(userId: number?): BasePart?
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function renderView(view: CoinView, now: number)
	if view.phase == "Scatter" then
		local alpha = math.clamp((now - view.startAt) / view.duration, 0, 1)
		local travelAlpha = easeOutCubic(alpha)
		local position = view.startPosition:Lerp(view.targetPosition, travelAlpha)
		position += Vector3.new(0, math.sin(alpha * math.pi) * view.arcHeight, 0)
		view.position = position
		view.holder.Position = position
		setGuiScale(view, view.scale * (0.72 + 0.28 * easeOutCubic(alpha)))
		if alpha >= 1 then
			view.phase = "Idle"
			view.position = view.targetPosition
			view.trail.Enabled = false
			setGuiScale(view, view.scale)
		end
	elseif view.phase == "Idle" then
		local bob = math.sin(now * IDLE_BOB_SPEED + view.bobOffset) * IDLE_BOB_HEIGHT
		view.holder.Position = view.position + Vector3.new(0, bob, 0)
	elseif view.phase == "MergeTarget" then
		local alpha = math.clamp((now - view.startAt) / view.duration, 0, 1)
		local eased = easeOutCubic(alpha)
		view.position = view.startPosition:Lerp(view.targetPosition, eased)
		view.holder.Position = view.position
		setGuiScale(view, view.displayScale + (view.scale - view.displayScale) * eased)
		if alpha >= 1 then
			view.phase = "Idle"
			view.position = view.targetPosition
			setGuiScale(view, view.scale)
		end
	elseif view.phase == "MergeConsumed" then
		local alpha = math.clamp((now - view.startAt) / view.duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ MERGE_EASE_POWER
		view.holder.Position = view.startPosition:Lerp(view.targetPosition, eased)
		setGuiScale(view, view.scale * math.max(0.08, 1 - eased))
		view.image.ImageTransparency = eased
		if alpha >= 1 then
			destroyView(view.id)
		end
	elseif view.phase == "Magnet" then
		local root = getPlayerRoot(view.playerUserId)
		if root then
			local alpha = math.clamp((now - view.startAt) / view.duration, 0, 1)
			-- Start moving immediately, then hand off to the stronger power curve for a responsive accelerating snap.
			local eased = alpha * MAGNET_INITIAL_PULL + alpha ^ MAGNET_EASE_POWER * (1 - MAGNET_INITIAL_PULL)
			local destination = root.Position + Vector3.new(0, 1.25, 0)
			view.position = view.startPosition:Lerp(destination, eased)
			view.holder.Position = view.position
			setGuiScale(view, view.scale * (1 + math.sin(alpha * math.pi) * 0.18))
		end
	elseif view.phase == "Collected" then
		local alpha = math.clamp((now - view.startAt) / COLLECTED_POP_DURATION, 0, 1)
		setGuiScale(view, view.scale * (1 + alpha * 0.48))
		view.image.ImageTransparency = alpha
		view.valueLabel.TextTransparency = alpha
		view.valueLabel.TextStrokeTransparency = alpha
		if alpha >= 1 then
			destroyView(view.id)
		end
	end
end

function CoinDropController.SpawnCoins(_, packets)
	if type(packets) ~= "table" then
		return
	end
	local playedSound = false
	for _, packet in packets do
		if type(packet) == "table"
			and type(packet.id) == "number"
			and type(packet.value) == "number"
			and typeof(packet.origin) == "Vector3"
			and typeof(packet.targetPosition) == "Vector3"
		then
			local view = createView(packet.id, packet.value, packet.origin, packet.scale or 1)
			view.phase = "Scatter"
			view.startPosition = packet.origin
			view.targetPosition = packet.targetPosition
			view.startAt = packet.launchAt or Workspace:GetServerTimeNow()
			view.duration = math.max(packet.duration or 0.6, 0.05)
			view.arcHeight = packet.arcHeight or 4
			view.trail.Enabled = true
			if not playedSound then
				Sounds.Play("Coin", view.holder, 90)
				playedSound = true
			end
		end
	end
end

function CoinDropController.MergeCoins(_, packet)
	if type(packet) ~= "table" or type(packet.targetId) ~= "number" or typeof(packet.position) ~= "Vector3" then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local duration = math.max(packet.duration or 0.28, 0.05)
	local target = coinViews[packet.targetId]
	if target then
		target.phase = "MergeTarget"
		target.startPosition = target.holder.Position
		target.targetPosition = packet.position
		target.startAt = now
		target.duration = duration
		updateValuePresentation(target, packet.value or target.value, packet.scale or target.scale)
	end
	if type(packet.consumedIds) == "table" then
		for _, id in packet.consumedIds do
			local consumed = coinViews[id]
			if consumed then
				consumed.phase = "MergeConsumed"
				consumed.startPosition = consumed.holder.Position
				consumed.targetPosition = packet.position
				consumed.startAt = now
				consumed.duration = duration
				consumed.trail.Enabled = true
			end
		end
	end
end

function CoinDropController.CollectCoin(_, id, userId, startAt, duration)
	local view = type(id) == "number" and coinViews[id]
	if not view or type(userId) ~= "number" then
		return
	end
	view.phase = "Magnet"
	view.startPosition = view.holder.Position
	view.startAt = type(startAt) == "number" and startAt or Workspace:GetServerTimeNow()
	view.duration = math.max(type(duration) == "number" and duration or MAGNET_DURATION_FALLBACK, 0.05)
	view.playerUserId = userId
	view.trail.Enabled = true
end

function CoinDropController.ReleaseCoin(_, id, position)
	local view = type(id) == "number" and coinViews[id]
	if not view or typeof(position) ~= "Vector3" then
		return
	end
	view.phase = "MergeTarget"
	view.startPosition = view.holder.Position
	view.targetPosition = position
	view.position = position
	view.startAt = Workspace:GetServerTimeNow()
	view.duration = 0.22
	view.playerUserId = nil
	view.trail.Enabled = false
end

function CoinDropController.CoinCollected(_, id, userId, _value)
	local view = type(id) == "number" and coinViews[id]
	if not view then
		return
	end
	view.phase = "Collected"
	view.startAt = Workspace:GetServerTimeNow()
	view.trail.Enabled = false
	if userId == Players.LocalPlayer.UserId then
		Sounds.Play("CoinCollect", Players.LocalPlayer.PlayerGui)
	end
end

function CoinDropController.CoinValueChanged(_, id, value, position, scale)
	local view = type(id) == "number" and coinViews[id]
	if not view or type(value) ~= "number" or typeof(position) ~= "Vector3" then
		return
	end
	view.position = position + Vector3.new(0, 0.35, 0)
	view.targetPosition = view.position
	updateValuePresentation(view, value, type(scale) == "number" and scale or nil)
	setGuiScale(view, view.scale)
end

function CoinDropController.DespawnCoins(_, ids)
	if type(ids) ~= "table" then
		return
	end
	for _, id in ids do
		if type(id) == "number" then
			destroyView(id)
		end
	end
end

local function renderCoins()
	local now = Workspace:GetServerTimeNow()
	for _, view in coinViews do
		renderView(view, now)
	end
end

function CoinDropController.Init()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	table.clear(coinViews)
	local oldFolder = Workspace:FindFirstChild("ClientCoinDrops")
	if oldFolder then
		oldFolder:Destroy()
	end
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "ClientCoinDrops"
	effectsFolder.Parent = Workspace

	coinNetwork = Networker.client.new("CoinDropController", CoinDropController)
	local snapshot = coinNetwork:fetch("GetSnapshot")
	if type(snapshot) == "table" then
		for _, packet in snapshot do
			if type(packet) == "table"
				and type(packet.id) == "number"
				and type(packet.value) == "number"
				and typeof(packet.position) == "Vector3"
			then
				createView(packet.id, packet.value, packet.position, packet.scale or 1)
			end
		end
	end
	renderConnection = RunService.RenderStepped:Connect(renderCoins)
end

return CoinDropController
