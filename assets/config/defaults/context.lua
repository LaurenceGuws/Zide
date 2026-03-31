local M = {}

local function file_exists(path)
	local f = io.open(path, "r")
	if f ~= nil then
		f:close()
		return true
	end
	return false
end

function M.build(load_relative)
	local is_windows = package.config:sub(1, 1) == "\\"
	local home = os.getenv("HOME") or ""
	local userprofile = os.getenv("USERPROFILE") or home
	local kitty_theme = nil
	local theme_import_ok, theme_import = pcall(load_relative, "theme_import.lua")

	if theme_import_ok and type(theme_import) == "table" and type(theme_import.from_kitty) == "function" then
		local kitty_theme_path = home .. "/.config/kitty/current-theme.conf"
		local import_ok, imported_theme = pcall(theme_import.from_kitty, kitty_theme_path)
		if import_ok and type(imported_theme) == "table" then
			kitty_theme = imported_theme
		end
	end

	local jetbrains_font_path = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf"
	local iosevka_font_path = "assets/fonts/IosevkaTermNerdFont-Regular.ttf"

	local app_font_path = jetbrains_font_path
	if file_exists(iosevka_font_path) then
		app_font_path = iosevka_font_path
	end

	local editor_font_path = app_font_path
	if file_exists(iosevka_font_path) then
		editor_font_path = jetbrains_font_path
	end

	local terminal_font_path = app_font_path
	if file_exists(iosevka_font_path) then
		terminal_font_path = iosevka_font_path
	end

	local terminal_shell_path = nil
	if is_windows then
		local pwsh7_path = "C:/Program Files/PowerShell/7/pwsh.exe"
		if file_exists(pwsh7_path) then
			terminal_shell_path = pwsh7_path
		end
	end

	local terminal_default_start_location = home
	if is_windows then
		terminal_default_start_location = userprofile
	end

	return {
		is_windows = is_windows,
		home = home,
		userprofile = userprofile,
		kitty_theme = kitty_theme,
		app_font_path = app_font_path,
		editor_font_path = editor_font_path,
		terminal_font_path = terminal_font_path,
		terminal_shell_path = terminal_shell_path,
		terminal_default_start_location = terminal_default_start_location,
	}
end

return M
