local M = {}

local available = {
	["ayu"] = "assets/themes/ayu.lua",
	["catppuccin-mocha"] = "assets/themes/generated/catppuccin-mocha.overlay.lua",
	["everforest-dark"] = "assets/themes/generated/everforest-dark.overlay.lua",
	["gruvbox-dark"] = "assets/themes/generated/gruvbox-dark.overlay.lua",
	["jellybeans-dark"] = "assets/themes/generated/jellybeans-dark.overlay.lua",
	["kanagawa-dragon"] = "assets/themes/kanagawa-dragon.lua",
	["material-oceanic"] = "assets/themes/generated/material-oceanic.overlay.lua",
	["modus-vivendi"] = "assets/themes/generated/modus-vivendi.overlay.lua",
	["monokai-classic"] = "assets/themes/generated/monokai-classic.overlay.lua",
	["monokai-pro"] = "assets/themes/generated/monokai-pro.overlay.lua",
	["monokai-ristretto"] = "assets/themes/generated/monokai-ristretto.overlay.lua",
	["monokai-soda"] = "assets/themes/generated/monokai-soda.overlay.lua",
	["moonfly-dark"] = "assets/themes/generated/moonfly-dark.overlay.lua",
	["nightfly-dark"] = "assets/themes/generated/nightfly-dark.overlay.lua",
	["noctis-dark"] = "assets/themes/generated/noctis-dark.overlay.lua",
	["onedark-dark"] = "assets/themes/generated/onedark-dark.overlay.lua",
	["onedarkpro-onedark"] = "assets/themes/generated/onedarkpro-onedark.overlay.lua",
	["onedarkpro-onedark-vivid"] = "assets/themes/generated/onedarkpro-onedark-vivid.overlay.lua",
	["poimandres-main"] = "assets/themes/generated/poimandres-main.overlay.lua",
	["rose-pine-main"] = "assets/themes/generated/rose-pine-main.overlay.lua",
	["sonokai-default"] = "assets/themes/generated/sonokai-default.overlay.lua",
	["tokyonight-night"] = "assets/themes/tokyonight-night.lua",
	["tokyonight-night-resolved"] = "assets/themes/generated/tokyonight-night-resolved.overlay.lua",
	["vaporwave"] = "assets/themes/generated/vaporwave.overlay.lua",
	["vim-enfocado-dark"] = "assets/themes/generated/vim-enfocado-dark.overlay.lua",
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
