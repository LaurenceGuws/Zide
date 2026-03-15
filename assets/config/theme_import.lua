local M = {}

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_color(value)
	if not value then
		return nil
	end
	local v = trim(value)
	v = v:gsub("^['\"]", ""):gsub("['\"]$", "")
	v = v:gsub("^0[xX]", "")
	if v:match("^#%x%x%x%x%x%x%x?%x?$") then
		return v:lower()
	end
	if v:match("^%x%x%x%x%x%x%x?%x?$") then
		return ("#" .. v:lower())
	end
	return nil
end

local function deep_merge(base, overlay)
	local out = {}
	for k, v in pairs(base or {}) do
		if type(v) == "table" then
			out[k] = deep_merge(v, {})
		else
			out[k] = v
		end
	end
	for k, v in pairs(overlay or {}) do
		if type(v) == "table" and type(out[k]) == "table" then
			out[k] = deep_merge(out[k], v)
		else
			out[k] = v
		end
	end
	return out
end

local ansi_name_to_index = {
	black = 0,
	red = 1,
	green = 2,
	yellow = 3,
	blue = 4,
	magenta = 5,
	cyan = 6,
	white = 7,
	bright_black = 8,
	bright_red = 9,
	bright_green = 10,
	bright_yellow = 11,
	bright_blue = 12,
	bright_magenta = 13,
	bright_cyan = 14,
	bright_white = 15,
}

local function set_palette_color(palette, key, raw_value)
	local k = key:lower()
	k = k:gsub("%-", "_")
	local color = normalize_color(raw_value)
	if not color then
		return
	end

	if k == "selection_background" then
		palette.selection = color
		return
	end
	if k == "cursor_color" then
		palette.cursor = color
		return
	end
	if k == "url_color" then
		palette.link = color
		return
	end
	if k == "tab_bar_background" then
		palette.ui_bar_bg = color
		return
	end
	if k == "active_tab_background" then
		palette.ui_accent = color
		return
	end
	if k == "active_tab_foreground" then
		palette.ui_text = color
		return
	end
	if k == "inactive_tab_background" then
		palette.ui_tab_inactive_bg = color
		return
	end
	if k == "inactive_tab_foreground" then
		palette.ui_text_inactive = color
		return
	end
	if k == "active_border_color" then
		palette.ui_border = color
		return
	end
	if k == "background" or k == "foreground" or k == "cursor" or k == "selection" then
		palette[k] = color
		return
	end

	local color_n = k:match("^color(%d+)$")
	if color_n then
		local idx = tonumber(color_n)
		if idx and idx >= 0 and idx <= 15 then
			palette["color" .. idx] = color
		end
		return
	end

	local named_idx = ansi_name_to_index[k]
	if named_idx ~= nil then
		palette["color" .. named_idx] = color
	end
end

local function read_lines(path)
	local f = assert(io.open(path, "r"), ("failed to open theme file: %s"):format(path))
	local lines = {}
	for line in f:lines() do
		lines[#lines + 1] = line
	end
	f:close()
	return lines
end

function M.from_kitty(path)
	local palette = {}
	for _, line in ipairs(read_lines(path)) do
		if not line:match("^%s*#") then
			local key, value = line:match("^%s*([%w%._%-]+)%s+(.+)$")
			if key and value then
				set_palette_color(palette, key, value)
			end
		end
	end
	return { palette = palette }
end

function M.from_ghostty(path)
	local palette = {}
	for _, line in ipairs(read_lines(path)) do
		if not line:match("^%s*#") then
			local key, value = line:match("^%s*([%w%._%-]+)%s*=%s*(.+)$")
			if key and value then
				local key_norm = key:lower():gsub("%-", "_")
				if key_norm == "palette" then
					local idx, color = value:match("^%s*(%d+)%s*=%s*([^%s]+)%s*$")
					if idx and color then
						set_palette_color(palette, "color" .. idx, color)
					end
				else
					set_palette_color(palette, key_norm, value)
				end
			end
		end
	end
	return { palette = palette }
end

function M.merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		out = deep_merge(out, select(i, ...))
	end
	return out
end

return M
