local PhysicsService = game:GetService("PhysicsService")

local PLAYER_CHARACTER_GROUP = "PlayerCharacters"

local CollisionController = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function assignPart(descendant: Instance)
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = PLAYER_CHARACTER_GROUP
	end
end

function CollisionController.Init()
	if not PhysicsService:IsCollisionGroupRegistered(PLAYER_CHARACTER_GROUP) then
		PhysicsService:RegisterCollisionGroup(PLAYER_CHARACTER_GROUP)
	end

	-- Player avatars do not push one another; future games can add their own groups separately.
	PhysicsService:CollisionGroupSetCollidable(PLAYER_CHARACTER_GROUP, PLAYER_CHARACTER_GROUP, false)
end

function CollisionController.OnCharacterAdded(player: Player, character: Model)
	local existingConnection = characterConnections[player]
	if existingConnection then
		existingConnection:Disconnect()
	end

	for _, descendant in character:GetDescendants() do
		assignPart(descendant)
	end

	characterConnections[player] = character.DescendantAdded:Connect(assignPart)
end

function CollisionController.OnPlayerRemoving(player: Player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
	end
	characterConnections[player] = nil
end

return CollisionController
