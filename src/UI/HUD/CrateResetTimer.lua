local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FormatTime = require(ReplicatedStorage.Modules.Math.FormatTime)
local CrateRuntime = require(ReplicatedStorage.Modules.Game.CrateRuntime)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

return function()
	local TimerText = Source("New Crates: --:--")
	local TopOffset = Source(SafeArea.GetTopOffset(16))
	local LastSecond = -1

	local function UpdateTimer()
		local NextResetTime = CrateRuntime.GetResetState()
		if type(NextResetTime) ~= "number" then
			TimerText("New Crates: --:--")
			return
		end
		-- Wall-clock time keeps counting while the server generates the next crate field.
		local SecondsRemaining = math.max(0, NextResetTime - os.time())
		if SecondsRemaining == LastSecond then return end
		LastSecond = SecondsRemaining
		TimerText(`New Crates: {FormatTime(SecondsRemaining)}`)
	end

	local Connections = {
		SafeArea.GetChangedSignal():Connect(function()
			TopOffset(SafeArea.GetTopOffset(16))
		end),
		CrateRuntime.GetResetChangedSignal():Connect(UpdateTimer),
		RunService.Heartbeat:Connect(UpdateTimer),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
	end)
	UpdateTimer()

	return Create "Frame" {
		Name = "CrateResetTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(34, 15, 17),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = function() return UDim2.new(0.5, 0, 0, TopOffset()) end,
		Size = UDim2.fromScale(0.26, 0.055),
		Create "UICorner" {
			CornerRadius = UDim.new(0, 12),
		},
		Create "UIStroke" {
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
		},
		Create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.04, 0.08),
			Size = UDim2.fromScale(0.92, 0.84),
			Text = TimerText,
			TextColor3 = Color3.fromRGB(255, 231, 231),
			TextScaled = true,
			Create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Color = Color3.new(0, 0, 0),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.045,
			},
			Create "UITextSizeConstraint" {
				MaxTextSize = 28,
				MinTextSize = 12,
			},
		},
	}
end
