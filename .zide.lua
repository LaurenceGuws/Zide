return {
    sdl = {
        log_level = "warning",
    },
    log = {
        console = "",
        file = "terminal.ui.perf,terminal.ui.write_ascii_origin,terminal.ui.row_fullwidth_origin,terminal.ui.grid_dirty_origin,terminal.ui.cursor_motion_damage,terminal.ui.row_render_pass,terminal.ui.dirty_retirement,terminal.env",
    },
    logs = {
        file_level = "warning",
        console_level = "info",
        file_levels = {
            ["terminal.ui.perf"] = "info",
            ["terminal.ui.write_ascii_origin"] = "info",
            ["terminal.ui.row_fullwidth_origin"] = "info",
            ["terminal.ui.grid_dirty_origin"] = "info",
            ["terminal.ui.cursor_motion_damage"] = "info",
            ["terminal.ui.row_render_pass"] = "info",
            ["terminal.ui.dirty_retirement"] = "info",
            ["terminal.env"] = "info",
        },
    },
}
