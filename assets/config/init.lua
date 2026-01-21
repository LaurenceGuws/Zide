-- Zide default config reference (loaded as system defaults).
-- Copy it to ~/.config/zide/init.lua or ./.zide.lua to customize.

return {
  -- Logging configuration.
  -- Options:
  --   log = "all" / "none" / "app.core,editor.core,editor.input,editor.highlight,terminal.core,terminal.metrics,terminal.alt,terminal.font,terminal.io,terminal.csi,terminal.sgr,terminal.osc" (comma-separated)
  --   log = { enable = { "app.core", "editor.core", "editor.input", "editor.highlight", "terminal.core", "terminal.metrics", "terminal.alt", "terminal.font", "terminal.io", "terminal.csi", "terminal.sgr", "terminal.osc" } }
  --   log = { file = { ... }, console = { ... } }
  -- If file/console are not set, enable is used for both.
  log = {
    enable = { "app.core", "terminal.core" },
    -- file = { "terminal.metrics" },
    -- console = { "app.core" },
  },

  -- Raylib logging configuration.
  -- log_level options: "none", "error", "warning", "warn", "info", "debug", "trace"
  raylib = {
    log_level = "info",
  },

  -- Editor configuration.
  -- text_store options: "rope", "piece_table"
  editor = {
    text_store = "rope",
  },
}
