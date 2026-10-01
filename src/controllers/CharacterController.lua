local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RunProgressionController = require(ReplicatedStorage.Controllers.RunProgressionController)
local RunSessionController = require(ReplicatedStorage.Controllers.RunSessionController)

local localPlayer = Players.LocalPlayer
local readySignal = Signal.new()
local deathConnection: RBXScriptConnection?
local workspaceChildAddedConnection: RBXScriptConnection?
local workspaceChildRemovedConnection: RBXScriptConnection?
local currentCameraConnection: RBXScriptConnection?
local progressionStateConnection: RBXScriptConnection?
local sessionStateConnection: RBXScriptConnection?
local spectateConnection: RBXScriptConnection?

local GAMEPLAY_CAMERA_BINDING = "GameplayTopDownCamera"
local GAMEPLAY_FIELD_OF_VIEW = 46
-- Keep the gameplay camera substantially zoomed out so players can read incoming hordes and hazards
-- well before they reach melee range. These offsets preserve the established viewing angle.
local CAMERA_HEIGHT = 64
local CAMERA_BEHIND_DISTANCE = 30
local CAMERA_FOCUS_HEIGHT = 2.5
local CAMERA_CHOICE_FORWARD_OFFSET = 4.5
local CAMERA_FOLLOW_RESPONSIVENESS = 9
local CAMERA_RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1

type CameraState = {
	camera: Camera,
	cameraType: Enum.CameraType,
	cameraSubject: Instance?,
	cframe: CFrame,
	fieldOfView: number,
}

type ListenerState = {
	listenerType: Enum.ListenerType,
	listener: any,
}

local CharacterController = {}
local CharacterNetwork: Networker.Client?
local IsReady = false
local gameplayCameraEnabled = false
local savedCameraState: CameraState? = nil
local savedListenerState: ListenerState? = nil
local gameplayListenerRoot: BasePart? = nil
local smoothedFocus: Vector3? = nil
local choiceAvailable = false

local function updateChoiceAvailability(runState)
	choiceAvailable = runState.active == true and type(runState.choices) == "table" and #runState.choices > 0
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getCameraRoot(): BasePart?
	local localRoot = getCharacterRoot(localPlayer)
	if localRoot then return localRoot end
	-- A downed player observes a living teammate without gaining movement or combat authority.
	local spectatePlayer = RunSessionController.GetSpectatePlayer()
	return if spectatePlayer then getCharacterRoot(spectatePlayer) else nil
end

local function restoreCamera()
	local state = savedCameraState
	savedCameraState = nil
	smoothedFocus = nil
	if not state or not state.camera.Parent then
		return
	end

	-- Only undo camera state that this controller owns. This keeps lobby camera systems free to take
	-- control if one has already replaced the gameplay camera during a session transition.
	if state.camera.CameraType == Enum.CameraType.Scriptable then
		state.camera.CameraType = state.cameraType
		state.camera.CFrame = state.cframe
		state.camera.FieldOfView = state.fieldOfView
		if state.cameraSubject and state.cameraSubject.Parent then
			state.camera.CameraSubject = state.cameraSubject
		end
	end
end

local function restoreAudioListener()
	local state = savedListenerState
	savedListenerState = nil
	if not state then
		return
	end

	local listenerType, listener = SoundService:GetListener()
	-- Only restore the previous listener while this controller still owns it. A lobby audio system is
	-- free to replace the listener during a session transition without being overwritten here.
	if listenerType == Enum.ListenerType.ObjectPosition and listener == gameplayListenerRoot then
		SoundService:SetListener(state.listenerType, state.listener)
	end
	gameplayListenerRoot = nil
end

local function updateGameplayAudioListener(root: BasePart)
	local listenerType, listener = SoundService:GetListener()
	if listenerType ~= Enum.ListenerType.ObjectPosition or listener ~= root then
		-- The top-down camera sits far above the battlefield, which would heavily attenuate every
		-- world-space sound. Listen from the character so spatial sounds retain their authored volume.
		SoundService:SetListener(Enum.ListenerType.ObjectPosition, root)
	end
	gameplayListenerRoot = root
end

local function claimCurrentCamera()
	restoreCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	savedCameraState = {
		camera = camera,
		cameraType = camera.CameraType,
		cameraSubject = camera.CameraSubject,
		cframe = camera.CFrame,
		fieldOfView = camera.FieldOfView,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = GAMEPLAY_FIELD_OF_VIEW

	local root = getCameraRoot()
	if root then
		smoothedFocus = root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT
	end
end

local function renderGameplayCamera(deltaTime: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not savedCameraState or savedCameraState.camera ~= camera then
		claimCurrentCamera()
	end

	local root = getCameraRoot()
	if not root then
		return
	end
	updateGameplayAudioListener(root)
	-- A live choice reel occupies the upper screen, so frame a little farther ahead along the fixed
	-- camera heading. This keeps the character slightly lower without moving gameplay geometry.
	local choiceOffset = if choiceAvailable then Vector3.new(0, 0, -CAMERA_CHOICE_FORWARD_OFFSET) else Vector3.zero
	local desiredFocus = root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT + choiceOffset
	-- Exponential smoothing is frame-rate independent and follows translation only. The fixed world
	-- heading deliberately avoids rotating the whole battlefield whenever the character turns.
	local followAlpha = 1 - math.exp(-CAMERA_FOLLOW_RESPONSIVENESS * math.max(deltaTime, 0))
	smoothedFocus = if smoothedFocus then smoothedFocus:Lerp(desiredFocus, followAlpha) else desiredFocus

	local focus = smoothedFocus :: Vector3
	local cameraPosition = focus + Vector3.new(0, CAMERA_HEIGHT, CAMERA_BEHIND_DISTANCE)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPosition, focus, Vector3.yAxis)
end

local function setGameplayCameraEnabled(enabled: boolean)
	if gameplayCameraEnabled == enabled then
		return
	end
	gameplayCameraEnabled = enabled
	if enabled then
		local listenerType, listener = SoundService:GetListener()
		savedListenerState = {
			listenerType = listenerType,
			listener = listener,
		}
		claimCurrentCamera()
		-- This runs just before Roblox's normal camera priority. Scriptable mode prevents the default
		-- camera from competing, while later one-frame presentation impulses can remain additive.
		RunService:BindToRenderStep(GAMEPLAY_CAMERA_BINDING, CAMERA_RENDER_PRIORITY, renderGameplayCamera)
	else
		RunService:UnbindFromRenderStep(GAMEPLAY_CAMERA_BINDING)
		restoreAudioListener()
		restoreCamera()
	end
end

local function updateGameplayCameraState()
	-- The authoritative map controller exposes exactly one top-level Game map in round servers.
	-- Using that boundary keeps the lobby and its scripted class-preview camera entirely unchanged.
	setGameplayCameraEnabled(Workspace:FindFirstChild("Game") ~= nil)
end

function CharacterController.Init()
	CharacterNetwork = Networker.client.new("CharacterController", CharacterController)
	if workspaceChildAddedConnection then
		workspaceChildAddedConnection:Disconnect()
	end
	if workspaceChildRemovedConnection then
		workspaceChildRemovedConnection:Disconnect()
	end
	if currentCameraConnection then
		currentCameraConnection:Disconnect()
	end
	if progressionStateConnection then
		progressionStateConnection:Disconnect()
	end
	if sessionStateConnection then
		sessionStateConnection:Disconnect()
	end
	if spectateConnection then
		spectateConnection:Disconnect()
	end
	workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Game" then
			updateGameplayCameraState()
		end
	end)
	workspaceChildRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Game" then
			updateGameplayCameraState()
		end
	end)
	currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if gameplayCameraEnabled then
			claimCurrentCamera()
		end
	end)
	updateChoiceAvailability(RunProgressionController.GetState())
	progressionStateConnection = RunProgressionController.GetStateChangedSignal():Connect(updateChoiceAvailability)
	sessionStateConnection = RunSessionController.GetStateChangedSignal():Connect(function()
		-- Snap on spectate transitions so the camera never sweeps across the whole arena between teammates.
		local root = getCameraRoot()
		smoothedFocus = root and (root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT) or nil
	end)
	spectateConnection = RunSessionController.GetSpectateChangedSignal():Connect(function()
		local root = getCameraRoot()
		smoothedFocus = root and (root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT) or nil
	end)
	updateGameplayCameraState()
	IsReady = true
	readySignal:Fire()
end

function CharacterController.WaitUntilReady()
	if not IsReady then
		readySignal:Wait()
	end
end

function CharacterController.RequestCharacter(): boolean
	CharacterController.WaitUntilReady()
	return (CharacterNetwork :: Networker.Client):fetch("RequestCharacter") == true
end

function CharacterController.OnCharacterAdded(character: Model)
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local camera = Workspace.CurrentCamera
	if camera and not gameplayCameraEnabled and camera.CameraType == Enum.CameraType.Custom then
		camera.CameraSubject = humanoid
	elseif gameplayCameraEnabled then
		-- Snap the smoothing anchor to a new run character so a replay never pans across the arena
		-- from the dead character's last position.
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			smoothedFocus = root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT
		end
	end
	deathConnection = humanoid.Died:Connect(function()
		-- The shared run continues while any teammate lives. The session controller selects the spectate
		-- target and authorizes either the fifth-wave checkpoint respawn or a purchased revive.
		if Workspace:FindFirstChild("Game") then
			return
		end
		task.delay(Players.RespawnTime, function()
			if localPlayer.Character == character or localPlayer.Character == nil then
				CharacterController.RequestCharacter()
			end
		end)
	end)
end

return CharacterController
