local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local MonetizationConfig = require(ReplicatedStorage.Modules.Game.MonetizationConfig)
local AbilityController = require(ServerStorage.Controllers.AbilityController)
local AnalyticsController = require(ServerStorage.Controllers.AnalyticsController)
local BackpackController = require(ServerStorage.Controllers.BackpackController)
local CharacterController = require(ServerStorage.Controllers.CharacterController)
local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local MonetizationController = require(ServerStorage.Controllers.MonetizationController)
local PartyTeleportService = require(ServerStorage.Controllers.PartyTeleportService)
local PowerupDropController = require(ServerStorage.Controllers.PowerupDropController)
local RageController = require(ServerStorage.Controllers.RageController)
local RoundController = require(ServerStorage.Controllers.RoundController)
local RunProgressionController = require(ServerStorage.Controllers.RunProgressionController)
local ServerContext = require(ServerStorage.Controllers.ServerContext)
local XPDropController = require(ServerStorage.Controllers.XPDropController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local RETURN_DELAY = 15
local REVIVE_HOLD_SECONDS = 1.5
local REVIVE_DISTANCE = 10

type RunRuntime = {
	startedAt: number?, zombiesKilled: number, coinsCollected: number, dead: boolean, ended: boolean,
	resultPacket: any?, deathConnection: RBXScriptConnection?, returnToken: number, restarting: boolean,
	revivePrompt: ProximityPrompt?, reviveConnections: { RBXScriptConnection }?,
	reviveHolds: { [Player]: { startedAt: number, endedAt: number? } }?,
}

local RunSessionController = {}
local sessionNetwork
local runtimes: { [Player]: RunRuntime } = {}
local replayVotes: { [Player]: boolean } = {}
local restartingParty = false
local teamWipeRevision = 0
local teamWipeAt: number? = nil

local function getPartyMemberLookup(): { [number]: boolean }?
	local runData = ServerContext.GetRunData()
	local memberIds = type(runData) == "table" and runData.partyMemberIds or nil
	if type(memberIds) ~= "table" then return nil end
	local lookup = {}
	for _, userId in memberIds do
		if type(userId) == "number" and userId % 1 == 0 and userId > 0 then lookup[userId] = true end
	end
	return if next(lookup) ~= nil then lookup else nil
end

local function isPartyMember(player: Player): boolean
	local lookup = getPartyMemberLookup()
	return player.Parent == Players and (not lookup or lookup[player.UserId] == true)
end

local function getPartyPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if isPartyMember(player) and runtimes[player] then table.insert(result, player) end
	end
	return result
end

local function getLivingUserIds(): { number }
	local result = {}
	for _, player in getPartyPlayers() do
		local runtime = runtimes[player]
		if runtime and not runtime.ended and not runtime.dead then table.insert(result, player.UserId) end
	end
	return result
end

local function getDeadCount(excludedPlayer: Player?): number
	local count = 0
	for _, player in getPartyPlayers() do
		local runtime = runtimes[player]
		if player ~= excludedPlayer and runtime and runtime.dead and not runtime.ended then count += 1 end
	end
	return count
end

local function getReplayVoteCount(): number
	local count = 0
	for _, player in getPartyPlayers() do if replayVotes[player] then count += 1 end end
	return count
end

local function makeSnapshot(player: Player, runtime: RunRuntime)
	if runtime.resultPacket then
		local result = table.clone(runtime.resultPacket)
		result.replayVoteCount = getReplayVoteCount()
		result.replayRequiredVotes = #getPartyPlayers()
		result.hasReplayVoted = replayVotes[player] == true
		return result
	end
	local livingUserIds = getLivingUserIds()
	local downedUserIds = {}
	for _, teammate in getPartyPlayers() do
		local teammateRuntime = runtimes[teammate]
		if teammateRuntime.dead and not teammateRuntime.ended then table.insert(downedUserIds, teammate.UserId) end
	end
	return {
		active = false, startedAt = runtime.startedAt, dead = runtime.dead,
		teamAliveCount = #livingUserIds, teamDeadCount = getDeadCount(nil),
		eligibleTeamRevives = getDeadCount(player), livingUserIds = livingUserIds,
		downedUserIds = downedUserIds, teamWipeAt = teamWipeAt,
	}
end

local function broadcastState()
	if not sessionNetwork then return end
	for _, player in getPartyPlayers() do
		local runtime = runtimes[player]
		if runtime then
			sessionNetwork:fire(player, if runtime.resultPacket then "GameOver" else "StateChanged", makeSnapshot(player, runtime))
		end
	end
end

local function disconnectDeath(runtime: RunRuntime)
	if runtime.deathConnection then runtime.deathConnection:Disconnect(); runtime.deathConnection = nil end
end

local function clearRevivePrompt(runtime: RunRuntime)
	for _, connection in runtime.reviveConnections or {} do connection:Disconnect() end
	runtime.reviveConnections = nil
	runtime.reviveHolds = nil
	if runtime.revivePrompt then runtime.revivePrompt:Destroy(); runtime.revivePrompt = nil end
end

local function ragdollCharacter(character: Model, humanoid: Humanoid)
	-- Preserve the corpse and its root for teammate wayfinding until a deliberate revive replaces it.
	humanoid.AutoRotate = false
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1
			and descendant.Part0.Name ~= "HumanoidRootPart" and descendant.Part1.Name ~= "HumanoidRootPart" then
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "DownedJoint"
			attachment0.CFrame = descendant.C0
			attachment0.Parent = descendant.Part0
			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "DownedJoint"
			attachment1.CFrame = descendant.C1
			attachment1.Parent = descendant.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.UpperAngle = 55
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = descendant.Part0
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			if descendant.Parent == character then descendant.CanCollide = descendant.Name ~= "HumanoidRootPart" end
			if descendant:CanSetNetworkOwnership() then descendant:SetNetworkOwner(nil) end
		end
	end
end

local function createRevivePrompt(player: Player, runtime: RunRuntime, character: Model)
	clearRevivePrompt(runtime)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeammateRevive"
	prompt.ActionText = "Revive (hold 1.5s)"
	prompt.ObjectText = player.DisplayName .. " - DOWNED"
	prompt.HoldDuration = REVIVE_HOLD_SECONDS
	prompt.MaxActivationDistance = REVIVE_DISTANCE
	prompt.RequiresLineOfSight = false
	runtime.revivePrompt = prompt
	local holds: { [Player]: { startedAt: number, endedAt: number? } } = {}
	runtime.reviveHolds = holds
	local function canHelp(helper: Player): boolean
		local helperRuntime = runtimes[helper]
		local helperCharacter = helper.Character
		local helperRoot = helperCharacter and helperCharacter:FindFirstChild("HumanoidRootPart")
		local helperHumanoid = helperCharacter and helperCharacter:FindFirstChildOfClass("Humanoid")
		return helper ~= player and isPartyMember(helper) and isPartyMember(player)
			and helperRuntime ~= nil and not helperRuntime.dead and not helperRuntime.ended and not helperRuntime.restarting
			and runtimes[player] == runtime and runtime.dead and not runtime.ended and not runtime.restarting
			and player.Character == character and root.Parent ~= nil and prompt.Parent == root and prompt.Enabled
			and helperHumanoid ~= nil and helperHumanoid.Health > 0
			and helperRoot ~= nil and helperRoot:IsA("BasePart")
			and (helperRoot.Position - root.Position).Magnitude <= REVIVE_DISTANCE
	end
	-- Prompt events are client-triggered; validate both participants, distance, and elapsed hold on the server.
	runtime.reviveConnections = {
		prompt.PromptButtonHoldBegan:Connect(function(helper)
			holds[helper] = if canHelp(helper) then { startedAt = os.clock() } else nil
		end),
		prompt.PromptButtonHoldEnded:Connect(function(helper)
			local hold = holds[helper]
			if not hold then return end
			local now = os.clock()
			if now - hold.startedAt < REVIVE_HOLD_SECONDS - 0.05 then holds[helper] = nil else hold.endedAt = now end
		end),
		prompt.Triggered:Connect(function(helper)
			local hold = holds[helper]
			holds[helper] = nil
			local now = os.clock()
			-- A short delivery allowance accepts either ordering of release/completion without accepting old holds.
			if not hold or now - hold.startedAt < REVIVE_HOLD_SECONDS - 0.05
				or (hold.endedAt and now - hold.endedAt > 0.25) or not canHelp(helper) then return end
			RunSessionController.RevivePlayer(player, "Teammate")
		end),
	}
	prompt.Parent = root
end

local function initializePlayer(player: Player)
	if runtimes[player] or not ServerContext.IsGameServer() then return end
	runtimes[player] = {
		startedAt = ZombieController.GetFirstZombieSpawnedAt(), zombiesKilled = 0, coinsCollected = 0,
		dead = false, ended = false, resultPacket = nil, deathConnection = nil, returnToken = 0, restarting = false,
	}
end

local function returnPlayerToLobby(player: Player, runtime: RunRuntime, token: number)
	if runtimes[player] ~= runtime or runtime.returnToken ~= token or player.Parent ~= Players then return end
	local success, errorMessage = PartyTeleportService.ReturnToLobby(player)
	if not success then
		warn(string.format("Could not return %s to lobby: %s", player.Name, errorMessage or "Unknown error"))
		if sessionNetwork then sessionNetwork:fire(player, "LobbyReturnFailed", errorMessage or "Could not return to the lobby.") end
	end
end

local function endPartyRun()
	teamWipeRevision += 1
	teamWipeAt = nil
	local now = workspace:GetServerTimeNow()
	for _, player in getPartyPlayers() do
		local runtime = runtimes[player]
		if runtime and not runtime.ended then
			runtime.ended = true
			runtime.returnToken += 1
			disconnectDeath(runtime)
			clearRevivePrompt(runtime)
			local progression = RunProgressionController.GetRunSummary(player)
			runtime.resultPacket = {
				active = true, startedAt = runtime.startedAt, endedAt = now, returnAt = now + RETURN_DELAY,
				stats = { survivalTime = if runtime.startedAt then math.max(now - runtime.startedAt, 0) else 0,
					zombiesKilled = runtime.zombiesKilled, levelReached = progression.level,
					coinsCollected = runtime.coinsCollected, xpCollected = progression.totalXP },
			}
			AnalyticsController.StartReplayFunnel(player, progression.level, RoundController.GetCurrentRound())
			RunProgressionController.EndRun(player)
			AbilityController.EndRun(player)
			MonetizationController.ResetRun(player)
			RageController.EndRun(player)
			BackpackController.SetCarriedCoins(player, 0)
			local token = runtime.returnToken
			task.delay(RETURN_DELAY, returnPlayerToLobby, player, runtime, token)
		end
	end
	broadcastState()
end

local function scheduleTeamWipeIfNeeded()
	if #getPartyPlayers() == 0 or #getLivingUserIds() > 0 then
		teamWipeRevision += 1; teamWipeAt = nil; return
	end
	teamWipeRevision += 1
	local revision = teamWipeRevision
	teamWipeAt = workspace:GetServerTimeNow() + MonetizationConfig.Run.TeamWipeGraceSeconds
	broadcastState()
	-- The grace window supports a deliberate Revive purchase. Any successful revive invalidates this revision.
	task.delay(MonetizationConfig.Run.TeamWipeGraceSeconds, function()
		if revision == teamWipeRevision and #getLivingUserIds() == 0 then endPartyRun() end
	end)
end

function RunSessionController.GetSnapshot(_, player: Player)
	initializePlayer(player)
	local runtime = runtimes[player]
	return runtime and makeSnapshot(player, runtime) or { active = false, dead = false }
end

function RunSessionController.CanUseRunProduct(player: Player): boolean
	local runtime = runtimes[player]
	return ServerContext.IsGameServer() and runtime ~= nil and not runtime.ended and not runtime.restarting
end

function RunSessionController.CanRevivePlayer(player: Player): boolean
	local runtime = runtimes[player]
	return RunSessionController.CanUseRunProduct(player) and runtime.dead
end

function RunSessionController.GetEligibleTeamReviveCount(player: Player): number
	return if RunSessionController.CanUseRunProduct(player) then getDeadCount(player) else 0
end

function RunSessionController.RevivePlayer(player: Player, _source: string): boolean
	local runtime = runtimes[player]
	if not runtime or runtime.ended or runtime.restarting or not runtime.dead or player.Parent ~= Players then return false end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local reviveCFrame = if root and root:IsA("BasePart") then CFrame.new(root.Position + Vector3.yAxis * 3) else nil
	-- Death never grants an automatic wave respawn; only receipts and completed teammate prompts enter here.
	runtime.dead = false
	teamWipeRevision += 1; teamWipeAt = nil
	if not CharacterController.ReloadCharacter(player, reviveCFrame) then
		runtime.dead = true; scheduleTeamWipeIfNeeded(); return false
	end
	clearRevivePrompt(runtime)
	if runtimes[player] ~= runtime or player.Parent ~= Players then return false end
	broadcastState()
	return true
end

function RunSessionController.ReviveTeam(buyer: Player, source: string): number
	if not RunSessionController.CanUseRunProduct(buyer) then return 0 end
	local revived = 0
	for _, teammate in getPartyPlayers() do
		if teammate ~= buyer and RunSessionController.RevivePlayer(teammate, source) then revived += 1 end
	end
	return revived
end

local function restartParty()
	if restartingParty then return end
	local partyPlayers = getPartyPlayers()
	if #partyPlayers == 0 or getReplayVoteCount() < #partyPlayers then broadcastState(); return end
	restartingParty = true
	teamWipeRevision += 1; teamWipeAt = nil
	for _, player in partyPlayers do
		AnalyticsController.TrackReplayStep(player, 3)
		local runtime = runtimes[player]
		runtime.restarting = true; runtime.returnToken += 1; disconnectDeath(runtime); clearRevivePrompt(runtime)
	end
	local failedPlayers = {}
	for _, player in partyPlayers do if not CharacterController.ReloadCharacter(player) then table.insert(failedPlayers, player) end end
	if #failedPlayers > 0 then
		for _, player in partyPlayers do
			local runtime = runtimes[player]
			runtime.restarting = false
			if runtime.resultPacket then
				local token = runtime.returnToken
				task.delay(math.max(runtime.resultPacket.returnAt - workspace:GetServerTimeNow(), 0), returnPlayerToLobby, player, runtime, token)
			end
			if sessionNetwork then sessionNetwork:fire(player, "ReplayFailed", "Could not restart every player. Please try again.") end
		end
		restartingParty = false; return
	end
	XPDropController.ClearAll(); CoinDropController.ClearAll(); PowerupDropController.ClearAll(); ZombieController.RestartRun()
	table.clear(replayVotes)
	for _, player in partyPlayers do
		local runtime = runtimes[player]
		runtime.startedAt = nil; runtime.zombiesKilled = 0; runtime.coinsCollected = 0
		runtime.dead = false; runtime.ended = false; runtime.resultPacket = nil; runtime.restarting = false
		AbilityController.RestartRun(player); RunProgressionController.RestartRun(player)
		MonetizationController.ResetRun(player); RageController.EndRun(player); BackpackController.SetCarriedCoins(player, 0)
		RunSessionController.OnCharacterAdded(player, player.Character)
		AnalyticsController.TrackReplayStep(player, 4); AnalyticsController.StartGameplayRun(player)
	end
	task.defer(function() RoundController.RestartRun(); restartingParty = false; broadcastState() end)
end

function RunSessionController.RequestReplay(_, player: Player)
	local runtime = runtimes[player]
	if not runtime or not runtime.ended or runtime.restarting or replayVotes[player]
		or player.Parent ~= Players or not isPartyMember(player) or not ServerContext.IsGameServer() then return end
	replayVotes[player] = true; runtime.returnToken += 1
	AnalyticsController.TrackReplayStep(player, 2); restartParty()
end

function RunSessionController.Init()
	sessionNetwork = Networker.server.new("RunSessionController", RunSessionController, {
		RunSessionController.GetSnapshot, RunSessionController.RequestReplay,
	})
	local function beginSurvivalClock(startedAt: number)
		for player, runtime in runtimes do
			if not runtime.ended and not runtime.startedAt then
				runtime.startedAt = startedAt
				if player.Parent == Players then sessionNetwork:fire(player, "RunStarted", startedAt) end
				AnalyticsController.TrackGameplayStep(player, 2, nil)
			end
		end
	end
	ZombieController.GetFirstZombieSpawnedSignal():Connect(beginSurvivalClock)
	local existingStart = ZombieController.GetFirstZombieSpawnedAt()
	if existingStart then beginSurvivalClock(existingStart) end
	ZombieController.GetZombieDiedSignal():Connect(function(death)
		local killer = type(death) == "table" and death.killer or nil
		local runtime = killer and runtimes[killer]
		if runtime and not runtime.ended then
			runtime.zombiesKilled += 1
			if runtime.zombiesKilled == 1 then AnalyticsController.TrackGameplayStep(killer, 3, nil) end
		end
	end)
	CoinDropController.GetCoinCollectedSignal():Connect(function(player: Player, value: number)
		local runtime = runtimes[player]
		if runtime and not runtime.ended then runtime.coinsCollected += value end
	end)
	if RunService:IsStudio() then
		ServerContext.GetChangedSignal():Connect(function(serverType)
			if serverType == "Game" then for _, player in Players:GetPlayers() do initializePlayer(player) end end
		end)
	end
end

function RunSessionController.OnPlayerAdded(player: Player) initializePlayer(player); broadcastState() end

function RunSessionController.OnCharacterAdded(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime or runtime.ended then return end
	disconnectDeath(runtime)
	clearRevivePrompt(runtime)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		runtime.deathConnection = humanoid.Died:Connect(function()
			if runtimes[player] ~= runtime or player.Character ~= character or runtime.ended or runtime.dead or runtime.restarting then return end
			runtime.dead = true
			for _, teammateRuntime in runtimes do
				if teammateRuntime.reviveHolds then teammateRuntime.reviveHolds[player] = nil end
			end
			disconnectDeath(runtime)
			ragdollCharacter(character, humanoid)
			createRevivePrompt(player, runtime, character)
			broadcastState(); scheduleTeamWipeIfNeeded()
		end)
	end
end

function RunSessionController.OnPlayerRemoving(player: Player)
	local runtime = runtimes[player]
	if runtime then runtime.returnToken += 1; disconnectDeath(runtime); clearRevivePrompt(runtime) end
	for _, otherRuntime in runtimes do
		if otherRuntime.reviveHolds then otherRuntime.reviveHolds[player] = nil end
	end
	replayVotes[player] = nil; runtimes[player] = nil
	task.defer(function() restartParty(); scheduleTeamWipeIfNeeded(); broadcastState() end)
end

return RunSessionController
