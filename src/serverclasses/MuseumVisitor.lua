local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedClass = require(ReplicatedStorage.Modules.Core.SharedClass)

local CLASS_INFO = {
	Name = "MuseumVisitor",
	AllowedMethods = {},
}

local MuseumVisitor = {}
MuseumVisitor.__index = MuseumVisitor

function MuseumVisitor.new(data)
	local self = setmetatable(data, MuseumVisitor)
	self:Link(CLASS_INFO)
	return self
end

function MuseumVisitor:MoveTo(targetCFrame: CFrame, duration: number)
	rawset(self, "CurrentCFrame", targetCFrame)
	self:FireAllClients("MoveTo", targetCFrame, duration)
end

function MuseumVisitor:ShowCash(amount: number)
	self:FireAllClients("ShowCash", amount)
end

function MuseumVisitor:Say(message: string)
	self:FireAllClients("Say", message)
end

function MuseumVisitor:FadeOut(duration: number)
	self:FireAllClients("FadeOut", duration)
end

function MuseumVisitor:Destroy()
	if self.UniqueId == nil then
		return
	end
	self:FireAllClients("Destroy")
	self:Unlink()
end

SharedClass:Link(MuseumVisitor, CLASS_INFO)

return MuseumVisitor
