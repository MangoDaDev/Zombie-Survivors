local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local XPDropController = require(ServerStorage.Controllers.XPDropController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local ZombieRewardsController = {}

local function onZombieDied(death)
	if type(death) ~= "table" or typeof(death.position) ~= "Vector3" or type(death.definition) ~= "table" then
		return
	end
	local killer = death.killer
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") or killer.Parent ~= Players then
		killer = nil
	end

	local xpValue = death.definition.XPValue
	if type(xpValue) == "number" and xpValue > 0 then
		XPDropController.Spawn(death.position, xpValue, killer, death.groundY)
	end
	local coinValue = death.definition.CoinValue
	if type(coinValue) == "number" and coinValue > 0 then
		CoinDropController.SpawnBurst(death.position, coinValue, death.groundY, killer)
	end
end

function ZombieRewardsController.Init()
	ZombieController.GetZombieDiedSignal():Connect(onZombieDied)
end

return ZombieRewardsController
