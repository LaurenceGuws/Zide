-- Zide default config reference (loaded as system defaults).
-- This file doubles as documentation; values here are active defaults.
-- Copy it to ~/.config/zide/init.lua or ./.zide.lua to customize.
---@diagnostic disable: undefined-global
local mod
do
	local ok, loaded = pcall(require, "zide-meta")
	if ok and type(loaded) == "table" then
		mod = loaded
	end
end
---@type ZideModule
local zide
if mod then
	zide = mod
else
	zide = {
		config = function(opts)
			return opts
		end,
	}
end

local function current_dir()
	local src = debug.getinfo(1, "S").source
	if type(src) == "string" and src:sub(1, 1) == "@" then
		local path = src:sub(2)
		return path:match("^(.*[/\\])") or "./"
	end
	return "./"
end

local function load_relative(path)
	return dofile(current_dir() .. path)
end

local function merge_into(dst, src)
	for k, v in pairs(src) do
		dst[k] = v
	end
	return dst
end

local function merge_many(...)
	local merged = {}
	for i = 1, select("#", ...) do
		merge_into(merged, select(i, ...))
	end
	return merged
end

local ctx = load_relative("defaults/context.lua").build(load_relative)
local logging_defaults = load_relative("defaults/logging.lua")
local theme_defaults = {
	-- Theme configuration.
	-- Colors accept hex strings (#RRGGBB or #RRGGBBAA) or tables { r = 0, g = 0, b = 0, a = 255 }.
	-- Optional importer helper:
	--   local theme_import = dofile("assets/config/theme_import.lua")
	--   local ghostty_theme = theme_import.from_ghostty("/path/to/ghostty/theme")
	--   local kitty_theme = theme_import.from_kitty("/path/to/kitty.conf")
	--   theme = theme_import.merge(ghostty_theme, { syntax = { comment = "#6f7a94" } })
	theme = load_relative("defaults/theme.lua")(ctx),
}
local app_defaults = load_relative("defaults/app.lua")(ctx)
local font_rendering_defaults = load_relative("defaults/font_rendering.lua")(ctx)
local selection_overlay_defaults = load_relative("defaults/selection_overlay.lua")
local editor_defaults = load_relative("defaults/editor.lua")(ctx)
local terminal_defaults = load_relative("defaults/terminal.lua")(ctx)
local keybind_defaults = load_relative("defaults/keybinds.lua")

---@type ZideConfig
return zide.config(merge_many(
	logging_defaults,
	theme_defaults,
	app_defaults,
	font_rendering_defaults,
	selection_overlay_defaults,
	editor_defaults,
	terminal_defaults,
	keybind_defaults
))
