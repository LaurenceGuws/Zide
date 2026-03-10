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
