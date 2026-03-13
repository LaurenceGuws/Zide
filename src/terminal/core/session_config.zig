const types = @import("../model/types.zig");
const input_modes = @import("input_modes.zig");
const view_cache = @import("view_cache.zig");

pub fn setDefaultColorsLocked(self: anytype, fg: types.Color, bg: types.Color) void {
    const old_attrs = self.core.primary.default_attrs;
    var new_attrs = types.defaultCell().attrs;
    new_attrs.fg = fg;
    new_attrs.bg = bg;
    new_attrs.underline_color = fg;

    self.core.primary.updateDefaultColors(old_attrs, new_attrs);
    self.core.alt.updateDefaultColors(old_attrs, new_attrs);
    self.core.history.updateDefaultColors(old_attrs.fg, old_attrs.bg, new_attrs.fg, new_attrs.bg);
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "session_config_default_colors");
}

pub fn setDefaultColors(self: anytype, fg: types.Color, bg: types.Color) void {
    self.lock();
    defer self.unlock();
    setDefaultColorsLocked(self, fg, bg);
}

fn setAnsiColorsLocked(self: anytype, colors: [16]types.Color) void {
    for (0..16) |i| {
        self.core.palette_default[i] = colors[i];
        self.core.palette_current[i] = colors[i];
    }
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "session_config_ansi_colors");
}

pub fn setAnsiColors(self: anytype, colors: [16]types.Color) void {
    self.lock();
    defer self.unlock();
    setAnsiColorsLocked(self, colors);
}

fn remapAnsiColorsLocked(self: anytype, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
    self.core.primary.updateAnsiColors(old_colors, new_colors);
    self.core.alt.updateAnsiColors(old_colors, new_colors);
    self.core.history.updateAnsiColors(old_colors, new_colors);
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "session_config_remap_ansi");
}

pub fn remapAnsiColors(self: anytype, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
    self.lock();
    defer self.unlock();
    remapAnsiColorsLocked(self, old_colors, new_colors);
}

fn snapshotAnsiColorsLocked(self: anytype) [16]types.Color {
    var colors: [16]types.Color = undefined;
    for (0..16) |i| {
        colors[i] = self.core.palette_current[i];
    }
    return colors;
}

pub fn setPaletteColorLocked(self: anytype, idx: usize, color: types.Color) void {
    if (idx >= self.core.palette_current.len) return;
    self.core.palette_current[idx] = color;
}

pub fn resetPaletteColorLocked(self: anytype, idx: usize) void {
    if (idx >= self.core.palette_current.len) return;
    self.core.palette_current[idx] = self.core.palette_default[idx];
}

pub fn resetAllPaletteColorsLocked(self: anytype) void {
    self.core.palette_current = self.core.palette_default;
}

pub fn setDynamicColorCodeLocked(self: anytype, code: u8, color: ?types.Color) void {
    switch (code) {
        10 => {
            const default_attrs = self.core.primary.default_attrs;
            setDefaultColorsLocked(self, color orelse self.core.base_default_attrs.fg, default_attrs.bg);
        },
        11 => {
            const default_attrs = self.core.primary.default_attrs;
            setDefaultColorsLocked(self, default_attrs.fg, color orelse self.core.base_default_attrs.bg);
        },
        else => {
            const idx = @as(usize, code - 10);
            if (idx < self.core.dynamic_colors.len) {
                self.core.dynamic_colors[idx] = color;
            }
        },
    }
}

pub fn applyThemePalette(self: anytype, fg: types.Color, bg: types.Color, ansi: ?[16]types.Color) void {
    self.lock();
    defer self.unlock();

    const old_ansi = if (ansi != null) snapshotAnsiColorsLocked(self) else undefined;
    setDefaultColorsLocked(self, fg, bg);
    if (ansi) |colors| {
        setAnsiColorsLocked(self, colors);
        remapAnsiColorsLocked(self, old_ansi, colors);
    }
}

pub fn setColumnMode132(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setColumnMode132Locked(self, enabled);
}

pub fn setColumnMode132Locked(self: anytype, enabled: bool) void {
    if (self.core.column_mode_132 == enabled) return;
    self.core.column_mode_132 = enabled;
    if (!enabled) return;
    self.core.primary.clear();
    self.core.alt.clear();
    self.core.primary.setCursor(0, 0);
    self.core.alt.setCursor(0, 0);
    _ = self.core.clear_generation.fetchAdd(1, .acq_rel);
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "session_config_column_mode_132");
}

pub fn setCellSize(self: anytype, cell_width: u16, cell_height: u16) void {
    self.lock();
    defer self.unlock();
    self.cell_width = cell_width;
    self.cell_height = cell_height;
}
