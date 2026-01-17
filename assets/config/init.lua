-- Zide default config reference (loaded as system defaults).
-- Copy it to ~/.config/zide/init.lua or ./.zide.lua to customize.

return {
  -- Logging configuration.
  -- Options:
  --   "all" / "none" / "app,terminal,metrics" (comma-separated)
  --   or log = { enable = { "app", "terminal" } }
  log = {
    enable = { "app", "terminal" },
  },

  -- Raylib logging configuration.
  -- log_level options: "none", "error", "warning"/"warn", "info", "debug", "trace"
  raylib = {
    log_level = "info",
  },
}
