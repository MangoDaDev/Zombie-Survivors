local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local StudVFX = require(ReplicatedStorage.Modules.UI.StudVFX)
local ZombieController = require(script.Parent.Parent.ZombieController)

local PassiveEffectsView = {}

local effectsFolder: Folder?
local burns = {}
local random = Random.new()

local function makePart(name: string, position: Vector3, color: Color3): Part?
	if not effectsFolder then
		return nil
	end
	local part = StudVFX.CreateBlock(effectsFolder, name, Vector3.one, color)
	part.Position = position
	return part
end

local function destroyBurn(targetId: number)
	local burn = burns[targetId]
	if burn then
		burn.holder:Destroy()
		burns[targetId] = nil
	end
end

local function radialStudBurst(position: Vector3, color: Color3, count: number, distance: number, duration: number)
	if not effectsFolder then
		return
	end
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2 + random:NextNumber(-0.14, 0.14)
		local direction = Vector3.new(math.cos(angle), random:NextNumber(0.12, 0.42), math.sin(angle)).Unit
		local block = makePart("PassiveImpactStud", position + direction * 0.3, color)
		if block then
			block.Material = Enum.Material.Plastic
			block.Size = Vector3.new(0.24, 0.24, random:NextNumber(0.65, 1.05))
			block.TopSurface = Enum.SurfaceType.Studs
			block.BottomSurface = Enum.SurfaceType.Studs
			block.FrontSurface = Enum.SurfaceType.Studs
			block.BackSurface = Enum.SurfaceType.Studs
			block.LeftSurface = Enum.SurfaceType.Studs
			block.RightSurface = Enum.SurfaceType.Studs
			block.CFrame = CFrame.lookAt(block.Position, block.Position + direction)
			TweenService:Create(block, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(position + direction * distance, position + direction * (distance + 1)),
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 0.25),
			}):Play()
			Debris:AddItem(block, duration + 0.05)
		end
	end
end

local function addFadingLight(parent: BasePart, color: Color3, brightness: number, range: number, duration: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
	TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
	}):Play()
end

function PassiveEffectsView.Init(folder: Folder)
	effectsFolder = folder
end

function PassiveEffectsView.BlastTriggered(packet)
	local color = if packet.secondary then Color3.fromRGB(255, 76, 29) else Color3.fromRGB(255, 157, 47)
	-- Blast is one of the most frequent passive procs, so use the bounded shared impact instead of a
	-- single neon sphere. The layered rings, crossed flash, and chips communicate both force and radius.
	local anchor = StudVFX.Impact(
		effectsFolder,
		packet.position,
		color,
		packet.radius,
		0.3,
		if packet.secondary then 1.35 else 1
	)
	if anchor then
		Sounds.Play("FlameBurst", anchor, 95)
		addFadingLight(anchor, color, if packet.secondary then 3 else 2, packet.radius * 1.2, 0.22)
	end
end

function PassiveEffectsView.BurnApplied(packet)
	local burn = burns[packet.targetId]
	if not burn then
		local position = ZombieController.GetZombieWorldPosition(packet.targetId)
		if not position then
			return
		end
		local holder = makePart("PassiveBurn", position + Vector3.new(0, 1.4, 0), Color3.new(1, 1, 1))
		if not holder then
			return
		end
		holder.Size = Vector3.new(0.1, 0.1, 0.1)
		holder.Transparency = 1
		local flame = Instance.new("Fire")
		flame.Name = "Flame"
		flame.Color = Color3.fromRGB(255, 133, 28)
		flame.SecondaryColor = Color3.fromRGB(255, 50, 15)
		flame.Heat = 5
		flame.Size = 3.2
		flame.Parent = holder
		local light = Instance.new("PointLight")
		light.Color = flame.Color
		light.Brightness = 0.7
		light.Range = 5
		light.Parent = holder
		Sounds.Play("FireDamage", holder, 75)
		burn = { holder = holder, light = light, phase = random:NextNumber(0, math.pi * 2) }
		burns[packet.targetId] = burn
	end
	burn.expiresAt = os.clock() + packet.duration
end

function PassiveEffectsView.BurnEnded(targetId: number)
	destroyBurn(targetId)
end

function PassiveEffectsView.ThornsTriggered(packet)
	local pulseRadius = if packet.burstRadius > 0 then packet.burstRadius else 2.5
	StudVFX.Ring(effectsFolder, packet.playerPosition + Vector3.yAxis * 0.1,
		Color3.fromRGB(108, 231, 137), pulseRadius, 0.24, 12)
	local impact = StudVFX.Flash(
		effectsFolder,
		packet.attackerPosition + Vector3.yAxis * 0.35,
		Color3.fromRGB(202, 255, 187),
		2.4,
		0.18
	)
	if impact then
		-- Thorns use an organic snap so the retaliation reads differently from armored impacts.
		Sounds.Play("AbilityThornsImpact", impact, 80)
		addFadingLight(impact, impact.Color, 1.8, 5.5, 0.14)
	end
	local recoilDirection = packet.attackerPosition - packet.playerPosition
	if recoilDirection.Magnitude > 0.01 then
		local facing = recoilDirection.Unit
		for index = -1, 1 do
			local spread = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(index * 24)) * facing)
			local thorn = makePart("ThornSpike", packet.playerPosition + Vector3.yAxis, Color3.fromRGB(151, 244, 157))
			if thorn then
				thorn.Material = Enum.Material.Plastic
				thorn.Size = Vector3.new(0.28, 0.28, 1.1)
				thorn.CFrame = CFrame.lookAt(thorn.Position, thorn.Position + spread)
				TweenService:Create(thorn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = thorn.Position + spread * math.min(pulseRadius, 3.5),
					Transparency = 1,
				}):Play()
				Debris:AddItem(thorn, 0.24)
			end
		end
	end
end

function PassiveEffectsView.CriticalHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" then
		return
	end
	if effectsFolder then
		local holder = makePart("CriticalHitFlash", packet.position + Vector3.yAxis * 1.4, Color3.new(1, 1, 1))
		if holder then
			holder.Size = Vector3.one * 0.1
			holder.Transparency = 1
			for _, child in ReplicatedStorage.Assets.VFX.CriticalHit.Impact:GetChildren() do
				if child:IsA("ParticleEmitter") then
					local emitter = child:Clone()
					emitter.Color = ColorSequence.new(Color3.fromRGB(255, 244, 151), Color3.fromRGB(255, 143, 36))
					emitter.Parent = holder
					emitter:Emit(if child.Name == "Flash" then 1 else 7)
				end
			end
			addFadingLight(holder, Color3.fromRGB(255, 197, 68), 2.2, 6, 0.18)
			Debris:AddItem(holder, 2)
		end
	end
	-- A small stud-built burst reads as a critical hit without replacing the zombie's damage feedback.
	for index = 1, 4 do
		local angle = index * math.pi / 2
		local offset = Vector3.new(math.cos(angle), 0.35, math.sin(angle))
		local block = makePart("CriticalSpark", packet.position + Vector3.yAxis * 1.4,
			Color3.fromRGB(255, 201, 70))
		if block then
			block.Material = Enum.Material.Plastic
			block.Size = Vector3.new(0.28, 0.28, 0.7)
			block.TopSurface = Enum.SurfaceType.Studs
			block.BottomSurface = Enum.SurfaceType.Studs
			block.FrontSurface = Enum.SurfaceType.Studs
			block.BackSurface = Enum.SurfaceType.Studs
			block.LeftSurface = Enum.SurfaceType.Studs
			block.RightSurface = Enum.SurfaceType.Studs
			block.CFrame = CFrame.lookAt(block.Position, block.Position + offset)
			TweenService:Create(block, TweenInfo.new(0.22), {
				Position = block.Position + offset * 1.4,
				Transparency = 1,
			}):Play()
			Debris:AddItem(block, 0.25)
		end
	end
end

function PassiveEffectsView.ArmorBlocked(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" then return end
	local color = if packet.heavy then Color3.fromRGB(113, 225, 255) else Color3.fromRGB(85, 158, 255)
	local soundAnchor
	for index = 1, 7 do
		local angle = (index - 1) / 7 * math.pi * 2
		local panel = makePart("ArmorPanel", packet.position, color)
		if panel then
			soundAnchor = soundAnchor or panel
			panel.Material = Enum.Material.Plastic
			panel.Size = Vector3.new(0.8, if packet.heavy then 1.25 else 0.9, 0.22)
			panel.TopSurface = Enum.SurfaceType.Studs
			panel.BottomSurface = Enum.SurfaceType.Studs
			panel.FrontSurface = Enum.SurfaceType.Studs
			panel.BackSurface = Enum.SurfaceType.Studs
			panel.LeftSurface = Enum.SurfaceType.Studs
			panel.RightSurface = Enum.SurfaceType.Studs
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2
			panel.CFrame = CFrame.lookAt(packet.position + offset, packet.position)
			panel.Transparency = 0.18
			TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = panel.Position + offset.Unit * 0.8,
				Transparency = 1,
			}):Play()
			Debris:AddItem(panel, 0.3)
		end
	end
	if soundAnchor then Sounds.Play("AbilityBladeImpact", soundAnchor, 80) end
end

function PassiveEffectsView.MagnetBurst(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3"
		or type(packet.radius) ~= "number" or packet.radius <= 0 then return end
	local color = Color3.fromRGB(78, 196, 255)
	local soundAnchor
	-- Inward-moving stud blocks make the collection direction immediately readable.
	for index = 1, 16 do
		local angle = (index - 1) / 16 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = packet.position + direction * math.min(packet.radius, 22)
		local block = makePart("MagnetPullStud", start, if index % 2 == 0 then color else Color3.fromRGB(255, 93, 93))
		if block then
			soundAnchor = soundAnchor or block
			block.Material = Enum.Material.Plastic
			block.Size = Vector3.new(0.28, 0.28, 0.9)
			block.CFrame = CFrame.lookAt(start, packet.position)
			TweenService:Create(block, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.lookAt(packet.position + direction * 1.2, packet.position),
				Transparency = 1,
			}):Play()
			Debris:AddItem(block, 0.48)
		end
	end
	if soundAnchor then Sounds.Play("SlotsJackpot", soundAnchor, 90) end
end

function PassiveEffectsView.ExecutionerHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" then return end
	local position = packet.position + Vector3.yAxis * 1.35
	local soundAnchor
	for index = -1, 1 do
		local slash = makePart("ExecutionerSlash", position, Color3.fromRGB(255, 63, 63))
		if slash then
			soundAnchor = soundAnchor or slash
			slash.Material = Enum.Material.Plastic
			slash.Size = Vector3.new(0.28, 0.28, 2.8)
			slash.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(index * 28), math.rad(38))
			TweenService:Create(slash, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.1, 0.1, 4.2),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slash, 0.25)
		end
	end
	radialStudBurst(position, Color3.fromRGB(255, 112, 81), 5, 2.2, 0.2)
	if soundAnchor then Sounds.Play("BodyImpact", soundAnchor, 80) end
end

function PassiveEffectsView.OverchargeTriggered(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" then return end
	local color = Color3.fromRGB(230, 83, 255)
	StudVFX.Flash(effectsFolder, packet.position + Vector3.yAxis * 0.5, color, 3.8, 0.24)
	StudVFX.Ring(effectsFolder, packet.position + Vector3.yAxis * 0.12, color, 4.5, 0.3, 12)
	radialStudBurst(packet.position, color, 12, 4.5, 0.28)
	local soundAnchor
	for index = 1, 2 do
		local bolt = makePart("OverchargeBolt", packet.position, color:Lerp(Color3.new(1, 1, 1), 0.45))
		if bolt then
			soundAnchor = soundAnchor or bolt
			bolt.Material = Enum.Material.Plastic
			bolt.Size = Vector3.new(0.35, 0.35, 3.4)
			bolt.CFrame = CFrame.new(packet.position) * CFrame.Angles(math.rad(18), math.rad((index - 1) * 90 + 45), math.rad(32))
			TweenService:Create(bolt, TweenInfo.new(0.24), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 5) }):Play()
			Debris:AddItem(bolt, 0.28)
		end
	end
	if soundAnchor then Sounds.Play("AbilityLightningCast", soundAnchor, 110) end
end

function PassiveEffectsView.Render()
	local now = os.clock()
	for targetId, burn in burns do
		local position = ZombieController.GetZombieWorldPosition(targetId)
		if now >= burn.expiresAt or not position then
			destroyBurn(targetId)
		else
			burn.holder.Position = position + Vector3.new(0, 1.4, 0)
			-- A gentle light pulse adds life to the status without adding particles or another update connection.
			burn.light.Brightness = 0.55 + math.max(0, math.sin(now * 7 + burn.phase)) * 0.55
		end
	end
end

return PassiveEffectsView
