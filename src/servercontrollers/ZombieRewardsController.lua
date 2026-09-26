local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PowerupConfig = require(ReplicatedStorage.Modules.Game.PowerupConfig)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local CoinDropController = require(ServerStorage.Controllers.CoinDropController)
local ClassController = require(ServerStorage.Controllers.ClassController)
local RageController = require(ServerStorage.Controllers.RageController)
local PassiveEffects = require(ServerStorage.Controllers.Ability.PassiveEffects)
local XPDropController = require(ServerStorage.Controllers.XPDropController)
local ZombieController = require(ServerStorage.Controllers.ZombieController)

local ZombieRewardsController = {}
local coinRemainders: { [Player]: number } = {}

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
		ClassController.RegisterRageKill(killer, RageController.IsActive(killer))
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
		-- Greed is rolled once against the server-confirmed killer, never from a client pickup claim.
		local greedBonus = if killer
			then PassiveEffects.GetGreedBonus(killer, death.definition.ThreatLevel or 0)
			else 0
		local baseValue = coinValue * rewardMultiplier + greedBonus
		local classMultiplier = if killer then ClassController.GetCoinRewardMultiplier(killer) else 1
		if classMultiplier == 1 then
			CoinDropController.SpawnBurst(death.position, baseValue, death.groundY, killer)
		else
			-- Carry fractional Scavenger rewards rather than losing 15% on one-Coin kills.
			local exactValue = baseValue * classMultiplier + (coinRemainders[killer] or 0)
			local wholeValue = math.floor(exactValue + 0.000001)
			coinRemainders[killer] = exactValue - wholeValue
			if wholeValue > 0 then
				CoinDropController.SpawnBurst(death.position, wholeValue, death.groundY, killer)
			end
		end
	end
end

function ZombieRewardsController.Init()
	ZombieController.GetZombieDiedSignal():Connect(onZombieDied)
end

function ZombieRewardsController.OnPlayerRemoving(player: Player)
	coinRemainders[player] = nil
end

return ZombieRewardsController
