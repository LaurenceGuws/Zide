const kitty_mod = @import("../kitty/graphics.zig");

pub fn resetStateCore(self: anytype) void {
    self.core.parser.reset();
    self.core.saved_charset = .{};
    self.core.primary.resetState();
    self.core.alt.resetState();
    self.core.current_hyperlink_id = 0;
    self.core.primary.clear();
    self.core.alt.clear();
    kitty_mod.clearKittyImages(self);
    _ = self.core.clear_generation.fetchAdd(1, .acq_rel);
}
