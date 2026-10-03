local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local RageController = require(ReplicatedStorage.Controllers.RageController)
local RageConfig = require(ReplicatedStorage.Modules.Game.Rage.RageConfig)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local ResponsiveViewport = require(script.Parent.Parent.ResponsiveViewport)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

return function()
	local responsiveViewport = ResponsiveViewport()
	local initialState = RageController.GetState()
	local state = source(initialState)
	local displayedRage = source(initialState.rage)
	local remaining = source(RageController.GetRemainingDuration())
	local progressTarget = source(displayedRage() / RageConfig.Maximum)
	local hovered = source(false)
	local inGame = source(Workspace:FindFirstChild("Game") ~= nil)
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
	cleanup(function()
		stateConnection:Disconnect()
		renderConnection:Disconnect()
		childAddedConnection:Disconnect()
		childRemovedConnection:Disconnect()
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(responsiveViewport)
	local function meterSize()
		return UIStyle.CombatMeterSize
	end
	local function meterAspectRatio()
		local size = meterSize()
		local reference = layout.Viewport.ReferenceSize()
		return (size.X.Scale * reference.X + size.X.Offset) / size.Y.Offset
	end
	layout.RageBar = ResponsiveLayout.Base(meterSize, layout.Viewport, meterAspectRatio)
	layout.Track = ResponsiveLayout.Child(UDim2.fromScale(0.66, 0.25), layout.RageBar)
	layout.Fill = ResponsiveLayout.Child(function()
		return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
	end, layout.Track)

	return create "Frame" {
		Name = "RageBar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(3, 24, 39),
		BorderSizePixel = 0,
		-- Keep Rage in the same centered HUD stack, directly above the level/XP bar on every viewport.
		Position = layout.RageBar.Position(UDim2.new(0.5, 0, 1, -76), Vector2.new(0.5, 1)),
		-- Both axes provide a responsive bounding box; the constraint selects the limiting one per viewport.
		Size = layout.RageBar.Size,
		Visible = inGame,
		ZIndex = 90,
		create "UIAspectRatioConstraint" {
			AspectRatio = function()
				local size = layout.RageBar.Size()
				return (size.X.Scale * responsiveViewport().X + size.X.Offset) / size.Y.Offset
			end,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		},
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		StudTexture({ ZIndex = 91, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UIStyle.CombatStudTileSize }),
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
			Position = UDim2.fromScale(0.025, 0.1),
			Size = UDim2.fromScale(0.66, 0.38),
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
			Position = UDim2.fromScale(0.025, 0.83),
			Size = UDim2.fromScale(0.66, 0.25),
			ZIndex = 91,
			create "UICorner" { CornerRadius = UDim.new(0, 3) },
			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = Color3.fromRGB(221, 116, 57),
				BorderSizePixel = 0,
				Size = layout.Fill.Size,
				ZIndex = 92,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
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
			Position = UDim2.fromScale(0.985, 0.5),
			Selectable = ready,
			Size = UDim2.fromScale(0.28, 0.75),
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
			StudTexture({ ZIndex = 94, ImageTransparency = UIStyle.CombatStudTransparency, TileSize = UDim2.fromOffset(32, 32) }),
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
