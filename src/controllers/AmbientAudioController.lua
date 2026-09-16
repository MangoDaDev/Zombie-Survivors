local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AmbientAudioConfig = require(ReplicatedStorage.Modules.Game.AmbientAudioConfig)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)

local AmbientAudioController = {}
local LocalPlayer = Players.LocalPlayer
local RandomGenerator = Random.new()
local Music: Sound?
local MusicTween: Tween?
local Playlist = {}
local PlaylistIndex = 0
local LastTemplate: Sound?
local DuckId = 0
local VolumeMultiplier = 1

local HIGH_RARITIES = { "Legendary", "Mythic", "Secret" }

local function ShufflePlaylist()
	table.clear(Playlist)
	local MusicFolder = ReplicatedStorage.Assets:FindFirstChild(AmbientAudioConfig.Music.FolderName)
	if not MusicFolder then
		warn(`AmbientAudioController could not find {AmbientAudioConfig.Music.FolderName}`)
		return
	end

	-- Play every music track without zone-based selection or repeats within a cycle.
	for _, Child in MusicFolder:GetChildren() do
		if Child:IsA("Sound") then table.insert(Playlist, Child) end
	end
	for Index = #Playlist, 2, -1 do
		local SwapIndex = RandomGenerator:NextInteger(1, Index)
		Playlist[Index], Playlist[SwapIndex] = Playlist[SwapIndex], Playlist[Index]
	end
	if #Playlist > 1 and Playlist[1] == LastTemplate then
		Playlist[1], Playlist[2] = Playlist[2], Playlist[1]
	end
	PlaylistIndex = 0
end

local function TweenMusicVolume(Volume: number, Duration: number)
	if not Music then return end
	if MusicTween then MusicTween:Cancel() end
	MusicTween = TweenService:Create(Music, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Volume = Volume,
	})
	MusicTween:Play()
end

local function PlayNextTrack()
	if PlaylistIndex >= #Playlist then ShufflePlaylist() end
	if #Playlist == 0 then return end

	PlaylistIndex += 1
	local Template = Playlist[PlaylistIndex]
	LastTemplate = Template
	if MusicTween then MusicTween:Cancel(); MusicTween = nil end
	if Music then Music:Destroy() end

	Music = Template:Clone()
	Music.Name = "Music"
	Music.Looped = false
	Music.Volume = AmbientAudioConfig.Music.Volume * VolumeMultiplier
	Music.Parent = SoundService
	Music.Ended:Once(PlayNextTrack)
	if Music.SoundId ~= "" then Music:Play() else PlayNextTrack() end
end

local function IsHighRarityColor(Color: Color3): boolean
	for _, Rarity in HIGH_RARITIES do
		local RarityColor = RarityInfo.Get(Rarity).Color
		local Difference = math.abs(RarityColor.R - Color.R) + math.abs(RarityColor.G - Color.G) + math.abs(RarityColor.B - Color.B)
		if Difference < 0.01 then return true end
	end
	return false
end

function AmbientAudioController.Duck(Duration: number?)
	DuckId += 1
	local ActiveDuckId = DuckId
	local Config = AmbientAudioConfig.Ducking
	VolumeMultiplier = Config.VolumeMultiplier
	TweenMusicVolume(AmbientAudioConfig.Music.Volume * VolumeMultiplier, Config.FadeOutDuration)
	task.delay(Duration or Config.HoldDuration, function()
		if ActiveDuckId ~= DuckId then return end
		VolumeMultiplier = 1
		TweenMusicVolume(AmbientAudioConfig.Music.Volume, Config.FadeInDuration)
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
	ShufflePlaylist()
	PlayNextTrack()
	ObservePresentationEvents()
end

return AmbientAudioController
