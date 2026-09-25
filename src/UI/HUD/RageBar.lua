local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local RageController = require(ReplicatedStorage.Controllers.RageController)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

return function()
	local initialState = RageController.GetState()
	local state = source(initialState)
	local displayedRage = source(initialState.rage)
	local remaining = source(RageController.GetRemainingDuration())
	local progressTarget = source(displayedRage() / RageConfig.Maximum)
	local hovered = source(false)
	local inGame = source(Workspace:FindFirstChild("Game") ~= nil)
	local viewportWidth = source(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1280)
	local narrowViewport = derive(function()
		return viewportWidth() < 700
	end)
	local smoothProgress = spring(progressTarget, 0.18, 0.9)
	local ready = derive(function()
		return not state().active and displayedRage() >= RageConfig.Maximum
	end)

	local function applyState(newState)
		state(newState)
		displayedRage(newState.rage)
		remaining(RageController.GetRemainingDuration())
		progressTarget(if newState.active then 1 else newState.rage / RageConfig.Maximum)
	end

	local stateConnection = RageController.GetStateChangedSignal():Connect(applyState)
	local renderConnection = RunService.RenderStepped:Connect(function()
		local currentState = state()
		if currentState.active then
			local durationRemaining = RageController.GetRemainingDuration()
			remaining(durationRemaining)
			progressTarget(math.clamp(durationRemaining / RageConfig.Duration, 0, 1))
		else
			local currentRage = RageController.GetCurrentRage()
			displayedRage(currentRage)
			progressTarget(currentRage / RageConfig.Maximum)
		end
	end)
	local childAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Game" then
			inGame(true)
		end
	end)
	local childRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Game" then
			inGame(false)
		end
	end)
	local viewportConnection = if Workspace.CurrentCamera
		then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportWidth(Workspace.CurrentCamera.ViewportSize.X)
		end)
		else nil
	cleanup(function()
		stateConnection:Disconnect()
		renderConnection:Disconnect()
		childAddedConnection:Disconnect()
		childRemovedConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)

	return create "Frame" {
		Name = "RageBar",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(31, 22, 22),
		BorderSizePixel = 0,
		Position = function()
			return if narrowViewport() then UDim2.new(0, 12, 1, -76) else UDim2.new(0, 20, 1, -24)
		end,
		Size = UDim2.fromOffset(220, 48),
		Visible = inGame,
		ZIndex = 90,
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		StudTexture({ ZIndex = 91, ImageTransparency = 0.86 }),
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if state().active or ready()
					then Color3.fromRGB(239, 91, 43)
					else Color3.fromRGB(133, 57, 43)
			end,
			Thickness = 2,
		},
		create "TextLabel" {
			Name = "Status",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.fromOffset(9, 4),
			Size = UDim2.new(1, -104, 0, 18),
			Text = function()
				if state().active then
					return string.format("RAGE  %.1fs", remaining())
				end
				return string.format("RAGE  %d%%", math.floor(displayedRage() + 0.5))
			end,
			TextColor3 = function()
				return if state().active or ready()
					then Color3.fromRGB(255, 226, 184)
					else Color3.fromRGB(231, 193, 177)
			end,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 92,
		},
		create "Frame" {
			Name = "Track",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(53, 35, 34),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.new(0, 9, 1, -8),
			Size = UDim2.new(1, -104, 0, 12),
			ZIndex = 91,
			create "UICorner" { CornerRadius = UDim.new(0, 3) },
			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = Color3.fromRGB(239, 80, 43),
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
				end,
				ZIndex = 92,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
				create "UIGradient" {
					Color = ColorSequence.new(Color3.fromRGB(221, 66, 47), Color3.fromRGB(255, 179, 71)),
				},
			},
		},
		create "TextButton" {
			Name = "Activate",
			Active = ready,
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = function()
				if state().active then
					return Color3.fromRGB(196, 68, 38)
				elseif ready() then
					return if hovered() then Color3.fromRGB(255, 105, 54) else Color3.fromRGB(230, 79, 42)
				end
				return Color3.fromRGB(91, 51, 44)
			end,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -6, 0.5, 0),
			Selectable = ready,
			Size = UDim2.new(0, 86, 1, -12),
			Text = function()
				return if state().active then "ACTIVE" elseif ready() then "ACTIVATE [R]" else "CHARGING"
			end,
			TextColor3 = function()
				return if state().active or ready()
					then Color3.new(1, 1, 1)
					else Color3.fromRGB(191, 154, 143)
			end,
			TextScaled = true,
			ZIndex = 93,
			create "UICorner" { CornerRadius = UDim.new(0, 4) },
			StudTexture({ ZIndex = 94, ImageTransparency = 0.82, TileSize = UDim2.fromOffset(16, 16) }),
			create "UIStroke" {
				Color = Color3.fromRGB(70, 31, 26),
				Thickness = 2,
			},
			MouseEnter = function()
				if ready() then
					hovered(true)
					Sounds.Play("HoverStart", Players.LocalPlayer.PlayerGui)
				end
			end,
			MouseLeave = function()
				hovered(false)
			end,
			Activated = function()
				if ready() then
					Sounds.Play("Click", Players.LocalPlayer.PlayerGui)
					RageController.Activate()
				end
			end,
		},
	}
end
