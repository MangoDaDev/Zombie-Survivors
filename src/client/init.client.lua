local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Controllers = ReplicatedStorage.Controllers
local Classes = ReplicatedStorage.Classes
local LocalPlayer = Players.LocalPlayer

local Packages = ReplicatedStorage.Packages

local ToInit = {}

local DataController = require(Controllers.DataController.DataControllerClient)
DataController:init()

--test

local RequiredModules = {}

for _, Object in ToInit do
	if typeof(Object) ~= "Instance" or not Object:IsA("ModuleScript") then
		return
	end
	print("Waiting to Required " .. Object.Name)
	local Module = require(Object)
	print("Required " .. Object.Name)
	table.insert(RequiredModules, Module)
	if Module.Init and Object.Parent ~= Classes and Object.Parent.Parent ~= Classes then
		print("Started to init " .. Object.Name)
		Module:Init()
		print("Initiated " .. Object.Name)
	elseif Module.init and Object.Parent ~= Classes and Object.Parent.Parent ~= Classes then
		print("Initiating " .. Object.Name)
		Module:init()
		print("Finished Initiating " .. Object.Name)
	end
end

local function OnCharacterAdded(char)
	for _, v in pairs(RequiredModules) do
		if char then
			if v.OnCharacterAdded then
				v.OnCharacterAdded(char)
			end
		end
	end
end

if LocalPlayer.Character then
	OnCharacterAdded(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	OnCharacterAdded(char)
end)
