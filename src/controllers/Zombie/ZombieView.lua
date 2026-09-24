local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	health,
	maximumHealth,
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

	local anchorPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local healthBar
	local healthFill
	if anchorPart then
		healthBar = Instance.new("BillboardGui")
		healthBar.Name = "HealthBar"
		healthBar.Adornee = anchorPart
		healthBar.AlwaysOnTop = true
		healthBar.LightInfluence = 0
		healthBar.MaxDistance = 90
		healthBar.Size = UDim2.fromOffset(76, 11)
		healthBar.StudsOffsetWorldSpace = Vector3.new(0, boundingSize.Y * 0.5 + 0.85, 0)
		healthBar.Parent = model

		local backing = Instance.new("Frame")
		backing.Name = "Backing"
		backing.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
		backing.BorderSizePixel = 0
		backing.Size = UDim2.fromScale(1, 1)
		backing.Parent = healthBar
		local backingCorner = Instance.new("UICorner")
		backingCorner.CornerRadius = UDim.new(1, 0)
		backingCorner.Parent = backing
		local backingStroke = Instance.new("UIStroke")
		backingStroke.Color = Color3.fromRGB(8, 10, 14)
		backingStroke.Thickness = 2
		backingStroke.Parent = backing

		healthFill = Instance.new("Frame")
		healthFill.Name = "Fill"
		healthFill.BackgroundColor3 = Color3.fromRGB(82, 226, 108)
		healthFill.BorderSizePixel = 0
		healthFill.Size = UDim2.fromScale(1, 1)
		healthFill.Parent = backing
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = healthFill
	end

	local hitHighlight = Instance.new("Highlight")
	hitHighlight.Name = "DamageFlash"
	hitHighlight.Adornee = model
	hitHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	hitHighlight.FillColor = Color3.new(1, 1, 1)
	hitHighlight.FillTransparency = 1
	hitHighlight.OutlineColor = Color3.new(1, 1, 1)
	hitHighlight.OutlineTransparency = 1
	hitHighlight.Parent = model

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
	self.health = if type(health) == "number" then health else definition.MaxHealth
	self.maximumHealth = if type(maximumHealth) == "number" then maximumHealth else definition.MaxHealth
	self.healthBar = healthBar
	self.healthFill = healthFill
	self.healthTween = nil
	self.hitHighlight = hitHighlight
	self.hitFlashTween = nil
	self.recoilOffset = Vector3.zero
	self.lastRenderAt = os.clock()

	return self
end

function ZombieView:GetRenderCFrame(now)
	local alpha = math.clamp((now - self.interpolationStartedAt) / self.interpolationDuration, 0, 1)
	return self.fromCFrame:Lerp(self.targetCFrame, alpha)
end

function ZombieView:Update(targetCFrame, state, attackSequence, attackStartedAt, health, maximumHealth, serverTime, receivedAt)
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
	self:SetHealth(health, maximumHealth, false)
end

function ZombieView:SetHealth(health, maximumHealth, animate: boolean)
	if type(health) ~= "number" or type(maximumHealth) ~= "number" or maximumHealth <= 0 then
		return
	end
	self.health = math.clamp(health, 0, maximumHealth)
	self.maximumHealth = maximumHealth
	if not self.healthFill then
		return
	end

	local ratio = self.health / maximumHealth
	local goal = {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = if ratio > 0.55
			then Color3.fromRGB(82, 226, 108)
			elseif ratio > 0.25 then Color3.fromRGB(255, 190, 54)
			else Color3.fromRGB(255, 76, 76),
	}
	if self.healthTween then
		self.healthTween:Cancel()
	end
	if animate then
		self.healthTween = TweenService:Create(
			self.healthFill,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		self.healthTween:Play()
	else
		self.healthFill.Size = goal.Size
		self.healthFill.BackgroundColor3 = goal.BackgroundColor3
	end
end

function ZombieView:ApplyDamage(health, maximumHealth, knockbackDirection, knockbackImpulse)
	self:SetHealth(health, maximumHealth, true)
	if self.hitFlashTween then
		self.hitFlashTween:Cancel()
	end
	self.hitHighlight.FillTransparency = 0.08
	self.hitHighlight.OutlineTransparency = 0.12
	self.hitFlashTween = TweenService:Create(
		self.hitHighlight,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	)
	self.hitFlashTween:Play()

	if typeof(knockbackDirection) == "Vector3" and type(knockbackImpulse) == "number" then
		-- Immediate client recoil bridges the short interval before the authoritative knockback snapshot arrives.
		self.recoilOffset += knockbackDirection * math.clamp(knockbackImpulse * 0.055, 0, 1.15)
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
	local renderDelta = math.clamp(localNow - self.lastRenderAt, 0, 0.1)
	self.lastRenderAt = localNow
	self.recoilOffset *= math.exp(-15 * renderDelta)
	renderCFrame += self.recoilOffset
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

function ZombieView:Destroy(delayDuration: number?)
	if self.healthTween then
		self.healthTween:Cancel()
	end
	if delayDuration and delayDuration > 0 then
		task.delay(delayDuration, function()
			self.model:Destroy()
		end)
		return
	end
	if self.hitFlashTween then
		self.hitFlashTween:Cancel()
	end
	self.model:Destroy()
end

return ZombieView
