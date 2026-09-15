local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.networker)

local CONFIG = {
	AnimationBundleId = 149344844441554,
	RequestCooldown = 0.5,
}

local CATEGORY_KEYWORDS = {
	Idle = "idle",
	Walk = "walk",
	Run = "run",
	Jump = "jump",
	Fall = "fall",
	Swim = "swim",
	Climb = "climb",
	Mood = "mood",
}

local CharacterController = {
	Config = CONFIG,
}
local CharacterNetwork: Networker.Server?

local readyPlayers: { [Player]: boolean } = {}
local loadingPlayers: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}
local cachedAnimationIds: { [string]: number }?
local animationCacheAttempted = false

local function getAnimationIds(): { [string]: number }?
	if cachedAnimationIds or animationCacheAttempted then
		return cachedAnimationIds
	end
	animationCacheAttempted = true
	local success, bundle = pcall(AssetService.GetBundleDetailsAsync, AssetService, CONFIG.AnimationBundleId)
	if not success or type(bundle) ~= "table" or type(bundle.Items) ~= "table" then
		warn("CharacterController could not load the configured animation bundle")
		return nil
	end

	local ids = {}
	for _, item in bundle.Items do
		local itemName = string.lower(tostring(item.Name or ""))
		for category, keyword in CATEGORY_KEYWORDS do
			if not ids[category] and string.find(itemName, keyword, 1, true) and type(item.Id) == "number" then
				ids[category] = item.Id
				break
			end
		end
	end
	cachedAnimationIds = ids
	return ids
end

local function applyR6Animations(character: Model, humanoid: Humanoid)
	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then return end
	local ids = getAnimationIds()
	if not ids then return end
	local description = humanoid:GetAppliedDescription()
	for category, id in ids do
		description[category .. "Animation"] = id
	end
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeadScale = 1
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	humanoid:ApplyDescription(description)
end

function CharacterController.RequestCharacter(_, player: Player): boolean
	if not readyPlayers[player] or loadingPlayers[player] or player.Parent ~= Players then
		return false
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < CONFIG.RequestCooldown then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return true
	end

	lastRequestAt[player] = now
	loadingPlayers[player] = true
	player:LoadCharacter()
	loadingPlayers[player] = nil
	return player.Character ~= nil
end

function CharacterController.Init()
	CharacterNetwork = Networker.server.new("CharacterController", CharacterController, {
		CharacterController.RequestCharacter,
	})
end

function CharacterController.OnPlayerAdded(player: Player)
	readyPlayers[player] = true
end

function CharacterController.OnCharacterAdded(_player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		task.spawn(applyR6Animations, character, humanoid)
	end
end

function CharacterController.OnPlayerRemoving(player: Player)
	readyPlayers[player] = nil
	loadingPlayers[player] = nil
	lastRequestAt[player] = nil
end

return CharacterController
