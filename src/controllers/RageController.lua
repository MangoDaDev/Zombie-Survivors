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
	chargeStartedAt = Workspace:GetServerTimeNow(),
	revision = 0,
}
local activeHighlight: Highlight?
local activeAttachment: Attachment?
local presentationEndToken = 0

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
		ending.FillTransparency = 0.82
		ending.OutlineColor = Color3.fromRGB(255, 220, 140)
		ending.OutlineTransparency = 0.48
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
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = Color3.fromRGB(255, 213, 92)
	highlight.OutlineTransparency = 0.12
	highlight.Parent = character
	activeHighlight = highlight
	TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 0.82, OutlineTransparency = 0.42 }
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
			emitter.LightEmission = 0.7
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(1.4, 3.6)
			emitter.Lifetime = NumberRange.new(0.35, 0.75)
			emitter.Enabled = true
			emitter.Parent = attachment
			emitter:Emit(if child.Name == "Flash" then 2 else 11)
		end
	end
	Sounds.Play("FlameBurst", root, 140)
end

local function schedulePresentationEnd(endsAt: number)
	presentationEndToken += 1
	local token = presentationEndToken
	task.delay(math.max(endsAt - Workspace:GetServerTimeNow(), 0), function()
		if token ~= presentationEndToken or not state.active or state.endsAt ~= endsAt then
			return
		end
		-- The server supplied the end timestamp, so presentation can finish on time without waiting for another packet.
		state.active = false
		state.rage = 0
		state.endsAt = 0
		state.chargeStartedAt = endsAt
		stateChanged:Fire(RageController.GetState())
		clearCharacterEffect(true)
		ended:Fire(RageController.GetState())
	end)
end

function RageController.RageStateChanged(_, packet)
	if type(packet) ~= "table"
		or not isFiniteNumber(packet.rage)
		or type(packet.active) ~= "boolean"
		or not isFiniteNumber(packet.endsAt)
		or not isFiniteNumber(packet.chargeStartedAt)
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
		chargeStartedAt = packet.chargeStartedAt,
		revision = packet.revision,
	}
	stateChanged:Fire(RageController.GetState())

	if state.active then
		schedulePresentationEnd(state.endsAt)
		if not wasActive then
			addCharacterEffect()
			activated:Fire(RageController.GetState())
		end
	elseif wasActive then
		presentationEndToken += 1
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
	if not rageNetwork or state.active or RageController.GetCurrentRage() < RageConfig.Maximum then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Predict only local UI/VFX so pressing Rage feels immediate; server packets reconcile or reject it.
	state.rage = RageConfig.Maximum
	state.active = true
	state.endsAt = Workspace:GetServerTimeNow() + RageConfig.Duration
	stateChanged:Fire(RageController.GetState())
	addCharacterEffect()
	activated:Fire(RageController.GetState())
	schedulePresentationEnd(state.endsAt)
	rageNetwork:fire("ActivateRage")
end

function RageController.GetState()
	local current = table.clone(state)
	current.rage = RageController.GetCurrentRage()
	return current
end

function RageController.GetCurrentRage(): number
	if state.active then
		return RageConfig.Maximum
	end
	return math.clamp(
		(Workspace:GetServerTimeNow() - state.chargeStartedAt) / RageConfig.ChargeDuration,
		0,
		1
	) * RageConfig.Maximum
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
