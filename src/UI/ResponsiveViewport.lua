local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.vide)

return function()
	local size = Vide.source(Vector2.new(1280, 720))
	local viewportConnection: RBXScriptConnection?
	local function bindCamera()
		if viewportConnection then viewportConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then
			local function updateSize()
				size(camera.ViewportSize)
			end
			updateSize()
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateSize)
		end
	end
	bindCamera()
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	Vide.cleanup(function()
		cameraConnection:Disconnect()
		if viewportConnection then viewportConnection:Disconnect() end
	end)
	return size
end
