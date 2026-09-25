local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local create = Vide.create

-- Shared tiled surface treatment keeps active HUD panels and menus visually consistent with
-- the existing STUD-style party UI without coupling those screens to one another.
return function(properties)
	properties = properties or {}
	return create "ImageLabel" {
		Name = properties.Name or "StudTexture",
		BackgroundTransparency = 1,
		Image = UIStyle.StudTexture,
		ImageColor3 = properties.ImageColor3 or Color3.new(1, 1, 1),
		ImageTransparency = properties.ImageTransparency or UIStyle.StudTransparency,
		ScaleType = Enum.ScaleType.Tile,
		Size = properties.Size or UDim2.fromScale(1, 1),
		TileSize = properties.TileSize or UDim2.fromOffset(22, 22),
		ZIndex = properties.ZIndex or 1,
	}
end
