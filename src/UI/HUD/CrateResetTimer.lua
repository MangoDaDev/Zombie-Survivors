local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FormatTime = require(ReplicatedStorage.Modules.Math.FormatTime)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

return function()
	local TimerText = Source("Crates Reset in --:--")
	local LastSecond = -1

	local function UpdateTimer()
		if Workspace:GetAttribute("CratesResetting") == true then
			TimerText("Crates Resetting...")
			return
		end
		local NextResetTime = Workspace:GetAttribute("NextCrateResetTime")
		if type(NextResetTime) ~= "number" then
			TimerText("Crates Reset in --:--")
			return
		end
		local SecondsRemaining = math.max(0, math.ceil(NextResetTime - Workspace:GetServerTimeNow()))
		if SecondsRemaining == LastSecond then return end
		LastSecond = SecondsRemaining
		TimerText(`Crates Reset in {FormatTime(SecondsRemaining)}`)
	end

	local Connections = {
		Workspace:GetAttributeChangedSignal("NextCrateResetTime"):Connect(UpdateTimer),
		Workspace:GetAttributeChangedSignal("CratesResetting"):Connect(UpdateTimer),
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
		Position = UDim2.fromScale(0.5, 0.025),
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
