local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local TweenService = game:GetService "TweenService"
local Debris = game:GetService "Debris"
local Workspace = game:GetService "Workspace"

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
<<<<<<< HEAD
local StudVFX = require(ReplicatedStorage.Modules.UI.StudVFX)
=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
local ZombieView = require(script.Parent.Zombie.ZombieView)

local ZombieController = {}
local zombieNetwork
local renderConnection
local renderFolder
local zombieViews = {}
local renderParts = {}
local renderCFrames = {}
local TAU = math.pi * 2
local bossState = {
	active = false,
	id = nil,
	typeName = nil,
	displayName = "",
	hint = "",
	color = Color3.fromRGB(195, 48, 61),
	health = 0,
	maximumHealth = 0,
}
local bossStateChanged = Signal.new()
local STUD_EFFECT_KINDS = {
	BossSummon = true,
	BossEnrage = true,
	BossEruption = true,
	PlagueBurst = true,
	WardenAura = true,
	Feast = true,
	HexBurst = true,
	AnchorTether = true,
	FrostCone = true,
	Rally = true,
	Steal = true,
	Hatch = true,
	MartyrBuff = true,
}

local function setBossState(active: boolean, id: number?, typeName: string?, health: number?, maximumHealth: number?)
	local definition = typeName and ZombieDefinitions[typeName] or nil
	local nextMaximumHealth = if type(maximumHealth) == "number" then math.max(maximumHealth, 0) else 0
	local nextHealth = if type(health) == "number" then math.clamp(health, 0, nextMaximumHealth) else 0
	if bossState.active == active
		and bossState.id == id
		and bossState.typeName == typeName
		and bossState.health == nextHealth
		and bossState.maximumHealth == nextMaximumHealth
	then
		return
	end
	bossState = {
		active = active,
		id = id,
		typeName = typeName,
		displayName = if definition then definition.DisplayName or "Boss" else "",
		hint = if definition then definition.BossHint or "" else "",
		color = if definition and typeof(definition.EffectColor) == "Color3"
			then definition.EffectColor
			else Color3.fromRGB(195, 48, 61),
		health = nextHealth,
		maximumHealth = nextMaximumHealth,
	}
	bossStateChanged:Fire(bossState)
end

local function addZombie(packet, serverTime)
	if type(packet) ~= "table" then
		return
	end

	local id, typeName, initialCFrame, state, attackSequence, attackStartedAt, scale, animationSpeedMultiplier, health, maximumHealth,
		specialState, specialSequence, specialStartedAt, specialTarget, specialValue =
		table.unpack(packet)
	if type(id) ~= "number" or type(typeName) ~= "string" or typeof(initialCFrame) ~= "CFrame" then
		return
	end

	local definition = ZombieDefinitions[typeName]
	local template = definition and ReplicatedStorage.Assets.Models.Zombies:FindFirstChild(definition.AssetName)
	if not definition or not template or not template:IsA "Model" then
		warn(string.format("Cannot render unknown zombie type %s", tostring(typeName)))
		return
	end
	if definition.IsBoss then
		setBossState(true, id, typeName, health or definition.MaxHealth, maximumHealth or definition.MaxHealth)
	end

	local existing = zombieViews[id]
	if existing then
		existing:Update(
			initialCFrame,
			state,
			attackSequence,
			attackStartedAt,
			health,
			maximumHealth,
			specialState,
			specialSequence,
			specialStartedAt,
			specialTarget,
			specialValue,
			serverTime,
			os.clock()
		)
		return
	end

	zombieViews[id] = ZombieView.new(
		id,
		typeName,
		definition,
		template,
		initialCFrame,
		state,
		attackSequence,
		attackStartedAt,
		scale,
		animationSpeedMultiplier,
		health,
		maximumHealth,
		specialState,
		specialSequence,
		specialStartedAt,
		specialTarget,
		specialValue,
		serverTime,
		renderFolder
	)
end

local function updateZombie(packet, serverTime, receivedAt)
	if type(packet) ~= "table" then
		return
	end

	local id, targetCFrame, state, attackSequence, attackStartedAt, health, maximumHealth,
		specialState, specialSequence, specialStartedAt, specialTarget, specialValue = table.unpack(packet)
	local view = type(id) == "number" and zombieViews[id]
	if view and typeof(targetCFrame) == "CFrame" and type(state) == "number" then
		view:Update(
			targetCFrame,
			state,
			attackSequence,
			attackStartedAt,
			health,
			maximumHealth,
			specialState,
			specialSequence,
			specialStartedAt,
			specialTarget,
			specialValue,
			serverTime,
			receivedAt
		)
		if view.definition.IsBoss then
			setBossState(true, id, view.typeName, health, maximumHealth)
		end
	end
end

local function makeEffectPart(name, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 100, 75)
	part.Parent = renderFolder
	return part
end

local function makeStudEffectPart(name, color)
	local part = makeEffectPart(name, color)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	return part
end

local function playEffectSound(soundName: string, parent: Instance, playbackSpeed: number?)
	local template = Sounds.Get(soundName)
	if template then
		Sounds.Play(soundName, parent, nil, {
			PlaybackSpeed = template.PlaybackSpeed * (playbackSpeed or 1),
		})
	end
end

local function playBossDeathShockwave(packet)
	local center = packet.Position + Vector3.yAxis * 0.2
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(195, 48, 61)
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 20, 180) else 150
	local duration = if type(packet.Duration) == "number" then math.clamp(packet.Duration, 0.6, 2) else 1.15
	local segmentCount = 24
<<<<<<< HEAD
	StudVFX.Flash(renderFolder, center + Vector3.yAxis * 1.2, color, 12, duration * 0.55)
	StudVFX.Ring(renderFolder, center, color, radius, duration, segmentCount)
	StudVFX.Burst(
		renderFolder,
		center + Vector3.yAxis * 1.5,
		color,
		18,
		math.min(radius * 0.22, 22),
		duration * 0.8,
		color:Lerp(Color3.new(1, 1, 1), 0.48)
	)
=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3

	local burst = makeStudEffectPart("BossDeathBurst", color:Lerp(Color3.new(1, 1, 1), 0.25))
	burst.CFrame = CFrame.new(center)
	burst.Size = Vector3.new(4, 0.5, 4)
	burst.Transparency = 0.05
	TweenService:Create(
		burst,
		TweenInfo.new(duration * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(22, 0.12, 22), Transparency = 1 }
	):Play()
	playEffectSound("FlameBurst", burst, 0.72)
	playEffectSound("Reward5", burst, 0.9)
	Debris:AddItem(burst, duration + 2)

	for index = 1, segmentCount do
		local angle = TAU * (index - 1) / segmentCount
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local startPosition = center + direction * 3
		local endPosition = center + direction * radius
		local segment = makeStudEffectPart("BossDeathShockwave", color)
		segment.CFrame = CFrame.lookAt(startPosition, center)
		segment.Size = Vector3.new(2.5, 0.32, 2)
		segment.Transparency = 0.08
		TweenService:Create(
			segment,
			TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.lookAt(endPosition, center),
				Size = Vector3.new(math.max(radius * TAU / segmentCount * 0.78, 4), 0.12, 3.5),
				Transparency = 1,
			}
		):Play()
		Debris:AddItem(segment, duration + 0.15)
	end

	for index = 1, 12 do
		local angle = TAU * (index - 1) / 12 + math.pi / 12
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spark = makeStudEffectPart("BossDeathSpark", color:Lerp(Color3.new(1, 1, 1), 0.35))
		spark.CFrame = CFrame.new(center + Vector3.yAxis * 1.5)
		spark.Size = Vector3.new(1.4, 1.4, 1.4)
		TweenService:Create(
			spark,
			TweenInfo.new(duration * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.new(center + direction * 24 + Vector3.yAxis * 8)
					* CFrame.Angles(angle, angle * 0.5, -angle),
				Transparency = 1,
			}
		):Play()
		Debris:AddItem(spark, duration)
	end
end

local function playBossEntrance(packet)
	local center = packet.Position + Vector3.yAxis * 0.08
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(195, 48, 61)
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 7, 18) else 9
	local duration = if type(packet.Duration) == "number" then math.clamp(packet.Duration, 1.5, 4) else 2.6
	local marker = makeStudEffectPart("BossEntranceMarker", color)
	marker.CFrame = CFrame.new(center)
	marker.Size = Vector3.new(radius * 2, 0.16, radius * 2)
	marker.Transparency = 0.62
<<<<<<< HEAD
	StudVFX.Ring(renderFolder, center + Vector3.yAxis * 0.04, color, radius, math.min(duration * 0.42, 0.9), 18)
=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
	playEffectSound("Alert", marker, 0.72)
	TweenService:Create(
		marker,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = Vector3.new(radius * 2.35, 0.28, radius * 2.35), Transparency = 0.18 }
	):Play()
	Debris:AddItem(marker, duration + 0.25)
	for layer = 1, 3 do
		task.delay((layer - 1) * duration * 0.24, function()
			if not renderFolder or not renderFolder.Parent then
				return
			end
			local dust = makeStudEffectPart("BossEntranceDust", Color3.fromRGB(116, 84, 53))
			dust.CFrame = CFrame.new(center + Vector3.yAxis * (0.04 + layer * 0.02))
			dust.Size = Vector3.new(radius * 0.45, 0.08, radius * 0.45)
			dust.Transparency = 0.42
			TweenService:Create(
				dust,
				TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(radius * (1.25 + layer * 0.25), 0.04, radius * (1.25 + layer * 0.25)), Transparency = 1 }
			):Play()
			Debris:AddItem(dust, 0.8)
		end)
	end

	-- Short, increasingly dense block bursts communicate digging without freezing player movement or
	-- creating physical debris. Every piece is local, non-colliding, and cleaned immediately after landing.
	task.spawn(function()
		local startedAt = os.clock()
		local burstIndex = 0
		while marker.Parent and os.clock() - startedAt < duration do
			burstIndex += 1
			local progress = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local shake = 0.08 + progress * 0.2
			marker.CFrame = CFrame.new(
				center + Vector3.new(math.sin(burstIndex * 2.17), 0, math.cos(burstIndex * 1.73)) * shake
			)
			local pieces = 2 + math.floor(progress * 4)
			for pieceIndex = 1, pieces do
				local angle = TAU * (pieceIndex / pieces) + burstIndex * 1.37
				local distance = radius * (0.25 + ((pieceIndex * 0.37 + progress) % 1) * 0.65)
				local startPosition = center + Vector3.new(math.cos(angle), 0.15, math.sin(angle)) * distance
				local debrisPart = makeStudEffectPart(
					"BossEntranceDebris",
					Color3.fromRGB(104, 72, 43):Lerp(color, progress * 0.2)
				)
				local size = 0.65 + progress * 0.75
				debrisPart.Size = Vector3.new(size, size, size)
				debrisPart.CFrame = CFrame.new(startPosition)
					* CFrame.Angles(angle, angle * 0.6, -angle * 0.35)
				TweenService:Create(
					debrisPart,
					TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						CFrame = CFrame.new(startPosition + Vector3.yAxis * (4 + progress * 5))
							* CFrame.Angles(angle + 1.2, angle * 1.5, angle),
						Transparency = 1,
					}
				):Play()
				Debris:AddItem(debrisPart, 0.48)
			end
			task.wait(math.max(0.12, 0.3 - progress * 0.16))
		end
	end)

	task.delay(math.max(duration - 0.18, 0), function()
		if not renderFolder or not renderFolder.Parent then
			return
		end
		local burst = makeStudEffectPart("BossEntranceBurst", color:Lerp(Color3.new(1, 1, 1), 0.2))
		burst.CFrame = CFrame.new(center)
		burst.Size = Vector3.new(3, 0.45, 3)
		playEffectSound("FlameBurst", burst, 0.68)
		TweenService:Create(
			burst,
			TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.new(radius * 2.6, 0.08, radius * 2.6), Transparency = 1 }
		):Play()
		Debris:AddItem(burst, 0.55)
	end)
end

local function playBossChargeTelegraph(packet)
	if typeof(packet.Target) ~= "Vector3" then
		return
	end
	local origin = packet.Position + Vector3.yAxis * 0.09
	local target = Vector3.new(packet.Target.X, origin.Y, packet.Target.Z)
	local offset = target - origin
	local length = offset.Magnitude
	if length < 1 then
		return
	end
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(255, 205, 120)
	local width = if type(packet.Width) == "number" then math.clamp(packet.Width * 2, 4, 18) else 10
	local duration = if type(packet.Duration) == "number" then math.clamp(packet.Duration, 0.5, 3) else 1.5
	local segmentCount = math.clamp(math.ceil(length / 5), 4, 14)
	for index = 1, segmentCount do
		local alpha = (index - 0.5) / segmentCount
		local segment = makeStudEffectPart("BossChargeLane", color)
		segment.CFrame = CFrame.lookAt(origin:Lerp(target, alpha), target)
		segment.Size = Vector3.new(width, 0.12, length / segmentCount * 0.82)
		segment.Transparency = 0.35
		TweenService:Create(
			segment,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 0.08 }
		):Play()
		Debris:AddItem(segment, duration + 0.08)
	end
	playEffectSound("SlowSwoosh", renderFolder, 0.62)
end

function ZombieController.ZombieAbility(_, packet)
	if type(packet) ~= "table" or type(packet.Kind) ~= "string" then
		return
	end

	if packet.Kind == "Projectile"
		and typeof(packet.Origin) == "Vector3"
		and typeof(packet.Target) == "Vector3"
		and type(packet.Duration) == "number"
	then
		local projectile = makeEffectPart("SpitProjectile", packet.Color)
		projectile.Shape = Enum.PartType.Ball
		projectile.Size = Vector3.one * 1.1
		projectile.CFrame = CFrame.new(packet.Origin)
		local projectileColor = projectile.Color
		StudVFX.Flash(renderFolder, packet.Origin, projectileColor, 1.6, 0.16)
		TweenService:Create(
			projectile,
			TweenInfo.new(math.clamp(packet.Duration, 0.05, 2), Enum.EasingStyle.Linear),
			{ CFrame = CFrame.new(packet.Target) }
		):Play()
		task.delay(math.clamp(packet.Duration, 0.05, 2), function()
			if renderFolder and renderFolder.Parent then
				StudVFX.Burst(renderFolder, packet.Target, projectileColor, 6, 2.2, 0.24)
			end
		end)
		Debris:AddItem(projectile, packet.Duration + 0.1)
		return
	end

	if typeof(packet.Position) ~= "Vector3" then
		return
	end
	if packet.Kind == "BossDeathShockwave" then
		playBossDeathShockwave(packet)
		return
	end
	if packet.Kind == "BossEntrance" then
		playBossEntrance(packet)
		return
	end
	if packet.Kind == "BossChargeTelegraph" then
		playBossChargeTelegraph(packet)
		return
	end
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 1, 30) else 2.5
	if packet.Kind == "SlowHazard" and type(packet.Duration) == "number" then
		local hazard = makeStudEffectPart(packet.Kind, packet.Color)
		hazard.Transparency = 0.48
		hazard.Size = Vector3.new(radius * 2, 0.18, radius * 2)
		hazard.CFrame = CFrame.new(packet.Position + Vector3.yAxis * 0.08)
		StudVFX.Ring(renderFolder, packet.Position + Vector3.yAxis * 0.12, hazard.Color, radius, 0.38, 16)
		TweenService:Create(
			hazard,
			TweenInfo.new(math.clamp(packet.Duration, 0.1, 20), Enum.EasingStyle.Linear),
			{ Transparency = 0.82 }
		):Play()
		Debris:AddItem(hazard, packet.Duration)
		return
	end
	local isStudEffect = STUD_EFFECT_KINDS[packet.Kind] == true
	local pulse = if isStudEffect then makeStudEffectPart(packet.Kind, packet.Color) else makeEffectPart(packet.Kind, packet.Color)
	pulse.Transparency = 0.15
	pulse.Shape = if isStudEffect then Enum.PartType.Block else Enum.PartType.Cylinder
	pulse.Size = if isStudEffect then Vector3.new(0.5, 0.16, 0.5) else Vector3.new(0.16, 0.5, 0.5)
	pulse.CFrame = CFrame.new(packet.Position + Vector3.yAxis * 0.12)
		* (if isStudEffect then CFrame.identity else CFrame.Angles(0, 0, math.pi * 0.5))
	TweenService:Create(
		pulse,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = if isStudEffect then Vector3.new(radius * 2, 0.16, radius * 2) else Vector3.new(0.16, radius * 2, radius * 2),
			Transparency = 1,
		}
	):Play()
	StudVFX.Burst(
		renderFolder,
		packet.Position + Vector3.yAxis * 0.3,
		pulse.Color,
		math.clamp(math.floor(radius * 0.65), 4, 9),
		math.min(radius * 0.5, 5),
		0.32
	)
	Debris:AddItem(pulse, 0.5)
end

function ZombieController.ZombieDamaged(_, id, health, maximumHealth, knockbackDirection, knockbackImpulse)
	local view = type(id) == "number" and zombieViews[id]
	if view then
		view:ApplyDamage(health, maximumHealth, knockbackDirection, knockbackImpulse)
		if view.definition.IsBoss then
			setBossState(true, id, view.typeName, health, maximumHealth)
		end
	end
end

function ZombieController.SpawnZombies(_, packets, serverTime)
	if type(packets) ~= "table" then
		return
	end

	for _, packet in packets do
		addZombie(packet, serverTime)
	end
end

function ZombieController.UpdateZombies(_, packets, serverTime)
	if type(packets) ~= "table" then
		return
	end

	local receivedAt = os.clock()
	for _, packet in packets do
		updateZombie(packet, serverTime, receivedAt)
	end
end

function ZombieController.RemoveZombies(_, ids)
	if type(ids) ~= "table" then
		return
	end

	for _, id in ids do
		local view = zombieViews[id]
		if view then
			if view.definition.IsBoss and bossState.id == id then
				setBossState(false, nil, nil, 0, 0)
			end
			if view.health <= 0 then
				view:Ragdoll()
			else
				view:Destroy()
			end
			zombieViews[id] = nil
		end
	end
end

local function renderZombies()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	table.clear(renderParts)
	table.clear(renderCFrames)
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	for _, view in zombieViews do
		view:AppendRender(renderParts, renderCFrames, camera, now, serverNow)
	end

	-- One bulk transform call avoids a render-step connection and property update per part.
	if #renderParts > 0 then
		Workspace:BulkMoveTo(renderParts, renderCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function ZombieController.GetZombieWorldPosition(id: number): Vector3?
	local view = zombieViews[id]
	return if view then view:GetRenderCFrame(os.clock()).Position else nil
end

function ZombieController.GetBossState()
	return bossState
end

function ZombieController.GetBossStateChangedSignal()
	return bossStateChanged
end

function ZombieController.Init()
	renderFolder = Instance.new "Folder"
	renderFolder.Name = "ClientZombies"
	renderFolder.Parent = Workspace

	zombieNetwork = Networker.client.new("ZombieController", ZombieController)
	local snapshot = zombieNetwork:fetch "GetSnapshot"
	if type(snapshot) == "table" and type(snapshot[2]) == "table" then
		for _, packet in snapshot[2] do
			addZombie(packet, snapshot[1])
		end
	end

	renderConnection = RunService.RenderStepped:Connect(renderZombies)
end

return ZombieController
