const kitty_mod = @import("../kitty/graphics.zig");
const input_modes = @import("input_modes.zig");

pub fn resetStateLocked(self: anytype) void {
    self.parser.reset();
    self.saved_charset = .{};
    self.primary.resetState();
    self.alt.resetState();
    self.current_hyperlink_id = 0;
    input_modes.resetInputModesLocked(self);
    self.primary.clear();
    self.alt.clear();
    kitty_mod.clearKittyImages(self);
    _ = self.clear_generation.fetchAdd(1, .acq_rel);
}

pub fn saveCursor(self: anytype) void {
    self.activeScreen().saveCursor();
    self.saved_charset = .{
        .active = true,
        .g0 = self.parser.g0_charset,
        .g1 = self.parser.g1_charset,
        .gl = self.parser.gl_charset,
        .target = self.parser.charset_target,
    };
}

pub fn restoreCursor(self: anytype) void {
    self.activeScreen().restoreCursor();
    if (!self.saved_charset.active) return;
    self.parser.g0_charset = self.saved_charset.g0;
    self.parser.g1_charset = self.saved_charset.g1;
    self.parser.gl_charset = self.saved_charset.gl;
    self.parser.charset_target = self.saved_charset.target;
}
