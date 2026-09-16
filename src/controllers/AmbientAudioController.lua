local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AmbientAudioConfig = require(ReplicatedStorage.Modules.Game.AmbientAudioConfig)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)

local AmbientAudioController = {}
local LocalPlayer = Players.LocalPlayer
local Channels = {}
local ChannelTweens = {}
local CurrentZoneName = "Outdoor"
local UpdateElapsed = 0
local DuckId = 0
local MuseumArea: BasePart?

local HIGH_RARITIES = { "Legendary", "Mythic", "Secret" }

local function GetTemplate(Config): Sound?
	local Folder = ReplicatedStorage.Assets:FindFirstChild(Config.FolderName)
	local Template = Folder and Folder:FindFirstChild(Config.SoundName)
	return if Template and Template:IsA("Sound") then Template else nil
end

local function CreateChannel(Name: string, Config): Sound?
	local Template = GetTemplate(Config)
	if not Template then
		warn(`AmbientAudioController could not find {Config.FolderName}.{Config.SoundName}`)
		return nil
	end

	local Channel = Template:Clone()
	Channel.Name = Name
	Channel.Looped = true
	Channel.Volume = 0
	Channel.Parent = SoundService
	if Channel.SoundId ~= "" then Channel:Play() end
	Channels[Name] = Channel
	return Channel
end

local function TweenVolume(Name: string, Volume: number, Duration: number)
	local Channel = Channels[Name]
	if not Channel then return end
	local ExistingTween = ChannelTweens[Name]
	if ExistingTween then ExistingTween:Cancel() end
	local Tween = TweenService:Create(Channel, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Volume = Volume,
	})
	ChannelTweens[Name] = Tween
	Tween:Play()
end

local function IsPointInside(Part: BasePart, Point: Vector3): boolean
	local LocalPoint = Part.CFrame:PointToObjectSpace(Point)
	local HalfSize = Part.Size * 0.5
	return math.abs(LocalPoint.X) <= HalfSize.X
		and math.abs(LocalPoint.Y) <= HalfSize.Y
		and math.abs(LocalPoint.Z) <= HalfSize.Z
end

local function GetZoneName(): string
	local Character = LocalPlayer.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not RootPart or not RootPart:IsA("BasePart") then return CurrentZoneName end
	if MuseumArea and MuseumArea.Parent and IsPointInside(MuseumArea, RootPart.Position) then return "Museum" end
	return "Outdoor"
end

local function SetZone(ZoneName: string)
	if CurrentZoneName == ZoneName then return end
	CurrentZoneName = ZoneName
	for Name, Config in AmbientAudioConfig.Zones do
		TweenVolume(Name, if Name == ZoneName then Config.Volume else 0, AmbientAudioConfig.CrossfadeDuration)
	end
end

local function IsHighRarityColor(Color: Color3): boolean
	for _, Rarity in HIGH_RARITIES do
		local RarityColor = RarityInfo.Get(Rarity).Color
		local Difference = math.abs(RarityColor.R - Color.R) + math.abs(RarityColor.G - Color.G) + math.abs(RarityColor.B - Color.B)
		if Difference < 0.01 then return true end
	end
	return false
end

local function ResolveMuseumArea()
	task.spawn(function()
		local Museums = Workspace:WaitForChild("PlayerMuseums")
		local Museum = Museums:WaitForChild(`Museum_{LocalPlayer.UserId}`)
		local Level = Museum:WaitForChild("Level_1")
		local Area = Level:WaitForChild("MuseumArea")
		if Area and Area:IsA("BasePart") then MuseumArea = Area end
	end)
end

function AmbientAudioController.Duck(Duration: number?)
	DuckId += 1
	local ActiveDuckId = DuckId
	local Config = AmbientAudioConfig.Ducking
	local MusicConfig = AmbientAudioConfig.Music
	TweenVolume("Music", MusicConfig.Volume * Config.VolumeMultiplier, Config.FadeOutDuration)
	task.delay(Duration or Config.HoldDuration, function()
		if ActiveDuckId ~= DuckId then return end
		TweenVolume("Music", MusicConfig.Volume, Config.FadeInDuration)
	end)
end

local function ObservePresentationEvents()
	RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepComplete"):Connect(function(IsComplete)
		if IsComplete == true then AmbientAudioController.Duck(AmbientAudioConfig.Ducking.HoldDuration) end
	end)

	task.spawn(function()
		local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
		local RevealGui = PlayerGui:WaitForChild("LocalRevealVFX")
		RevealGui.DescendantAdded:Connect(function(Descendant)
			if Descendant.Name == "RarityVignette" and Descendant:IsA("ImageLabel")
				and IsHighRarityColor(Descendant.ImageColor3)
			then
				AmbientAudioController.Duck(AmbientAudioConfig.Ducking.HoldDuration)
			end
		end)
	end)
end

function AmbientAudioController.Init()
	CreateChannel("Music", AmbientAudioConfig.Music)
	for Name, Config in AmbientAudioConfig.Zones do CreateChannel(Name, Config) end
	local Outdoor = Channels.Outdoor
	if Outdoor then Outdoor.Volume = AmbientAudioConfig.Zones.Outdoor.Volume end
	local Music = Channels.Music
	if Music then Music.Volume = AmbientAudioConfig.Music.Volume end
	ResolveMuseumArea()
	ObservePresentationEvents()
	RunService.Heartbeat:Connect(function(DeltaTime)
		UpdateElapsed += DeltaTime
		if UpdateElapsed < AmbientAudioConfig.ZoneCheckInterval then return end
		UpdateElapsed = 0
		SetZone(GetZoneName())
	end)
end

return AmbientAudioController
