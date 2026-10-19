--!strict
-- Number formatting for UI, in the K/M/B/T style of simulator games.

local SUFFIXES = {
	{ value = 1e12, suffix = "T" },
	{ value = 1e9, suffix = "B" },
	{ value = 1e6, suffix = "M" },
	{ value = 1e3, suffix = "K" },
}

local Format = {}

-- 950 -> "950", 1500 -> "1.5K", 2000000 -> "2M".
function Format.number(value: number): string
	for _, entry in SUFFIXES do
		if value >= entry.value then
			-- Truncate (not round) to one decimal so 999,999 shows as 999.9K, never 1000K.
			-- Multiply before dividing to keep integer inputs exact.
			local text = string.format("%.1f", math.floor(value * 10 / entry.value) / 10)
			return (text:gsub("%.0$", "")) .. entry.suffix
		end
	end
	return tostring(math.floor(value))
end

return Format
