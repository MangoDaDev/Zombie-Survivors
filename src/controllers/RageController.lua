local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local RageController = {}

local localPlayer = Players.LocalPlayer
local rageNetwork: Networker.Client?
local state = {
	rage = 0,
	active = false,
	endsAt = 0,
	revision = 0,
}
local activeHighlight: Highlight?
local activeAttachment: Attachment?

local stateChanged = Signal.new()
local activated = Signal.new()
local ended = Signal.new()

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function clearCharacterEffect(playEndingEffect: boolean)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if playEndingEffect and root and root:IsA("BasePart") then
		local ending = Instance.new("Highlight")
		ending.Name = "RageEndingEmphasis"
		ending.Adornee = character
		ending.DepthMode = Enum.HighlightDepthMode.Occluded
		ending.FillColor = Color3.fromRGB(255, 136, 54)
		ending.FillTransparency = 0.72
		ending.OutlineColor = Color3.fromRGB(255, 220, 140)
		ending.OutlineTransparency = 0.3
		ending.Parent = character
		local tween = TweenService:Create(ending, TweenInfo.new(0.45), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		tween.Completed:Once(function()
			ending:Destroy()
		end)
		tween:Play()
		Sounds.Play("SpeedCoil", root, 110)
	end

	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
	if activeAttachment then
		activeAttachment:Destroy()
		activeAttachment = nil
	end
end

local function addCharacterEffect()
	clearCharacterEffect(false)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "RageEmphasis"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 91, 39)
	highlight.FillTransparency = 0.3
	highlight.OutlineColor = Color3.fromRGB(255, 213, 92)
	highlight.OutlineTransparency = 0.02
	highlight.Parent = character
	activeHighlight = highlight
	TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 0.79, OutlineTransparency = 0.34 }
	):Play()

	local attachment = Instance.new("Attachment")
	attachment.Name = "RageAura"
	attachment.Position = Vector3.new(0, -2.1, 0)
	attachment.Parent = root
	activeAttachment = attachment

	local impactTemplate = ReplicatedStorage.Assets.VFX.CriticalHit.Impact
	for _, child in impactTemplate:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			emitter.Name = "Rage" .. child.Name
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 85), Color3.fromRGB(255, 64, 28))
			emitter.LightEmission = 0.9
			emitter.Rate = 5
			emitter.Speed = NumberRange.new(1.5, 4)
			emitter.Lifetime = NumberRange.new(0.35, 0.75)
			emitter.Enabled = true
			emitter.Parent = attachment
			emitter:Emit(if child.Name == "Flash" then 3 else 14)
		end
	end
	Sounds.Play("FlameBurst", root, 140)
end

function RageController.RageStateChanged(_, packet)
	if type(packet) ~= "table"
		or not isFiniteNumber(packet.rage)
		or type(packet.active) ~= "boolean"
		or not isFiniteNumber(packet.endsAt)
		or type(packet.revision) ~= "number"
		or packet.revision % 1 ~= 0
		or packet.revision <= state.revision
	then
		return
	end

	local wasActive = state.active
	state = {
		rage = math.clamp(packet.rage, 0, RageConfig.Maximum),
		active = packet.active,
		endsAt = packet.endsAt,
		revision = packet.revision,
	}
	stateChanged:Fire(RageController.GetState())

	if state.active and not wasActive then
		addCharacterEffect()
		activated:Fire(RageController.GetState())
	elseif wasActive and not state.active then
		clearCharacterEffect(true)
		ended:Fire(RageController.GetState())
	end
end

function RageController.Init()
	rageNetwork = Networker.client.new("RageController", RageController)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == RageConfig.ActivationKey then
			RageController.Activate()
		end
	end)
end

function RageController.OnCharacterAdded(_character: Model)
	clearCharacterEffect(false)
	if state.active then
		task.defer(addCharacterEffect)
	end
end

function RageController.Activate()
	if rageNetwork and state.rage >= RageConfig.Maximum and not state.active then
		rageNetwork:fire("ActivateRage")
	end
end

function RageController.GetState()
	return table.clone(state)
end

function RageController.GetRemainingDuration(): number
	return if state.active then math.max(state.endsAt - Workspace:GetServerTimeNow(), 0) else 0
end

function RageController.GetStateChangedSignal()
	return stateChanged
end

function RageController.GetActivatedSignal()
	return activated
end

function RageController.GetEndedSignal()
	return ended
end

return RageController
