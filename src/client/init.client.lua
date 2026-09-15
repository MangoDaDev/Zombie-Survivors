local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local local_player = Players.LocalPlayer
local data_service = require(ReplicatedStorage.Packages.dataservice).client

data_service:init()

local modules_to_init = {
	ReplicatedStorage.Controllers.PlayerStateController,
	ReplicatedStorage.Controllers.CharacterController,
	ReplicatedStorage.Controllers.CrateController,
	ReplicatedStorage.Controllers.BatController,
	ReplicatedStorage.Controllers.MuseumVisitorController,
	ReplicatedStorage.Controllers.TopbarController,
	ReplicatedStorage.UI.UIOrigin,
	ReplicatedStorage.Controllers.GuidanceController,
	ReplicatedStorage.Controllers.InventoryController,
	ReplicatedStorage.Controllers.FixingController,
}

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
