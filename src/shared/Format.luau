--!strict
-- Skracanie duzych liczb. Gatunek "+1" bardzo szybko wchodzi w miliardy,
-- wiec HUD musi to znosic bez rozjezdzania sie.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(value: number): string
	if value ~= value or value == math.huge then
		return "∞"
	end

	local sign = if value < 0 then "-" else ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end

	local tier = math.floor(math.log(value, 1000))
	tier = math.clamp(tier, 1, #SUFFIXES - 1)

	local scaled = value / 1000 ^ tier
	local suffix = SUFFIXES[tier + 1]

	if scaled < 10 then
		return string.format("%s%.2f%s", sign, scaled, suffix)
	elseif scaled < 100 then
		return string.format("%s%.1f%s", sign, scaled, suffix)
	end
	return string.format("%s%d%s", sign, math.floor(scaled), suffix)
end

function Format.time(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60

	if hours > 0 then
		return string.format("%dh %dmin", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dmin", minutes)
	end
	return string.format("%ds", seconds)
end

return Format
