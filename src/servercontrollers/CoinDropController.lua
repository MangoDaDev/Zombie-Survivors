-- Currently unused after removal of simulator gameplay. Preserved as reusable authoritative item-drop logic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local CoinDropConfig = require(ReplicatedStorage.Modules.Game.CoinDropConfig)
local RunRewardsController = require(ServerStorage.Controllers.RunRewardsController)

local UPDATE_INTERVAL = 0.1
local MERGE_INTERVAL = 0.3
local MERGE_RADIUS = 2.25
-- Keep drops meaningfully spaced: they scatter wider than the reduced pickup radius and expire after 20 seconds.
local COIN_LIFETIME = 20
local MIN_SCATTER_DISTANCE = 5
local MAX_SCATTER_DISTANCE = 10
local MAX_ACTIVE_COINS = 120
local MAX_MERGE_PARTNERS = 7
local CLIENT_CLAIM_DISTANCE_TOLERANCE = 2.5
local CLIENT_CLAIM_REQUEST_INTERVAL = 0.04

type CoinState = {
	id: number,
	value: number,
	position: Vector3,
	collectibleAt: number,
	despawnAt: number,
	collectingPlayer: Player?,
	collectAt: number?,
}

local CoinDropController = {}

local coinNetwork
local heartbeatConnection
local random = Random.new()
local nextCoinId = 0
local activeCount = 0
local accumulator = 0
local mergeAccumulator = 0
local coins: { [number]: CoinState } = {}
local lastClientClaimAt: { [Player]: number } = {}

local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local function getVisualScale(value: number): number
	return 1 + math.min((math.log(value) / math.log(2)) * 0.1, 0.65)
end

local function findNearestCoin(position: Vector3): CoinState?
	local nearest
	local nearestDistance = math.huge
	for _, coin in coins do
		local distance = (coin.position - position).Magnitude
		if distance < nearestDistance then
			nearest = coin
			nearestDistance = distance
		end
	end
	return nearest
end

local function addOverflowValue(position: Vector3, value: number)
	local coin = findNearestCoin(position)
	if not coin then
		return
	end
	-- At the object cap, fold the reward into an existing coin (even one already magnetizing) so value is
	-- never discarded just because a large wave died before the current pickup animations completed.
	coin.value += value
	coin.despawnAt = workspace:GetServerTimeNow() + COIN_LIFETIME
	coinNetwork:fireAll("CoinValueChanged", coin.id, coin.value, coin.position, getVisualScale(coin.value))
end

function CoinDropController.SpawnBurst(position: Vector3, totalValue: number, landingHeight: number?)
	if typeof(position) ~= "Vector3" or type(totalValue) ~= "number" or totalValue <= 0 then
		return
	end
	totalValue = math.max(1, math.floor(totalValue))
	landingHeight = if type(landingHeight) == "number" then landingHeight else position.Y
	if activeCount >= MAX_ACTIVE_COINS then
		addOverflowValue(position, totalValue)
		return
	end

	local desiredCount = math.clamp(math.ceil(totalValue / 2), 3, 7)
	local dropCount = math.min(desiredCount, MAX_ACTIVE_COINS - activeCount)
	local remainingValue = totalValue
	local packets = {}
	local now = workspace:GetServerTimeNow()

	for index = 1, dropCount do
		local remainingDrops = dropCount - index + 1
		local value = math.max(1, math.floor(remainingValue / remainingDrops))
		remainingValue -= value
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(MIN_SCATTER_DISTANCE, MAX_SCATTER_DISTANCE)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local horizontalTarget = position + direction * distance
		local targetPosition = Vector3.new(horizontalTarget.X, landingHeight, horizontalTarget.Z)
		local duration = random:NextNumber(0.52, 0.78)

		nextCoinId += 1
		local coin: CoinState = {
			id = nextCoinId,
			value = value,
			position = targetPosition,
			collectibleAt = now + duration * 0.72,
			despawnAt = now + COIN_LIFETIME,
			collectingPlayer = nil,
			collectAt = nil,
		}
		coins[coin.id] = coin
		activeCount += 1
		table.insert(packets, {
			id = coin.id,
			value = value,
			origin = position + Vector3.new(0, 0.4, 0),
			targetPosition = targetPosition + Vector3.new(0, 0.35, 0),
			launchAt = now,
			duration = duration,
			arcHeight = random:NextNumber(3.2, 5.8),
			scale = getVisualScale(value),
		})
	end

	if remainingValue > 0 then
		packets[#packets].value += remainingValue
		coins[packets[#packets].id].value += remainingValue
		packets[#packets].scale = getVisualScale(packets[#packets].value)
	end
	if #packets > 0 then
		coinNetwork:fireAll("SpawnCoins", packets)
	end
end

local function mergeNearbyCoins(now: number)
	local grid = {}
	for id, coin in coins do
		if not coin.collectingPlayer and now >= coin.collectibleAt then
			local cellX = math.floor(coin.position.X / MERGE_RADIUS)
			local cellZ = math.floor(coin.position.Z / MERGE_RADIUS)
			local key = tostring(cellX) .. ":" .. tostring(cellZ)
			grid[key] = grid[key] or {}
			table.insert(grid[key], id)
		end
	end

	local consumed = {}
	for id, coin in coins do
		if consumed[id] or coin.collectingPlayer or now < coin.collectibleAt then
			continue
		end
		local cellX = math.floor(coin.position.X / MERGE_RADIUS)
		local cellZ = math.floor(coin.position.Z / MERGE_RADIUS)
		local mergedIds = {}
		local totalValue = coin.value
		local weightedPosition = coin.position * coin.value
		local despawnAt = coin.despawnAt

		for xOffset = -1, 1 do
			for zOffset = -1, 1 do
				local cell = grid[tostring(cellX + xOffset) .. ":" .. tostring(cellZ + zOffset)]
				if cell then
					for _, otherId in cell do
						local other = coins[otherId]
						if otherId ~= id
							and not consumed[otherId]
							and other
							and not other.collectingPlayer
							and (other.position - coin.position).Magnitude <= MERGE_RADIUS
						then
							consumed[otherId] = true
							table.insert(mergedIds, otherId)
							totalValue += other.value
							weightedPosition += other.position * other.value
							despawnAt = math.max(despawnAt, other.despawnAt)
							if #mergedIds >= MAX_MERGE_PARTNERS then
								break
							end
						end
					end
				end
				if #mergedIds >= MAX_MERGE_PARTNERS then
					break
				end
			end
			if #mergedIds >= MAX_MERGE_PARTNERS then
				break
			end
		end

		if #mergedIds > 0 then
			coin.value = totalValue
			coin.position = weightedPosition / totalValue
			coin.collectibleAt = now + 0.24
			coin.despawnAt = despawnAt
			for _, mergedId in mergedIds do
				coins[mergedId] = nil
				activeCount -= 1
			end
			coinNetwork:fireAll("MergeCoins", {
				targetId = id,
				consumedIds = mergedIds,
				value = totalValue,
				position = coin.position + Vector3.new(0, 0.35, 0),
				duration = 0.28,
				scale = getVisualScale(totalValue),
			})
		end
	end
end

local function despawnExpiredCoins(now: number)
	local expiredIds = {}
	for id, coin in coins do
		if not coin.collectingPlayer and now >= coin.despawnAt then
			coins[id] = nil
			activeCount -= 1
			table.insert(expiredIds, id)
		end
	end
	if #expiredIds > 0 then
		-- Expiration is authoritative and batched so every client removes the same drops with one message.
		coinNetwork:fireAll("DespawnCoins", expiredIds)
	end
end

local function finishCollections(now: number)
	for id, coin in coins do
		local player = coin.collectingPlayer
		if player and coin.collectAt and now >= coin.collectAt then
			if player.Parent == Players and getLiveRoot(player) then
				RunRewardsController.AddCoins(player, coin.value)
				coins[id] = nil
				activeCount -= 1
				coinNetwork:fireAll("CoinCollected", id, player.UserId, coin.value)
			else
				coin.collectingPlayer = nil
				coin.collectAt = nil
				coinNetwork:fireAll("ReleaseCoin", id, coin.position + Vector3.new(0, 0.35, 0))
			end
		end
	end
end

local function beginCollection(coin: CoinState, player: Player, now: number)
	coin.collectingPlayer = player
	coin.collectAt = now + CoinDropConfig.CollectionDuration
	coinNetwork:fireAll("CollectCoin", coin.id, player.UserId, now, CoinDropConfig.CollectionDuration)
end

local function sendAuthoritativeCoinState(player: Player, id: number, coin: CoinState?, now: number)
	if not coin then
		coinNetwork:fire(player, "DespawnCoins", { id })
	elseif coin.collectingPlayer then
		coinNetwork:fire(
			player,
			"CollectCoin",
			id,
			coin.collectingPlayer.UserId,
			(coin.collectAt or now) - CoinDropConfig.CollectionDuration,
			CoinDropConfig.CollectionDuration
		)
	else
		coinNetwork:fire(player, "ReleaseCoin", id, coin.position + Vector3.new(0, 0.35, 0))
	end
end

function CoinDropController.RequestCollect(_, player: Player, ids)
	if type(ids) ~= "table" or player.Parent ~= Players then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - (lastClientClaimAt[player] or 0) < CLIENT_CLAIM_REQUEST_INTERVAL then
		return
	end
	lastClientClaimAt[player] = now

	local root = getLiveRoot(player)
	local seen = {}
	local inspected = 0
	for _, id in ids do
		inspected += 1
		if inspected > CoinDropConfig.MaxPredictionBatch then
			break
		end
		if type(id) ~= "number" or id % 1 ~= 0 or seen[id] then
			continue
		end
		seen[id] = true

		local coin = coins[id]
		if not coin
			or coin.collectingPlayer
			or not root
			or now < coin.collectibleAt
			or (root.Position - coin.position).Magnitude
				> CoinDropConfig.CollectionRadius + CLIENT_CLAIM_DISTANCE_TOLERANCE
		then
			-- Reconcile rejected and contested predictions instead of leaving their local animation stuck.
			sendAuthoritativeCoinState(player, id, coin, now)
		else
			-- The server uses its own character position and a small latency allowance; the client never awards value.
			beginCollection(coin, player, now)
		end
	end
end

local function startCollections(now: number)
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local root = getLiveRoot(player)
		if root then
			table.insert(candidates, { player = player, position = root.Position })
		end
	end
	for id, coin in coins do
		if coin.collectingPlayer or now < coin.collectibleAt then
			continue
		end
		local nearestPlayer
		local nearestDistance = CoinDropConfig.CollectionRadius
		for _, candidate in candidates do
			local distance = (candidate.position - coin.position).Magnitude
			if distance <= nearestDistance then
				nearestDistance = distance
				nearestPlayer = candidate.player
			end
		end
		if nearestPlayer then
			beginCollection(coin, nearestPlayer, now)
		end
	end
end

local function step(deltaTime: number)
	accumulator += deltaTime
	mergeAccumulator += deltaTime
	if accumulator < UPDATE_INTERVAL then
		return
	end
	accumulator = 0
	local now = workspace:GetServerTimeNow()
	finishCollections(now)
	despawnExpiredCoins(now)
	startCollections(now)
	if mergeAccumulator >= MERGE_INTERVAL then
		mergeAccumulator = 0
		mergeNearbyCoins(now)
	end
end

function CoinDropController.GetSnapshot(_, _player)
	local snapshot = {}
	for _, coin in coins do
		if not coin.collectingPlayer then
			table.insert(snapshot, {
				id = coin.id,
				value = coin.value,
				position = coin.position + Vector3.new(0, 0.35, 0),
				scale = getVisualScale(coin.value),
			})
		end
	end
	return snapshot
end

function CoinDropController.Init()
	coinNetwork = Networker.server.new("CoinDropController", CoinDropController, {
		CoinDropController.GetSnapshot,
		CoinDropController.RequestCollect,
	})
	heartbeatConnection = RunService.Heartbeat:Connect(step)
end

function CoinDropController.OnPlayerRemoving(player: Player)
	lastClientClaimAt[player] = nil
end

return CoinDropController
