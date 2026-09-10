local SUFFIXES = {
	{ value = 1e33, symbol = "D" },
	{ value = 1e30, symbol = "N" },
	{ value = 1e27, symbol = "Oc" },
	{ value = 1e24, symbol = "Sp" },
	{ value = 1e21, symbol = "Sx" },
	{ value = 1e18, symbol = "QT" },
	{ value = 1e15, symbol = "QD" },
	{ value = 1e12, symbol = "T" },
	{ value = 1e9, symbol = "B" },
	{ value = 1e6, symbol = "M" },
	{ value = 1e3, symbol = "K" },
}

local function trimZeros(value: number): string
	local formatted = string.format("%.2f", value)
	local trimmed = formatted:gsub("%.?0+$", "")
	return trimmed
end

local function FormatNumber(value: number | string): string?
	local number = tonumber(value)
	if number == nil then
		return nil
	end

	local sign = if number < 0 then "-" else ""
	number = math.abs(number)

	if number < 1000 then
		return sign .. trimZeros(math.floor(number * 100) / 100)
	end

	if number >= 1e36 then
		return sign .. string.format("%.2e", number)
	end

	for _, suffix in SUFFIXES do
		if number >= suffix.value then
			return sign .. trimZeros(number / suffix.value) .. suffix.symbol
		end
	end

	return sign .. trimZeros(number)
end

return FormatNumber
