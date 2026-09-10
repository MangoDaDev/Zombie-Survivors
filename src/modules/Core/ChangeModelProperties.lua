local function applyProperties(instance: Instance, properties: { [string]: any })
	for property, value in properties do
		-- Failure is expected when a heterogeneous hierarchy does not expose a property.
		pcall(function()
			(instance :: any)[property] = value
		end)
	end
end

local function ChangeModelProperties(root: Instance, properties: { [string]: any }, className: string?)
	if className == nil or root:IsA(className) then
		applyProperties(root, properties)
	end

	for _, descendant in root:GetDescendants() do
		if className == nil or descendant:IsA(className) then
			applyProperties(descendant, properties)
		end
	end
end

return ChangeModelProperties
