local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local TweenService = game:GetService "TweenService"
local Debris = game:GetService "Debris"
local Workspace = game:GetService "Workspace"

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local StudVFX = require(ReplicatedStorage.Modules.UI.StudVFX)
local ZombieView = require(script.Parent.Zombie.ZombieView)
local CombatPrediction = require(script.Parent.Zombie.CombatPrediction)
local Players = game:GetService("Players")

local ZombieController = {}
local zombieNetwork
local renderConnection
local renderFolder
local zombieViews = {}
local renderParts = {}
local renderCFrames = {}
local TAU = math.pi * 2
local ZOMBIE_HIT_SOUND = "BulletHit"
local ZOMBIE_DEATH_SOUND = "BodyImpact"
local HIT_SOUND_MIN_INTERVAL = 0.035
local DEATH_SOUND_MIN_INTERVAL = 0.025
local nextHitSoundAt = 0
local nextDeathSoundAt = 0
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
			setBossState(true, id, view.typeName, view.health, view.maximumHealth)
		end
	end
end

local function makeStudEffectPart(name, color)
	return StudVFX.CreateBlock(
		renderFolder,
		name,
		Vector3.one,
		if typeof(color) == "Color3" then color else Color3.fromRGB(255, 100, 75)
	)
end

local function playEffectSound(soundName: string, parent: Instance, playbackSpeed: number?)
	local template = Sounds.Get(soundName)
	if template then
		Sounds.Play(soundName, parent, nil, {
			PlaybackSpeed = template.PlaybackSpeed * (playbackSpeed or 1),
		})
	end
end

local function playZombieDamageSound(view, killed: boolean)
	local now = os.clock()
	local nextAllowedAt = if killed then nextDeathSoundAt else nextHitSoundAt
	if now < nextAllowedAt then
		return
	end

	local soundName = if killed then ZOMBIE_DEATH_SOUND else ZOMBIE_HIT_SOUND
	local template = Sounds.Get(soundName)
	if not template then
		return
	end
	if killed then
		nextDeathSoundAt = now + DEATH_SOUND_MIN_INTERVAL
	else
		nextHitSoundAt = now + HIT_SOUND_MIN_INTERVAL
	end

	-- Damage bursts can affect large hordes in one frame, so cap the shared cue rate while retaining
	-- positional feedback. Deaths use a separate budget so ordinary impacts cannot suppress lethal cues.
	local pitchVariation = ((view.id % 5) - 2) * 0.025
	local playbackScale = (if killed then 0.72 else 0.96) + pitchVariation
	Sounds.Play(soundName, view.model, 85, {
		PlaybackSpeed = template.PlaybackSpeed * playbackScale,
	})
end

local function playBossDeathShockwave(packet)
	local center = packet.Position + Vector3.yAxis * 0.2
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(195, 48, 61)
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 20, 180) else 150
	local duration = if type(packet.Duration) == "number" then math.clamp(packet.Duration, 0.6, 2) else 1.15
	local segmentCount = 24
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
	StudVFX.Ring(renderFolder, center + Vector3.yAxis * 0.04, color, radius, math.min(duration * 0.42, 0.9), 18)
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

local function playBossAreaTelegraph(packet)
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 1, 30) else 8
	local duration = if type(packet.Duration) == "number" then math.clamp(packet.Duration, 0.5, 3) else 1.4
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(180, 220, 65)
	local position = packet.Position + Vector3.yAxis * 0.1
	-- Additional volley targets need their own stationary warning for the entire server windup.
	-- Twelve stud segments bound the cost and exactly outline the authoritative damage radius.
	for index = 1, 12 do
		local angle = TAU * (index - 1) / 12
		local segment = makeStudEffectPart("BossAreaWarning", color)
		segment.Size = Vector3.new(0.35, 0.14, TAU * radius / 12)
		segment.CFrame = CFrame.new(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
			* CFrame.Angles(0, -angle, 0)
		segment.Transparency = 0.45
		TweenService:Create(segment, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.08 }):Play()
		Debris:AddItem(segment, duration + 0.08)
	end
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
		local projectile = makeStudEffectPart("SpitProjectileCore", packet.Color)
		projectile.Size = Vector3.one * 0.82
		projectile.CFrame = CFrame.new(packet.Origin)
		local projectileColor = projectile.Color
		local travelDuration = math.clamp(packet.Duration, 0.05, 2)
		local travelDirection = packet.Target - packet.Origin
		for trailIndex = 1, 3 do
			local trail = makeStudEffectPart("SpitProjectileTrail", projectileColor:Lerp(Color3.new(1, 1, 1), trailIndex * 0.1))
			local offset = if travelDirection.Magnitude > 0.01
				then -travelDirection.Unit * trailIndex * 0.48 else Vector3.zero
			trail.Size = Vector3.one * (0.72 - trailIndex * 0.13)
			trail.Transparency = 0.18 + trailIndex * 0.18
			trail.CFrame = CFrame.new(packet.Origin + offset)
			TweenService:Create(trail, TweenInfo.new(travelDuration, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(packet.Target + offset),
				Transparency = 0.75 + trailIndex * 0.07,
			}):Play()
			Debris:AddItem(trail, travelDuration + 0.1)
		end
		StudVFX.Flash(renderFolder, packet.Origin, projectileColor, 1.6, 0.16)
		TweenService:Create(
			projectile,
			TweenInfo.new(travelDuration, Enum.EasingStyle.Linear),
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
	if packet.Kind == "BossAreaTelegraph" then
		playBossAreaTelegraph(packet)
		return
	end
	local radius = if type(packet.Radius) == "number" then math.clamp(packet.Radius, 1, 30) else 2.5
	if packet.Kind == "SlowHazard" and type(packet.Duration) == "number" then
		local hazardDuration = math.clamp(packet.Duration, 0.1, 20)
		local hazardColor = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(255, 100, 75)
		-- Broken overlapping tiles make hazards feel authored while remaining fully local and non-physical.
		for tileIndex = 1, 7 do
			local angle = TAU * (tileIndex - 1) / 6
			local isCenter = tileIndex == 7
			local tile = makeStudEffectPart(packet.Kind .. "Tile", hazardColor)
			local tileSize = radius * (if isCenter then 0.9 else 0.58)
			local offset = if isCenter then Vector3.zero
				else Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.55
			tile.Transparency = 0.5 + (tileIndex % 2) * 0.08
			tile.Size = Vector3.new(tileSize, 0.12, tileSize * (if tileIndex % 2 == 0 then 0.72 else 1))
			tile.CFrame = CFrame.new(packet.Position + offset + Vector3.yAxis * 0.07) * CFrame.Angles(0, angle * 1.4, 0)
			TweenService:Create(tile, TweenInfo.new(hazardDuration, Enum.EasingStyle.Linear), { Transparency = 0.88 }):Play()
			Debris:AddItem(tile, hazardDuration)
		end
		StudVFX.Ring(renderFolder, packet.Position + Vector3.yAxis * 0.12, hazardColor, radius, 0.38, 16)
		return
	end
	local color = if typeof(packet.Color) == "Color3" then packet.Color else Color3.fromRGB(255, 100, 75)
	if packet.Kind == "Explosion" then
		-- Bomber deaths need an unmistakable volume and shock front, not the lighter generic hit recipe.
		StudVFX.Explosion(renderFolder, packet.Position, color, radius, 0.48, 1.2)
		return
	end
	StudVFX.Impact(renderFolder, packet.Position, color, radius, 0.45,
		if STUD_EFFECT_KINDS[packet.Kind] then 1.15 else 0.9)
end

function ZombieController.ZombieDamaged(_, id, health, maximumHealth, knockbackDirection, knockbackImpulse,
	ownerUserId, source, predictionKey, serverTime, actualDamage)
	local view = type(id) == "number" and zombieViews[id]
	if view then
		local matched = false
		local suppressCue = false
		local predictedDeath = view.predictedDeathAt ~= nil
		if ownerUserId == Players.LocalPlayer.UserId and type(actualDamage) == "number" then
			matched, suppressCue = CombatPrediction.Resolve(view, source, predictionKey, serverTime, actualDamage)
			if not matched and actualDamage > 0 then
				view:ShowDamageNumber(actualDamage)
			end
		end
		local killed = type(health) == "number" and health <= 0
		if not suppressCue or (killed and not predictedDeath) then
			playZombieDamageSound(view, killed)
		end
		view:ApplyDamage(health, maximumHealth, knockbackDirection, knockbackImpulse, suppressCue, serverTime)
		if view.definition.IsBoss then
			setBossState(true, id, view.typeName, view.health, view.maximumHealth)
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
		CombatPrediction.Step(view, serverNow)
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

function ZombieController.GetNearestZombiePositions(origin: Vector3, range: number, count: number)
	-- Prediction queries the existing view registry only once per scheduled volley, never the hierarchy per frame.
	local candidates = {}
	for id, view in zombieViews do
		if CombatPrediction.GetHealth(view) > 0 then
			local position = view:GetRenderCFrame(os.clock()).Position
			local distance = (position - origin).Magnitude
			if distance <= range then
				table.insert(candidates, { id = id, position = position, distance = distance })
			end
		end
	end
	table.sort(candidates, function(left, right)
		return if left.distance == right.distance then left.id < right.id else left.distance < right.distance
	end)
	while #candidates > count do
		table.remove(candidates)
	end
	return candidates
end

function ZombieController.PredictHit(id: number, source: string, key: string, damage: number): boolean
	local view = zombieViews[id]
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge
		or not view or not CombatPrediction.Add(view, source, key, damage, Workspace:GetServerTimeNow()) then
		return false
	end
	view:FlashHit()
	playZombieDamageSound(view, view.predictedDeathAt ~= nil)
	return true
end

function ZombieController.ClearPredictedHits(source: string?)
	for _, view in zombieViews do
		CombatPrediction.Cancel(view, source)
	end
end

function ZombieController.CancelPredictedHit(id: number, source: string, key: string)
	local view = zombieViews[id]
	if view then
		CombatPrediction.Cancel(view, source, key)
	end
end

function ZombieController.OnCharacterAdded(_character: Model)
	ZombieController.ClearPredictedHits()
end

function ZombieController.GetContactCandidates(origin: Vector3, range: number)
	local candidates = {}
	local now = os.clock()
	for id, view in zombieViews do
		if CombatPrediction.GetHealth(view) > 0 then
			local position = view:GetRenderCFrame(now).Position
			local offset = position - origin
			if math.abs(offset.Y) <= 7 and Vector2.new(offset.X, offset.Z).Magnitude <= range then
				table.insert(candidates, { id = id, position = position })
			end
		end
	end
	return candidates
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
