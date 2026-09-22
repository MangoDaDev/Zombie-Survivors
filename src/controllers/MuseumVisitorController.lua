local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuseumVisitor = require(ReplicatedStorage.Classes.MuseumVisitor)
local Networker = require(ReplicatedStorage.Packages.networker)

local MuseumVisitorController = {}
local Visitors = {}
local Network
local ViewedOwnerUserId
local ViewRequestToken = 0

local function RequestViewedMuseum(OwnerUserId)
	ViewedOwnerUserId = OwnerUserId
	ViewRequestToken += 1
	local RequestToken = ViewRequestToken
	local function SendViewRequest()
		if RequestToken ~= ViewRequestToken then return end
		Network:fire("SetViewedMuseum", OwnerUserId)
		-- Keep retrying until the server confirms the base, since its position may lag the client at the boundary.
		task.delay(1, SendViewRequest)
	end
	SendViewRequest()
end

local function GetVisitor(UniqueId)
	return if type(UniqueId) == "string" then Visitors[UniqueId] else nil
end

function MuseumVisitorController.CreateVisitor(_, Data)
	if type(Data) ~= "table" or type(Data.UniqueId) ~= "string" or type(Data.OwnerUserId) ~= "number" then return end
	local ExistingVisitor = Visitors[Data.UniqueId]
	if ExistingVisitor then ExistingVisitor:Destroy() end
	local MoveTarget = Data.MoveTarget
	local MoveDuration = Data.MoveDuration
	Data.MoveTarget = nil
	Data.MoveDuration = nil
	local Visitor = MuseumVisitor.new(Data)
	Visitors[Data.UniqueId] = Visitor
	if typeof(MoveTarget) == "CFrame" and type(MoveDuration) == "number" then
		Visitor:MoveTo(MoveTarget, MoveDuration)
	end
end

function MuseumVisitorController.MoveVisitor(_, UniqueId, TargetCFrame, Duration)
	local Visitor = GetVisitor(UniqueId)
	if Visitor and typeof(TargetCFrame) == "CFrame" and type(Duration) == "number" then Visitor:MoveTo(TargetCFrame, Duration) end
end

function MuseumVisitorController.ShowVisitorCash(_, UniqueId, Amount)
	local Visitor = GetVisitor(UniqueId)
	if Visitor and type(Amount) == "number" then Visitor:ShowCash(Amount) end
end

function MuseumVisitorController.VisitorSay(_, UniqueId, Message)
	local Visitor = GetVisitor(UniqueId)
	if Visitor and type(Message) == "string" then Visitor:Say(Message) end
end

function MuseumVisitorController.RagdollVisitor(_, UniqueId, Knockback)
	local Visitor = GetVisitor(UniqueId)
	if Visitor and typeof(Knockback) == "Vector3" then Visitor:Ragdoll(Knockback) end
end

function MuseumVisitorController.GetOwnHitTargets(HitboxCFrame: CFrame, HitboxSize: Vector3)
	local Targets = {}
	local HalfHitboxSize = HitboxSize / 2
	for UniqueId, Visitor in Visitors do
		local Model = Visitor.Model
		if Visitor.OwnerUserId == game.Players.LocalPlayer.UserId and Model and not Visitor.IsRagdolled then
			local BoundingCFrame, BoundingSize = Model:GetBoundingBox()
			local LocalPosition = HitboxCFrame:PointToObjectSpace(BoundingCFrame.Position)
			local HalfTargetSize = BoundingSize / 2
			if math.abs(LocalPosition.X) <= HalfHitboxSize.X + HalfTargetSize.X
				and math.abs(LocalPosition.Y) <= HalfHitboxSize.Y + HalfTargetSize.Y
				and math.abs(LocalPosition.Z) <= HalfHitboxSize.Z + HalfTargetSize.Z
			then
				table.insert(Targets, { Model = Model, UniqueId = UniqueId })
			end
		end
	end
	return Targets
end

function MuseumVisitorController.FadeVisitor(_, UniqueId, Duration)
	local Visitor = GetVisitor(UniqueId)
	if Visitor and type(Duration) == "number" then Visitor:FadeOut(Duration) end
end

function MuseumVisitorController.DestroyVisitor(_, UniqueId)
	local Visitor = GetVisitor(UniqueId)
	if not Visitor then return end
	Visitors[UniqueId] = nil
	Visitor:Destroy()
end

function MuseumVisitorController.ClearOwner(_, OwnerUserId)
	if type(OwnerUserId) ~= "number" then return end
	for UniqueId, Visitor in Visitors do
		if Visitor.OwnerUserId == OwnerUserId then
			Visitors[UniqueId] = nil
			Visitor:Destroy()
		end
	end
	if OwnerUserId == ViewedOwnerUserId then RequestViewedMuseum(OwnerUserId) end
end

function MuseumVisitorController.ConfirmViewedMuseum(_, OwnerUserId)
	if OwnerUserId == ViewedOwnerUserId then ViewRequestToken += 1 end
end

function MuseumVisitorController.Init()
	Network = Networker.client.new("MuseumVisitorController", MuseumVisitorController)
	MuseumVisitor.SetViewedOwnerChangedHandler(RequestViewedMuseum)
	Network:fire("Ready")
end

return MuseumVisitorController
