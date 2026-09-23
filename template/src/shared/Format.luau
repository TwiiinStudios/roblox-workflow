--[[
	Pure helpers for showing numbers to players. No Roblox APIs here, so it can be unit tested
	with `lune run tools/test.luau`.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1500 -> "1.5K", 2000000 -> "2M", 999 -> "999"
function Format.abbreviate(n: number): string
	local negative = n < 0
	n = math.abs(n)

	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end

	local text
	if index == 1 then
		text = tostring(math.floor(n))
	else
		text = string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", "")
	end

	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

return Format
