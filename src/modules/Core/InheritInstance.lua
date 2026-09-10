local function InheritInstance(instance: { [any]: any }, baseClass: { [any]: any })
	local previousMetatable = getmetatable(instance)
	local previousIndex = if type(previousMetatable) == "table" then previousMetatable.__index else nil
	local inheritedMetatable = if type(previousMetatable) == "table" then table.clone(previousMetatable) else {}

	inheritedMetatable.__index = function(self, key)
		local value
		if type(previousIndex) == "function" then
			value = previousIndex(self, key)
		elseif type(previousIndex) == "table" then
			value = previousIndex[key]
		end

		if value ~= nil then
			return value
		end
		return baseClass[key]
	end

	setmetatable(instance, inheritedMetatable)

	return instance
end

return InheritInstance
