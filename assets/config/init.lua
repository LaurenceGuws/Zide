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

    -- SDL logging configuration.
    -- log_level options: "none", "critical", "error", "warning", "warn", "info", "debug", "trace"
    sdl = {
        log_level = "info",
    },

    -- Theme configuration.
    -- Colors accept hex strings (#RRGGBB or #RRGGBBAA) or tables { r = 0, g = 0, b = 0, a = 255 }.
    -- Nordic palette defaults (from nordic.nvim).
    theme = {
        palette = {
            background = "#242933",
            foreground = "#BBC3D4",
            selection = "#3B4252",
            cursor = "#D8DEE9",
            link = "#81A1C1",
            line_number = "#4C566A",
            line_number_bg = "#1E222A",
            current_line = "#191D24",
        },
        syntax = {
            comment = "#4C566A",
            string = "#A3BE8C",
            keyword = "#D08770",
            number = "#BE9DB8",
            ["function"] = "#88C0D0",
            variable = "#BBC3D4",
            type_name = "#EBCB8B",
            operator = "#BBC3D4",
            builtin = "#5E81AC",
            punctuation = "#60728A",
            constant = "#BE9DB8",
            attribute = "#8FBCBB",
            namespace = "#E7C173",
            label = "#D08770",
            error = "#C5727A",
        },
    },

    -- App shell configuration.
    -- Note: editor + terminal currently share the same font stack.
    app = {
        font = {
            path = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
            size = 16,
        },
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
        -- Optional override (same font as app/terminal for now).
        -- font = { path = "/usr/share/fonts/...", size = 16 },
    },

    -- Terminal configuration.
    terminal = {
        -- Optional override (same font as app/editor for now).
        -- font = { path = "/usr/share/fonts/...", size = 16 },
    },
}
