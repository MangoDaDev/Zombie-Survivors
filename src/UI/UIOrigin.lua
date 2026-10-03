local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

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

	-- Player health belongs above characters; suppress Roblox's competing screen health display too.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	unmount = mount(App, player.PlayerGui)
end

return UIOrigin
