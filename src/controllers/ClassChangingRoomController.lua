local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassController = require(script.Parent.ClassController)
local ClassAccessoryFit = require(ReplicatedStorage.Modules.Game.Classes.ClassAccessoryFit)

local localPlayer = Players.LocalPlayer
local ClassChangingRoomController = {}

local ROOM_POSITION = Vector3.new(0, 3000, 0)
local ROOM_PARTS = {
	"Origin", "Floor", "BackWall", "LeftWall", "RightWall",
	"LeftLocker", "RightLocker", "LeftLockerInset", "RightLockerInset",
	"TopRail", "LeftRail", "RightRail", "FrontFloorTrim", "RearBaseTrim",
}
local scene: Model?
local avatar: Model?
local camera: Camera?
local previousCameraType: Enum.CameraType?
local previousCameraSubject: Instance?
local previousCameraCFrame: CFrame?
local previousFieldOfView: number?
local viewportConnection: RBXScriptConnection?
local revision = 0

local function frameCamera()
	if not avatar or not camera then return end
	local _, size = avatar:GetBoundingBox()
	local height = size.Y
	local viewport = camera.ViewportSize
	local portrait = viewport.X < 600 and viewport.X < viewport.Y
	-- Reserve the upper portion of the screen for the entire avatar; the class
	-- description and action occupy the lower-right portion on every viewport.
	local distance = math.max(if portrait then 12 else 10, height * (if portrait then 4.1 else 2.6))
	-- Looking toward +Z makes camera-right point toward world -X. Aim right of the
	-- avatar in world space so the avatar lands on the visible right side of the UI.
	local lookX = if portrait then 2.2 else 4
	local target = ROOM_POSITION + Vector3.new(lookX, height * (if portrait then 0.05 else 0.15), 0)
	local eye = ROOM_POSITION + Vector3.new(lookX, height * 0.55, -distance)
	camera.CFrame = CFrame.lookAt(eye, target)
	camera.Focus = CFrame.new(ROOM_POSITION + Vector3.new(0, height * 0.5, 0))
end

local function updateAvatar()
	if not scene then return end
	if avatar then avatar:Destroy(); avatar = nil end
	local character = localPlayer.Character
	if not character then return end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	clone.Name = "ClassPreviewAvatar"
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.LocalTransparencyModifier = 0
		elseif descendant:IsA("Motor6D") then
			-- A neutral pose avoids freezing the preview in a mid-run animation frame.
			descendant.Transform = CFrame.identity
		end
	end
	local oldAccessory = clone:FindFirstChild("ClassAccessory")
	if oldAccessory then oldAccessory:Destroy() end
	clone:PivotTo(CFrame.new(ROOM_POSITION))
	local bounds, size = clone:GetBoundingBox()
	clone:PivotTo(clone:GetPivot() + Vector3.new(-bounds.Position.X + ROOM_POSITION.X, ROOM_POSITION.Y + size.Y / 2 - bounds.Position.Y, -bounds.Position.Z + ROOM_POSITION.Z))
	clone.Parent = scene
	avatar = clone

	local head = clone:FindFirstChild("Head")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local classes = models and models:FindFirstChild("Classes")
	local template = classes and classes:FindFirstChild(ClassController.GetPreviewClassId())
	if head and head:IsA("BasePart") and template and template:IsA("Model") then
		-- Only the Workspace preview gets this headpiece; purchases and live appearance remain authoritative.
		local accessory = template:Clone()
		accessory.Name = "PreviewClassAccessory"
		ClassAccessoryFit.FitToHead(accessory, head)
		for _, part in accessory:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		accessory.Parent = clone
	end
	frameCamera()
end

local function closeRoom()
	revision += 1
	if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
	if avatar then avatar:Destroy(); avatar = nil end
	if scene then scene:Destroy(); scene = nil end
	if camera and camera == Workspace.CurrentCamera and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = previousCameraType or Enum.CameraType.Custom
		local subject = previousCameraSubject
		if not subject or not subject.Parent then
			local character = localPlayer.Character
			subject = character and character:FindFirstChildOfClass("Humanoid")
		end
		if subject then camera.CameraSubject = subject end
		if previousCameraCFrame then camera.CFrame = previousCameraCFrame end
		if previousFieldOfView then camera.FieldOfView = previousFieldOfView end
	end
	camera = nil
	previousCameraType = nil
	previousCameraSubject = nil
	previousCameraCFrame = nil
	previousFieldOfView = nil
end

local function openRoom()
	closeRoom()
	local openingRevision = revision
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 10)
		local models = assets and assets:WaitForChild("Models", 10)
		local classes = models and models:WaitForChild("Classes", 10)
		local roomTemplate = classes and classes:WaitForChild("ChangingRoom", 10)
		-- A replicated parent may arrive before its children; clone only a complete authored room.
		local roomReady = roomTemplate ~= nil
		local deadline = os.clock() + 10
		if roomTemplate then
			for _, partName in ROOM_PARTS do
				if not roomTemplate:FindFirstChild(partName) and not roomTemplate:WaitForChild(partName, math.max(0.1, deadline - os.clock())) then
					roomReady = false
					break
				end
			end
		end
		if openingRevision ~= revision or not ClassController.IsOpen() then return end
		if not roomReady or not roomTemplate or not roomTemplate:IsA("Model") then
			warn("Class changing room asset is unavailable")
			return
		end
		-- The authored room is cloned into real Workspace 3D, not displayed in a ViewportFrame.
		-- Client-local placement keeps the preview isolated from lobby gameplay and other players.
		scene = roomTemplate:Clone()
		scene.Name = "ClassChangingRoomPreview"
		scene:PivotTo(CFrame.new(ROOM_POSITION))
		scene.Parent = Workspace
		camera = Workspace.CurrentCamera
		if camera then
			previousCameraType = camera.CameraType
			previousCameraSubject = camera.CameraSubject
			previousCameraCFrame = camera.CFrame
			previousFieldOfView = camera.FieldOfView
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 48
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(frameCamera)
		end
		updateAvatar()
	end)
end

function ClassChangingRoomController.Init()
	ClassController.GetOpenChangedSignal():Connect(function(isOpen)
		if isOpen then openRoom() else closeRoom() end
	end)
	ClassController.GetPreviewChangedSignal():Connect(function()
		if ClassController.IsOpen() then updateAvatar() end
	end)
	localPlayer.CharacterAdded:Connect(function()
		if ClassController.IsOpen() then updateAvatar() end
	end)
	localPlayer.CharacterAppearanceLoaded:Connect(function()
		if ClassController.IsOpen() then updateAvatar() end
	end)
end

return ClassChangingRoomController
