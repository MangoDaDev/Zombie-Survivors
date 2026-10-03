-- Presentation-only prediction. Never write these snapshots into DataService or use them as authority.
local ClientActionState = {}
ClientActionState.__index = ClientActionState

function ClientActionState.new(initialState, onChanged)
	return setmetatable({
		state = initialState,
		onChanged = onChanged,
		nextRequestId = 0,
		pending = nil,
	}, ClientActionState)
end

function ClientActionState:Get()
	return if self.pending then self.pending.transform(self.state) else self.state
end

function ClientActionState:Apply(packet, settlePending: boolean?)
	-- Revisions also protect asynchronous startup snapshots from overwriting newer push events.
	if type(packet.revision) ~= "number" or packet.revision % 1 ~= 0
		or packet.revision < 0 or packet.revision <= (self.state.revision or -1) then
		return
	end
	if settlePending then
		self.pending = nil
		if self.timeoutThread then
			task.cancel(self.timeoutThread)
			self.timeoutThread = nil
		end
	end
	self.state = packet
	self.onChanged(self:Get())
end

function ClientActionState:Begin(transform): number?
	if self.pending then
		return nil
	end
	self.nextRequestId += 1
	local requestId = self.nextRequestId
	self.pending = { id = requestId, transform = transform }
	self.onChanged(self:Get())
	-- A disconnected or lost request must not leave a control permanently disabled.
	self.timeoutThread = task.delay(8, function()
		if self.pending and self.pending.id == requestId then
			self.timeoutThread = nil
			self.pending = nil
			self.onChanged(self:Get())
		end
	end)
	return requestId
end

function ClientActionState:Resolve(requestId, packet)
	if not self.pending or self.pending.id ~= requestId then
		-- A timed-out response may still contain newer authoritative state, but cannot clear a later intent.
		self:Apply(packet)
		return
	end
	self.pending = nil
	if self.timeoutThread then
		task.cancel(self.timeoutThread)
		self.timeoutThread = nil
	end
	if packet.revision > (self.state.revision or -1) then
		self.state = packet
	end
	self.onChanged(self:Get())
end

return ClientActionState
