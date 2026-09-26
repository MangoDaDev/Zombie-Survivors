local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local local_player = Players.LocalPlayer
local data_service = require(ReplicatedStorage.Packages.dataservice).client

data_service:init()

local modules_to_init = {
	ReplicatedStorage.Controllers.ChatCommandController,
	ReplicatedStorage.Controllers.PlayerStateController,
	ReplicatedStorage.Controllers.CoinsController,
	ReplicatedStorage.Controllers.GameReadyController,
	ReplicatedStorage.Controllers.RageController,
	ReplicatedStorage.Controllers.AbilityController,
	ReplicatedStorage.Controllers.RunProgressionController,
	ReplicatedStorage.Controllers.ClassController,
	ReplicatedStorage.Controllers.ClassChangingRoomController,
	ReplicatedStorage.Controllers.ZombieIndexController,
	ReplicatedStorage.Controllers.RunSessionController,
	ReplicatedStorage.Controllers.CharacterController,
	ReplicatedStorage.Controllers.ZombieController,
	ReplicatedStorage.Controllers.CoinDropController,
	ReplicatedStorage.Controllers.XPDropController,
	ReplicatedStorage.Controllers.PowerupDropController,
	ReplicatedStorage.Controllers.PartyTeleporterController,
	ReplicatedStorage.UI.UIOrigin,
}

-- Simulator-era reward rolls and extraction remain dormant. Current run choices, pickups, and death
-- presentation are driven by their authoritative game-server controllers.

local initialized_modules = {}

for _, module_script in modules_to_init do
	local module = require(module_script)

	if module.SetDataService then
		module.SetDataService(data_service)
	end

	table.insert(initialized_modules, module)

	if module.Init then
		module.Init()
	elseif module.init then
		module:init()
	end
end

local function OnCharacterAdded(character: Model)
	for _, module in initialized_modules do
		if module.OnCharacterAdded then
			module.OnCharacterAdded(character)
		end
	end
end

if local_player.Character then
	OnCharacterAdded(local_player.Character)
end

local_player.CharacterAdded:Connect(OnCharacterAdded)
