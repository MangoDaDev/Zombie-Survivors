local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassesAbilitiesTutorialController = require(ReplicatedStorage.Controllers.ClassesAbilitiesTutorialController)
local ClassController = require(ReplicatedStorage.Controllers.ClassController)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local HEAVY_FONT = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy)
local GOLD = Color3.fromRGB(255, 207, 65)

local function findPromptPart(): BasePart?
	local structure = Workspace:FindFirstChild("Classes")
	local promptPart = structure and structure:FindFirstChild("PromptPart")
	return if promptPart and promptPart:IsA("BasePart") then promptPart else nil
end

return function()
	local tutorialState = source(ClassesAbilitiesTutorialController.GetState())
	local shopOpen = source(ClassController.IsOpen())
	local markerPosition = source(UDim2.fromScale(0.5, 0.5))
	local markerRotation = source(0)
	local markerAvailable = source(false)
	local pulse = source(1)
	local rootSize = source(Vector2.new(1280, 720))
	local topOffset = source(SafeArea.GetTopOffset(12))
	local promptPart = findPromptPart()
	local connections = {}
	local renderConnection: RBXScriptConnection?
	local descendantConnection: RBXScriptConnection?

	local function stopWorldGuidance()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		markerAvailable(false)
		pulse(1)
	end

	local function startWorldGuidance()
		if renderConnection then return end
		promptPart = findPromptPart()
		descendantConnection = Workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart")
				and descendant.Name == "PromptPart"
				and descendant.Parent
				and descendant.Parent.Name == "Classes"
				and descendant.Parent.Parent == Workspace
			then
				promptPart = descendant
			end
		end)
		renderConnection = RunService.RenderStepped:Connect(function()
			pulse(1 + math.sin(os.clock() * 4.5) * 0.08)
			if shopOpen() then
				markerAvailable(false)
				return
			end
			if not promptPart or not promptPart:IsDescendantOf(Workspace) then
				promptPart = findPromptPart()
			end
			local camera = Workspace.CurrentCamera
			if not camera or not promptPart then
				-- If the Studio-owned booth has not replicated yet, keep guidance useful by pointing at
				-- the existing bottom-center Classes launcher instead of hiding the arrow entirely.
				local size = rootSize()
				markerPosition(UDim2.fromOffset(size.X * 0.5, size.Y - 104))
				markerRotation(90)
				markerAvailable(true)
				return
			end
			local screenPoint, onScreen = camera:WorldToViewportPoint(promptPart.Position)
			local size = rootSize()
			local center = size * 0.5
			local delta = Vector2.new(screenPoint.X, screenPoint.Y) - center
			if screenPoint.Z < 0 then
				delta = -delta
			end
			if delta.Magnitude < 1 then
				delta = Vector2.new(0, 1)
			end
			local margin = 62
			local direction = delta.Unit
			local target = if onScreen and screenPoint.Z > 0
				then Vector2.new(screenPoint.X, screenPoint.Y) - direction * 68
				else center + direction * math.max(size.X, size.Y)
			target = Vector2.new(
				math.clamp(target.X, margin, size.X - margin),
				math.clamp(target.Y, topOffset() + margin + 46, size.Y - margin)
			)
			markerPosition(UDim2.fromOffset(target.X, target.Y))
			markerRotation(math.deg(math.atan2(direction.Y, direction.X)))
			markerAvailable(true)
		end)
	end

	table.insert(connections, ClassesAbilitiesTutorialController.GetStateChangedSignal():Connect(function(newState)
		tutorialState(newState)
		if newState.active then startWorldGuidance() else stopWorldGuidance() end
	end))
	table.insert(connections, ClassController.GetOpenChangedSignal():Connect(function(isOpen)
		shopOpen(isOpen)
	end))
	table.insert(connections, SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end))
	if tutorialState().active then startWorldGuidance() end

	cleanup(function()
		stopWorldGuidance()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	local active = derive(function()
		return tutorialState().active
	end)

	return create "Frame" {
		Name = "ClassesAbilitiesTutorial",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = active,
		ZIndex = 900,
		action(function(instance)
			local root = instance :: Frame
			rootSize(root.AbsoluteSize)
			table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				rootSize(root.AbsoluteSize)
			end))
		end),
		create "Frame" {
			Name = "Instruction",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(9, 42, 58),
			BorderSizePixel = 0,
			Position = function()
				return UDim2.new(0.5, 0, 0, topOffset())
			end,
			Size = function()
				return if rootSize().X < 600 then UDim2.new(0.84, 0, 0.08, 0) else UDim2.new(0.42, 0, 0.08, 0)
			end,
			ZIndex = 901,
			create "UIAspectRatioConstraint" {
				AspectRatio = 7.2,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			create "UICorner" { CornerRadius = UDim.new(0, 6) },
			create "UIStroke" { Color = GOLD, Thickness = 3 },
			create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = HEAVY_FONT,
				Position = UDim2.fromScale(0.03, 0.12),
				Size = UDim2.fromScale(0.94, 0.76),
				Text = function()
					return if shopOpen()
						then "CLAIM BLADE DANCER"
						else "FIND THE CLASSES SHOP"
				end,
				TextColor3 = Color3.fromRGB(255, 244, 194),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 902,
			},
		},
		create "Frame" {
			Name = "WorldArrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = markerPosition,
			Rotation = markerRotation,
			Size = UDim2.fromOffset(96, 52),
			Visible = markerAvailable,
			ZIndex = 905,
			create "UIScale" { Scale = pulse },
			create "Frame" {
				Name = "Shaft",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(68, 16),
				ZIndex = 905,
				create "UICorner" { CornerRadius = UDim.new(0, 7) },
				create "UIStroke" { Color = Color3.fromRGB(30, 20, 4), Thickness = 3 },
			},
			create "Frame" {
				Name = "ArrowHeadUpper",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(72, 15),
				Rotation = 45,
				Size = UDim2.fromOffset(38, 16),
				ZIndex = 906,
				create "UICorner" { CornerRadius = UDim.new(0, 7) },
				create "UIStroke" { Color = Color3.fromRGB(30, 20, 4), Thickness = 3 },
			},
			create "Frame" {
				Name = "ArrowHeadLower",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(72, 37),
				Rotation = -45,
				Size = UDim2.fromOffset(38, 16),
				ZIndex = 906,
				create "UICorner" { CornerRadius = UDim.new(0, 7) },
				create "UIStroke" { Color = Color3.fromRGB(30, 20, 4), Thickness = 3 },
			},
		},
	}
end
