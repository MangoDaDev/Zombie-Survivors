local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local App = require(script.Parent.App)

local mount = vide.mount
local player = Players.LocalPlayer

local UIOrigin = {}
local unmount: (() -> ())?

function UIOrigin:Init()
	if unmount then
		return
	end

	unmount = mount(App, player.PlayerGui)
end

return UIOrigin
