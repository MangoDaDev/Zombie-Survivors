local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Controllers = ServerStorage.Controllers
local ToInit = {}
local RequiredModules = {}
local LeftPlayers = {}
local DataController = require(Controllers.DataControllerServer)
local ResetData = false
DataController:init({
	resetData = ResetData and game.RunService:IsStudio(),
	template = require(Controllers.DataControllerServer.DataTemplate),
})
for _, Object in ToInit do
	if typeof(Object) ~= "Instance" or not Object:IsA("ModuleScript") then
		return
	end
	local Module = require(Object)
	table.insert(RequiredModules, Module)
	if Module.Init then
		print("Initiating " .. Object.Name)
		Module:Init()
		print("Finished Initiating " .. Object.Name)
	elseif Module.init then
		print("Initiating " .. Object.Name)
		Module:init()
		print("Finished Initiating " .. Object.Name)
	end
end
local function OnPlayerRemoving(plr, FinishedModules)
	if plr == nil then
		return
	end
	if not LeftPlayers[plr] then
		LeftPlayers[plr] = true
		DataController:update(plr, "LastLeaveTime", function()
			return os.clock()
		end)
		if FinishedModules == nil then
			FinishedModules = RequiredModules
		end
		for _, v in pairs(FinishedModules) do
			if v.OnPlayerRemoving then
				v.OnPlayerRemoving(plr)
			end
		end
	end
end
local function OnPlayerAdded(plr)
	if DataController._profiles[plr] == nil then
		repeat
			task.wait()
		until plr == nil or DataController._profiles[plr] ~= nil
	end

	if plr == nil then
		return
	end

	DataController:update(plr, "JoinTimes", function(c)
		return c + 1
	end)
	local FinishedModules = {}
	for _, v in pairs(RequiredModules) do
		if plr then
			if v.OnPlayerAdded then
				v.OnPlayerAdded(plr)
				table.insert(FinishedModules, v)
			end
		elseif #FinishedModules > 1 then
			OnPlayerRemoving(plr, FinishedModules)
		end
	end
	--DataController:set(plr,"Bucks",1000000000000)
end
local function OnCharacterAdded(plr, char)
	for _, v in pairs(RequiredModules) do
		if plr and char then
			if v.OnCharacterAdded then
				v.OnCharacterAdded(plr, char)
			end
		end
	end
end
DataController:addPlayerRemovingCallback(function(plr)
	OnPlayerRemoving(plr)
end)
Players.PlayerAdded:Connect(function(plr)
	OnPlayerAdded(plr)
	if plr.Character then
		OnCharacterAdded(plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		OnCharacterAdded(plr, char)
	end)
end)
for _, plr in pairs(Players:GetPlayers()) do
	task.spawn(function()
		OnPlayerAdded(plr)
		if plr.Character then
			OnCharacterAdded(plr, plr.Character)
		end
		plr.CharacterAdded:Connect(function(char)
			OnCharacterAdded(plr, char)
		end)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, plr in ipairs(Players:GetPlayers()) do
		if DataController._profiles[plr] then
			DataController:update(plr, "TimePlayed", function(c)
				return (c or 0) + dt
			end)
		end
	end
end)
