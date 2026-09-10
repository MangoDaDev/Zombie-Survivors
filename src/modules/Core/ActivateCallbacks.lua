local RunService = game:GetService("RunService")

export type Callback = {
	Function: ((...any) -> ())?,
	Arguments: { any }?,
	RunContext: Enum.RunContext?,
}

local function shouldRun(context: Enum.RunContext?): boolean
	if context == Enum.RunContext.Server then
		return RunService:IsServer()
	elseif context == Enum.RunContext.Client then
		return RunService:IsClient()
	end
	return true
end

local function ActivateCallbacks(callbacks: { Callback })
	for _, callback in callbacks do
		if callback.Function and shouldRun(callback.RunContext) then
			task.spawn(callback.Function, table.unpack(callback.Arguments or {}))
		end
	end
end

return ActivateCallbacks
