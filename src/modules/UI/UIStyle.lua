local UIStyle = {
	Font = Font.fromName "Ubuntu",
	StudTexture = "rbxassetid://6927295847", -- Keep in mind that the stud texture is an image of 4x4 studs.
	GlowTexture = "rbxassetid://85440167673906",
	-- Robux prices use Roblox's built-in text glyph so purchase controls do not depend on an image icon.
	RobuxSymbol = utf8.char(0xE002),
	Colors = {
		Ink = Color3.fromRGB(30, 30, 30),
		InkSoft = Color3.fromRGB(40, 40, 40),
		Paper = Color3.fromRGB(255, 255, 255),
		PaperShadow = Color3.fromRGB(206, 206, 206),
		Muted = Color3.fromRGB(163, 163, 163),
		Green = Color3.fromRGB(71, 190, 104),
		Red = Color3.fromRGB(218, 75, 75),
		RedDark = Color3.fromRGB(115, 50, 50),
		Blue = Color3.fromRGB(70, 158, 209),
		BlueDark = Color3.fromRGB(35, 76, 126),
		Gold = Color3.fromRGB(241, 180, 67),
	},
	CornerRadius = UDim.new(0, 6),
	SmallCornerRadius = UDim.new(0, 4),
	OutlineThickness = 3,
	InsideStrokeTransparency = 0.55,
	StudTransparency = 0.82,
	-- Composed menus use one uniform visual reduction so fixed-offset descendants scale together.
	-- ClassInterface intentionally does not consume this value and retains its authored size.
	NonClassMenuScale = 0.84,
}

return UIStyle
