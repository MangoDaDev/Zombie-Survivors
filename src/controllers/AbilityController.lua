local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local AbilityDefinitions = require(ReplicatedStorage.Modules.Game.Abilities.AbilityDefinitions)
local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local AbilityController = {}

local dataService
local abilityNetwork: Networker.Client?
local effectsFolder: Folder?
local renderConnection: RBXScriptConnection?
local inventoryOpen = false
local projectiles = {}

local stateChanged = Signal.new()
local inventoryOpenChanged = Signal.new()
local abilityDiscovered = Signal.new()
local actionResult = Signal.new()

local function getEmptyData()
	return {
		Owned = {},
		Levels = {},
		Equipped = {
			Weapon = {},
			Passive = {},
		},
	}
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function emitAt(position: Vector3, flashCount: number, sparkCount: number)
	if not effectsFolder then
		return nil
	end

	local holder = Instance.new("Part")
	holder.Name = "DaggerEffect"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Transparency = 1
	holder.Position = position
	holder.Parent = effectsFolder

	local template = ReplicatedStorage.Assets.VFX.CriticalHit.Impact
	for _, child in template:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			emitter.Parent = holder
			emitter:Emit(if child.Name == "Flash" then flashCount else sparkCount)
		end
	end
	Debris:AddItem(holder, 2)
	return holder
end

local function getFlightCFrame(position: Vector3, targetPosition: Vector3, spin: number): CFrame
	local direction = targetPosition - position
	if direction.Magnitude < 0.001 then
		direction = Vector3.zAxis
	end
	-- The inspected Dagger model points down local +Y, so this aligns its blade with travel direction.
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, spin, 0)
end

local function addTrail(model: Model)
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		return
	end

	local front = Instance.new("Attachment")
	front.Name = "TrailFront"
	front.Position = Vector3.new(0, 0.42, 0)
	front.Parent = primaryPart
	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, -0.42, 0)
	back.Parent = primaryPart
	local trail = Instance.new("Trail")
	trail.Name = "FlightTrail"
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = ColorSequence.new(Color3.fromRGB(205, 236, 255), Color3.fromRGB(95, 183, 255))
	trail.LightEmission = 0.8
	trail.Lifetime = 0.12
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new(0.18, 1)
	trail.Parent = primaryPart
end

local function spawnDagger(packet)
	if not effectsFolder then
		return
	end
	local template = ReplicatedStorage.Assets.Models.Abilities:FindFirstChild("Dagger")
	if not template or not template:IsA("Model") then
		return
	end

	local model = template:Clone()
	model.Name = "DaggerProjectile"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	model:ScaleTo(packet.scale)
	addTrail(model)
	model:PivotTo(getFlightCFrame(packet.startPosition, packet.targetPosition, 0))
	model.Parent = effectsFolder

	local launchEffect = emitAt(packet.startPosition, 0, 3)
	if launchEffect then
		Sounds.Play("Swoosh", launchEffect, 120)
	end
	table.insert(projectiles, {
		model = model,
		startPosition = packet.startPosition,
		targetPosition = packet.targetPosition,
		launchAt = packet.launchAt,
		duration = packet.duration,
	})
end

local function renderProjectiles()
	local now = Workspace:GetServerTimeNow()
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local alpha = math.clamp((now - projectile.launchAt) / projectile.duration, 0, 1)
		local position = projectile.startPosition:Lerp(projectile.targetPosition, alpha)
		position += Vector3.yAxis * math.sin(alpha * math.pi) * 0.55
		local spin = alpha * math.pi * 2.4
		projectile.model:PivotTo(getFlightCFrame(position, projectile.targetPosition, spin))

		if alpha >= 1 then
			local impactEffect = emitAt(projectile.targetPosition, 1, 8)
			if impactEffect then
				Sounds.Play("BulletHit", impactEffect, 120)
			end
			projectile.model:Destroy()
			table.remove(projectiles, index)
		end
	end
end

function AbilityController.AbilityDiscovered(_, abilityId, revealAt, autoRollWasPaused)
	if type(abilityId) ~= "string"
		or not AbilityDefinitions.ById[abilityId]
		or not isFiniteNumber(revealAt)
		or type(autoRollWasPaused) ~= "boolean"
	then
		return
	end

	local delayDuration = math.max(revealAt - Workspace:GetServerTimeNow(), 0)
	task.delay(delayDuration, function()
		abilityDiscovered:Fire(abilityId, autoRollWasPaused)
	end)
end

function AbilityController.ActionResult(_, success, message, milestone)
	if type(success) ~= "boolean" or type(message) ~= "string" or type(milestone) ~= "boolean" then
		return
	end
	if milestone then
		Sounds.Play("SlotsJackpot", Players.LocalPlayer.PlayerGui)
	end
	actionResult:Fire(success, message, milestone)
	NotificationManager.Notify(
		message,
		if milestone then 4 else 2.5,
		if milestone then UIStyle.Colors.Gold elseif success then UIStyle.Colors.Green else UIStyle.Colors.Red
	)
end

function AbilityController.DaggerThrown(_, packet)
	if type(packet) ~= "table"
		or typeof(packet.startPosition) ~= "Vector3"
		or typeof(packet.targetPosition) ~= "Vector3"
		or not isFiniteNumber(packet.launchAt)
		or not isFiniteNumber(packet.duration)
		or packet.duration <= 0
		or packet.duration > 1
		or not isFiniteNumber(packet.scale)
		or packet.scale <= 0
		or packet.scale > 1
	then
		return
	end

	local delayDuration = math.max(packet.launchAt - Workspace:GetServerTimeNow(), 0)
	task.delay(delayDuration, function()
		spawnDagger(packet)
	end)
end

function AbilityController.SetDataService(service)
	dataService = service
end

function AbilityController.Init()
	abilityNetwork = Networker.client.new("AbilityController", AbilityController)
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "AbilityEffects"
	effectsFolder.Parent = Workspace
	renderConnection = RunService.RenderStepped:Connect(renderProjectiles)
	dataService:getChangedSignal(AbilityDefinitions.DataKey):Connect(function()
		stateChanged:Fire(AbilityController.GetState())
	end)
end

function AbilityController.GetState()
	local state = dataService and dataService:get(AbilityDefinitions.DataKey)
	return if type(state) == "table" then state else getEmptyData()
end

function AbilityController.SetInventoryOpen(open: boolean)
	if type(open) ~= "boolean" or inventoryOpen == open then
		return
	end
	inventoryOpen = open
	inventoryOpenChanged:Fire(open)
end

function AbilityController.IsInventoryOpen(): boolean
	return inventoryOpen
end

function AbilityController.EquipAbility(abilityId: string)
	if abilityNetwork and AbilityDefinitions.ById[abilityId] then
		abilityNetwork:fire("EquipAbility", abilityId)
	end
end

function AbilityController.UnequipAbility(abilityId: string)
	if abilityNetwork and AbilityDefinitions.ById[abilityId] then
		abilityNetwork:fire("UnequipAbility", abilityId)
	end
end

function AbilityController.UpgradeAbility(abilityId: string)
	if abilityNetwork and AbilityDefinitions.ById[abilityId] then
		abilityNetwork:fire("UpgradeAbility", abilityId)
	end
end

function AbilityController.AcknowledgeDiscovery(abilityId: string)
	if abilityNetwork and AbilityDefinitions.ById[abilityId] then
		abilityNetwork:fire("AcknowledgeDiscovery", abilityId)
	end
end

function AbilityController.GetStateChangedSignal()
	return stateChanged
end

function AbilityController.GetInventoryOpenChangedSignal()
	return inventoryOpenChanged
end

function AbilityController.GetAbilityDiscoveredSignal()
	return abilityDiscovered
end

function AbilityController.GetActionResultSignal()
	return actionResult
end

return AbilityController
