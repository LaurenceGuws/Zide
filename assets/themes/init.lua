local M = {}

local available = {
	["ayu"] = "assets/themes/ayu.lua",
	["kanagawa-dragon"] = "assets/themes/kanagawa-dragon.lua",
	["tokyonight-night"] = "assets/themes/tokyonight-night.lua",
}

function M.available()
	return available
end

function M.load(name)
	local path = available[name]
	assert(path, ("unknown imported theme: %s"):format(tostring(name)))
	return dofile(path)
end

return M
