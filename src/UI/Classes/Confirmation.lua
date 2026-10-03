local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Signal = require(ReplicatedStorage.Packages.signal)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local ResponsiveViewport = require(script.Parent.Parent.ResponsiveViewport)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer
local Requested = Signal.new()

local Confirmation = {}

function Confirmation.Show(Text: string, OnConfirmed: () -> ())
	if Text == "" then return end
	Requested:Fire(Text, OnConfirmed)
end

function Confirmation.Component()
	local responsiveViewport = ResponsiveViewport()
	local IsVisible = Source(false)
	local Text = Source("")
	local ConfirmCallback: (() -> ())?

	local function Resolve(IsConfirmed: boolean)
		if not IsVisible() then return end
		local Callback = ConfirmCallback
		ConfirmCallback = nil
		IsVisible(false)
		if IsConfirmed and Callback then Callback() end
	end

	local RequestConnection = Requested:Connect(function(NewText: string, NewConfirmCallback: () -> ())
		Text(NewText)
		ConfirmCallback = NewConfirmCallback
		IsVisible(true)
		Sounds.Play("Popup", LocalPlayer.PlayerGui)
	end)
	Cleanup(function()
		ConfirmCallback = nil
		RequestConnection:Disconnect()
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(responsiveViewport)
	layout.Confirmation = layout.Viewport
	layout.Panel = ResponsiveLayout.Base(UDim2.fromScale(0.9, 0.3), layout.Confirmation, 2.15)
	layout.Actions = ResponsiveLayout.Child(UDim2.fromScale(0.9, 0.28), layout.Panel)

	return Create "Frame" {
		Name = "Confirmation",
		Active = true,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.38,
		Size = UDim2.fromScale(1, 1),
		Visible = IsVisible,
		ZIndex = 100,
		Create "Frame" {
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = UIStyle.Colors.InkSoft,
			BorderSizePixel = 0,
			-- Keep confirmations above ordinary application UI.
			Position = layout.Panel.Position(UDim2.fromScale(0.5, 0.34), Vector2.new(0.5, 0.5)),
			-- The generous responsive bounds keep confirmations readable on phones while the
			-- aspect constraint limits their desktop height and preserves the authored shape.
			Size = layout.Panel.Size,
			ZIndex = 101,
			Create "UIAspectRatioConstraint" {
				AspectRatio = 2.15,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			},
			Create "UICorner" { CornerRadius = UIStyle.CornerRadius },
			Create "UIStroke" {
				Color = UIStyle.Colors.Ink,
				Thickness = UIStyle.OutlineThickness,
			},
			Create "Frame" {
				Name = "StudPlate",
				BackgroundColor3 = UIStyle.Colors.BlueDark,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 0.91),
				ZIndex = 102,
				Create "UICorner" { CornerRadius = UIStyle.CornerRadius },
				Create "UIGradient" {
					Color = ColorSequence.new(UIStyle.Colors.Blue, UIStyle.Colors.BlueDark),
					Rotation = 90,
				},
				Create "UIStroke" {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = UIStyle.Colors.Paper,
					Thickness = UIStyle.OutlineThickness,
					Transparency = UIStyle.InsideStrokeTransparency,
				},
			},
			Create "ImageLabel" {
				Name = "StudTexture",
				BackgroundTransparency = 1,
				Image = UIStyle.StudTexture,
				ImageColor3 = UIStyle.Colors.Paper,
				ImageTransparency = UIStyle.StudTransparency,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 0.91),
				TileSize = UDim2.fromOffset(108, 108),
				ZIndex = 103,
			},
			Create "TextLabel" {
				Name = "Question",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.07, 0.1),
				Size = UDim2.fromScale(0.86, 0.38),
				Text = Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 104,
				Create "UIStroke" {
					Color = UIStyle.Colors.Ink,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.045,
				},
				Create "UITextSizeConstraint" { MaxTextSize = 34, MinTextSize = 16 },
			},
			Create "Frame" {
				Name = "Actions",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.59),
				Size = UDim2.fromScale(0.9, 0.28),
				ZIndex = 104,
				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = layout.Actions.Padding(UDim.new(0.08, 0), "X"),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},
				Button({
					Text = "Yes",
					BackgroundColor3 = UIStyle.Colors.Red,
					LayoutOrder = 1,
					OnActivated = function() Resolve(true) end,
				}),
				Button({
					Text = "No",
					BackgroundColor3 = UIStyle.Colors.Blue,
					LayoutOrder = 2,
					OnActivated = function() Resolve(false) end,
				}),
			},
		},
	}
end

return Confirmation
