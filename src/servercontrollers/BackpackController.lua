local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackpackConfig = require(ReplicatedStorage.Modules.Game.BackpackConfig)
local ServerContext = require(script.Parent.ServerContext)

local ASSET_FOLDER = ReplicatedStorage.Assets.Models.Bags
local TORSO_NAMES = { "UpperTorso", "Torso" }
local TORSO_WAIT_TIMEOUT = 10

type StageDefinition = {
	MinimumCoins: number,
	AssetName: string,
	MountOffsetZ: number,
}

local BackpackController = {}

local carriedCoinsByPlayer: { [Player]: number } = {}
local equippedBackpacks: { [Player]: Model } = {}
local equippedStages: { [Player]: StageDefinition } = {}
local torsoConnections: { [Player]: RBXScriptConnection } = {}

local function disconnectTorsoConnection(player: Player)
	local connection = torsoConnections[player]
	if connection then
		connection:Disconnect()
		torsoConnections[player] = nil
	end
end

local function findTorso(character: Model): BasePart?
	for _, torsoName in TORSO_NAMES do
		local torso = character:FindFirstChild(torsoName)
		if torso and torso:IsA("BasePart") then
			return torso
		end
	end
	return nil
end

local function prepareBackpack(backpack: Model)
	for _, descendant in backpack:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function equipBackpack(player: Player, character: Model, torso: BasePart): boolean
	if player.Character ~= character or character.Parent == nil then
		return false
	end

	local stage = BackpackConfig.GetStage(carriedCoinsByPlayer[player] or 0)
	local currentBackpack = equippedBackpacks[player]
	if currentBackpack
		and currentBackpack.Parent == character
		and equippedStages[player] == stage
	then
		return true
	end

	local template = ASSET_FOLDER:FindFirstChild(stage.AssetName)
	if not template or not template:IsA("Model") then
		warn(string.format("BackpackController could not find model %s in %s", stage.AssetName, ASSET_FOLDER:GetFullName()))
		return false
	end

	local backpack = template:Clone()
	local mount = backpack.PrimaryPart
	if not mount or mount.Name ~= "Mount" then
		backpack:Destroy()
		warn(string.format("BackpackController requires %s to use its Mount as PrimaryPart", template:GetFullName()))
		return false
	end

	backpack.Name = BackpackConfig.ModelName
	-- The inspected assets face the same direction as the character; positive local Z places them on the back.
	backpack:PivotTo(torso.CFrame * CFrame.new(0, 0, stage.MountOffsetZ))
	prepareBackpack(backpack)

	local characterWeld = Instance.new("WeldConstraint")
	characterWeld.Name = "CharacterWeld"
	characterWeld.Part0 = torso
	characterWeld.Part1 = mount
	characterWeld.Parent = mount

	-- Parent the replacement before removing the previous stage so in-flight coins always retain a valid bag target.
	backpack.Parent = character
	equippedBackpacks[player] = backpack
	equippedStages[player] = stage
	if currentBackpack and currentBackpack ~= backpack then
		currentBackpack:Destroy()
	end
	return true
end

local function attachWhenTorsoIsReady(player: Player, character: Model)
	disconnectTorsoConnection(player)

	local torso = findTorso(character)
	if torso then
		equipBackpack(player, character, torso)
		return
	end

	local connection
	connection = character.ChildAdded:Connect(function()
		local addedTorso = findTorso(character)
		if not addedTorso then
			return
		end
		if connection then
			connection:Disconnect()
		end
		torsoConnections[player] = nil
		equipBackpack(player, character, addedTorso)
	end)
	torsoConnections[player] = connection

	task.delay(TORSO_WAIT_TIMEOUT, function()
		if torsoConnections[player] == connection then
			disconnectTorsoConnection(player)
			warn(string.format("BackpackController could not find a torso for %s", player.Name))
		end
	end)
end

function BackpackController.SetCarriedCoins(player: Player, carriedCoins: number)
	if player.Parent ~= Players or carriedCoins < 0 or carriedCoins % 1 ~= 0 then
		return
	end

	carriedCoinsByPlayer[player] = carriedCoins
	local character = player.Character
	local torso = character and findTorso(character)
	if character and torso then
		equipBackpack(player, character, torso)
	end
end

function BackpackController.AddCarriedCoins(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
		return
	end
	BackpackController.SetCarriedCoins(player, (carriedCoinsByPlayer[player] or 0) + amount)
end

function BackpackController.GetCarriedCoins(player: Player): number
	return carriedCoinsByPlayer[player] or 0
end

function BackpackController.OnPlayerAdded(player: Player)
	carriedCoinsByPlayer[player] = 0
end

function BackpackController.OnCharacterAdded(player: Player, character: Model)
	if not ServerContext.IsGameServer() then
		return
	end
	-- The coin bag is run equipment; lobby characters must remain unchanged.
	attachWhenTorsoIsReady(player, character)
end

function BackpackController.OnPlayerRemoving(player: Player)
	disconnectTorsoConnection(player)
	carriedCoinsByPlayer[player] = nil
	equippedBackpacks[player] = nil
	equippedStages[player] = nil
end

return BackpackController
