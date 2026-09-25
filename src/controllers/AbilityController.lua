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
local ActiveWeaponEffects = require(script.Parent.Ability.ActiveWeaponEffects)
local CrowdWeaponEffects = require(script.Parent.Ability.CrowdWeaponEffects)
local OrbitingSwordsView = require(script.Parent.Ability.OrbitingSwordsView)
local PassiveEffectsView = require(script.Parent.Ability.PassiveEffectsView)

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

local function emitAt(position: Vector3, flashCount: number, sparkCount: number, rage: boolean?)
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
			if rage then
				emitter.Color = ColorSequence.new(Color3.fromRGB(255, 225, 92), Color3.fromRGB(255, 67, 28))
				emitter.LightEmission = 0.65
			end
			emitter.Parent = holder
			emitter:Emit(if child.Name == "Flash" then flashCount else sparkCount)
		end
	end
	if rage then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 101, 42)
		light.Brightness = 1.6
		light.Range = 6.5
		light.Parent = holder
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

local function addTrail(model: Model, rage: boolean)
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
	trail.Color = if rage
		then ColorSequence.new(Color3.fromRGB(255, 238, 105), Color3.fromRGB(255, 58, 25))
		else ColorSequence.new(Color3.fromRGB(205, 236, 255), Color3.fromRGB(95, 183, 255))
	trail.LightEmission = if rage then 0.82 else 0.8
	trail.Lifetime = if rage then 0.2 else 0.12
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new(0.18, 1)
	trail.WidthScale = if rage then NumberSequence.new(1.28, 0) else NumberSequence.new(1, 0)
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
	addTrail(model, packet.rage)
	if packet.rage then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RageDaggerGlow"
		highlight.Adornee = model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(255, 91, 35)
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = Color3.fromRGB(255, 231, 117)
		highlight.OutlineTransparency = 0.25
		highlight.Parent = model
	end
	model:PivotTo(getFlightCFrame(packet.startPosition, packet.targetPosition, 0))
	model.Parent = effectsFolder

	local launchEffect = emitAt(packet.startPosition, if packet.rage then 1 else 0, if packet.rage then 6 else 3, packet.rage)
	if launchEffect and packet.daggerIndex == 1 then
		Sounds.Play("Swoosh", launchEffect, 120)
	end
	table.insert(projectiles, {
		model = model,
		startPosition = packet.startPosition,
		targetPosition = packet.targetPosition,
		launchAt = packet.launchAt,
		duration = packet.duration,
		rage = packet.rage,
		daggerIndex = packet.daggerIndex,
	})
end

local function renderProjectiles(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local alpha = math.clamp((now - projectile.launchAt) / projectile.duration, 0, 1)
		local position = projectile.startPosition:Lerp(projectile.targetPosition, alpha)
		position += Vector3.yAxis * math.sin(alpha * math.pi) * 0.55
		local spin = alpha * math.pi * 2.4
		projectile.model:PivotTo(getFlightCFrame(position, projectile.targetPosition, spin))

		if alpha >= 1 then
			local impactEffect = emitAt(
				projectile.targetPosition,
				1,
				if projectile.rage then 11 else 8,
				projectile.rage
			)
			if impactEffect and projectile.daggerIndex == 1 then
				Sounds.Play("BulletHit", impactEffect, 120)
			end
			projectile.model:Destroy()
			table.remove(projectiles, index)
		end
	end
	ActiveWeaponEffects.Render(now, deltaTime)
	CrowdWeaponEffects.Render(now, deltaTime)
	OrbitingSwordsView.Render(now, deltaTime)
	PassiveEffectsView.Render()
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
		or type(packet.rage) ~= "boolean"
		or type(packet.daggerIndex) ~= "number"
		or packet.daggerIndex % 1 ~= 0
		or packet.daggerIndex < 1
	then
		return
	end

	local delayDuration = math.max(packet.launchAt - Workspace:GetServerTimeNow(), 0)
	task.delay(delayDuration, function()
		spawnDagger(packet)
	end)
end

function AbilityController.OrbitingSwordsState(_, packet)
	OrbitingSwordsView.ApplyState(packet)
end

function AbilityController.SwordReleased(_, packet)
	OrbitingSwordsView.SpawnReleased(packet)
end

function AbilityController.FireballSpawned(_, packet)
	ActiveWeaponEffects.FireballSpawned(packet)
end

function AbilityController.FireballExploded(_, packet)
	ActiveWeaponEffects.FireballExploded(packet)
end

function AbilityController.FireballBurnApplied(_, packet)
	ActiveWeaponEffects.FireballBurnApplied(packet)
end

function AbilityController.FireballBurnEnded(_, targetId)
	ActiveWeaponEffects.FireballBurnEnded(targetId)
end

function AbilityController.BlastTriggered(_, packet)
	if type(packet) ~= "table"
		or typeof(packet.position) ~= "Vector3"
		or not isFiniteNumber(packet.radius)
		or packet.radius <= 0
		or packet.radius > 20
		or type(packet.secondary) ~= "boolean"
	then
		return
	end
	PassiveEffectsView.BlastTriggered(packet)
end

function AbilityController.PassiveBurnApplied(_, packet)
	if type(packet) ~= "table"
		or type(packet.targetId) ~= "number"
		or packet.targetId % 1 ~= 0
		or packet.targetId < 1
		or not isFiniteNumber(packet.duration)
		or packet.duration <= 0
		or packet.duration > 15
	then
		return
	end
	PassiveEffectsView.BurnApplied(packet)
end

function AbilityController.PassiveBurnEnded(_, targetId)
	if type(targetId) == "number" and targetId % 1 == 0 and targetId >= 1 then
		PassiveEffectsView.BurnEnded(targetId)
	end
end

function AbilityController.ThornsTriggered(_, packet)
	if type(packet) ~= "table"
		or typeof(packet.playerPosition) ~= "Vector3"
		or typeof(packet.attackerPosition) ~= "Vector3"
		or not isFiniteNumber(packet.burstRadius)
		or packet.burstRadius < 0
		or packet.burstRadius > 15
	then
		return
	end
	PassiveEffectsView.ThornsTriggered(packet)
end

function AbilityController.FireballGroundCreated(_, packet)
	ActiveWeaponEffects.FireballGroundCreated(packet)
end

function AbilityController.FireballGroundRemoved(_, id)
	ActiveWeaponEffects.FireballGroundRemoved(id)
end

function AbilityController.LightningCast(_, packet)
	ActiveWeaponEffects.LightningCast(packet)
end

function AbilityController.BoomerangSpawned(_, packet)
	ActiveWeaponEffects.BoomerangSpawned(packet)
end

function AbilityController.BoomerangPhaseChanged(_, packet)
	ActiveWeaponEffects.BoomerangPhaseChanged(packet)
end

function AbilityController.BoomerangHit(_, packet)
	ActiveWeaponEffects.BoomerangHit(packet)
end

function AbilityController.BoomerangEnded(_, id)
	ActiveWeaponEffects.BoomerangEnded(id)
end

function AbilityController.AuraState(_, packet)
	CrowdWeaponEffects.AuraState(packet)
end

function AbilityController.AuraHit(_, packet)
	CrowdWeaponEffects.AuraHit(packet)
end

function AbilityController.AuraPulse(_, packet)
	CrowdWeaponEffects.AuraPulse(packet)
end

function AbilityController.BallSpawned(_, packet)
	CrowdWeaponEffects.BallSpawned(packet)
end

function AbilityController.BallRedirected(_, packet)
	CrowdWeaponEffects.BallRedirected(packet)
end

function AbilityController.BallHit(_, packet)
	CrowdWeaponEffects.BallHit(packet)
end

function AbilityController.BallEnded(_, id)
	CrowdWeaponEffects.BallEnded(id)
end

function AbilityController.DrillSpawned(_, packet)
	CrowdWeaponEffects.DrillSpawned(packet)
end

function AbilityController.DrillHit(_, packet)
	CrowdWeaponEffects.DrillHit(packet)
end

function AbilityController.DrillEnded(_, id)
	CrowdWeaponEffects.DrillEnded(id)
end

function AbilityController.MinePlaced(_, packet)
	CrowdWeaponEffects.MinePlaced(packet)
end

function AbilityController.MineTriggered(_, packet)
	CrowdWeaponEffects.MineTriggered(packet)
end

function AbilityController.MineExploded(_, packet)
	CrowdWeaponEffects.MineExploded(packet)
end

function AbilityController.MineRemoved(_, id)
	CrowdWeaponEffects.MineRemoved(id)
end

function AbilityController.PoisonCreated(_, packet)
	CrowdWeaponEffects.PoisonCreated(packet)
end

function AbilityController.PoisonRemoved(_, id)
	CrowdWeaponEffects.PoisonRemoved(id)
end

function AbilityController.AbilityEffectsCleared(_, ownerUserId, abilityId)
	ActiveWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
	CrowdWeaponEffects.AbilityEffectsCleared(ownerUserId, abilityId)
end

function AbilityController.SetDataService(service)
	dataService = service
end

function AbilityController.Init()
	abilityNetwork = Networker.client.new("AbilityController", AbilityController)
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "AbilityEffects"
	effectsFolder.Parent = Workspace
	ActiveWeaponEffects.Init(effectsFolder)
	CrowdWeaponEffects.Init(effectsFolder)
	OrbitingSwordsView.Init(effectsFolder)
	PassiveEffectsView.Init(effectsFolder)
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
