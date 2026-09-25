local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local PowerupConfig = require(ReplicatedStorage.Modules.Game.PowerupConfig)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local IDLE_BOB_HEIGHT = 0.32
local IDLE_BOB_SPEED = 2.8
local IDLE_SPIN_SPEED = 1.8
local COLLECTION_DURATION = 0.24

type PowerupView = {
	id: number,
	powerupId: string,
	model: Model,
	phase: string,
	position: Vector3,
	startPosition: Vector3,
	targetPosition: Vector3,
	startAt: number,
	duration: number,
	arcHeight: number,
	rotation: number,
	bobOffset: number,
	collectorUserId: number?,
	despawnAt: number,
}

type ActiveEffect = {
	powerupId: string,
	userId: number,
	model: Model,
	highlight: Highlight?,
	endsAt: number,
	rotation: number,
}

local PowerupDropController = {}

local localPlayer = Players.LocalPlayer
local powerupNetwork
local effectsFolder: Folder?
local renderConnection: RBXScriptConnection?
local views: { [number]: PowerupView } = {}
local activeEffects: { [string]: ActiveEffect } = {}

local function getLiveRoot(userId: number): (Model?, BasePart?)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, root
	end
	return nil, nil
end

local function prepareModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

local function destroyView(id: number)
	local view = views[id]
	if view then
		views[id] = nil
		view.model:Destroy()
	end
end

local function createView(id: number, powerupId: string, position: Vector3, despawnAt: number): PowerupView?
	local existing = views[id]
	if existing then
		return existing
	end
	local definition = PowerupConfig.Definitions[powerupId]
	local pickupFolder = ReplicatedStorage.Assets.Models.Pickups
	local template = definition and pickupFolder:FindFirstChild(definition.ModelName)
	if not definition or not template or not template:IsA("Model") then
		warn(string.format("Missing power-up model for %s", tostring(powerupId)))
		return nil
	end

	local model = template:Clone()
	model.Name = string.format("%s_%d", powerupId, id)
	prepareModel(model)
	local rootPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if rootPart then
		local light = Instance.new("PointLight")
		light.Name = "PowerupGlow"
		light.Color = definition.Color
		light.Brightness = 2.2
		light.Range = 13
		light.Shadows = false
		light.Parent = rootPart
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "PowerupHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = definition.Color
	highlight.FillTransparency = 0.74
	highlight.OutlineColor = definition.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.OutlineTransparency = 0.08
	highlight.Parent = model
	model:PivotTo(CFrame.new(position))
	model.Parent = effectsFolder

	local view: PowerupView = {
		id = id,
		powerupId = powerupId,
		model = model,
		phase = "Idle",
		position = position,
		startPosition = position,
		targetPosition = position,
		startAt = 0,
		duration = 0,
		arcHeight = 0,
		rotation = (id % 17) * 0.39,
		bobOffset = (id % 13) * 0.47,
		collectorUserId = nil,
		despawnAt = despawnAt,
	}
	views[id] = view
	return view
end

local function renderView(view: PowerupView, now: number, deltaTime: number)
	view.rotation += IDLE_SPIN_SPEED * deltaTime
	if view.phase == "Scatter" then
		local alpha = math.clamp((now - view.startAt) / view.duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		view.position = view.startPosition:Lerp(view.targetPosition, eased)
			+ Vector3.new(0, math.sin(alpha * math.pi) * view.arcHeight, 0)
		if alpha >= 1 then
			view.phase = "Idle"
			view.position = view.targetPosition
		end
	elseif view.phase == "Collect" then
		local root
		if view.collectorUserId then
			local _, resolvedRoot = getLiveRoot(view.collectorUserId)
			root = resolvedRoot
		end
		if root then
			local alpha = math.clamp((now - view.startAt) / COLLECTION_DURATION, 0, 1)
			view.position = view.startPosition:Lerp(root.Position + Vector3.new(0, 1.5, 0), alpha ^ 2)
		end
		if now - view.startAt >= COLLECTION_DURATION then
			destroyView(view.id)
			return
		end
	else
		view.position = view.targetPosition
	end

	local bob = if view.phase == "Idle"
		then math.sin(now * IDLE_BOB_SPEED + view.bobOffset) * IDLE_BOB_HEIGHT
		else 0
	view.model:PivotTo(CFrame.new(view.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, view.rotation, 0))
	local highlight = view.model:FindFirstChild("PowerupHighlight")
	if highlight and highlight:IsA("Highlight") and view.despawnAt - now < 3 then
		highlight.Enabled = math.floor(now * 8) % 2 == 0
	end
end

local function createPulse(position: Vector3, color: Color3, radius: number)
	local ring = Instance.new("Part")
	ring.Name = "PowerupPulse"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.12
	ring.Size = Vector3.new(0.16, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi * 0.5)
	ring.Parent = effectsFolder
	TweenService:Create(
		ring,
		TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.16, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.55)

	local burst = Instance.new("Part")
	burst.Name = "PowerupBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CastShadow = false
	burst.Shape = Enum.PartType.Ball
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Transparency = 0.38
	burst.Size = Vector3.one * 1.5
	burst.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	burst.Parent = effectsFolder
	TweenService:Create(
		burst,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * math.min(radius, 14), Transparency = 1 }
	):Play()
	Debris:AddItem(burst, 0.38)
end

local function flashCharacter(character: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "PowerupActivationFlash"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.FillTransparency = 0.25
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.5)
	highlight.OutlineTransparency = 0.05
	highlight.Parent = character
	TweenService:Create(highlight, TweenInfo.new(0.65), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(highlight, 0.7)
end

local function clearActiveEffect(key: string)
	local effect = activeEffects[key]
	if not effect then
		return
	end
	activeEffects[key] = nil
	effect.model:Destroy()
	if effect.highlight then
		effect.highlight:Destroy()
	end
end

local function addActiveEffect(powerupId: string, userId: number, endsAt: number)
	if powerupId ~= "GuardianHalo" and powerupId ~= "LuckySkull" and powerupId ~= "Stopwatch" then
		return
	end
	local key = tostring(userId) .. ":" .. powerupId
	clearActiveEffect(key)
	local definition = PowerupConfig.Definitions[powerupId]
	local template = ReplicatedStorage.Assets.Models.Pickups:FindFirstChild(definition.ModelName)
	if not template or not template:IsA("Model") then
		return
	end
	local model = template:Clone()
	model.Name = powerupId .. "Active"
	model:ScaleTo(if powerupId == "GuardianHalo" then 0.75 else 0.55)
	prepareModel(model)
	model.Parent = effectsFolder

	local character = select(1, getLiveRoot(userId))
	local highlight
	if character then
		highlight = Instance.new("Highlight")
		highlight.Name = powerupId .. "Aura"
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = definition.Color
		highlight.FillTransparency = 0.86
		highlight.OutlineColor = definition.Color
		highlight.OutlineTransparency = 0.25
		highlight.Parent = character
	end
	activeEffects[key] = {
		powerupId = powerupId,
		userId = userId,
		model = model,
		highlight = highlight,
		endsAt = endsAt,
		rotation = 0,
	}
end

local function renderActiveEffects(now: number, deltaTime: number)
	for key, effect in activeEffects do
		if now >= effect.endsAt then
			clearActiveEffect(key)
			continue
		end
		local character, root = getLiveRoot(effect.userId)
		if not character or not root then
			continue
		end
		if not effect.highlight or effect.highlight.Parent ~= character then
			if effect.highlight then
				effect.highlight:Destroy()
			end
			local definition = PowerupConfig.Definitions[effect.powerupId]
			local highlight = Instance.new("Highlight")
			highlight.Name = effect.powerupId .. "Aura"
			highlight.Adornee = character
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillColor = definition.Color
			highlight.FillTransparency = 0.86
			highlight.OutlineColor = definition.Color
			highlight.OutlineTransparency = 0.25
			highlight.Parent = character
			effect.highlight = highlight
		end
		effect.rotation += deltaTime * (if effect.powerupId == "GuardianHalo" then 2.4 else 1.35)
		local offset = if effect.powerupId == "GuardianHalo"
			then Vector3.new(0, 4.1, 0)
			else Vector3.new(
				if effect.powerupId == "Stopwatch" then 2.1 else -2.1,
				2.25 + math.sin(now * 2.8) * 0.2,
				0
			)
		effect.model:PivotTo(CFrame.new(root.Position + offset) * CFrame.Angles(0, effect.rotation, 0))
	end
end

function PowerupDropController.SpawnPowerup(_, packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.powerupId) ~= "string"
		or typeof(packet.origin) ~= "Vector3"
		or typeof(packet.position) ~= "Vector3"
	then
		return
	end
	local view = createView(packet.id, packet.powerupId, packet.origin, packet.despawnAt or math.huge)
	if not view then
		return
	end
	view.phase = "Scatter"
	view.startPosition = packet.origin
	view.targetPosition = packet.position
	view.position = packet.origin
	view.startAt = packet.launchAt or Workspace:GetServerTimeNow()
	view.duration = math.max(packet.duration or 0.5, 0.05)
	view.arcHeight = packet.arcHeight or 4
	local definition = PowerupConfig.Definitions[packet.powerupId]
	if definition then
		-- The colored ground burst makes the reward reveal legible through the existing prop fragments.
		createPulse(packet.origin, definition.Color, 5)
	end
end

function PowerupDropController.PowerupCollected(_, id, userId, powerupId, position, endsAt)
	if type(id) ~= "number"
		or type(userId) ~= "number"
		or type(powerupId) ~= "string"
		or typeof(position) ~= "Vector3"
	then
		return
	end
	local definition = PowerupConfig.Definitions[powerupId]
	if not definition then
		return
	end
	local view = views[id]
	if view then
		view.phase = "Collect"
		view.collectorUserId = userId
		view.startPosition = view.position
		view.startAt = Workspace:GetServerTimeNow()
	end
	local character, root = getLiveRoot(userId)
	local effectPosition = root and root.Position or position
	createPulse(effectPosition, definition.Color, definition.PulseRadius)
	if character then
		flashCharacter(character, definition.Color)
	end
	if type(endsAt) == "number" and endsAt > Workspace:GetServerTimeNow() then
		addActiveEffect(powerupId, userId, endsAt)
	end
	if userId == localPlayer.UserId then
		NotificationManager.Notify(
			string.format("%s - %s", definition.DisplayName, definition.ActivationText),
			3.2,
			definition.Color
		)
		Sounds.Play(definition.SoundName, localPlayer.PlayerGui)
	end
end

function PowerupDropController.DespawnPowerups(_, ids)
	if type(ids) ~= "table" then
		return
	end
	for _, id in ids do
		if type(id) == "number" then
			destroyView(id)
		end
	end
end

function PowerupDropController.ClearPlayerPowerups(_, userId)
	if type(userId) ~= "number" then
		return
	end
	for key, effect in activeEffects do
		if effect.userId == userId then
			clearActiveEffect(key)
		end
	end
end

local function render(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for _, view in views do
		renderView(view, now, deltaTime)
	end
	renderActiveEffects(now, deltaTime)
end

function PowerupDropController.Init()
	if renderConnection then
		renderConnection:Disconnect()
	end
	for id in views do
		destroyView(id)
	end
	for key in activeEffects do
		clearActiveEffect(key)
	end
	local oldFolder = Workspace:FindFirstChild(PowerupConfig.RuntimeFolderName)
	if oldFolder then
		oldFolder:Destroy()
	end
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = PowerupConfig.RuntimeFolderName
	effectsFolder.Parent = Workspace

	powerupNetwork = Networker.client.new("PowerupDropController", PowerupDropController)
	local snapshot = powerupNetwork:fetch("GetSnapshot")
	if type(snapshot) == "table" then
		for _, packet in snapshot do
			if type(packet) == "table"
				and type(packet.id) == "number"
				and type(packet.powerupId) == "string"
				and typeof(packet.position) == "Vector3"
			then
				createView(packet.id, packet.powerupId, packet.position, packet.despawnAt or math.huge)
			end
		end
	end
	renderConnection = RunService.RenderStepped:Connect(render)
end

return PowerupDropController
