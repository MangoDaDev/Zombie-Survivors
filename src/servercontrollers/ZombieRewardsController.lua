local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PowerupConfig = require(ReplicatedStorage.Modules.Game.PowerupConfig)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
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
	local rewardMultiplier = 1
	if killer then
		local luckyEndsAt = RuntimeState.Get(killer, "LuckySkullEndsAt", 0)
		if type(luckyEndsAt) == "number" and workspace:GetServerTimeNow() < luckyEndsAt then
			-- Lucky Skull doubles only rewards from kills credited to its owner; it never changes zombie health.
			rewardMultiplier = PowerupConfig.LuckySkull.RewardMultiplier
		end
	end

	local xpValue = death.definition.XPValue
	if type(xpValue) == "number" and xpValue > 0 then
		XPDropController.Spawn(death.position, xpValue * rewardMultiplier, killer, death.groundY)
	end
	local coinValue = death.definition.CoinValue
	if type(coinValue) == "number" and coinValue > 0 then
		CoinDropController.SpawnBurst(death.position, coinValue * rewardMultiplier, death.groundY, killer)
	end
end

function ZombieRewardsController.Init()
	ZombieController.GetZombieDiedSignal():Connect(onZombieDied)
end

return ZombieRewardsController
