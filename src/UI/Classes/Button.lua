local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Vide = require(ReplicatedStorage.Packages.vide)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local create, derive, effect = Vide.create, Vide.derive, Vide.effect
local read, source, spring = Vide.read, Vide.source, Vide.spring

type Reactive<T> = T | (() -> T)
export type Props = {
	Text: Reactive<string>?,
	OnActivated: (() -> ())?,
	Enabled: Reactive<boolean>?,
	BackgroundColor3: Reactive<Color3>?,
	LayoutOrder: Reactive<number>?,
}

local function readOr<T>(value: Reactive<T>?, default: T): T
	return if value == nil then default else read(value)
end

return function(props: Props)
	local hovered, pressed = source(false), source(false)
	local enabled = derive(function()
		return readOr(props.Enabled, true)
	end)
	local scale = spring(
		derive(function()
			if not enabled() then
				return 1
			end
			if pressed() then
				return 0.95
			end
			return if hovered() then 1.04 else 1
		end),
		0.15,
		0.9
	)
	effect(function()
		if not enabled() then
			hovered(false)
			pressed(false)
		end
	end)

	return create "Frame" {
		Name = "Button",
		BackgroundColor3 = function()
			return if enabled() then UIStyle.Colors.InkSoft else UIStyle.Colors.Ink
		end,
		BackgroundTransparency = function()
			return if enabled() then 0 else 0.45
		end,
		BorderSizePixel = 0,
		LayoutOrder = function()
			return readOr(props.LayoutOrder, 0)
		end,
		Size = UDim2.fromScale(0.3, 1),
		create "UICorner" { CornerRadius = UIStyle.CornerRadius },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = UIStyle.Colors.Ink,
			Thickness = UIStyle.OutlineThickness,
			Transparency = 0.08,
		},
		create "UIScale" { Scale = scale },
		create "Frame" {
			Name = "Content",
			BackgroundColor3 = function()
				return readOr(props.BackgroundColor3, UIStyle.Colors.Blue)
			end,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.88, 0),
			ZIndex = 1,
			create "UICorner" { CornerRadius = UIStyle.CornerRadius },
			create "ImageLabel" {
				Name = "StudTexture",
				BackgroundTransparency = 1,
				Image = UIStyle.StudTexture,
				ImageTransparency = UIStyle.StudTransparency,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(54, 54),
				ZIndex = 2,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = UIStyle.Colors.Paper,
				Thickness = UIStyle.OutlineThickness,
				Transparency = UIStyle.InsideStrokeTransparency,
			},
		},
		create "TextLabel" {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = UIStyle.Font,
			Text = function()
				return readOr(props.Text, "Button")
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 3,
			create "UIStroke" {
				Color = UIStyle.Colors.Ink,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.055,
			},
			create "UITextSizeConstraint" { MaxTextSize = 24, MinTextSize = 15 },
		},
		create "TextButton" {
			Active = enabled,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = enabled,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			FontFace = UIStyle.Font,
			ZIndex = 5,
			MouseEnter = function()
				if enabled() and not hovered() then
					hovered(true)
				end
			end,
			MouseLeave = function()
				hovered(false)
				pressed(false)
			end,
			InputBegan = function(input)
				if
					enabled()
					and (
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					pressed(true)
				end
			end,
			InputEnded = function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					pressed(false)
				end
			end,
			Activated = function()
				pressed(false)
				if enabled() and props.OnActivated then
					props.OnActivated()
				end
			end,
		},
	}
end
