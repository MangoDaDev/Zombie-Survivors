local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieProtocol = require(ReplicatedStorage.Modules.Game.Zombies.ZombieProtocol)
local ProceduralAnimator = require(script.Parent.ProceduralAnimator)

local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

local ZombieView = {}
ZombieView.__index = ZombieView

function ZombieView.new(id, typeName, definition, template, initialCFrame, state, attackSequence, serverTime, parent)
	local model = template:Clone()
	local templatePivot = model:GetPivot()
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local partRecords = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Client zombies are anchored visuals only and can never collide, touch, or
			-- participate in queries against players or other rendered zombies.
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			table.insert(partRecords, {
				part = descendant,
				name = descendant.Name,
				localCFrame = templatePivot:ToObjectSpace(descendant.CFrame),
				animationPivot = ProceduralAnimator.GetPartPivotOffset(descendant.Name, descendant.Size),
			})
		end
	end

	model.Name = string.format("%s_%d", typeName, id)
	model:PivotTo(initialCFrame)
	model.Parent = parent

	local self = setmetatable({}, ZombieView)
	self.id = id
	self.typeName = typeName
	self.definition = definition
	self.model = model
	self.partRecords = partRecords
	self.boundingLocalCFrame = templatePivot:ToObjectSpace(boundingCFrame)
	self.boundingSize = boundingSize
	self.fromCFrame = initialCFrame
	self.targetCFrame = initialCFrame
	self.interpolationStartedAt = os.clock()
	self.interpolationDuration = ZombieProtocol.SnapshotInterval
	self.lastServerTime = serverTime
	self.state = state
	self.attackSequence = attackSequence
	self.attackStartedAt = -math.huge

	return self
end

function ZombieView:GetRenderCFrame(now)
	local alpha = math.clamp((now - self.interpolationStartedAt) / self.interpolationDuration, 0, 1)
	return self.fromCFrame:Lerp(self.targetCFrame, alpha)
end

function ZombieView:Update(targetCFrame, state, attackSequence, serverTime, receivedAt)
	self.fromCFrame = self:GetRenderCFrame(receivedAt)
	self.targetCFrame = targetCFrame
	self.interpolationStartedAt = receivedAt

	if type(serverTime) == "number" and type(self.lastServerTime) == "number" then
		-- Derive the smoothing window from server snapshots instead of networking velocity.
		self.interpolationDuration = math.clamp(serverTime - self.lastServerTime, 0.05, 0.5)
	else
		self.interpolationDuration = ZombieProtocol.SnapshotInterval
	end
	self.lastServerTime = serverTime
	self.state = state

	if type(attackSequence) == "number" and attackSequence ~= self.attackSequence then
		self.attackSequence = attackSequence
		self.attackStartedAt = receivedAt
	end
end

function ZombieView:IsVisible(camera, renderCFrame)
	local boxCFrame = renderCFrame * self.boundingLocalCFrame
	local halfSize = self.boundingSize * 0.5

	-- The requested visibility rule is deliberately exact: normal visual updates
	-- stop only when every one of the bounding box's eight corners is off-screen.
	for _, sign in CORNER_SIGNS do
		local corner = boxCFrame:PointToWorldSpace(halfSize * sign)
		local _, onScreen = camera:WorldToViewportPoint(corner)
		if onScreen then
			return true
		end
	end

	return false
end

function ZombieView:AppendRender(parts, cframes, camera, now)
	local renderCFrame = self:GetRenderCFrame(now)
	if not self:IsVisible(camera, renderCFrame) then
		return
	end

	local elapsed = now + self.id * 0.173
	local attackElapsed = now - self.attackStartedAt
	for _, record in self.partRecords do
		local animationOffset = ProceduralAnimator.GetPartOffset(
			self.definition.AnimationStyle,
			record.name,
			record.animationPivot,
			self.state,
			elapsed,
			attackElapsed
		)
		table.insert(parts, record.part)
		table.insert(cframes, renderCFrame * record.localCFrame * animationOffset)
	end
end

function ZombieView:Destroy()
	self.model:Destroy()
end

return ZombieView
