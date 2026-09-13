local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayVFX = require(ReplicatedStorage.Modules.UI.PlayVFX)

local SoundAssets = ReplicatedStorage.Assets.Sounds

local Sounds = {}

function Sounds.Get(SoundName: string): Sound?
	local Template = SoundAssets:FindFirstChild(SoundName)
	return if Template and Template:IsA("Sound") then Template else nil
end

function Sounds.Play(SoundName: string, Parent: Instance, RollOffMaxDistance: number?): Sound?
	local Template = Sounds.Get(SoundName)
	if Template == nil then
		warn(`Sounds could not find the {SoundName} sound`)
		return nil
	end

	local Clones = PlayVFX(Template, Parent)
	local Sound = Clones[1]
	if Sound == nil or not Sound:IsA("Sound") then
		return nil
	end

	if RollOffMaxDistance then
		Sound.RollOffMaxDistance = RollOffMaxDistance
	end
	return Sound
end

return Sounds
