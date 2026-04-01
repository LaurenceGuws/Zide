const session_config = @import("../session_config.zig");
const types = @import("../../model/types.zig");

pub fn setDefaultColorsLocked(self: anytype, fg: types.Color, bg: types.Color) void {
    session_config.setDefaultColorsLocked(self, fg, bg);
}

pub fn setDefaultColors(self: anytype, fg: types.Color, bg: types.Color) void {
    session_config.setDefaultColors(self, fg, bg);
}

pub fn setAnsiColors(self: anytype, colors: [16]types.Color) void {
    session_config.setAnsiColors(self, colors);
}

pub fn remapAnsiColors(
    self: anytype,
    old_colors: [16]types.Color,
    new_colors: [16]types.Color,
) void {
    session_config.remapAnsiColors(self, old_colors, new_colors);
}

pub fn setPaletteColorLocked(self: anytype, idx: usize, color: types.Color) void {
    session_config.setPaletteColorLocked(self, idx, color);
}

pub fn resetPaletteColorLocked(self: anytype, idx: usize) void {
    session_config.resetPaletteColorLocked(self, idx);
}

pub fn resetAllPaletteColorsLocked(self: anytype) void {
    session_config.resetAllPaletteColorsLocked(self);
}

pub fn setDynamicColorCodeLocked(self: anytype, code: u8, color: ?types.Color) void {
    session_config.setDynamicColorCodeLocked(self, code, color);
}

pub fn applyThemePalette(
    self: anytype,
    fg: types.Color,
    bg: types.Color,
    ansi: ?[16]types.Color,
) void {
    session_config.applyThemePalette(self, fg, bg, ansi);
}

pub fn setColumnMode132(self: anytype, enabled: bool) void {
    session_config.setColumnMode132(self, enabled);
}

pub fn setColumnMode132Locked(self: anytype, enabled: bool) void {
    session_config.setColumnMode132Locked(self, enabled);
}

pub fn setCellSize(self: anytype, cell_width: u16, cell_height: u16) void {
    session_config.setCellSize(self, cell_width, cell_height);
}
