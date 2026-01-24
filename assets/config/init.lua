-- Zide default config reference (loaded as system defaults).
-- Copy it to ~/.config/zide/init.lua or ./.zide.lua to customize.

return {
    -- Logging configuration.
    -- Options:
    --   log = "all" / "none" / "app.core,editor.core,editor.input,editor.highlight,terminal.core,terminal.metrics,terminal.alt,terminal.font,terminal.io,terminal.csi,terminal.sgr,terminal.osc,terminal.replay" (comma-separated)
    --   log = "all" / "none" / "... ,editor.perf" for file load + rope init timings
    --   log = { enable = { "app.core", "editor.core", "editor.input", "editor.highlight", "terminal.core", "terminal.metrics", "terminal.alt", "terminal.font", "terminal.io", "terminal.csi", "terminal.sgr", "terminal.osc", "terminal.replay" } }
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
    editor = {
        -- Soft wrap long lines.
        wrap = false,
        -- Render work budgets (lines per frame). Set to 0 to disable precompute.
        render = {
            -- highlight_budget = 120,
            -- width_budget = 120,
        },
    },
}
