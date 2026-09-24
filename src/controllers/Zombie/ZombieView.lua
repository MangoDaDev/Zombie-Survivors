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

function ZombieView.new(
	id,
	typeName,
	definition,
	template,
	initialCFrame,
	state,
	attackSequence,
	attackStartedAt,
	scale,
	animationSpeedMultiplier,
	serverTime,
	parent
)
	local model = template:Clone()
	scale = if type(scale) == "number" then scale else 1
	animationSpeedMultiplier = if type(animationSpeedMultiplier) == "number" then animationSpeedMultiplier else 1
	-- Model:ScaleTo preserves the entire rig's proportions; individual parts are never distorted.
	model:ScaleTo(math.clamp(scale, 0.5, 2))
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
	self.attackStartedAt = if type(attackStartedAt) == "number" then attackStartedAt else -math.huge
	self.animationSpeedMultiplier = math.clamp(animationSpeedMultiplier, 0.5, 2)

	return self
end

function ZombieView:GetRenderCFrame(now)
	local alpha = math.clamp((now - self.interpolationStartedAt) / self.interpolationDuration, 0, 1)
	return self.fromCFrame:Lerp(self.targetCFrame, alpha)
end

function ZombieView:Update(targetCFrame, state, attackSequence, attackStartedAt, serverTime, receivedAt)
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
	end
	if type(attackStartedAt) == "number" then
		self.attackStartedAt = attackStartedAt
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

function ZombieView:AppendRender(parts, cframes, camera, localNow, serverNow)
	local renderCFrame = self:GetRenderCFrame(localNow)
	if not self:IsVisible(camera, renderCFrame) then
		return
	end

	local elapsed = (localNow + self.id * 0.173) * self.animationSpeedMultiplier
	local attackElapsed = serverNow - self.attackStartedAt
	for _, record in self.partRecords do
		local animationOffset = ProceduralAnimator.GetPartOffset(
			self.definition,
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
