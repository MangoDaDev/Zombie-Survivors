local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BreakableConfig = require(script.Parent.Breakable.BreakableConfig)
local MapController = require(script.Parent.MapController)
local PowerupDropController = require(script.Parent.PowerupDropController)
local ServerContext = require(script.Parent.ServerContext)

type Breakable = {
	id: number,
	model: Model,
	baseCFrame: CFrame,
	position: Vector3,
	radius: number,
	health: number,
	feedbackSequence: number,
	nextFeedbackAt: number,
}

local BreakableController = {}

local random = Random.new()
local breakables: { [number]: Breakable } = {}
local nextId = 0
local runtimeFolder: Folder?
local started = false
local contextChangedConnection

local assets = ReplicatedStorage.Assets
local breakableTemplates = assets.Models.Breakables
local sounds = assets.Sounds

local function chooseTemplate()
	local totalWeight = 0
	for _, definition in BreakableConfig.Templates do
		totalWeight += definition.Weight
	end

	local roll = random:NextNumber(0, totalWeight)
	local runningWeight = 0
	for _, definition in BreakableConfig.Templates do
		runningWeight += definition.Weight
		if roll <= runningWeight then
			return definition
		end
	end
	return BreakableConfig.Templates[#BreakableConfig.Templates]
end

local function getBaseplate(activeMap: Instance): BasePart?
	local baseplate = activeMap:FindFirstChild("Baseplate")
	return if baseplate and baseplate:IsA("BasePart") then baseplate else nil
end

local function isPositionClear(position: Vector3): boolean
	local spawnCFrame = MapController.GetSpawnCFrame()
	if spawnCFrame then
		local spawnOffset = position - spawnCFrame.Position
		if Vector2.new(spawnOffset.X, spawnOffset.Z).Magnitude < BreakableConfig.SpawnSafeRadius then
			return false
		end
	end

	for _, breakable in breakables do
		local offset = position - breakable.position
		if Vector2.new(offset.X, offset.Z).Magnitude < BreakableConfig.MinimumSpacing + breakable.radius then
			return false
		end
	end
	return true
end

local function findSpawnCFrame(activeMap: Instance, baseplate: BasePart, modelHeight: number): CFrame?
	local halfSize = baseplate.Size * 0.5
	local margin = BreakableConfig.EdgeMargin
	if halfSize.X <= margin or halfSize.Z <= margin then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { activeMap }
	for _ = 1, BreakableConfig.PlacementAttempts do
		local localOffset = Vector3.new(
			random:NextNumber(-halfSize.X + margin, halfSize.X - margin),
			halfSize.Y + 30,
			random:NextNumber(-halfSize.Z + margin, halfSize.Z - margin)
		)
		local rayOrigin = baseplate.CFrame:PointToWorldSpace(localOffset)
		local hit = Workspace:Raycast(rayOrigin, -baseplate.CFrame.UpVector * 80, raycastParams)
		if hit and isPositionClear(hit.Position) then
			local yaw = random:NextNumber(0, math.pi * 2)
			return CFrame.new(hit.Position + hit.Normal * (modelHeight * 0.5 + 0.03))
				* CFrame.fromAxisAngle(hit.Normal, yaw)
		end
	end
	return nil
end

local function playSound(parent: BasePart, names: { string }, volume: number)
	local template = sounds:FindFirstChild(names[random:NextInteger(1, #names)])
	if not template or not template:IsA("Sound") then
		return
	end
	local sound = template:Clone()
	-- Authored sounds are reused, but runtime copies get restrained spatial settings so a break is local and punchy.
	sound.Volume = volume
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 85
	sound.PlaybackSpeed = random:NextNumber(0.94, 1.08)
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.5)
end

local function flashModel(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlash"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 232, 176)
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	Debris:AddItem(highlight, 0.09)
end

local function playHitFeedback(breakable: Breakable, hitOrigin: Vector3?)
	local now = Workspace:GetServerTimeNow()
	if now < breakable.nextFeedbackAt then
		return
	end
	breakable.nextFeedbackAt = now + BreakableConfig.HitFeedbackCooldown
	breakable.feedbackSequence += 1
	local sequence = breakable.feedbackSequence
	local primaryPart = breakable.model.PrimaryPart
	if primaryPart then
		playSound(primaryPart, BreakableConfig.HitSounds, 0.55)
	end
	flashModel(breakable.model)

	local kickDirection = Vector3.new(0, 0, -1)
	if typeof(hitOrigin) == "Vector3" then
		local offset = breakable.position - hitOrigin
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > 0.001 then
			kickDirection = horizontal.Unit
		end
	end
	local rotationAxis = Vector3.new(-kickDirection.Z, 0, kickDirection.X)
	breakable.model:PivotTo(
		(breakable.baseCFrame + kickDirection * BreakableConfig.HitKickDistance)
			* CFrame.fromAxisAngle(rotationAxis, math.rad(2.5))
	)
	task.delay(BreakableConfig.HitKickDuration, function()
		if breakables[breakable.id] == breakable and breakable.feedbackSequence == sequence then
			breakable.model:PivotTo(breakable.baseCFrame)
		end
	end)
end

local function fadeFragments(model: Model)
	task.delay(BreakableConfig.FragmentFadeDelay, function()
		if not model.Parent then
			return
		end
		local tweenInfo = TweenInfo.new(BreakableConfig.FragmentFadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				TweenService:Create(descendant, tweenInfo, { Transparency = 1 }):Play()
			end
		end
	end)
end

local function queueSpawn(delaySeconds: number)
	task.delay(delaySeconds, function()
		if not started or not runtimeFolder or not runtimeFolder.Parent then
			return
		end
		if not BreakableController.SpawnOne() then
			-- A crowded placement pass is temporary; retry instead of permanently lowering map density.
			queueSpawn(2)
		end
	end)
end

local function breakModel(breakable: Breakable, hitOrigin: Vector3?, knockbackImpulse: number?, owner: Player?)
	breakables[breakable.id] = nil
	breakable.feedbackSequence += 1
	local model = breakable.model
	local primaryPart = model.PrimaryPart
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	-- Every destroyed prop releases exactly one collectible; use its actual lower bound so tall authored
	-- models do not leave the reward floating above the floor.
	PowerupDropController.Spawn(breakable.position, boundingCFrame.Position.Y - boundingSize.Y * 0.5, owner)
	if primaryPart then
		playSound(primaryPart, BreakableConfig.BreakSounds, 0.8)
	end
	flashModel(model)

	local impactDirection = Vector3.new(0, 0, -1)
	if typeof(hitOrigin) == "Vector3" then
		local offset = breakable.position - hitOrigin
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > 0.001 then
			impactDirection = horizontal.Unit
		end
	end
	local impulseSpeed = math.clamp((knockbackImpulse or 0) * 0.28, 2, 8)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
			if descendant ~= primaryPart and descendant.Transparency < 1 then
				descendant.Anchored = false
				-- Fragments are cosmetic and non-colliding so a satisfying break cannot shove players or block combat.
				descendant.CanCollide = false
				local scatter = Vector3.new(random:NextNumber(-6, 6), random:NextNumber(7, 13), random:NextNumber(-6, 6))
				descendant.AssemblyLinearVelocity = impactDirection * impulseSpeed + scatter
				descendant.AssemblyAngularVelocity = Vector3.new(
					random:NextNumber(-9, 9),
					random:NextNumber(-9, 9),
					random:NextNumber(-9, 9)
				)
			end
		end
	end
	fadeFragments(model)
	Debris:AddItem(model, BreakableConfig.FragmentLifetime)

	local respawnDelay = random:NextNumber(BreakableConfig.RespawnDelay.Min, BreakableConfig.RespawnDelay.Max)
	queueSpawn(respawnDelay)
end

function BreakableController.SpawnOne(): boolean
	local activeMap = MapController.GetActiveMap()
	local folder = runtimeFolder
	if not activeMap or not folder then
		return false
	end
	local baseplate = getBaseplate(activeMap)
	if not baseplate then
		warn("BreakableController could not find the active Game map's Baseplate")
		return false
	end

	local definition = chooseTemplate()
	local template = breakableTemplates:FindFirstChild(definition.Name)
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn(string.format("BreakableController could not use breakable model %s", definition.Name))
		return false
	end
	local _, modelSize = template:GetBoundingBox()
	local spawnCFrame = findSpawnCFrame(activeMap, baseplate, modelSize.Y)
	if not spawnCFrame then
		return false
	end

	nextId += 1
	local model = template:Clone()
	model.Name = string.format("%s_%d", definition.Name, nextId)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	model:PivotTo(spawnCFrame)
	model.Parent = folder

	local radius = math.max(modelSize.X, modelSize.Z) * 0.5
	breakables[nextId] = {
		id = nextId,
		model = model,
		baseCFrame = spawnCFrame,
		position = spawnCFrame.Position,
		radius = radius,
		health = definition.MaxHealth,
		feedbackSequence = 0,
		nextFeedbackAt = 0,
	}
	return true
end

local function startSpawning()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = BreakableConfig.RuntimeFolderName
	folder.Parent = Workspace
	runtimeFolder = folder

	-- Breakables are a Game-mode invariant: populate the active map once, then replace each destroyed prop.
	for _ = 1, BreakableConfig.SpawnCount do
		if not BreakableController.SpawnOne() then
			queueSpawn(2)
		end
	end
end

function BreakableController.DamageBreakable(
	id: number,
	amount: number,
	hitOrigin: Vector3?,
	knockbackImpulse: number?,
	owner: Player?
): (boolean, boolean)
	local breakable = breakables[id]
	if not breakable or type(amount) ~= "number" or amount <= 0 then
		return false, false
	end
	local actualDamage = math.min(amount, breakable.health)
	breakable.health -= actualDamage
	local killed = breakable.health <= 0
	if killed then
		breakModel(breakable, hitOrigin, knockbackImpulse, owner)
	else
		playHitFeedback(breakable, hitOrigin)
	end
	return actualDamage > 0, killed
end

function BreakableController.GetBreakablesInRadius(position: Vector3, maximumDistance: number, maximumCount: number?)
	local candidates = {}
	local countLimit = maximumCount or math.huge
	for id, breakable in breakables do
		local offset = breakable.position - position
		local horizontalDistance = Vector2.new(offset.X, offset.Z).Magnitude
		if math.abs(offset.Y) <= 10 and horizontalDistance <= maximumDistance + breakable.radius then
			table.insert(candidates, {
				id = id,
				position = breakable.position,
				radius = breakable.radius,
				distance = horizontalDistance,
			})
		end
	end
	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)
	for index = #candidates, countLimit + 1, -1 do
		table.remove(candidates, index)
	end
	return candidates
end

function BreakableController.Init()
	if ServerContext.IsGameServer() then
		startSpawning()
	elseif RunService:IsStudio() then
		contextChangedConnection = ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then
				startSpawning()
				contextChangedConnection:Disconnect()
				contextChangedConnection = nil
			end
		end)
	end
end

return BreakableController
