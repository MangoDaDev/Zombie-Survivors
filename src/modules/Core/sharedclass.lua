local SharedClass = {}
SharedClass.__index = SharedClass

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local IsServer = RunService:IsServer()

local EventsFolder: Folder
local Event: RemoteEvent
local Func: RemoteFunction

if IsServer then
	EventsFolder = Instance.new("Folder", script)
	EventsFolder.Name = "Events"
	Event = Instance.new("RemoteEvent", EventsFolder)
	Func = Instance.new("RemoteFunction", EventsFolder)
else
	EventsFolder = script:WaitForChild("Events")
	Event = EventsFolder:WaitForChild("RemoteEvent")
	Func = EventsFolder:WaitForChild("RemoteFunction")
end

local UpdateStudentProperties = {}
local Students = {}
local ClientClasses = {}

local PendingActions = {}

local function CloneWithoutCycles(Root)
	if type(Root) ~= "table" then
		return Root
	end

	local Seen = {} -- original table -> cloned table
	local InStack = {} -- tables currently being visited (cycle detection)

	local function Clone(t)
		if Seen[t] then
			-- If we are revisiting a table that is still in the call stack,
			-- this is a cycle → remove reference
			if InStack[t] then
				return nil
			end

			-- Non-cyclic shared reference: reuse clone
			return Seen[t]
		end

		local copy = {}
		Seen[t] = copy
		InStack[t] = true

		for k, v in pairs(t) do
			local newKey = k
			local newValue = v

			if type(k) == "table" then
				newKey = Clone(k)
			end

			if type(v) == "table" then
				newValue = Clone(v)
			end

			if newKey ~= nil and newValue ~= nil then
				copy[newKey] = newValue
			end
		end

		InStack[t] = nil
		return copy
	end

	return Clone(Root)
end

if RunService:IsServer() then
	Event.OnServerEvent:Connect(function(plr, UniqueId, Method, ...)
		if UniqueId == true then
			for _, Student in pairs(Students) do
				if Student and Student.SharedClassName then
					local ToSend = CloneWithoutCycles(Student)
					Event:FireClient(plr, true, Student.SharedClassName, ToSend)
					for _, key in pairs(Student.ReplicatedProperties or {}) do
						Event:FireClient(plr, Student.UniqueId, false, key, Student[key])
					end
				end
			end
		else
			local Student = Students[UniqueId]
			if Student then
				local AllowedMethods = Student.AllowedMethods
				local Allowed = AllowedMethods and table.find(AllowedMethods, Method)
				if Student[Method] and Allowed then
					Student[Method](Student, plr, ...)
				elseif not Allowed then
					warn("Method " .. Method .. " Is Not Allowed!")
				else
					warn("Method " .. Method .. " Does not Exist!")
				end
			else
				warn("Student with UniqueId " .. tostring(UniqueId) .. " Does not Exist!")
				warn(debug.traceback(), plr, UniqueId, Method, ...)
			end
		end
	end)

	Func.OnServerInvoke = function(plr, UniqueId, Method, ...)
		local Student = Students[UniqueId]
		if Student then
			local AllowedMethods = Student.AllowedMethods
			local Allowed = AllowedMethods and table.find(AllowedMethods, Method)
			if Student[Method] and Allowed then
				return Student[Method](Student, plr, ...)
			elseif not Allowed then
				warn("Method " .. Method .. " Is Not Allowed!")
				warn(debug.traceback(), plr, UniqueId, Method, ...)
			else
				warn("Method " .. Method .. " Does not Exist!")
				warn(debug.traceback(), plr, UniqueId, Method, ...)
			end
		else
			warn("Student with UniqueId " .. UniqueId .. " Does not Exist!")
			warn(debug.traceback(), plr, UniqueId, Method, ...)
		end
	end
else
	Event.OnClientEvent:Connect(function(UniqueId, Method, ...)
		if UniqueId == true then
			local Args = { ... }
			local ClassName = Method
			local ClassData = CloneWithoutCycles(Args[1])
			while ClientClasses[ClassName] == nil do
				task.wait()
			end
			if ClientClasses[ClassName] and Students[ClassData.UniqueId] == nil then
				if ClassData.UniqueId == nil then
					warn("UniqueId is missing from ClassData. Are your tables not mixed types?")
					warn(debug.traceback(), UniqueId, Method, ...)
				end
				local New = ClientClasses[ClassName].new(ClassData)
				local ClassPendingActions = PendingActions[ClassData.UniqueId]
				task.spawn(function()
					if ClassPendingActions then
						for _, Action in pairs(ClassPendingActions) do
							local Method = Action.Method
							if New[Method] then
								New[Method](New, table.unpack(Action.Args or {}))
							end
						end
						PendingActions[ClassData.UniqueId] = nil
					end
				end)
			end
		else
			local Student = Students[UniqueId]
			if Method ~= false then
				if Student then
					if Student[Method] then
						Student[Method](Student, ...)
					else
						warn("Method " .. Method .. " Does not Exist!")
					end
				else
					if PendingActions[UniqueId] == nil then
						PendingActions[UniqueId] = {}
					end

					table.insert(PendingActions[UniqueId], { Method = Method, Args = { ... } })

					warn(
						"Student with UniqueId "
							.. UniqueId
							.. " Does not Exist!, Added Method "
							.. Method
							.. " To Queue",
						{ ... }
					)
				end
			elseif Student then
				local Args = { ... }
				local UpdateName = Args[1]
				Student[UpdateName] = Args[2]
			end
		end
	end)

	Func.OnClientInvoke = function(UniqueId, Method, ...)
		local Student = Students[UniqueId]
		if Student then
			if Student[Method] then
				return Student[Method](Student, ...)
			else
				warn("Method " .. Method .. " Does not Exist!")
				warn(debug.traceback(), UniqueId, Method, ...)
			end
		else
			if PendingActions[UniqueId] == nil then
				PendingActions[UniqueId] = {}
			end

			table.insert(PendingActions[UniqueId], { Method = Method, Args = { ... } })

			warn("Student with UniqueId " .. UniqueId .. " Does not Exist!, Added Method " .. Method .. " To Queue")
			warn(debug.traceback(), UniqueId, Method, ...)
		end
	end

	Event:FireServer(true)
end

function SharedClass:CleanupConnections(SelfInstance)
	local Proxy = getmetatable(SelfInstance).__proxy
	for i, Connection in pairs(Proxy or self) do
		if typeof(Connection) == "RBXScriptConnection" then
			Connection:Disconnect()
			self[i] = nil
		end
	end
end

function SharedClass:FireServer(Method, ...)
	if not IsServer then
		if self.UniqueId == nil then
			warn("Unique Id is nil!", Method, ..., debug.traceback())
			return
		end
		Event:FireServer(self.UniqueId, Method, ...)
	else
		warn("ClassInstance.FireServer Can only be called from the client!")
	end
end

function SharedClass:InvokeServer(Method, ...)
	if not IsServer then
		if self.UniqueId == nil then
			warn("Unique Id is nil!", Method, ...)
			return
		end
		return Func:InvokeServer(self.UniqueId, Method, ..., debug.traceback())
	else
		warn("ClassInstance.InvokeServer Can only be called from the client!")
	end
end

function SharedClass:FireClient(plr: Player | { Player }, Method, ...)
	if IsServer then
		if self.UniqueId == nil then
			warn("Unique Id is nil!", Method, ..., debug.traceback())
			return
		end
		if type(plr) == "table" then
			for _, Player in plr do
				Event:FireClient(Player, self.UniqueId, Method, ...)
			end
		else
			Event:FireClient(plr, Method, ...)
		end
	else
		warn("ClassInstance.FireClient Can only be called from the server!")
	end
end

function SharedClass:InvokeClient(plr, Method, ...)
	if not IsServer then
		warn("ClassInstance.InvokeClient can only be called from the server!")
		return
	end

	if self.UniqueId == nil then
		warn("Unique Id is nil!", Method, ..., debug.traceback())
		return
	end

	local args = table.pack(...)

	local success, result = pcall(function()
		return Func:InvokeClient(plr, self.UniqueId, Method, table.unpack(args, 1, args.n))
	end)

	if success then
		return result
	else
		warn(result)
	end
end

function SharedClass:FireAllClients(Method, ...)
	if IsServer then
		Event:FireAllClients(self.UniqueId, Method, ...)
	else
		warn("ClassInstance.FireAllClients Can only be called from the server!")
	end
end

function SharedClass:Link(Data, Extra)
	if IsServer then
		if self ~= SharedClass then
			self.UniqueId = self.UniqueId or HttpService:GenerateGUID(false)
			Students[self.UniqueId] = self
			self.SharedClassName = Data.Name
			self.AllowedMethods = Data.AllowedMethods or {}
			self.ReplicatedProperties = Data.ReplicatedProperties or {}
			self.Shared = true
			Event:FireAllClients(true, Data.Name, self)
		end
	else
		if self == SharedClass then
			ClientClasses[Extra.Name] = Data
		elseif self.Shared then
			Students[self.UniqueId] = self
		end
	end

	if self == SharedClass then
		setmetatable(Data, SharedClass)
		if Extra.Utils then
			local Utils
			if type(Extra.Utils) == "table" then
				Utils = Extra.Utils
			elseif typeof(Extra.Utils) == "Instance" and Extra.Utils:IsA("ModuleScript") then
				local Temp: ModuleScript = Extra.Utils
				Utils = require(Temp)
			end
			setmetatable(Data, Utils)
			setmetatable(Utils, SharedClass)
		end
	else
		local OldIndex = self.__index
		local Proxy = {}

		local Metatable = {
			__index = function(_, key)
				local proxyValue = rawget(Proxy, key)

				if proxyValue ~= nil then
					return proxyValue
				end

				if type(OldIndex) == "table" then
					return OldIndex[key]
				elseif type(OldIndex) == "function" then
					return OldIndex(self, key)
				end
			end,

			__newindex = function(self, key, value)
				local old = rawget(Proxy, key) or rawget(self, key)

				if old ~= value then
					rawset(Proxy, key, value)
				end

				if RunService:IsServer() then
					if old ~= value and self.ReplicatedProperties and table.find(self.ReplicatedProperties, key) then
						Event:FireAllClients(self.UniqueId, false, key, value)
					end
				end
			end,

			__proxy = Proxy,
		}

		setmetatable(self, Metatable)

		Proxy.__index = OldIndex
	end
end

function SharedClass:Unlink()
	if self == SharedClass then
		warn("ClassInstance.Unlink Cannot be called on the SharedClass base table!")
		return
	end

	if not self.UniqueId then
		return -- already unlinked, or never linked
	end

	if IsServer then
		Event:FireAllClients(self.UniqueId, "Unlink") -- tell clients to tear down their copy
		Students[self.UniqueId] = nil
		self.UniqueId = nil
	else
		Students[self.UniqueId] = nil
		PendingActions[self.UniqueId] = nil
		self.UniqueId = nil
	end
end

return SharedClass
