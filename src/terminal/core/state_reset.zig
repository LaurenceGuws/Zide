const kitty_mod = @import("../kitty/graphics.zig");
const input_modes = @import("input_modes.zig");

pub fn resetStateLocked(self: anytype) void {
    self.core.parser.reset();
    self.core.saved_charset = .{};
    self.core.primary.resetState();
    self.core.alt.resetState();
    self.core.current_hyperlink_id = 0;
    input_modes.resetInputModesLocked(self);
    self.core.primary.clear();
    self.core.alt.clear();
    kitty_mod.clearKittyImages(self);
    _ = self.core.clear_generation.fetchAdd(1, .acq_rel);
}

pub fn saveCursor(self: anytype) void {
    self.activeScreen().saveCursor();
    self.core.saved_charset = .{
        .active = true,
        .g0 = self.core.parser.g0_charset,
        .g1 = self.core.parser.g1_charset,
        .gl = self.core.parser.gl_charset,
        .target = self.core.parser.charset_target,
    };
}

pub fn restoreCursor(self: anytype) void {
    self.activeScreen().restoreCursor();
    if (!self.core.saved_charset.active) return;
    self.core.parser.g0_charset = self.core.saved_charset.g0;
    self.core.parser.g1_charset = self.core.saved_charset.g1;
    self.core.parser.gl_charset = self.core.saved_charset.gl;
    self.core.parser.charset_target = self.core.saved_charset.target;
}
