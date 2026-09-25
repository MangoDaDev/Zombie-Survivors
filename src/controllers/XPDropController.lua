local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local IDLE_BOB_HEIGHT = 0.28
local IDLE_BOB_SPEED = 2.6
local IDLE_SPIN_SPEED = 1.6
local MAGNET_ACCELERATION = 5.4

type XPView = {
	id: number,
	value: number,
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
}

local XPDropController = {}

local xpNetwork
local effectsFolder: Folder?
local renderConnection: RBXScriptConnection?
local views: { [number]: XPView } = {}

local function getRoot(userId: number?): BasePart?
	local player = userId and Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function destroyView(id: number)
	local view = views[id]
	if view then
		views[id] = nil
		view.model:Destroy()
	end
end

local function applyValueStyle(view: XPView, value: number, scale: number)
	view.value = value
	view.model:ScaleTo(scale)
	local tier = RunProgressionConfig.GetXPVisualTier(value)
	local color = tier.Color
	for _, descendant in view.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
	local light = view.model:FindFirstChild("XPGlow", true)
	if light and light:IsA("PointLight") then
		light.Color = color
	end
	local highlight = view.model:FindFirstChild("XPHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.FillColor = color
		highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.35)
	end
end

local function createView(id: number, value: number, position: Vector3, scale: number): XPView
	local existing = views[id]
	if existing then
		applyValueStyle(existing, value, scale)
		return existing
	end

	local template = ReplicatedStorage.Assets.Models.Pickups.XPCrystal
	local model = template:Clone()
	model.Name = "XP_" .. tostring(id)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local rootPart = model:FindFirstChildWhichIsA("BasePart", true)
	if rootPart then
		local light = Instance.new("PointLight")
		light.Name = "XPGlow"
		light.Brightness = 2.4
		light.Range = 12
		light.Shadows = false
		light.Parent = rootPart
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "XPHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 0.72
	highlight.OutlineTransparency = 0.12
	highlight.Parent = model
	model:PivotTo(CFrame.new(position))
	model.Parent = effectsFolder

	local view: XPView = {
		id = id,
		value = value,
		model = model,
		phase = "Idle",
		position = position,
		startPosition = position,
		targetPosition = position,
		startAt = 0,
		duration = 0,
		arcHeight = 0,
		rotation = (id % 13) * 0.37,
		bobOffset = (id % 11) * 0.51,
		collectorUserId = nil,
	}
	views[id] = view
	applyValueStyle(view, value, scale)
	return view
end

local function renderView(view: XPView, now: number, deltaTime: number)
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
	elseif view.phase == "Idle" then
		view.position = view.targetPosition
	elseif view.phase == "Magnet" then
		local root = getRoot(view.collectorUserId)
		if root then
			local destination = root.Position + Vector3.new(0, 1.25, 0)
			local alpha = 1 - math.exp(-MAGNET_ACCELERATION * deltaTime)
			view.position = view.position:Lerp(destination, alpha)
		end
	end

	local bob = if view.phase == "Idle"
		then math.sin(now * IDLE_BOB_SPEED + view.bobOffset) * IDLE_BOB_HEIGHT
		else 0
	view.model:PivotTo(CFrame.new(view.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, view.rotation, 0))
end

function XPDropController.SpawnXP(_, packet)
	if type(packet) ~= "table"
		or type(packet.id) ~= "number"
		or type(packet.value) ~= "number"
		or typeof(packet.origin) ~= "Vector3"
		or typeof(packet.position) ~= "Vector3"
	then
		return
	end
	local view = createView(packet.id, packet.value, packet.origin, packet.scale or 1)
	view.phase = "Scatter"
	view.startPosition = packet.origin
	view.targetPosition = packet.position
	view.position = packet.origin
	view.startAt = packet.launchAt or Workspace:GetServerTimeNow()
	view.duration = math.max(packet.duration or 0.45, 0.05)
	view.arcHeight = packet.arcHeight or 3
end

function XPDropController.MagnetXP(_, id, userId, position, _startAt)
	local view = type(id) == "number" and views[id]
	if not view or type(userId) ~= "number" then
		return
	end
	if typeof(position) == "Vector3" then
		view.position = position
	end
	view.phase = "Magnet"
	view.collectorUserId = userId
end

function XPDropController.ReleaseXP(_, id, position)
	local view = type(id) == "number" and views[id]
	if not view or typeof(position) ~= "Vector3" then
		return
	end
	view.phase = "Idle"
	view.position = position
	view.targetPosition = position
	view.collectorUserId = nil
end

function XPDropController.XPCollected(_, id, userId, _value)
	if type(id) ~= "number" then
		return
	end
	if userId == Players.LocalPlayer.UserId then
		Sounds.Play("Gem", Players.LocalPlayer.PlayerGui)
	end
	destroyView(id)
end

function XPDropController.XPValueChanged(_, id, value, scale)
	local view = type(id) == "number" and views[id]
	if view and type(value) == "number" then
		applyValueStyle(view, value, type(scale) == "number" and scale or 1)
	end
end

function XPDropController.DespawnXP(_, ids)
	if type(ids) ~= "table" then
		return
	end
	for _, id in ids do
		if type(id) == "number" then
			destroyView(id)
		end
	end
end

local function render(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for _, view in views do
		renderView(view, now, deltaTime)
	end
end

function XPDropController.Init()
	if renderConnection then
		renderConnection:Disconnect()
	end
	for id in views do
		destroyView(id)
	end
	local oldFolder = Workspace:FindFirstChild("ClientXPDrops")
	if oldFolder then
		oldFolder:Destroy()
	end
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "ClientXPDrops"
	effectsFolder.Parent = Workspace

	xpNetwork = Networker.client.new("XPDropController", XPDropController)
	local snapshot = xpNetwork:fetch("GetSnapshot")
	if type(snapshot) == "table" then
		for _, packet in snapshot do
			if type(packet) == "table"
				and type(packet.id) == "number"
				and type(packet.value) == "number"
				and typeof(packet.position) == "Vector3"
			then
				local view = createView(packet.id, packet.value, packet.position, packet.scale or 1)
				if type(packet.collectorUserId) == "number" then
					view.phase = "Magnet"
					view.collectorUserId = packet.collectorUserId
				end
			end
		end
	end
	renderConnection = RunService.RenderStepped:Connect(render)
end

return XPDropController
