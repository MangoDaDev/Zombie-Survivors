local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local frozenRoot: BasePart?
local wasAnchored = false

local PlayerFreezeState = {}

function PlayerFreezeState.Freeze(target: CFrame?): boolean
	if not RunService:IsClient() then
		return false
	end

	PlayerFreezeState.Unfreeze()

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	if target then
		root.CFrame = target
	end

	frozenRoot = root
	wasAnchored = root.Anchored
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	return true
end

function PlayerFreezeState.Unfreeze()
	if frozenRoot and frozenRoot.Parent then
		frozenRoot.Anchored = wasAnchored
	end

	frozenRoot = nil
	wasAnchored = false
end

return PlayerFreezeState
