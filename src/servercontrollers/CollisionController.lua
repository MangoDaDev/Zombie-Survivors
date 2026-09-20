local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Modules.Game.CollisionGroups)

local CollisionController = {}
local CharacterConnections: { [Player]: RBXScriptConnection } = {}

local function RegisterGroup(GroupName: string)
	if not PhysicsService:IsCollisionGroupRegistered(GroupName) then PhysicsService:RegisterCollisionGroup(GroupName) end
end

local function AssignPart(Descendant: Instance)
	if Descendant:IsA("BasePart") then Descendant.CollisionGroup = CollisionGroups.PlayerCharacters end
end

function CollisionController.Init()
	RegisterGroup(CollisionGroups.CrateDebris)
	RegisterGroup(CollisionGroups.Ground)
	RegisterGroup(CollisionGroups.PlayerCharacters)
	RegisterGroup(CollisionGroups.NPCCharacters)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.CrateDebris, CollisionGroups.CrateDebris, false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.CrateDebris, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.CrateDebris, CollisionGroups.Ground, true)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.CrateDebris, CollisionGroups.PlayerCharacters, false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.CrateDebris, CollisionGroups.NPCCharacters, false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PlayerCharacters, CollisionGroups.PlayerCharacters, false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PlayerCharacters, CollisionGroups.NPCCharacters, false)
	local Ground = workspace:FindFirstChild("Baseplate")
	if Ground and Ground:IsA("BasePart") then Ground.CollisionGroup = CollisionGroups.Ground end
end

function CollisionController.OnCharacterAdded(Player: Player, Character: Model)
	local ExistingConnection = CharacterConnections[Player]
	if ExistingConnection then ExistingConnection:Disconnect() end
	for _, Descendant in Character:GetDescendants() do AssignPart(Descendant) end
	CharacterConnections[Player] = Character.DescendantAdded:Connect(AssignPart)
end

function CollisionController.OnPlayerRemoving(Player: Player)
	local Connection = CharacterConnections[Player]
	if Connection then Connection:Disconnect() end
	CharacterConnections[Player] = nil
end

return CollisionController
