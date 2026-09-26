local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local localPlayer = Players.LocalPlayer
local readySignal = Signal.new()
local deathConnection: RBXScriptConnection?
local workspaceChildAddedConnection: RBXScriptConnection?
local workspaceChildRemovedConnection: RBXScriptConnection?
local currentCameraConnection: RBXScriptConnection?

local GAMEPLAY_CAMERA_BINDING = "GameplayTopDownCamera"
local GAMEPLAY_FIELD_OF_VIEW = 46
local CAMERA_HEIGHT = 32
local CAMERA_BEHIND_DISTANCE = 15
local CAMERA_FOCUS_HEIGHT = 2.5
local CAMERA_FOLLOW_RESPONSIVENESS = 9
local CAMERA_RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1

type CameraState = {
	camera: Camera,
	cameraType: Enum.CameraType,
	cameraSubject: Instance?,
	cframe: CFrame,
	fieldOfView: number,
}

local CharacterController = {}
local CharacterNetwork: Networker.Client?
local IsReady = false
local gameplayCameraEnabled = false
local savedCameraState: CameraState? = nil
local smoothedFocus: Vector3? = nil

local function getLiveRoot(): BasePart?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
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

	local root = getLiveRoot()
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

	local root = getLiveRoot()
	if not root then
		return
	end
	local desiredFocus = root.Position + Vector3.yAxis * CAMERA_FOCUS_HEIGHT
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
		claimCurrentCamera()
		-- This runs just before Roblox's normal camera priority. Scriptable mode prevents the default
		-- camera from competing, while later one-frame presentation impulses can remain additive.
		RunService:BindToRenderStep(GAMEPLAY_CAMERA_BINDING, CAMERA_RENDER_PRIORITY, renderGameplayCamera)
	else
		RunService:UnbindFromRenderStep(GAMEPLAY_CAMERA_BINDING)
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
		-- A game-session death ends the run; RunSessionController owns the personal result/countdown flow.
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
