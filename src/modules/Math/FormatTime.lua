local function FormatTime(seconds: number): string
	local remaining = math.max(math.floor(seconds + 0.5), 0)
	local years = math.floor(remaining / 31_536_000)
	remaining %= 31_536_000
	local days = math.floor(remaining / 86_400)
	remaining %= 86_400
	local hours = math.floor(remaining / 3_600)
	remaining %= 3_600
	local minutes = math.floor(remaining / 60)
	local finalSeconds = remaining % 60

	local parts = {}
	local function addPart(value: number)
		table.insert(parts, if #parts == 0 then tostring(value) else string.format("%02d", value))
	end

	if years > 0 then
		addPart(years)
	end
	if days > 0 or #parts > 0 then
		addPart(days)
	end
	if hours > 0 or #parts > 0 then
		addPart(hours)
	end
	addPart(minutes)
	addPart(finalSeconds)

	return table.concat(parts, ":")
end

return FormatTime
