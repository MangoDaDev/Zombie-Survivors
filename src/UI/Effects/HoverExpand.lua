local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MultiplyUDim2 = require(ReplicatedStorage.Modules.Math.MultiplyUDim2)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)

local HoverExpand = {}
HoverExpand.__index = HoverExpand

function HoverExpand.new(Button: GuiObject, Percentage: number?, SFXOn: boolean?)
	local Self = setmetatable({}, HoverExpand)
	Self.Button = Button
	Self.Percentage = Percentage or 1.05
	Self.SFXOn = SFXOn ~= false
	Self.BaseSize = Button.Size
	Self.ExpandedSize = MultiplyUDim2(Self.BaseSize, Self.Percentage)
	Self.Enabled = true
	Self.Destroyed = false
	Self.Connections = {}

	table.insert(Self.Connections, Button.MouseEnter:Connect(function()
		if not Self.Enabled or Self.Destroyed then return end
		if Self.SFXOn then Sounds.Play("HoverStart", Button) end
		TweenService:Create(Button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Size = Self.ExpandedSize,
		}):Play()
	end))
	table.insert(Self.Connections, Button.MouseLeave:Connect(function()
		if Self.Destroyed then return end
		TweenService:Create(Button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Size = Self.BaseSize,
		}):Play()
	end))

	return Self
end

function HoverExpand:SetPercentage(Percentage: number)
	self.Percentage = Percentage
	self.ExpandedSize = MultiplyUDim2(self.BaseSize, Percentage)
end

function HoverExpand:SetBaseSize(Size: UDim2)
	self.BaseSize = Size
	self.ExpandedSize = MultiplyUDim2(Size, self.Percentage)
end

function HoverExpand:Refresh()
	self:SetBaseSize(self.Button.Size)
end

function HoverExpand:Enable()
	self.Enabled = true
end

function HoverExpand:Disable()
	self.Enabled = false
	self.Button.Size = self.BaseSize
end

function HoverExpand:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, Connection in self.Connections do
		Connection:Disconnect()
	end
	table.clear(self.Connections)
end

return HoverExpand
