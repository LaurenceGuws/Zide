const types = @import("../../model/types.zig");
const input_modes = @import("../input_modes.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");

fn publishConfigViewLocked(self: anytype, source: []const u8) void {
    terminal_publication.publishCurrentViewLocked(self, source);
}

fn setDefaultColorsNoPublishLocked(self: anytype, fg: types.Color, bg: types.Color) void {
    self.core.setDefaultColors(fg, bg);
}

pub fn setDefaultColorsLocked(self: anytype, fg: types.Color, bg: types.Color) void {
    setDefaultColorsNoPublishLocked(self, fg, bg);
    publishConfigViewLocked(self, "session_config_default_colors");
}

pub fn setDefaultColors(self: anytype, fg: types.Color, bg: types.Color) void {
    self.lock();
    defer self.unlock();
    setDefaultColorsLocked(self, fg, bg);
}

fn setAnsiColorsNoPublishLocked(self: anytype, colors: [16]types.Color) void {
    self.core.setAnsiColors(colors);
}

fn setAnsiColorsLocked(self: anytype, colors: [16]types.Color) void {
    setAnsiColorsNoPublishLocked(self, colors);
    publishConfigViewLocked(self, "session_config_ansi_colors");
}

pub fn setAnsiColors(self: anytype, colors: [16]types.Color) void {
    self.lock();
    defer self.unlock();
    setAnsiColorsLocked(self, colors);
}

fn remapAnsiColorsNoPublishLocked(self: anytype, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
    self.core.remapAnsiColors(old_colors, new_colors);
}

fn remapAnsiColorsLocked(self: anytype, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
    remapAnsiColorsNoPublishLocked(self, old_colors, new_colors);
    publishConfigViewLocked(self, "session_config_remap_ansi");
}

pub fn remapAnsiColors(self: anytype, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
    self.lock();
    defer self.unlock();
    remapAnsiColorsLocked(self, old_colors, new_colors);
}

fn snapshotAnsiColorsLocked(self: anytype) [16]types.Color {
    return self.core.snapshotAnsiColors();
}

pub fn setPaletteColorLocked(self: anytype, idx: usize, color: types.Color) void {
    self.core.setPaletteColor(idx, color);
}

pub fn resetPaletteColorLocked(self: anytype, idx: usize) void {
    self.core.resetPaletteColor(idx);
}

pub fn resetAllPaletteColorsLocked(self: anytype) void {
    self.core.resetAllPaletteColors();
}

pub fn setDynamicColorCodeLocked(self: anytype, code: u8, color: ?types.Color) void {
    self.core.setDynamicColorCode(code, color);
}

pub fn applyThemePalette(self: anytype, fg: types.Color, bg: types.Color, ansi: ?[16]types.Color) void {
    self.lock();
    defer self.unlock();

    const old_ansi = if (ansi != null) snapshotAnsiColorsLocked(self) else undefined;
    setDefaultColorsNoPublishLocked(self, fg, bg);
    if (ansi) |colors| {
        setAnsiColorsNoPublishLocked(self, colors);
        remapAnsiColorsNoPublishLocked(self, old_ansi, colors);
    }
    publishConfigViewLocked(self, "session_config_theme_palette");
}

pub fn setConfiguredCursorStyle(self: anytype, cursor_style: types.CursorStyle) void {
    self.lock();
    defer self.unlock();
    self.core.primary.cursor_style = cursor_style;
    self.core.alt.cursor_style = cursor_style;
    publishConfigViewLocked(self, "session_config_cursor_style");
}

pub fn setColumnMode132(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setColumnMode132Locked(self, enabled);
}

pub fn setColumnMode132Locked(self: anytype, enabled: bool) void {
    if (!self.core.setColumnMode132(enabled)) return;
    if (!enabled) return;
    publishConfigViewLocked(self, "session_config_column_mode_132");
}

pub fn setCellSize(self: anytype, cell_width: u16, cell_height: u16) void {
    self.lock();
    defer self.unlock();
    self.interaction.cell_width = cell_width;
    self.interaction.cell_height = cell_height;
}
