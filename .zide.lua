return {
    sdl = {
        log_level = "warning",
    },
    log = {
        console = "sdl.gl,sdl.window",
        file = "terminal.ui.target_sample,sdl.gl,sdl.window",
    },
    logs = {
        file_level = "warning",
        console_level = "info",
        file_levels = {
            ["terminal.ui.target_sample"] = "info",
            ["sdl.gl"] = "info",
            ["sdl.window"] = "info",
        },
        console_levels = {
            ["sdl.gl"] = "info",
            ["sdl.window"] = "info",
        },
    },
}
