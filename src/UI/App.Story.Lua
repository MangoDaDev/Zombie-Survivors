local ReplicatedStorage = game:GetService "ReplicatedStorage"
local vide = require(ReplicatedStorage.Packages.vide)
local App = require(ReplicatedStorage.UI.App)
local story = {
	vide = vide,
	story = function()
		return App
	end,
}

return story
