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
  zide = { config = function(opts) return opts end }
end

---@type ZideConfig
return zide.config({
  log_file_filter = "renderer.present,renderer.terminal_present",
  log_console_filter = "renderer.present,renderer.terminal_present",
})
