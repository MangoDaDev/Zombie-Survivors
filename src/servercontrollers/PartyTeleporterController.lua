local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local PartyTeleporterConfig = require(ReplicatedStorage.Modules.Game.PartyTeleporterConfig)
local PartyTeleportService = require(script.Parent.PartyTeleportService)

local FONT = Font.fromName("ComicNeueAngular")
local AVAILABLE_COLOR = Color3.fromRGB(156, 161, 174)
local WAITING_COLOR = Color3.fromRGB(70, 158, 209)
local FULL_COLOR = Color3.fromRGB(71, 190, 104)
local STARTING_COLOR = Color3.fromRGB(241, 180, 67)

type WorldView = {
	billboard: BillboardGui,
	panel: Frame,
	status: TextLabel,
	occupancy: TextLabel,
	countdown: TextLabel,
	leader: TextLabel,
	light: PointLight,
}

type TeleporterState = {
	id: string,
	hitbox: BasePart,
	base: BasePart,
	baseDecals: { Decal },
	baseColor: Color3,
	baseMaterial: Enum.Material,
	entryCFrame: CFrame,
	exitCFrame: CFrame,
	view: WorldView,
	members: { Player },
	memberLookup: { [Player]: boolean },
	leader: Player?,
	maxSize: number,
	friendsOnly: boolean,
	configured: boolean,
	setupDeadline: number?,
	normalDeadline: number?,
	deadline: number?,
	fullAccelerated: boolean,
	locked: boolean,
	loading: boolean,
	teleportAttempt: number,
	activeRunId: string?,
	lastDisplayedSecond: number?,
}

local PartyTeleporterController = {}

local partyNetwork
local heartbeatConnection: RBXScriptConnection?
local zoneAccumulator = 0
local orderedStates: { TeleporterState } = {}
local playerState: { [Player]: TeleporterState } = {}
local suppressedUntilExit: { [Player]: TeleporterState } = {}
local lastRequestAt: { [Player]: number } = {}
local lastMessageAt: { [Player]: number } = {}
local teleportingPlayers: { [Player]: TeleporterState } = {}
local teleportingAttempts: { [Player]: number } = {}

local function makeLabel(name: string, parent: Instance, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.Position = position
	label.Size = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(24, 27, 34)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.03
	stroke.Parent = label
	return label
end

local function createWorldView(billboardLocation: BasePart): WorldView
	local previous = billboardLocation:FindFirstChild("PartyStatus")
	if previous then
		previous:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PartyStatus"
	billboard.Adornee = billboardLocation
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = PartyTeleporterConfig.WorldDisplayDistance
	-- Billboard scale components are measured in world studs, keeping the display tied to the
	-- teleporter rather than presenting as a fixed-pixel card at every distance.
	billboard.Size = UDim2.fromScale(11, 6.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	billboard.Parent = billboardLocation

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = billboard

	local status = makeLabel("Status", panel, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.22))
	local occupancy = makeLabel("Occupancy", panel, UDim2.fromScale(0.08, 0.27), UDim2.fromScale(0.84, 0.27))
	local countdown = makeLabel("Countdown", panel, UDim2.fromScale(0.08, 0.55), UDim2.fromScale(0.84, 0.2))
	local leader = makeLabel("Leader", panel, UDim2.fromScale(0.08, 0.78), UDim2.fromScale(0.84, 0.14))
	leader.TextColor3 = Color3.fromRGB(228, 232, 240)

	local light = Instance.new("PointLight")
	light.Name = "PartyLight"
	light.Brightness = 0.8
	light.Color = AVAILABLE_COLOR
	light.Range = 13
	light.Parent = billboardLocation

	return {
		billboard = billboard,
		panel = panel,
		status = status,
		occupancy = occupancy,
		countdown = countdown,
		leader = leader,
		light = light,
	}
end

local function getCountdown(state: TeleporterState, now: number): number?
	local activeDeadline = if state.configured then state.deadline else state.setupDeadline
	if not activeDeadline then
		return nil
	end
	return math.max(0, math.ceil(activeDeadline - now))
end

local function updateWorldView(state: TeleporterState, now: number)
	local memberCount = #state.members
	local countdown = getCountdown(state, now)
	local color = AVAILABLE_COLOR
	local status = "OPEN"

	if state.locked then
		color = STARTING_COLOR
		status = if state.loading then "LOADING..." else "STARTING..."
	elseif memberCount > 0 and not state.configured then
		color = WAITING_COLOR
		status = "CONFIGURING"
	elseif memberCount >= state.maxSize and memberCount > 0 then
		color = FULL_COLOR
		status = "FULL"
	elseif memberCount > 0 then
		color = WAITING_COLOR
		status = if state.friendsOnly then "FRIENDS ONLY" else "OPEN TO EVERYONE"
	end

	state.view.status.Text = status
	state.view.status.TextColor3 = color
	state.view.occupancy.Text = string.format("%d / %d", memberCount, state.maxSize)
	state.view.countdown.Text = if memberCount > 0 and not state.configured
		then "LEADER SETTING UP"
		elseif countdown then string.format("%ds", countdown)
		else "ENTER TO JOIN"
	state.view.leader.Text = if state.leader then "LEADER  " .. state.leader.DisplayName else ""
	state.view.light.Color = color
	state.view.light.Brightness = if state.locked then 2.8 elseif memberCount > 0 then 1.55 else 0.8
	local baseTint = state.baseColor:Lerp(color, if memberCount > 0 then 0.62 else 0.15)
	state.base.Color = baseTint
	-- Keep the authored base decals synchronized with the teleporter's state color.
	for _, decal in state.baseDecals do
		decal.Color3 = baseTint
	end
	state.base.Material = if memberCount > 0 then Enum.Material.Neon else state.baseMaterial
	state.lastDisplayedSecond = countdown
end

local function playSound(state: TeleporterState, soundName: string)
	local sounds = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Sounds")
	local template = sounds and sounds:FindFirstChild(soundName)
	if not template or not template:IsA("Sound") then
		return
	end
	local sound = template:Clone()
	sound.Parent = state.view.billboard.Adornee
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 1)
end

local function makePacket(state: TeleporterState, player: Player)
	return {
		teleporterId = state.id,
		memberCount = #state.members,
		maxSize = state.maxSize,
		leaderUserId = state.leader and state.leader.UserId or 0,
		leaderName = state.leader and state.leader.DisplayName or "",
		friendsOnly = state.friendsOnly,
		configuring = not state.configured,
		countdown = getCountdown(state, Workspace:GetServerTimeNow()),
		isLeader = state.leader == player,
		locked = state.locked,
		loading = state.loading,
	}
end

local function sendPlayerState(player: Player, state: TeleporterState?)
	if player.Parent == Players then
		partyNetwork:fire(player, "PartyStateChanged", if state then makePacket(state, player) else nil)
	end
end

local function broadcastState(state: TeleporterState)
	for _, member in state.members do
		sendPlayerState(member, state)
	end
end

local function notify(player: Player, message: string, kind: string?)
	if player.Parent == Players then
		partyNetwork:fire(player, "PartyMessage", message, kind or "Info")
	end
end

local function notifyThrottled(player: Player, message: string)
	local now = os.clock()
	if now - (lastMessageAt[player] or -math.huge) < 2 then
		return
	end
	lastMessageAt[player] = now
	notify(player, message, "Error")
end

local function isInside(state: TeleporterState, player: Player, padding: number?): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end

	local localPosition = state.hitbox.CFrame:PointToObjectSpace(root.Position)
	local halfSize = state.hitbox.Size * 0.5
	local horizontalPadding = padding or 0
	return math.abs(localPosition.X) <= halfSize.X + horizontalPadding
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z + horizontalPadding
end

local function movePlayer(player: Player, targetCFrame: CFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	character:PivotTo(targetCFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function canJoinFriendsOnly(state: TeleporterState, player: Player): boolean
	local leader = state.leader
	if not state.friendsOnly or not leader or leader == player then
		return true
	end

	local success, isFriend = pcall(leader.IsFriendsWith, leader, player.UserId)
	return success and isFriend == true
end

local function restoreNormalCountdown(state: TeleporterState, now: number)
	if not state.fullAccelerated then
		return
	end
	state.fullAccelerated = false
	state.deadline = math.max(state.normalDeadline or now, now + PartyTeleporterConfig.LeaveRecoveryCountdown)
end

local function updateFullCountdown(state: TeleporterState, now: number)
	if state.locked or not state.configured or #state.members == 0 then
		return
	end
	if #state.members >= state.maxSize then
		if not state.fullAccelerated then
			state.fullAccelerated = true
			state.deadline = math.min(state.deadline or math.huge, now + PartyTeleporterConfig.FullCountdown)
		end
	else
		restoreNormalCountdown(state, now)
	end
end

local function resetState(state: TeleporterState, suppressMembers: boolean?)
	if state.activeRunId then
		PartyTeleportService.Cancel(state.activeRunId)
	end
	for _, member in state.members do
		playerState[member] = nil
		teleportingPlayers[member] = nil
		teleportingAttempts[member] = nil
		if suppressMembers then
			suppressedUntilExit[member] = state
		end
		sendPlayerState(member, nil)
	end
	table.clear(state.members)
	table.clear(state.memberLookup)
	state.leader = nil
	state.maxSize = PartyTeleporterConfig.DefaultPartySize
	state.friendsOnly = false
	state.configured = false
	state.setupDeadline = nil
	state.normalDeadline = nil
	state.deadline = nil
	state.fullAccelerated = false
	state.locked = false
	state.loading = false
	state.activeRunId = nil
	state.teleportAttempt += 1
	updateWorldView(state, Workspace:GetServerTimeNow())
end

local function finishSetup(state: TeleporterState, now: number)
	if state.locked or state.configured or #state.members == 0 then
		return
	end

	state.configured = true
	state.setupDeadline = nil
	state.normalDeadline = now + PartyTeleporterConfig.NormalCountdown
	state.deadline = state.normalDeadline
	updateFullCountdown(state, now)
	updateWorldView(state, now)
	broadcastState(state)
	playSound(state, "Popup")
end

local function expireSetup(state: TeleporterState)
	local members = table.clone(state.members)
	for _, member in members do
		notify(member, "Party setup expired because it was not confirmed.", "Error")
	end

	-- Setup expiry must never auto-confirm. Eject every unconfirmed member and suppress zone
	-- re-entry until they physically leave the teleporter so the same timeout cannot loop.
	resetState(state, true)
	for _, member in members do
		movePlayer(member, state.exitCFrame)
	end
end

local function removeMember(state: TeleporterState, player: Player, suppressUntilExit: boolean?)
	if not state.memberLookup[player] then
		return
	end
	state.memberLookup[player] = nil
	playerState[player] = nil
	teleportingPlayers[player] = nil
	teleportingAttempts[player] = nil
	if suppressUntilExit then
		suppressedUntilExit[player] = state
	end

	local index = table.find(state.members, player)
	if index then
		table.remove(state.members, index)
	end
	sendPlayerState(player, nil)

	if #state.members == 0 then
		resetState(state)
		return
	end
	if state.leader == player then
		state.leader = state.members[1]
		notify(state.leader, "You are now the party leader.", "Success")
	end

	updateFullCountdown(state, Workspace:GetServerTimeNow())
	updateWorldView(state, Workspace:GetServerTimeNow())
	broadcastState(state)
	playSound(state, "Pop")
end

local function tryAddMember(state: TeleporterState, player: Player)
	if state.locked or playerState[player] then
		return
	end
	if #state.members >= state.maxSize then
		notifyThrottled(player, "That party is full.")
		return
	end
	if not canJoinFriendsOnly(state, player) then
		notifyThrottled(player, "That party is friends-only.")
		return
	end

	local now = Workspace:GetServerTimeNow()
	state.memberLookup[player] = true
	table.insert(state.members, player)
	playerState[player] = state
	-- The authored teleporter is a closed elevator. Its outer hitbox edge accepts the player,
	-- then the server places them inside; the Exit request is the only normal way back out.
	movePlayer(player, state.entryCFrame)
	if not state.leader then
		state.leader = player
		state.setupDeadline = now + PartyTeleporterConfig.SetupDuration
	end

	updateFullCountdown(state, now)
	updateWorldView(state, now)
	broadcastState(state)
	playSound(state, "Popup")
end

local function failTeleport(state: TeleporterState, message: string, attempt: number?)
	if not state.locked or (attempt and state.teleportAttempt ~= attempt) then
		return
	end
	local members = table.clone(state.members)
	for _, member in members do
		notify(member, message, "Error")
	end
	resetState(state, true)
	for _, member in members do
		movePlayer(member, state.exitCFrame)
	end
end

local function findStateForRun(runId: string, players: { Player }): TeleporterState?
	for _, player in players do
		local state = teleportingPlayers[player]
		if state and state.activeRunId == runId then
			return state
		end
	end
	return nil
end

local function startTeleport(state: TeleporterState)
	if state.locked or #state.members == 0 then
		return
	end

	local validMembers = {}
	for _, member in state.members do
		if member.Parent == Players and isInside(state, member) then
			table.insert(validMembers, member)
		end
	end
	if #validMembers == 0 or not state.leader or not table.find(validMembers, state.leader) then
		local members = table.clone(state.members)
		resetState(state, true)
		for _, member in members do
			movePlayer(member, state.exitCFrame)
		end
		return
	end

	state.locked = true
	state.teleportAttempt += 1
	local teleportAttempt = state.teleportAttempt
	updateWorldView(state, Workspace:GetServerTimeNow())
	broadcastState(state)
	playSound(state, "CountdownBeep")
	for _, member in validMembers do
		teleportingPlayers[member] = state
		teleportingAttempts[member] = teleportAttempt
	end

	task.spawn(function()
		local runId = HttpService:GenerateGUID(false)
		state.activeRunId = runId
		local success, errorMessage = PartyTeleportService.Teleport(validMembers, state.leader :: Player, runId)
		if not success then
			warn("Party teleport failed: " .. (errorMessage or "Unknown error"))
			failTeleport(state, errorMessage or "Teleport failed. Everyone was returned to the lobby.", teleportAttempt)
			return
		end

		-- TeleportInitFailed handles explicit failures. This watchdog also recovers if Roblox leaves
		-- the party in this server without producing a synchronous error.
		task.delay(PartyTeleporterConfig.TeleportWatchdogDuration, function()
			if state.locked and state.teleportAttempt == teleportAttempt and #state.members > 0 then
				failTeleport(state, "Teleport timed out. Everyone was returned to the lobby.", teleportAttempt)
			end
		end)
	end)
end

local function stepZones(deltaTime: number)
	zoneAccumulator += deltaTime
	if zoneAccumulator < PartyTeleporterConfig.ZoneCheckInterval then
		return
	end
	zoneAccumulator = 0
	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local currentState = playerState[player]
		if currentState and not currentState.locked and not isInside(currentState, player) then
			removeMember(currentState, player)
			currentState = nil
		end

		local suppressedState = suppressedUntilExit[player]
		if suppressedState and not isInside(suppressedState, player) then
			suppressedUntilExit[player] = nil
			suppressedState = nil
		end

		if not currentState and not suppressedState then
			for _, state in orderedStates do
				if isInside(state, player, PartyTeleporterConfig.EntryPadding) then
					tryAddMember(state, player)
					break
				end
			end
		end
	end

	for _, state in orderedStates do
		if #state.members > 0 and not state.locked then
			if not state.configured then
				local countdown = getCountdown(state, now)
				if countdown and countdown <= 0 then
					expireSetup(state)
				elseif countdown ~= state.lastDisplayedSecond then
					updateWorldView(state, now)
					broadcastState(state)
				end
			else
				local countdown = getCountdown(state, now)
				if countdown and countdown <= 0 then
					startTeleport(state)
				elseif countdown ~= state.lastDisplayedSecond then
					updateWorldView(state, now)
					broadcastState(state)
					if countdown and countdown <= 3 then
						playSound(state, "CountdownBeep")
					end
				end
			end
		end
	end
end

local function canRequest(player: Player): boolean
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < PartyTeleporterConfig.RequestCooldown then
		return false
	end
	lastRequestAt[player] = now
	return true
end

function PartyTeleporterController.GetState(_, player: Player)
	local state = playerState[player]
	return state and makePacket(state, player) or nil
end

function PartyTeleporterController.SetMaxPartySize(_, player: Player, maximumSize: any)
	local state = playerState[player]
	if not canRequest(player)
		or not state
		or state.locked
		or state.configured
		or state.leader ~= player
		or type(maximumSize) ~= "number"
		or maximumSize % 1 ~= 0
		or maximumSize < PartyTeleporterConfig.MinimumPartySize
		or maximumSize > PartyTeleporterConfig.MaximumPartySize
		or maximumSize < #state.members
	then
		return
	end
	state.maxSize = maximumSize
	updateFullCountdown(state, Workspace:GetServerTimeNow())
	updateWorldView(state, Workspace:GetServerTimeNow())
	broadcastState(state)
end

function PartyTeleporterController.SetFriendsOnly(_, player: Player, enabled: any)
	local state = playerState[player]
	if not canRequest(player)
		or not state
		or state.locked
		or state.configured
		or state.leader ~= player
		or type(enabled) ~= "boolean"
	then
		return
	end
	state.friendsOnly = enabled
	updateWorldView(state, Workspace:GetServerTimeNow())
	broadcastState(state)
end

function PartyTeleporterController.ConfirmParty(_, player: Player)
	if not canRequest(player) then
		return
	end
	local state = playerState[player]
	if state and not state.locked and not state.configured and state.leader == player then
		finishSetup(state, Workspace:GetServerTimeNow())
	end
end

function PartyTeleporterController.LeaveParty(_, player: Player)
	if not canRequest(player) then
		return
	end
	local state = playerState[player]
	if state and not state.locked then
		removeMember(state, player, true)
		movePlayer(player, state.exitCFrame)
	end
end

function PartyTeleporterController.CancelParty(_, player: Player)
	if not canRequest(player) then
		return
	end
	local state = playerState[player]
	if state and not state.locked and state.leader == player then
		local members = table.clone(state.members)
		for _, member in members do
			notify(member, "The party was cancelled.", "Info")
		end
		resetState(state, true)
		for _, member in members do
			movePlayer(member, state.exitCFrame)
		end
	end
end

function PartyTeleporterController.Init()
	partyNetwork = Networker.server.new("PartyTeleporterController", PartyTeleporterController, {
		PartyTeleporterController.GetState,
		PartyTeleporterController.SetMaxPartySize,
		PartyTeleporterController.SetFriendsOnly,
		PartyTeleporterController.ConfirmParty,
		PartyTeleporterController.LeaveParty,
		PartyTeleporterController.CancelParty,
	})

	local lobby = Workspace:FindFirstChild("Lobby")
	local teleportersFolder = lobby and lobby:FindFirstChild("Teleporters")
	if not teleportersFolder or not teleportersFolder:IsA("Folder") then
		-- Game servers intentionally move the entire lobby out of Workspace; the network endpoint remains
		-- available so the shared client bootstrap can resolve an empty party state without special cases.
		return
	end
	local lobbySpawn = lobby:FindFirstChild("LobbySpawnPos")
	if not lobbySpawn or not lobbySpawn:IsA("BasePart") then
		warn("PartyTeleporterController requires Workspace.Lobby.LobbySpawnPos")
		return
	end

	local models = {}
	for _, child in teleportersFolder:GetChildren() do
		if child:IsA("Model") and child.Name == "Teleporter" then
			table.insert(models, child)
		end
	end
	table.sort(models, function(left, right)
		return left:GetPivot().Position.Z < right:GetPivot().Position.Z
	end)

	for index, model in models do
		local hitbox = model:FindFirstChild("Hitbox")
		local billboardLocation = model:FindFirstChild("BillboardLocation")
		local base = model:FindFirstChild("Base")
		if not hitbox or not hitbox:IsA("BasePart")
			or not billboardLocation or not billboardLocation:IsA("BasePart")
			or not base or not base:IsA("BasePart")
		then
			warn(string.format("PartyTeleporterController skipped malformed teleporter %s", model:GetFullName()))
			continue
		end

		-- The authored Hitbox defines the zone only; it must never physically block players from entering.
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = false
		-- Do not disable any authored Collision walls. Players enter through the hitbox edge and are
		-- placed inside by the server, then use the explicit Exit button to leave the closed elevator.
		local insidePosition = Vector3.new(
			hitbox.Position.X,
			base.Position.Y + base.Size.Y * 0.5 + 3,
			hitbox.Position.Z
		)
		local exitDirection = Vector3.new(
			lobbySpawn.Position.X - insidePosition.X,
			0,
			lobbySpawn.Position.Z - insidePosition.Z
		).Unit
		local localExitDirection = hitbox.CFrame:VectorToObjectSpace(exitDirection)
		local halfSize = hitbox.Size * 0.5
		local edgeDistance = math.abs(localExitDirection.X) * halfSize.X
			+ math.abs(localExitDirection.Z) * halfSize.Z
		local exitPosition = insidePosition
			+ exitDirection * (edgeDistance + PartyTeleporterConfig.EntryPadding + 4)
		local baseDecals: { Decal } = {}
		for _, baseChild in base:GetChildren() do
			if baseChild:IsA("Decal") then
				table.insert(baseDecals, baseChild)
			end
		end
		local state: TeleporterState = {
			id = tostring(index),
			hitbox = hitbox,
			base = base,
			baseDecals = baseDecals,
			baseColor = base.Color,
			baseMaterial = base.Material,
			entryCFrame = CFrame.lookAt(insidePosition, insidePosition + exitDirection),
			exitCFrame = CFrame.lookAt(exitPosition, exitPosition + exitDirection),
			view = createWorldView(billboardLocation),
			members = {},
			memberLookup = {},
			leader = nil,
			maxSize = PartyTeleporterConfig.DefaultPartySize,
			friendsOnly = false,
			configured = false,
			setupDeadline = nil,
			normalDeadline = nil,
			deadline = nil,
			fullAccelerated = false,
			locked = false,
			loading = false,
			teleportAttempt = 0,
			activeRunId = nil,
			lastDisplayedSecond = nil,
		}
		table.insert(orderedStates, state)
		updateWorldView(state, Workspace:GetServerTimeNow())
	end

	TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
		local state = teleportingPlayers[player]
		local attempt = teleportingAttempts[player]
		if state and attempt then
			warn(string.format("Teleport failed for %s (%s): %s", player.Name, teleportResult.Name, errorMessage))
			failTeleport(state, "Teleport failed. Everyone was returned to the lobby.", attempt)
		end
	end)
	if RunService:IsStudio() then
		-- These signals are emitted only by the guarded local simulator; published success remains Roblox-owned.
		PartyTeleportService.GetStudioLoadingStartedSignal():Connect(function(runId, players)
			local state = findStateForRun(runId, players)
			if state and state.locked then
				state.loading = true
				updateWorldView(state, Workspace:GetServerTimeNow())
				broadcastState(state)
			end
		end)
		PartyTeleportService.GetStudioCompletedSignal():Connect(function(runId, players)
			local state = findStateForRun(runId, players)
			if state and state.locked then
				resetState(state)
			end
		end)
		PartyTeleportService.GetStudioFailedSignal():Connect(function(runId, players, errorMessage)
			local state = findStateForRun(runId, players)
			if state then
				failTeleport(state, errorMessage or "The Studio teleport failed.")
			end
		end)
	end
	heartbeatConnection = RunService.Heartbeat:Connect(stepZones)
end

function PartyTeleporterController.OnPlayerRemoving(player: Player)
	local state = playerState[player]
	if state then
		removeMember(state, player)
	end
	playerState[player] = nil
	suppressedUntilExit[player] = nil
	lastRequestAt[player] = nil
	lastMessageAt[player] = nil
	teleportingPlayers[player] = nil
	teleportingAttempts[player] = nil
end

return PartyTeleporterController
