local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local Workspace = game:GetService "Workspace"

local Networker = require(ReplicatedStorage.Packages.networker)
local ZombieDefinitions = require(ReplicatedStorage.Modules.Game.Zombies.ZombieDefinitions)
local ZombieView = require(script.Parent.Zombie.ZombieView)

local ZombieController = {}
local zombieNetwork
local renderConnection
local renderFolder
local zombieViews = {}
local renderParts = {}
local renderCFrames = {}

local function addZombie(packet, serverTime)
	if type(packet) ~= "table" then
		return
	end

	local id, typeName, initialCFrame, state, attackSequence, attackStartedAt, scale, animationSpeedMultiplier, health, maximumHealth =
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

	local existing = zombieViews[id]
	if existing then
		existing:Update(
			initialCFrame,
			state,
			attackSequence,
			attackStartedAt,
			health,
			maximumHealth,
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
		serverTime,
		renderFolder
	)
end

local function updateZombie(packet, serverTime, receivedAt)
	if type(packet) ~= "table" then
		return
	end

	local id, targetCFrame, state, attackSequence, attackStartedAt, health, maximumHealth = table.unpack(packet)
	local view = type(id) == "number" and zombieViews[id]
	if view and typeof(targetCFrame) == "CFrame" and type(state) == "number" then
		view:Update(targetCFrame, state, attackSequence, attackStartedAt, health, maximumHealth, serverTime, receivedAt)
	end
end

function ZombieController.ZombieDamaged(_, id, health, maximumHealth, knockbackDirection, knockbackImpulse)
	local view = type(id) == "number" and zombieViews[id]
	if view then
		view:ApplyDamage(health, maximumHealth, knockbackDirection, knockbackImpulse)
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
