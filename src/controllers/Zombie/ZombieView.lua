local Debris = game:GetService("Debris")
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

local function connectRagdollPart(torso: BasePart, part: BasePart)
	local jointPosition = (torso.Position + part.Position) * 0.5
	local torsoAttachment = Instance.new("Attachment")
	torsoAttachment.Name = part.Name .. "RagdollTorsoAttachment"
	torsoAttachment.Position = torso.CFrame:PointToObjectSpace(jointPosition)
	torsoAttachment.Parent = torso
	local partAttachment = Instance.new("Attachment")
	partAttachment.Name = "RagdollAttachment"
	partAttachment.Position = part.CFrame:PointToObjectSpace(jointPosition)
	partAttachment.Parent = part

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = part.Name .. "RagdollSocket"
	socket.Attachment0 = torsoAttachment
	socket.Attachment1 = partAttachment
	socket.LimitsEnabled = true
	socket.UpperAngle = if part.Name == "Head" then 35 else 65
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -40
	socket.TwistUpperAngle = 40
	socket.Parent = torso

	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Name = part.Name .. "RagdollNoCollision"
	noCollision.Part0 = torso
	noCollision.Part1 = part
	noCollision.Parent = torso
end

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
	specialState,
	specialSequence,
	specialStartedAt,
	specialTarget,
	specialValue,
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

	-- Every appearance variant is authored in ReplicatedStorage.Assets.Models.Zombies. Runtime rendering
	-- only clones the exact named model and never manufactures a recolored zombie variant.
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

	local warningMarker = Instance.new("Part")
	warningMarker.Name = "AbilityWarning"
	warningMarker.Shape = Enum.PartType.Cylinder
	warningMarker.Anchored = true
	warningMarker.CanCollide = false
	warningMarker.CanTouch = false
	warningMarker.CanQuery = false
	warningMarker.Material = Enum.Material.Neon
	warningMarker.Color = tintColor or Color3.fromRGB(255, 90, 70)
	warningMarker.Transparency = 1
	warningMarker.Size = Vector3.new(0.12, 2, 2)
	warningMarker.Parent = model

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
		-- BillboardGui supplies the camera-facing orientation. Extra clearance keeps the bar separated
		-- from the zombie silhouette when the gameplay camera compresses vertical depth from above.
		healthBar.StudsOffsetWorldSpace = Vector3.new(0, boundingSize.Y * 0.5 + 1.35, 0)
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
	self.specialState = specialState or ZombieProtocol.SpecialState.None
	self.specialSequence = specialSequence or 0
	self.specialStartedAt = specialStartedAt or 0
	self.specialTarget = if typeof(specialTarget) == "Vector3" then specialTarget else initialCFrame.Position
	self.specialValue = specialValue or 0
	self.warningMarker = warningMarker
	self.armorBroken = typeName ~= "Hardened" or self.specialValue <= 0
	self.healthBar = healthBar
	self.healthFill = healthFill
	self.healthTween = nil
	self.hitHighlight = hitHighlight
	self.hitFlashTween = nil
	self.lastHitDirection = Vector3.zero
	self.lastKnockbackImpulse = 0

	return self
end

function ZombieView:GetRenderCFrame(now)
	local alpha = math.clamp((now - self.interpolationStartedAt) / self.interpolationDuration, 0, 1)
	return self.fromCFrame:Lerp(self.targetCFrame, alpha)
end

function ZombieView:Update(
	targetCFrame,
	state,
	attackSequence,
	attackStartedAt,
	health,
	maximumHealth,
	specialState,
	specialSequence,
	specialStartedAt,
	specialTarget,
	specialValue,
	serverTime,
	receivedAt
)
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
	self.specialState = specialState or ZombieProtocol.SpecialState.None
	self.specialSequence = specialSequence or self.specialSequence
	self.specialStartedAt = specialStartedAt or self.specialStartedAt
	self.specialTarget = if typeof(specialTarget) == "Vector3" then specialTarget else self.specialTarget
	self.specialValue = if type(specialValue) == "number" then specialValue else self.specialValue
	if self.typeName == "Hardened" and not self.armorBroken and self.specialValue <= 0 then
		self.armorBroken = true
		for _, record in self.partRecords do
			if record.part.Transparency < 1 then
				record.part.Material = Enum.Material.SmoothPlastic
				record.part.Color = record.part.Color:Lerp(Color3.fromRGB(82, 74, 68), 0.65)
			end
		end
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
		-- Keep knockback translation exclusively in the server simulation so local hit feedback cannot
		-- visually push a zombie outside its authoritative combat zone between snapshots.
		self.lastHitDirection = knockbackDirection
		self.lastKnockbackImpulse = knockbackImpulse
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
	local SpecialState = ZombieProtocol.SpecialState
	local showWarning = self.specialState == SpecialState.Windup
		or self.specialState == SpecialState.Warning
		or self.specialState == SpecialState.Countdown
	-- A warning can be on-screen even when the burrowed body or ranged caster is not.
	if not self:IsVisible(camera, renderCFrame) and not showWarning then
		return
	end

	local elapsed = (localNow + self.id * 0.173) * self.animationSpeedMultiplier
	local attackElapsed = serverNow - self.attackStartedAt
	local isHidden = self.specialState == SpecialState.Burrowed or self.specialState == SpecialState.Warning
	if isHidden then
		renderCFrame *= CFrame.new(0, -self.boundingSize.Y, 0)
	end
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

	if showWarning then
		local radius = 3
		if self.specialState == SpecialState.Countdown then
			radius = self.definition.Special.Radius or self.definition.Special.SpawnRadius or radius
		elseif self.typeName == "Tank" then
			radius = self.definition.Special.Radius
		elseif type(self.definition.Special.Radius) == "number" then
			radius = self.definition.Special.Radius
		elseif self.specialState == SpecialState.Warning then
			radius = 4
		end
		self.warningMarker.Transparency = 0.3 + math.sin(localNow * 12) * 0.15
		self.warningMarker.Size = Vector3.new(0.12, radius * 2, radius * 2)
		table.insert(parts, self.warningMarker)
		table.insert(cframes, CFrame.new(self.specialTarget + Vector3.yAxis * 0.08) * CFrame.Angles(0, 0, math.pi * 0.5))
	else
		self.warningMarker.Transparency = 1
	end
end

function ZombieView:Ragdoll()
	if self.healthTween then
		self.healthTween:Cancel()
	end
	if self.healthBar then
		self.healthBar.Enabled = false
	end

	local parts = {}
	for _, record in self.partRecords do
		parts[record.name] = record.part
	end
	local torso = parts.Torso
	if not torso then
		self.model:Destroy()
		return
	end

	-- Rendered zombies are segmented anchored models. On authoritative death, convert the visible
	-- pose into a short-lived local physics assembly; this cannot influence server combat state.
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("JointInstance") then
			descendant:Destroy()
		end
	end
	for _, name in { "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = parts[name]
		if part then
			connectRagdollPart(torso, part)
		end
	end
	local root = parts.Root
	if root then
		root:Destroy()
	end
	for name, part in parts do
		if name ~= "Root" and part.Parent then
			part.Anchored = false
			part.CanCollide = true
			part.CanQuery = false
			part.CanTouch = false
		end
	end

	local impulseDirection = self.lastHitDirection
	if impulseDirection.Magnitude < 0.001 then
		impulseDirection = -torso.CFrame.LookVector
	end
	torso.AssemblyLinearVelocity = impulseDirection.Unit * math.clamp(self.lastKnockbackImpulse * 0.7, 5, 14)
		+ Vector3.new(0, 7, 0)
	torso.AssemblyAngularVelocity = Vector3.new(2.5, 1.5, -2)
	Debris:AddItem(self.model, 2.6)
end

function ZombieView:Destroy()
	if self.healthTween then
		self.healthTween:Cancel()
	end
	if self.hitFlashTween then
		self.hitFlashTween:Cancel()
	end
	self.model:Destroy()
end

return ZombieView
