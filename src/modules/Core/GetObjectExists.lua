local function GetObjectExists(object: unknown): boolean
	return typeof(object) == "Instance" and (object :: Instance).Parent ~= nil
end

return GetObjectExists
