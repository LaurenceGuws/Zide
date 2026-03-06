const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    const mode = build_options.build_mode;
    const path = if (std.mem.eql(u8, mode, "ide")) "ide-full-graph" else "focused-runtime-only";
    std.debug.print("build mode: {s}\n", .{mode});
    std.debug.print("graph path: {s}\n", .{path});
}
