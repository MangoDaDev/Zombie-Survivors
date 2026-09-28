local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local DEFAULT_CLEANUP_LIFETIME = 30

type PlayOptions = {
	PlaybackSpeed: number?,
	RollOffMinDistance: number?,
	Volume: number?,
}

local Sounds = {}

local function getWorldCFrame(parent: Instance): CFrame?
	if parent:IsA("Attachment") then
		return parent.WorldCFrame
	elseif parent:IsA("BasePart") then
		return parent.CFrame
	elseif parent:IsA("Model") then
		return parent:GetPivot()
	end
	return nil
end

local function createPlaybackParent(sourceParent: Instance): Instance
	local worldCFrame = getWorldCFrame(sourceParent)
	if not worldCFrame then
		return SoundService
	end

	local emitter = Instance.new("Part")
	emitter.Name = "TransientSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.CastShadow = false
	emitter.Size = Vector3.one * 0.05
	emitter.Transparency = 1
	emitter.CFrame = worldCFrame
	emitter.Parent = Workspace
	return emitter
end

function Sounds.Get(soundName: string): Sound?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local soundAssets = assets and assets:FindFirstChild("Sounds")
	local template = soundAssets and soundAssets:FindFirstChild(soundName)
	return if template and template:IsA("Sound") then template else nil
end

function Sounds.Play(
	soundName: string,
	sourceParent: Instance,
	rollOffMaxDistance: number?,
	options: PlayOptions?
): Sound?
	local template = Sounds.Get(soundName)
	if template == nil then
		-- Studio-owned sound assets are optional in the blank template.
		return nil
	end

	local sound = template:Clone()
	if rollOffMaxDistance then
		sound.RollOffMaxDistance = rollOffMaxDistance
	end
	if options then
		if options.PlaybackSpeed then
			sound.PlaybackSpeed = options.PlaybackSpeed
		end
		if options.RollOffMinDistance then
			sound.RollOffMinDistance = options.RollOffMinDistance
		end
		if options.Volume then
			sound.Volume = options.Volume
		end
	end

	-- A one-shot owns its playback parent so deleting a short-lived projectile, impact, or UI
	-- instance cannot cut the sound off. Positional sounds retain the source's launch location.
	local playbackParent = createPlaybackParent(sourceParent)
	local cleanupTarget = if playbackParent == SoundService then sound else playbackParent
	sound.Parent = playbackParent
	sound.Ended:Once(function()
		if cleanupTarget.Parent then
			cleanupTarget:Destroy()
		end
	end)
	sound:Play()

	-- TimeLength can still be zero while an asset loads, so keep a generous fallback for cleanup.
	local playbackSpeed = math.max(math.abs(sound.PlaybackSpeed), 0.01)
	local cleanupLifetime = if sound.TimeLength > 0
		then math.max(sound.TimeLength / playbackSpeed + 2, 5)
		else DEFAULT_CLEANUP_LIFETIME
	Debris:AddItem(cleanupTarget, cleanupLifetime)
	return sound
end

return Sounds
