-- Currently unused after removal of extraction gameplay. Preserved for possible future run-reward adaptation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local RunRewardsController = {}

local rewardNetwork: Networker.Client?
local pendingCoins = 0
local inSafeArea = false
local pendingCoinsChanged = Signal.new()
local safeAreaChanged = Signal.new()
local rewardsClaimed = Signal.new()

local function setPendingCoins(value: any)
	if type(value) ~= "number" or value ~= value or value < 0 or value % 1 ~= 0 or value == pendingCoins then
		return
	end

	pendingCoins = value
	pendingCoinsChanged:Fire(value)
end

local function setInSafeArea(value: any)
	if type(value) ~= "boolean" or value == inSafeArea then
		return
	end

	inSafeArea = value
	safeAreaChanged:Fire(value)
end

function RunRewardsController.RunRewardsChanged(_, rewards)
	if type(rewards) == "table" then
		setPendingCoins(rewards.coins)
		setInSafeArea(rewards.inSafeArea)
	end
end

function RunRewardsController.RewardsClaimed(_, amount)
	if type(amount) == "number" and amount == amount and amount > 0 and amount % 1 == 0 then
		rewardsClaimed:Fire(amount)
	end
end

function RunRewardsController.Init()
	rewardNetwork = Networker.client.new("RunRewardsController", RunRewardsController)
	local rewards = (rewardNetwork :: Networker.Client):fetch("GetState")
	if type(rewards) == "table" then
		setPendingCoins(rewards.coins)
		setInSafeArea(rewards.inSafeArea)
	end
end

function RunRewardsController.GetPendingCoins(): number
	return pendingCoins
end

function RunRewardsController.GetPendingCoinsChangedSignal()
	return pendingCoinsChanged
end

function RunRewardsController.IsInSafeArea(): boolean
	return inSafeArea
end

function RunRewardsController.GetSafeAreaChangedSignal()
	return safeAreaChanged
end

function RunRewardsController.GetRewardsClaimedSignal()
	return rewardsClaimed
end

function RunRewardsController.ReturnToBaseAndClaim()
	if rewardNetwork then
		(rewardNetwork :: Networker.Client):fire("ReturnToBaseAndClaim")
	end
end

return RunRewardsController
