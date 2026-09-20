local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local MuseumVisitor = {}
MuseumVisitor.__index = MuseumVisitor

local function GetCurrentCFrame(Visitor, Now: number): CFrame
	if Visitor.MoveTarget == nil then
		return Visitor.CurrentCFrame
	end
	local MoveAlpha = math.clamp((Now - Visitor.MoveStartedAt) / Visitor.MoveDuration, 0, 1)
	local Position = Visitor.MoveStart.Position:Lerp(Visitor.MoveTarget.Position, MoveAlpha)
	local Rotation = if MoveAlpha < 1 then Visitor.MoveRotation else Visitor.MoveTarget.Rotation
	return CFrame.new(Position) * Rotation
end

function MuseumVisitor.new(Data, Replicator)
	local Self = setmetatable(Data, MuseumVisitor)
	Self.UniqueId = HttpService:GenerateGUID(false)
	Self.Replicator = Replicator
	Self.CurrentCFrame = Self.CurrentCFrame or Self.SpawnCFrame
	return Self
end

function MuseumVisitor:StartReplication()
	self:Replicate("CreateVisitor", self:GetSnapshot())
end

function MuseumVisitor:Replicate(Method: string, ...)
	if self.Replicator then self.Replicator(self, Method, ...) end
end

function MuseumVisitor:GetSnapshot()
	local Now = Workspace:GetServerTimeNow()
	local Snapshot = {
		UniqueId = self.UniqueId,
		OwnerUserId = self.OwnerUserId,
		SpawnCFrame = self.SpawnCFrame,
		CurrentCFrame = GetCurrentCFrame(self, Now),
		ShirtTemplate = self.ShirtTemplate,
		PantsTemplate = self.PantsTemplate,
		HairTemplate = self.HairTemplate,
		SkinColor = self.SkinColor,
	}
	if self.MoveTarget then
		Snapshot.MoveTarget = self.MoveTarget
		Snapshot.MoveDuration = math.max(self.MoveDuration - (Now - self.MoveStartedAt), 0.01)
	end
	return Snapshot
end

function MuseumVisitor:MoveTo(TargetCFrame: CFrame, Duration: number)
	local Now = Workspace:GetServerTimeNow()
	local MoveStart = GetCurrentCFrame(self, Now)
	local MoveDirection = TargetCFrame.Position - MoveStart.Position
	local FlatDirection = Vector3.new(MoveDirection.X, 0, MoveDirection.Z)
	self.CurrentCFrame = TargetCFrame
	self.MoveStart = MoveStart
	self.MoveTarget = TargetCFrame
	self.MoveStartedAt = Now
	self.MoveDuration = math.max(Duration, 0.01)
	self.MoveRotation = if FlatDirection.Magnitude > 0.01
		then CFrame.lookAt(Vector3.zero, FlatDirection).Rotation
		else MoveStart.Rotation
	self:Replicate("MoveVisitor", self.UniqueId, TargetCFrame, Duration)
end

function MuseumVisitor:ShowCash(Amount: number)
	self:Replicate("ShowVisitorCash", self.UniqueId, Amount)
end

function MuseumVisitor:Say(Message: string)
	self:Replicate("VisitorSay", self.UniqueId, Message)
end

function MuseumVisitor:GetCurrentCFrame(): CFrame
	return GetCurrentCFrame(self, Workspace:GetServerTimeNow())
end

function MuseumVisitor:Ragdoll(Knockback: Vector3)
	self.CurrentCFrame = GetCurrentCFrame(self, Workspace:GetServerTimeNow())
	self.MoveTarget = nil
	self:Replicate("RagdollVisitor", self.UniqueId, Knockback)
end

function MuseumVisitor:FadeOut(Duration: number)
	self:Replicate("FadeVisitor", self.UniqueId, Duration)
end

function MuseumVisitor:Destroy()
	if self.UniqueId == nil then return end
	self:Replicate("DestroyVisitor", self.UniqueId)
	self.UniqueId = nil
	self.Replicator = nil
end

return MuseumVisitor
