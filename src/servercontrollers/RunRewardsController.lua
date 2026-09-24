-- Currently unused after removal of extraction gameplay. Preserved for its reusable transient reward and zone logic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local BackpackController = require(ServerStorage.Controllers.BackpackController)
local CoinsConfig = require(ReplicatedStorage.Modules.Game.CoinsConfig)
local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)
local CoinsController = require(ServerStorage.Controllers.CoinsController)

local RETURN_REQUEST_COOLDOWN = 1
local SAFE_AREA_CHECK_INTERVAL = 0.15
local SAFE_AREA_EDGE_TOLERANCE = 2
local SAFE_AREA_MIN_HEIGHT = -4
local SAFE_AREA_MAX_HEIGHT = 20

type PlayerRunRewards = {
	coins: number,
	inSafeArea: boolean,
}

local RunRewardsController = {}

local rewardNetwork
local safeSpawn: SpawnLocation?
local safeFloor: BasePart?
local safeAreaAccumulator = 0
local safeAreaHeartbeatConnection: RBXScriptConnection?
local rewardsByPlayer: { [Player]: PlayerRunRewards } = {}
local lastReturnRequestAt: { [Player]: number } = {}
local claimingPlayers: { [Player]: boolean } = {}

local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function findSafeFloor(spawnLocation: SpawnLocation): BasePart?
	local bestFloor
	local bestArea = 0

	for _, instance in Workspace:GetChildren() do
		if not instance:IsA("BasePart") or instance == spawnLocation then
			continue
		end

		local localSpawnPosition = instance.CFrame:PointToObjectSpace(spawnLocation.Position)
		local insideFloor = math.abs(localSpawnPosition.X) <= instance.Size.X * 0.5
			and math.abs(localSpawnPosition.Z) <= instance.Size.Z * 0.5
		local nearTopSurface = math.abs(localSpawnPosition.Y - instance.Size.Y * 0.5) <= 6
		local area = instance.Size.X * instance.Size.Z

		if insideFloor and nearTopSurface and area > bestArea then
			bestFloor = instance
			bestArea = area
		end
	end

	return bestFloor
end

local function isInSafeArea(root: BasePart): boolean
	local floor = safeFloor
	if not floor or floor.Parent == nil then
		return false
	end

	local localPosition = floor.CFrame:PointToObjectSpace(root.Position)
	return math.abs(localPosition.X) <= floor.Size.X * 0.5 + SAFE_AREA_EDGE_TOLERANCE
		and math.abs(localPosition.Z) <= floor.Size.Z * 0.5 + SAFE_AREA_EDGE_TOLERANCE
		and localPosition.Y >= SAFE_AREA_MIN_HEIGHT
		and localPosition.Y <= SAFE_AREA_MAX_HEIGHT
end

local function sendRewards(player: Player)
	local rewards = rewardsByPlayer[player]
	if rewardNetwork and rewards then
		rewardNetwork:fire(player, "RunRewardsChanged", {
			coins = rewards.coins,
			inSafeArea = rewards.inSafeArea,
		})
	end
end

local function claimRewards(player: Player): boolean
	local rewards = rewardsByPlayer[player]
	local root = getLiveRoot(player)
	if not rewards or rewards.coins <= 0 or not root or not isInSafeArea(root) or claimingPlayers[player] then
		return false
	end

	claimingPlayers[player] = true
	local claimedCoins = rewards.coins
	local added = CoinsController.Add(player, claimedCoins)
	if added then
		-- Run earnings become persistent only after the server confirms the player is inside the safe area.
		rewards.coins = 0
		BackpackController.SetCarriedCoins(player, rewards.coins)
		sendRewards(player)
		-- Only a confirmed server claim can start the client reward presentation.
		rewardNetwork:fire(player, "RewardsClaimed", claimedCoins)
	end
	claimingPlayers[player] = nil

	return added
end

local function updatePlayerSafeArea(player: Player)
	local rewards = rewardsByPlayer[player]
	if not rewards then
		return
	end

	local root = getLiveRoot(player)
	local inSafeArea = root ~= nil and isInSafeArea(root)
	local changed = rewards.inSafeArea ~= inSafeArea
	-- Safe-area membership is the single replicated gate for base-only UI and reward banking.
	rewards.inSafeArea = inSafeArea

	if inSafeArea and claimRewards(player) then
		return
	end
	if changed then
		sendRewards(player)
	end
end

local function stepSafeAreas(deltaTime: number)
	safeAreaAccumulator += deltaTime
	if safeAreaAccumulator < SAFE_AREA_CHECK_INTERVAL then
		return
	end
	safeAreaAccumulator = 0

	for player in rewardsByPlayer do
		updatePlayerSafeArea(player)
	end
end

function RunRewardsController.AddCoins(player: Player, amount: number): boolean
	local rewards = rewardsByPlayer[player]
	if not rewards
		or player.Parent ~= Players
		or type(amount) ~= "number"
		or amount ~= amount
		or amount <= 0
		or amount % 1 ~= 0
	then
		return false
	end

	local balance = CoinsController.Get(player)
	if balance == nil or amount > CoinsConfig.MaximumBalance - balance - rewards.coins then
		return false
	end

	-- Collected coins remain transient run rewards until an authoritative safe-area claim succeeds.
	rewards.coins += amount
	-- The visible backpack stage always follows this authoritative carried amount, never a client claim.
	BackpackController.SetCarriedCoins(player, rewards.coins)
	sendRewards(player)
	return true
end

function RunRewardsController.IsInSafeArea(player: Player): boolean
	local root = getLiveRoot(player)
	-- Combat checks use the live authoritative position so crossing the boundary takes effect immediately,
	-- independently of the lower-frequency replication/update interval used by the HUD and reward claims.
	return root ~= nil and isInSafeArea(root)
end

function RunRewardsController.GetState(_, player: Player)
	local rewards = rewardsByPlayer[player]
	return {
		coins = if rewards then rewards.coins else 0,
		inSafeArea = if rewards then rewards.inSafeArea else false,
	}
end

function RunRewardsController.ReturnToBaseAndClaim(_, player: Player): boolean
	local rewards = rewardsByPlayer[player]
	local spawnLocation = safeSpawn
	local root = getLiveRoot(player)
	if not rewards or not spawnLocation or spawnLocation.Parent == nil or not root then
		return false
	end

	local now = workspace:GetServerTimeNow()
	if now - (lastReturnRequestAt[player] or 0) < RETURN_REQUEST_COOLDOWN then
		return false
	end
	lastReturnRequestAt[player] = now

	local destination = spawnLocation.CFrame * CFrame.new(0, spawnLocation.Size.Y * 0.5 + 4, 0)
	if not TeleportPlayer(player, destination) then
		return false
	end

	-- Clear carried momentum so the player cannot be flung back out before the safe-area check and claim.
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	updatePlayerSafeArea(player)
	return true
end

function RunRewardsController.Init()
	rewardNetwork = Networker.server.new("RunRewardsController", RunRewardsController, {
		RunRewardsController.GetState,
		RunRewardsController.ReturnToBaseAndClaim,
	})

	local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
	if not spawnLocation or not spawnLocation:IsA("SpawnLocation") then
		warn("RunRewardsController requires Workspace.SpawnLocation to return players to base")
		return
	end

	safeSpawn = spawnLocation
	safeFloor = findSafeFloor(spawnLocation)
	if not safeFloor then
		warn("RunRewardsController could not resolve the safe floor containing Workspace.SpawnLocation")
		return
	end

	safeAreaHeartbeatConnection = RunService.Heartbeat:Connect(stepSafeAreas)
end

function RunRewardsController.OnPlayerAdded(player: Player)
	rewardsByPlayer[player] = {
		coins = 0,
		inSafeArea = false,
	}
	-- Publish initialization as well as transitions so an early client snapshot cannot remain stale.
	sendRewards(player)
end

function RunRewardsController.OnCharacterAdded(player: Player, character: Model)
	-- Re-evaluate immediately on spawn; the shared heartbeat handles all later area transitions.
	task.defer(function()
		if player.Character ~= character or player.Parent ~= Players then
			return
		end
		updatePlayerSafeArea(player)
	end)
end

function RunRewardsController.OnPlayerRemoving(player: Player)
	rewardsByPlayer[player] = nil
	lastReturnRequestAt[player] = nil
	claimingPlayers[player] = nil
end

return RunRewardsController
