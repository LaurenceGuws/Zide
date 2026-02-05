const std = @import("std");

pub fn keyModeFlags(self: anytype) u32 {
    return self.activeScreen().keyModeFlags();
}

pub fn keyModePush(self: anytype, flags: u32) void {
    self.activeScreen().keyModePush(flags);
    self.updateInputSnapshot();
}

pub fn keyModePop(self: anytype, count: usize) void {
    self.activeScreen().keyModePop(count);
    self.updateInputSnapshot();
}

pub fn keyModeModify(self: anytype, flags: u32, mode: u32) void {
    self.activeScreen().keyModeModify(flags, mode);
    self.updateInputSnapshot();
}

pub fn keyModeQuery(self: anytype) void {
    const flags = keyModeFlags(self);
    if (self.pty) |*pty| {
        var buf: [32]u8 = undefined;
        const seq = std.fmt.bufPrint(&buf, "\x1b[?{d}u", .{flags}) catch return;
        _ = pty.write(seq) catch {};
    }
}

pub fn setKeypadMode(self: anytype, enabled: bool) void {
    self.app_keypad = enabled;
    self.updateInputSnapshot();
}

pub fn appKeypadEnabled(self: anytype) bool {
    return self.input_snapshot.app_keypad.load(.acquire);
}
