local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	}
end
