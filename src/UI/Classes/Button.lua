local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Vide = require(ReplicatedStorage.Packages.vide)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local create, derive, effect = Vide.create, Vide.derive, Vide.effect
local read, source, spring = Vide.read, Vide.source, Vide.spring

local LocalPlayer = Players.LocalPlayer
local BLACK = Color3.new(0, 0, 0)
local DARK_TINT_ALPHA = 0.42

type Reactive<T> = T | (() -> T)
export type Props = {
	Text: Reactive<string>?,
	OnActivated: (() -> ())?,
	Enabled: Reactive<boolean>?,
	BackgroundColor3: Reactive<Color3>?,
	CornerRadius: Reactive<UDim>?,
	FontFace: Reactive<Font>?,
	LayoutOrder: Reactive<number>?,
	MaxTextSize: Reactive<number>?,
	MinTextSize: Reactive<number>?,
	Size: Reactive<UDim2>?,
	StrokeThickness: Reactive<number>?,
	TextBounds: Reactive<UDim2>?,
	TextCenterY: Reactive<number>?,
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
	local outlineColor = derive(function()
		return BLACK:Lerp(buttonColor(), 0.56)
	end)
	local faceColor = derive(function()
		local color = buttonColor()
		if not enabled() then
			return color:Lerp(UIStyle.Colors.Ink, 0.45)
		elseif pressed() then
			return color:Lerp(tintedBlack(), 0.08)
		end
		return if hovered() then color:Lerp(UIStyle.Colors.Paper, 0.08) else color
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
			-- Keep enough backing visible to communicate depth without producing a tall dark band.
			return if enabled() and pressed() then 0.04 else 0
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
		Name = "ButtonSlot",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = function()
			return readOr(props.LayoutOrder, 0)
		end,
		Size = function()
			return readOr(props.Size, UDim2.fromScale(0.3, 1))
		end,
		create "Frame" {
			Name = "Button",
			-- Keep layout sizing on the unscaled slot; the visual button is centered so hover/press springs
			-- expand around its middle instead of pulling away from the top-left corner.
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = function()
				return if enabled() then tintedBlack() else BLACK:Lerp(buttonColor(), 0.2)
			end,
			BackgroundTransparency = function()
				return if enabled() then 0 else 0.45
			end,
			BorderSizePixel = 0,
			create "UICorner" {
				CornerRadius = function()
					-- Corner rounding is opt-in so this interaction component does not impose a visual style.
					return readOr(props.CornerRadius, UDim.new(0, 0))
				end,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				-- Keep the silhouette crisp even though the other dark details inherit the button color.
				Color = outlineColor,
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
			BackgroundColor3 = faceColor,
			BorderSizePixel = 0,
			-- Compress the raised face into its backing while pressed so clicks feel physical.
			Position = function()
				return UDim2.fromScale(0, faceDepth())
			end,
			Size = function()
				return UDim2.fromScale(1, 0.88 - faceDepth())
			end,
			ZIndex = 1,
			create "UICorner" {
				CornerRadius = function()
					return readOr(props.CornerRadius, UDim.new(0, 0))
				end,
			},
			create "ImageLabel" {
				Name = "StudTexture",
				BackgroundTransparency = 1,
				Image = UIStyle.StudTexture,
				ImageTransparency = UIStyle.StudTransparency,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(108, 108),
				ZIndex = 2,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = function()
					return buttonColor():Lerp(UIStyle.Colors.Paper, 0.38)
				end,
				Thickness = UIStyle.OutlineThickness,
				Transparency = UIStyle.InsideStrokeTransparency,
			},
		},
		create "TextLabel" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = function()
				return readOr(props.FontFace, UIStyle.Font)
			end,
			-- Move the label by the same spring offset as the raised face so the button depresses as one unit.
			Position = function()
				return UDim2.fromScale(0.5, readOr(props.TextCenterY, 0.5) + faceDepth())
			end,
			Size = function()
				return readOr(props.TextBounds, UDim2.fromScale(1, 1))
			end,
			Text = function()
				return readOr(props.Text, "Button")
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 3,
			create "UIStroke" {
				Color = outlineColor,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = function()
					return readOr(props.StrokeThickness, 0.055)
				end,
			},
			create "UITextSizeConstraint" {
				MaxTextSize = function()
					return readOr(props.MaxTextSize, 24)
				end,
				MinTextSize = function()
					return readOr(props.MinTextSize, 15)
				end,
			},
		},
		create "TextButton" {
			Active = enabled,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = enabled,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextScaled = true,
			FontFace = function()
				return readOr(props.FontFace, UIStyle.Font)
			end,
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
		},
	}
end
