local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local local_player = Players.LocalPlayer
local player_gui = local_player:WaitForChild("PlayerGui")
local GAME_FONT = Font.fromName("ComicNeueAngular")

local function New(class_name: string, properties, parent: Instance?): Instance
	local instance = Instance.new(class_name)
	for property, value in properties do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

ReplicatedFirst:RemoveDefaultLoadingScreen()

local screen = New("ScreenGui", {
	Name = "LoadingScreen",
	DisplayOrder = 1000,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
}, player_gui) :: ScreenGui

local canvas = New("CanvasGroup", {
	Name = "Background",
	BackgroundColor3 = Color3.fromRGB(16, 18, 24),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, screen) :: CanvasGroup

local title = New("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	FontFace = GAME_FONT,
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(360, 48),
	Text = "Loading",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
}, canvas) :: TextLabel
-- Keep the scaled loading hierarchy close to its authored desktop sizes while still shrinking cleanly.
New("UITextSizeConstraint", { MaxTextSize = 32, MinTextSize = 18 }, title)

local status = New("TextLabel", {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	FontFace = GAME_FONT,
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromOffset(360, 28),
	Text = "Starting...",
	TextColor3 = Color3.fromRGB(180, 185, 198),
	TextScaled = true,
}, canvas) :: TextLabel
New("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11 }, status)

local loading_bar = New("Frame", {
	Name = "LoadingBar",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(43, 47, 58),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromOffset(320, 8),
}, canvas) :: Frame
New("UICorner", { CornerRadius = UDim.new(1, 0) }, loading_bar)

local progress = New("Frame", {
	Name = "Progress",
	BackgroundColor3 = Color3.fromRGB(235, 238, 245),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(0, 1),
}, loading_bar) :: Frame
New("UICorner", { CornerRadius = UDim.new(1, 0) }, progress)

local function SetProgress(amount: number, message: string)
	status.Text = message
	TweenService:Create(
		progress,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(amount, 1) }
	):Play()
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

SetProgress(0.4, "Loading Game...")
player_gui:WaitForChild("App")

SetProgress(0.75, "Getting You Ready...")
local character_controller = require(ReplicatedStorage.Controllers.CharacterController)
character_controller:WaitUntilReady()

while not local_player.Character do
	character_controller:RequestCharacter()
	if not local_player.Character then
		task.wait(0.5)
	end
end

SetProgress(1, "Ready")
task.wait(0.3)

local fade = TweenService:Create(
	canvas,
	TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ GroupTransparency = 1 }
)
fade:Play()
fade.Completed:Wait()
screen:Destroy()
