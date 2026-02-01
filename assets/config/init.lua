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
            ui_bar_bg = "#1E1F29",
            ui_panel_bg = "#181921",
            ui_panel_overlay = "#181921EB",
            ui_hover = "#3B4252",
            ui_pressed = "#3A3C4E",
            ui_tab_inactive_bg = "#232430",
            ui_accent = "#BE9DB8",
            ui_border = "#434C5E",
            ui_modified = "#D08770",
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

    -- Keybindings (keycode-based). Key names match `shared_types.input.Key` tags.
    keybinds = {
        global = {
            { key = "n", mods = { "ctrl" }, action = "new_editor" },
            { key = "equal", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
            { key = "kp_add", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
            { key = "minus", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
            { key = "kp_subtract", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
            { key = "zero", mods = { "ctrl" }, action = "zoom_reset" },
            { key = "grave", mods = { "ctrl" }, action = "toggle_terminal" },
        },
        editor = {
            { key = "s", mods = { "ctrl" }, action = "save" },
            { key = "z", mods = { "ctrl" }, action = "undo", ["repeat"] = true },
            { key = "y", mods = { "ctrl" }, action = "redo", ["repeat"] = true },
        },
        terminal = {
            { key = "c", mods = { "ctrl", "shift" }, action = "copy" },
            { key = "v", mods = { "ctrl", "shift" }, action = "paste" },
        },
    },
}
