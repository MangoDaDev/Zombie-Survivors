local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local ZombieController = require(script.Parent.Parent.ZombieController)

local PassiveEffectsView = {}

local effectsFolder: Folder?
local burns = {}

local function makePart(name: string, position: Vector3, color: Color3, shape: Enum.PartType): Part?
	if not effectsFolder then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = position
	part.Parent = effectsFolder
	return part
end

local function destroyBurn(targetId: number)
	local burn = burns[targetId]
	if burn then
		burn.holder:Destroy()
		burns[targetId] = nil
	end
end

function PassiveEffectsView.Init(folder: Folder)
	effectsFolder = folder
end

function PassiveEffectsView.BlastTriggered(packet)
	local color = if packet.secondary then Color3.fromRGB(255, 76, 29) else Color3.fromRGB(255, 157, 47)
	local ring = makePart("BlastRadius", packet.position, color, Enum.PartType.Cylinder)
	if ring then
		ring.Size = Vector3.new(0.12, 0.2, 0.2)
		ring.Transparency = 0.28
		ring.CFrame = CFrame.new(packet.position) * CFrame.Angles(0, 0, math.pi / 2)
		TweenService:Create(
			ring,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.12, packet.radius * 2, packet.radius * 2), Transparency = 1 }
		):Play()
		Sounds.Play("FlameBurst", ring, 95)
		Debris:AddItem(ring, 0.35)
	end

	local flash = makePart("BlastFlash", packet.position, Color3.fromRGB(255, 239, 129), Enum.PartType.Ball)
	if flash then
		flash.Size = Vector3.one * 0.8
		flash.Transparency = 0.05
		TweenService:Create(
			flash,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * packet.radius * 1.15, Transparency = 1 }
		):Play()
		Debris:AddItem(flash, 0.3)
	end
end

function PassiveEffectsView.BurnApplied(packet)
	local burn = burns[packet.targetId]
	if not burn then
		local position = ZombieController.GetZombieWorldPosition(packet.targetId)
		if not position then
			return
		end
		local holder = makePart("PassiveBurn", position + Vector3.new(0, 1.4, 0), Color3.new(1, 1, 1), Enum.PartType.Block)
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
		burn = { holder = holder }
		burns[packet.targetId] = burn
	end
	burn.expiresAt = os.clock() + packet.duration
end

function PassiveEffectsView.BurnEnded(targetId: number)
	destroyBurn(targetId)
end

function PassiveEffectsView.ThornsTriggered(packet)
	local pulseRadius = if packet.burstRadius > 0 then packet.burstRadius else 2.5
	local pulse = makePart("ThornsPulse", packet.playerPosition, Color3.fromRGB(108, 231, 137), Enum.PartType.Ball)
	if pulse then
		pulse.Size = Vector3.one * 0.6
		pulse.Transparency = 0.5
		TweenService:Create(
			pulse,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * pulseRadius * 2, Transparency = 1 }
		):Play()
		Debris:AddItem(pulse, 0.3)
	end

	local impact = makePart("ThornsImpact", packet.attackerPosition, Color3.fromRGB(202, 255, 187), Enum.PartType.Ball)
	if impact then
		impact.Size = Vector3.one * 0.45
		impact.Transparency = 0.05
		TweenService:Create(impact, TweenInfo.new(0.14), { Size = Vector3.one * 2.4, Transparency = 1 }):Play()
		Sounds.Play("MetalHitSoft", impact, 80)
		Debris:AddItem(impact, 0.25)
	end
end

function PassiveEffectsView.CriticalHit(packet)
	if type(packet) ~= "table" or typeof(packet.position) ~= "Vector3" then
		return
	end
	-- A small stud-built burst reads as a critical hit without replacing the zombie's damage feedback.
	for index = 1, 4 do
		local angle = index * math.pi / 2
		local offset = Vector3.new(math.cos(angle), 0.35, math.sin(angle))
		local block = makePart("CriticalSpark", packet.position + Vector3.yAxis * 1.4,
			Color3.fromRGB(255, 201, 70), Enum.PartType.Block)
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

function PassiveEffectsView.Render()
	local now = os.clock()
	for targetId, burn in burns do
		local position = ZombieController.GetZombieWorldPosition(targetId)
		if now >= burn.expiresAt or not position then
			destroyBurn(targetId)
		else
			burn.holder.Position = position + Vector3.new(0, 1.4, 0)
		end
	end
end

return PassiveEffectsView
