local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HoverExpand = require(ReplicatedStorage.UI.Effects.HoverExpand)

local Notification = {}
Notification.__index = Notification

local BASE_COLOR = Color3.fromRGB(255, 0, 0)
local ATTENTION_COLOR = Color3.fromRGB(255, 170, 170)

local function CreateGui(Text: string): TextLabel
	local Gui = Instance.new("TextLabel")
	Gui.Name = Text
	Gui.Active = true
	Gui.AnchorPoint = Vector2.new(0.5, 0.5)
	Gui.BackgroundColor3 = BASE_COLOR
	Gui.BorderSizePixel = 0
	Gui.Position = UDim2.fromScale(0.88, 0.12)
	Gui.Size = UDim2.fromOffset(30, 30)
	Gui.Text = ""
	Gui.TextScaled = true
	Gui.Visible = false
	Gui.ZIndex = 40

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(1, 0)
	Corner.Parent = Gui

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.new(1, 1, 1)
	Stroke.Thickness = 2
	Stroke.Parent = Gui

	local Amount = Instance.new("TextLabel")
	Amount.Name = "Amount"
	Amount.BackgroundTransparency = 1
	Amount.Font = Enum.Font.GothamBold
	Amount.Size = UDim2.fromScale(1, 1)
	Amount.Text = ""
	Amount.TextColor3 = Color3.new(1, 1, 1)
	Amount.TextScaled = true
	Amount.ZIndex = 41
	Amount.Parent = Gui

	local TextConstraint = Instance.new("UITextSizeConstraint")
	TextConstraint.MaxTextSize = 18
	TextConstraint.MinTextSize = 8
	TextConstraint.Parent = Amount

	return Gui
end

function Notification:UpdateAttentionAnimation()
	if self.AnimationThread then
		task.cancel(self.AnimationThread)
		self.AnimationThread = nil
	end

	if not self.Gui.Visible then
		self.Gui.Rotation = 0
		self.Gui.Size = self.BaseSize
		return
	end

	self.Gui.Size = self.BaseSize
	self.Gui.Rotation = 0
	self.Gui.BackgroundColor3 = BASE_COLOR
	self.AnimationThread = task.spawn(function()
		while self.Gui.Parent and self.Gui.Visible do
			local Time = 0
			while Time < 0.8 and self.Gui.Parent and self.Gui.Visible do
				local DeltaTime = task.wait()
				Time += DeltaTime
				local Progress = Time / 0.8
				local Fade = 1 - Progress
				local Scale = 1 + math.abs(math.sin(Time * 22)) * Fade
				self.Gui.Rotation = math.sin(Time * 45) * 10 * Fade
				self.Gui.Size = UDim2.new(
					self.BaseSize.X.Scale * Scale,
					self.BaseSize.X.Offset * Scale,
					self.BaseSize.Y.Scale * Scale,
					self.BaseSize.Y.Offset * Scale
				)
				local Intensity = math.clamp((Scale - 1) / 0.4, 0, 1) * Fade
				self.Gui.BackgroundColor3 = BASE_COLOR:Lerp(ATTENTION_COLOR, Intensity)
			end

			local Tween = TweenService:Create(self.Gui, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = self.BaseSize,
				Rotation = 0,
				BackgroundColor3 = BASE_COLOR,
			})
			Tween:Play()
			Tween.Completed:Wait()
			if self.Gui.Parent and self.Gui.Visible then task.wait(1) end
		end
		self.AnimationThread = nil
		if self.Gui.Parent then
			self.Gui.Rotation = 0
			self.Gui.Size = self.BaseSize
			self.Gui.BackgroundColor3 = BASE_COLOR
		end
	end)
end

function Notification.new(Text: string, Parent: Instance)
	local Self = setmetatable({}, Notification)
	Self.Gui = CreateGui(Text)
	Self.Gui.Parent = Parent
	Self.BaseSize = Self.Gui.Size
	Self.AnimationThread = nil
	Self.ButtonEffect = HoverExpand.new(Self.Gui)
	Self:SetAmount(0)
	return Self
end

function Notification:SetAmount(Amount: number)
	if self.Amount == Amount then return end
	self.Amount = Amount
	local IsVisible = Amount > 0
	self.Gui.Visible = IsVisible
	if IsVisible then
		self.Gui.Amount.Text = tostring(Amount)
	end
	self:UpdateAttentionAnimation()
end

function Notification:Destroy()
	if self.AnimationThread then
		task.cancel(self.AnimationThread)
		self.AnimationThread = nil
	end
	self.ButtonEffect:Destroy()
	self.Gui:Destroy()
end

return Notification
