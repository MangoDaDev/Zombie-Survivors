local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local CoinDropConfig = require(ReplicatedStorage.Modules.Game.CoinDropConfig)
local RunProgressionConfig = require(ReplicatedStorage.Modules.Game.RunProgressionConfig)
local CoinsController = require(ServerStorage.Controllers.CoinsController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)

local UPDATE_INTERVAL = 0.1
local MERGE_INTERVAL = 0.3
local MERGE_RADIUS = 2.25
-- Keep drops meaningfully spaced so burst rewards remain readable before magnet collection begins.
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
	ownerUserId: number?,
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

local function canCollect(coin: CoinState, player: Player): boolean
	return coin.ownerUserId == nil or coin.ownerUserId == player.UserId
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

local function addOverflowValue(position: Vector3, value: number, ownerUserId: number?): boolean
	local coin = findNearestCoin(position)
	if coin and coin.ownerUserId ~= ownerUserId then
		coin = nil
		local nearestDistance = math.huge
		for _, candidate in coins do
			local distance = (candidate.position - position).Magnitude
			if candidate.ownerUserId == ownerUserId and distance < nearestDistance then
				coin = candidate
				nearestDistance = distance
			end
		end
	end
	if not coin then
		return false
	end
	-- At the object cap, fold the reward into an existing coin (even one already magnetizing) so value is
	-- never discarded just because a large wave died before the current pickup animations completed.
	coin.value += value
	coin.despawnAt = workspace:GetServerTimeNow() + CoinDropConfig.Lifetime
	coinNetwork:fireAll("CoinValueChanged", coin.id, coin.value, coin.position, getVisualScale(coin.value))
	return true
end

function CoinDropController.SpawnBurst(position: Vector3, totalValue: number, landingHeight: number?, owner: Player?)
	if not ServerContext.IsGameServer()
		or typeof(position) ~= "Vector3"
		or type(totalValue) ~= "number"
		or totalValue <= 0
	then
		return
	end
	totalValue = math.max(1, math.floor(totalValue))
	landingHeight = if type(landingHeight) == "number" then landingHeight else position.Y
	local ownerUserId = if RunProgressionConfig.Pickups.Ownership == "Killer" and owner then owner.UserId else nil
	if activeCount >= MAX_ACTIVE_COINS and addOverflowValue(position, totalValue, ownerUserId) then
		return
	end

	local desiredCount = math.clamp(math.ceil(totalValue / 2), 3, 7)
	-- A new killer-owned reward may temporarily exceed the visual cap when there is no same-owner
	-- coin to merge into; preserving currency is more important than a single extra visual.
	local dropCount = math.min(desiredCount, math.max(MAX_ACTIVE_COINS - activeCount, 1))
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
			despawnAt = now + CoinDropConfig.Lifetime,
			collectingPlayer = nil,
			collectAt = nil,
			ownerUserId = ownerUserId,
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
			ownerUserId = coin.ownerUserId,
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
							and other.ownerUserId == coin.ownerUserId
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
				local awarded = CoinsController.Add(player, coin.value)
				if awarded then
					coins[id] = nil
					activeCount -= 1
					coinNetwork:fireAll("CoinCollected", id, player.UserId, coin.value)
				else
					-- A transient data-access failure must not silently consume a permanent reward.
					coin.collectingPlayer = nil
					coin.collectAt = nil
					coinNetwork:fireAll("ReleaseCoin", id, coin.position + Vector3.new(0, 0.35, 0))
				end
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
			or not canCollect(coin, player)
			or (root.Position - coin.position).Magnitude
				> CoinDropConfig.MagnetRadius + CLIENT_CLAIM_DISTANCE_TOLERANCE
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
		local nearestDistance = CoinDropConfig.MagnetRadius
		for _, candidate in candidates do
			local distance = (candidate.position - coin.position).Magnitude
			if canCollect(coin, candidate.player) and distance <= nearestDistance then
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
			ownerUserId = coin.ownerUserId,
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
	if ServerContext.IsGameServer() then
		heartbeatConnection = RunService.Heartbeat:Connect(step)
	elseif RunService:IsStudio() then
		ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" and not heartbeatConnection then
				heartbeatConnection = RunService.Heartbeat:Connect(step)
			end
		end)
	end
end

function CoinDropController.OnPlayerRemoving(player: Player)
	lastClientClaimAt[player] = nil
end

return CoinDropController
