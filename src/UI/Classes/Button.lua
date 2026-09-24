local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Vide = require(ReplicatedStorage.Packages.vide)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local create, derive, effect = Vide.create, Vide.derive, Vide.effect
local read, source, spring = Vide.read, Vide.source, Vide.spring

local LocalPlayer = Players.LocalPlayer
local BLACK = Color3.new(0, 0, 0)
local DARK_TINT_ALPHA = 0.18

type Reactive<T> = T | (() -> T)
export type Props = {
	Text: Reactive<string>?,
	OnActivated: (() -> ())?,
	Enabled: Reactive<boolean>?,
	BackgroundColor3: Reactive<Color3>?,
	LayoutOrder: Reactive<number>?,
	Size: Reactive<UDim2>?,
}

local function readOr<T>(value: Reactive<T>?, default: T): T
	return if value == nil then default else read(value)
end

return function(props: Props)
	local hovered, pressed = source(false), source(false)
	local enabled = derive(function()
		return readOr(props.Enabled, true)
	end)
	local buttonColor = derive(function()
		return readOr(props.BackgroundColor3, UIStyle.Colors.Blue)
	end)
	local tintedBlack = derive(function()
		return BLACK:Lerp(buttonColor(), DARK_TINT_ALPHA)
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
	local faceDepth = spring(
		derive(function()
			return if enabled() and pressed() then 0.065 else 0
		end),
		0.11,
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
			return if enabled() then tintedBlack() else BLACK:Lerp(buttonColor(), 0.08)
		end,
		BackgroundTransparency = function()
			return if enabled() then 0 else 0.45
		end,
		BorderSizePixel = 0,
		LayoutOrder = function()
			return readOr(props.LayoutOrder, 0)
		end,
		Size = function()
			return readOr(props.Size, UDim2.fromScale(0.3, 1))
		end,
		create "UICorner" { CornerRadius = UIStyle.CornerRadius },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			-- Keep the silhouette crisp even though the other dark details inherit the button color.
			Color = BLACK,
			Thickness = UIStyle.OutlineThickness,
		},
		create "UIScale" { Scale = scale },
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIStyle.GlowTexture,
			ImageColor3 = buttonColor,
			ImageTransparency = function()
				return if enabled() and hovered() then 0.82 else 0.94
			end,
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(1.24, 1.6),
		},
		create "Frame" {
			Name = "Content",
			BackgroundColor3 = function()
				local Color = buttonColor()
				if not enabled() then return Color:Lerp(UIStyle.Colors.Ink, 0.45) end
				if pressed() then return Color:Lerp(tintedBlack(), 0.08) end
				return if hovered() then Color:Lerp(UIStyle.Colors.Paper, 0.08) else Color
			end,
			BorderSizePixel = 0,
			-- Compress the raised face into its backing while pressed so clicks feel physical.
			Position = function()
				return UDim2.fromScale(0, faceDepth())
			end,
			Size = function()
				return UDim2.fromScale(1, 0.88 - faceDepth())
			end,
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
				Color = tintedBlack,
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
					Sounds.Play("HoverStart", LocalPlayer.PlayerGui)
				end
			end,
			MouseLeave = function()
				if hovered() then
					Sounds.Play("HoverEnd", LocalPlayer.PlayerGui)
				end
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
					Sounds.Play("MouseDown", LocalPlayer.PlayerGui)
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
					Sounds.Play("Click", LocalPlayer.PlayerGui)
					props.OnActivated()
				end
			end,
		},
	}
end
