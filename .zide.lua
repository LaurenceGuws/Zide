return {
    sdl = {
        log_level = "warning",
    },
    log = {
        console = "",
        file = "terminal.ui.perf,terminal.ui.redraw,terminal.ui.lifecycle,terminal.parse,terminal.frame,terminal.env",
    },
    logs = {
        file_level = "warning",
        console_level = "info",
        file_levels = {
            ["terminal.ui.perf"] = "info",
            ["terminal.ui.redraw"] = "debug",
            ["terminal.ui.lifecycle"] = "info",
            ["terminal.parse"] = "info",
            ["terminal.frame"] = "info",
            ["terminal.env"] = "info",
        },
    },
}
