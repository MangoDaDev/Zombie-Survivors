local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassController = require(script.Parent.ClassController)

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
local avatarBodyHeight = 6

local function getBodyVerticalBounds(model: Model): (number, number)
	local minimumY = math.huge
	local maximumY = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant:FindFirstAncestorWhichIsA("Accessory") then
			local halfSize = descendant.Size * 0.5
			local cframe = descendant.CFrame
			-- Account for rotated limbs so the preview stands on the room floor without using accessory bounds.
			local verticalExtent = math.abs(cframe.RightVector.Y) * halfSize.X
				+ math.abs(cframe.UpVector.Y) * halfSize.Y
				+ math.abs(cframe.LookVector.Y) * halfSize.Z
			minimumY = math.min(minimumY, cframe.Position.Y - verticalExtent)
			maximumY = math.max(maximumY, cframe.Position.Y + verticalExtent)
		end
	end
	if minimumY == math.huge then
		local bounds, size = model:GetBoundingBox()
		return bounds.Position.Y - size.Y * 0.5, bounds.Position.Y + size.Y * 0.5
	end
	return minimumY, maximumY
end

local function frameCamera()
	if not avatar or not camera then return end
	local height = avatarBodyHeight
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

local function getAccessoryType(instance: Instance): Enum.AccessoryType?
	if instance:IsA("Accessory") then
		return instance.AccessoryType
	end
	if instance:IsA("Hat") then
		return Enum.AccessoryType.Hat
	end
	return nil
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
	local bodyMinimumY, bodyMaximumY = getBodyVerticalBounds(clone)
	local rootPart = clone:FindFirstChild("HumanoidRootPart")
	local bodyCenter = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else clone:GetPivot().Position
	avatarBodyHeight = math.max(4, bodyMaximumY - bodyMinimumY)
	clone:PivotTo(clone:GetPivot() + Vector3.new(
		ROOM_POSITION.X - bodyCenter.X,
		ROOM_POSITION.Y - bodyMinimumY,
		ROOM_POSITION.Z - bodyCenter.Z
	))
	clone.Parent = scene
	avatar = clone
	-- Frame the authored room from body-only bounds before accessory work, so malformed gear can never blank the preview.
	frameCamera()

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local classes = models and models:FindFirstChild("Classes")
	local template = classes and classes:FindFirstChild(ClassController.GetPreviewClassId())
	if humanoid and template and template:IsA("Accoutrement") then
		local accessory = template:Clone()
		accessory.Name = "PreviewClassAccessory"
		local accessoryType = getAccessoryType(accessory)
		-- Mirror live characters by hiding only avatar accessories that share this class accessory's category.
		for _, child in clone:GetChildren() do
			if accessoryType and getAccessoryType(child) == accessoryType then
				child:Destroy()
			end
		end
		-- Humanoid attachment accepts the intact legacy Hat, preserving its AttachmentPoint and original scale.
		humanoid:AddAccessory(accessory :: any)
		for _, part in accessory:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
	end
end

local function closeRoom()
	revision += 1
	if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
	if avatar then avatar:Destroy(); avatar = nil end
	avatarBodyHeight = 6
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
