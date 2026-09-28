local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local localPlayer = Players.LocalPlayer
local HEALTH_GREEN = Color3.fromRGB(69, 205, 105)
local HEALTH_YELLOW = Color3.fromRGB(235, 180, 60)
local HEALTH_RED = Color3.fromRGB(220, 75, 75)

return function()
	local health = source(0)
	local maximumHealth = source(100)
	local hasHumanoid = source(false)
	local inGame = source(Workspace:FindFirstChild("Game") ~= nil)
	local topOffset = source(SafeArea.GetTopOffset(12))
	local viewportWidth = source(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1280)
	local progressTarget = source(0)
	local smoothProgress = spring(progressTarget, 0.18, 0.9)
	local humanoidHealthConnection: RBXScriptConnection? = nil
	local humanoidMaximumHealthConnection: RBXScriptConnection? = nil
	local characterChildConnection: RBXScriptConnection? = nil

	local function disconnectHumanoid()
		if humanoidHealthConnection then
			humanoidHealthConnection:Disconnect()
			humanoidHealthConnection = nil
		end
		if humanoidMaximumHealthConnection then
			humanoidMaximumHealthConnection:Disconnect()
			humanoidMaximumHealthConnection = nil
		end
		hasHumanoid(false)
	end

	local function updateHealth(humanoid: Humanoid)
		local currentMaximum = math.max(humanoid.MaxHealth, 1)
		local currentHealth = math.clamp(humanoid.Health, 0, currentMaximum)
		health(currentHealth)
		maximumHealth(currentMaximum)
		progressTarget(currentHealth / currentMaximum)
	end

	local function bindHumanoid(humanoid: Humanoid)
		disconnectHumanoid()
		hasHumanoid(true)
		updateHealth(humanoid)
		humanoidHealthConnection = humanoid.HealthChanged:Connect(function()
			updateHealth(humanoid)
		end)
		humanoidMaximumHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			updateHealth(humanoid)
		end)
	end

	local function bindCharacter(character: Model)
		disconnectHumanoid()
		if characterChildConnection then
			characterChildConnection:Disconnect()
			characterChildConnection = nil
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			bindHumanoid(humanoid)
			return
		end

		-- CharacterAdded may fire before all descendants replicate. Listening for the Humanoid keeps the
		-- HUD event-driven without allowing an unbounded WaitForChild to stall the component.
		characterChildConnection = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				characterChildConnection:Disconnect()
				characterChildConnection = nil
				bindHumanoid(child)
			end
		end)
	end

	local healthColor = derive(function()
		local progress = progressTarget()
		if progress <= 0.25 then
			return HEALTH_RED
		elseif progress <= 0.5 then
			return HEALTH_YELLOW
		end
		return HEALTH_GREEN
	end)
	local narrowViewport = derive(function()
		return viewportWidth() < 700
	end)

	local characterConnection = localPlayer.CharacterAdded:Connect(bindCharacter)
	local workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Game" then
			inGame(true)
		end
	end)
	local workspaceChildRemovedConnection = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Game" then
			inGame(false)
		end
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end)
	local viewportConnection = if Workspace.CurrentCamera
		then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportWidth(Workspace.CurrentCamera.ViewportSize.X)
		end)
		else nil

	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	end

	cleanup(function()
		characterConnection:Disconnect()
		workspaceChildAddedConnection:Disconnect()
		workspaceChildRemovedConnection:Disconnect()
		safeAreaConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		if characterChildConnection then
			characterChildConnection:Disconnect()
		end
		disconnectHumanoid()
	end)

	return create "Frame" {
		Name = "HealthBar",
		BackgroundColor3 = Color3.fromRGB(23, 31, 29),
		BorderSizePixel = 0,
		Position = function()
			-- The bar sits directly below permanent currency, leaving the centered XP/Rage stack and
			-- right-side ability tray unobstructed on both desktop and narrow mobile viewports.
			return UDim2.fromOffset(
				if narrowViewport() then 12 else 20,
				topOffset() + (if narrowViewport() then 132 else 56)
			)
		end,
		Size = UDim2.new(0.08, 150, 0.05, 16),
		Visible = function()
			return inGame() and hasHumanoid()
		end,
		ZIndex = 90,
		create "UISizeConstraint" {
			MaxSize = Vector2.new(240, 52),
			MinSize = Vector2.new(180, 39),
		},
		create "UIAspectRatioConstraint" {
			AspectRatio = 240 / 52,
			DominantAxis = Enum.DominantAxis.Width,
		},
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return healthColor():Lerp(Color3.new(0, 0, 0), 0.25)
			end,
			Thickness = 2,
		},
		StudTexture({ ZIndex = 91, ImageTransparency = 0.86 }),
		create "TextLabel" {
			Name = "Label",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.new(0, 9, 0.08, 0),
			Size = UDim2.new(0.42, 0, 0.34, 0),
			Text = "HEALTH",
			TextColor3 = Color3.fromRGB(220, 232, 225),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 92,
		},
		create "TextLabel" {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.new(1, -9, 0.08, 0),
			Size = UDim2.new(0.52, 0, 0.34, 0),
			-- Always show the requested current/maximum format, including at zero health.
			Text = function()
				return string.format("%d / %d", math.ceil(health()), math.ceil(maximumHealth()))
			end,
			TextColor3 = healthColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 92,
		},
		create "Frame" {
			Name = "Track",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(42, 52, 48),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.new(0.5, 0, 0.86, 0),
			Size = UDim2.new(1, -18, 0.33, 0),
			ZIndex = 91,
			create "UICorner" { CornerRadius = UDim.new(0, 3) },
			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = healthColor,
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
				end,
				ZIndex = 92,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
				create "UIGradient" {
					Color = function()
						local color = healthColor()
						return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.12), color)
					end,
				},
			},
		},
	}
end
