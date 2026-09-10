local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local localPlayer = Players.LocalPlayer
local readySignal = Signal.new()
local deathConnection: RBXScriptConnection?

local CharacterController = {
	networker = nil :: Networker.Client?,
	ready = false,
}

function CharacterController:Init()
	self.networker = Networker.client.new("CharacterController", self)
	self.ready = true
	readySignal:Fire()
end

function CharacterController:WaitUntilReady()
	if not self.ready then
		readySignal:Wait()
	end
end

function CharacterController:RequestCharacter(): boolean
	self:WaitUntilReady()
	return (self.networker :: Networker.Client):fetch("RequestCharacter") == true
end

function CharacterController.OnCharacterAdded(character: Model)
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if Workspace.CurrentCamera.CameraType == Enum.CameraType.Custom then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
	deathConnection = humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if localPlayer.Character == character or localPlayer.Character == nil then
				CharacterController:RequestCharacter()
			end
		end)
	end)
end

return CharacterController
