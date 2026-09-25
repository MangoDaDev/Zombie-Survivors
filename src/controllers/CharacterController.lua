local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local localPlayer = Players.LocalPlayer
local readySignal = Signal.new()
local deathConnection: RBXScriptConnection?

local CharacterController = {}
local CharacterNetwork: Networker.Client?
local IsReady = false

function CharacterController.Init()
	CharacterNetwork = Networker.client.new("CharacterController", CharacterController)
	IsReady = true
	readySignal:Fire()
end

function CharacterController.WaitUntilReady()
	if not IsReady then
		readySignal:Wait()
	end
end

function CharacterController.RequestCharacter(): boolean
	CharacterController.WaitUntilReady()
	return (CharacterNetwork :: Networker.Client):fetch("RequestCharacter") == true
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
		-- A game-session death ends the run; RunSessionController owns the personal result/countdown flow.
		if Workspace:FindFirstChild("Game") then
			return
		end
		task.delay(Players.RespawnTime, function()
			if localPlayer.Character == character or localPlayer.Character == nil then
				CharacterController.RequestCharacter()
			end
		end)
	end)
end

return CharacterController
