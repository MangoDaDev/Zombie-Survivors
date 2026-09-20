local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GetProfilePicture = require(ReplicatedStorage.Modules.Platform.GetProfilePicture)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local BaseMarkerController = {}

local LocalPlayer = Players.LocalPlayer
local Markers: { [Model]: BillboardGui } = {}

local LOCAL_SIZE = UDim2.fromOffset(220, 180)
local OTHER_SIZE = UDim2.fromOffset(140, 115)
local LOCAL_OFFSET = Vector3.new(0, 15, 0)
local OTHER_OFFSET = Vector3.new(0, 10, 0)

local function New(ClassName: string, Properties, Parent: Instance?): Instance
	local InstanceObject = Instance.new(ClassName)
	for Property, Value in Properties do
		InstanceObject[Property] = Value
	end
	InstanceObject.Parent = Parent
	return InstanceObject
end

local function GetOwner(Museum: Model): Player?
	local UserId = tonumber(string.match(Museum.Name, "^Museum_(%d+)$"))
	return if UserId then Players:GetPlayerByUserId(UserId) else nil
end

local function CreateMarker(Museum: Model)
	if Markers[Museum] then return end
	local Owner = GetOwner(Museum)
	if not Owner then return end

	local Roof = Museum:FindFirstChild("Roof") or Museum:WaitForChild("Roof", 10)
	-- A replicated Roof can arrive before its children; wait for the authored mount before creating the marker.
	local RoofMount = Roof and (Roof:FindFirstChild("RoofMount") or Roof:WaitForChild("RoofMount", 10))
	if not RoofMount or not RoofMount:IsA("BasePart") or not Museum.Parent then return end

	local IsLocalBase = Owner == LocalPlayer
	local Marker = New("BillboardGui", {
		Name = "BaseMarker",
		Adornee = RoofMount,
		AlwaysOnTop = true,
		LightInfluence = 0,
		-- Base markers must remain visible from anywhere so players can locate their museum.
		MaxDistance = math.huge,
		Size = if IsLocalBase then LOCAL_SIZE else OTHER_SIZE,
		StudsOffsetWorldSpace = if IsLocalBase then LOCAL_OFFSET else OTHER_OFFSET,
	}, Museum) :: BillboardGui

	local ProfileSize = if IsLocalBase then 126 else 78
	local Profile = New("ImageLabel", {
		Name = "ProfilePicture",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UIStyle.Colors.Paper,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(ProfileSize, ProfileSize),
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
	}, Marker) :: ImageLabel
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, Profile)
	New("UIStroke", {
		Color = if IsLocalBase then UIStyle.Colors.Gold else UIStyle.Colors.Ink,
		Thickness = if IsLocalBase then 5 else 3,
	}, Profile)

	New("TextLabel", {
		Name = "BaseLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		FontFace = UIStyle.Font,
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, if IsLocalBase then 48 else 31),
		Text = if IsLocalBase then "Your Base" else `{Owner.DisplayName}'s Base`,
		TextColor3 = UIStyle.Colors.Paper,
		TextScaled = true,
		TextStrokeColor3 = UIStyle.Colors.Ink,
		TextStrokeTransparency = 0,
		TextWrapped = true,
	}, Marker)

	Markers[Museum] = Marker
	task.spawn(function()
		local ProfilePicture = GetProfilePicture(Owner)
		if ProfilePicture and Profile.Parent then Profile.Image = ProfilePicture end
	end)

	Museum.Destroying:Once(function()
		Markers[Museum] = nil
	end)
end

function BaseMarkerController.Init()
	local PlayerMuseums = Workspace:FindFirstChild("PlayerMuseums") or Workspace:WaitForChild("PlayerMuseums", 10)
	if not PlayerMuseums then return end
	for _, Museum in PlayerMuseums:GetChildren() do
		if Museum:IsA("Model") then task.spawn(CreateMarker, Museum) end
	end
	PlayerMuseums.ChildAdded:Connect(function(Museum)
		if Museum:IsA("Model") then task.spawn(CreateMarker, Museum) end
	end)
end

return BaseMarkerController
