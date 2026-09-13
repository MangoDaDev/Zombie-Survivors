local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TeleportPlayer = require(ReplicatedStorage.Modules.Game.TeleportPlayer)

local museumAssets = ReplicatedStorage.Assets.Models.Museum
local museumTemplate = museumAssets.Museum
local museumCFrames = museumAssets.MuseumCFrames

type MuseumAssignment = {
	museum: Model,
	position: BasePart,
}

local MuseumController = {}

local assignments: { [Player]: MuseumAssignment } = {}
local occupiedPositions: { [BasePart]: Player } = {}
local positions: { BasePart } = {}
local playerMuseums: Folder

local function getAvailablePosition(): BasePart?
	for _, position in positions do
		if occupiedPositions[position] == nil then
			return position
		end
	end
	return nil
end

local function moveMuseumToPosition(museum: Model, position: BasePart)
	local cFramePart = museum:FindFirstChild("CFramePart") :: BasePart
	local pivotOffset = cFramePart.CFrame:ToObjectSpace(museum:GetPivot())
	museum:PivotTo(position.CFrame * pivotOffset)
end

local function teleportCharacterToMuseum(player: Player, character: Model)
	local assignment = assignments[player]
	if assignment == nil then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if rootPart == nil or assignments[player] ~= assignment or player.Parent ~= Players then
		return
	end

	local spawnCFrame = assignment.museum:FindFirstChild("SpawnCFrame") :: BasePart
	TeleportPlayer(character, spawnCFrame)
end

function MuseumController:Init()
	playerMuseums = Instance.new("Folder")
	playerMuseums.Name = "PlayerMuseums"
	playerMuseums.Parent = Workspace

	for _, position in museumCFrames:GetChildren() do
		if position:IsA("BasePart") then
			table.insert(positions, position)
		end
	end

	table.sort(positions, function(a, b)
		return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
	end)
end

function MuseumController.OnPlayerAdded(player: Player)
	if assignments[player] then
		return
	end

	local position = getAvailablePosition()
	if position == nil then
		warn(`MuseumController could not assign a museum to {player.Name}: no positions are available`)
		return
	end

	local museum = museumTemplate:Clone()
	museum.Name = `Museum_{player.UserId}`
	moveMuseumToPosition(museum, position)
	museum.Parent = playerMuseums

	occupiedPositions[position] = player
	assignments[player] = {
		museum = museum,
		position = position,
	}
end

function MuseumController.OnCharacterAdded(player: Player, character: Model)
	task.spawn(teleportCharacterToMuseum, player, character)
end

function MuseumController.OnPlayerRemoving(player: Player)
	local assignment = assignments[player]
	if assignment == nil then
		return
	end

	assignments[player] = nil
	occupiedPositions[assignment.position] = nil
	assignment.museum:Destroy()
end

return MuseumController
