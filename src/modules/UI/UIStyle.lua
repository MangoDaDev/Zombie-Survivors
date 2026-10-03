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
	-- User-required combat identity: keep studs clearly visible when polishing the HUD.
	CombatStudTransparency = 0.72,
	CombatStudTileSize = UDim2.fromOffset(64, 64),
	ReferenceViewport = Vector2.new(1280, 720),
	-- For requests to make UI bigger/smaller specifically on high-resolution screens,
	-- tune this Scale share (lower = slower growth), preserving the reference-size pixel base.
	BaseContainerScaleWeight = 0.65,
	RoundStatusSize = UDim2.fromScale(0.9, 0.095),
	RoundStatusAspectRatio = 520 / 68,
	NarrowRoundStatusAspectRatio = 396 / 68,
	-- Combat meters share one width and height; narrow phones expand them across the bottom dock.
	CombatMeterSize = UDim2.new(0.22, 160, 0, 52),
	CompactCombatWidth = 1400,
	-- Preserve the existing authored menu reduction; high-resolution growth belongs to
	-- BaseContainerScaleWeight. ClassInterface retains its original reference-size scale.
	NonClassMenuScale = 0.84,
}

return UIStyle
