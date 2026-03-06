const std = @import("std");

pub const DependencySource = enum {
    link,
    zig,
};

pub fn parseDependencyPath(raw: []const u8) DependencySource {
    if (std.mem.eql(u8, raw, "link")) return .link;
    if (std.mem.eql(u8, raw, "zig")) return .zig;
    std.debug.panic("invalid -Dpath='{s}' (expected 'link' or 'zig')", .{raw});
}
