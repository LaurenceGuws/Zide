const std = @import("std");
const step_catalog = @import("step_catalog");

pub fn main() !void {
    std.debug.print("Zide build surface\n==================\n\n", .{});
    inline for (step_catalog.operator_step_groups) |group| {
        std.debug.print("{s}\n", .{group.title});
        for (group.steps) |step| {
            std.debug.print("- `{s}`: {s}\n", .{ step.name, step.description });
        }
        std.debug.print("\n", .{});
    }
    std.debug.print(
        \\Build policy notes
        \\- Default runtime mode is `ide`; use `-Dmode=terminal` or `-Dmode=editor` for focused builds.
        \\- Current runtime graphics path is SDL3 + OpenGL on the live build surface.
        \\- Native host architecture authority lives under `app_architecture/platform/`; do not treat the live graphics path as the durable host contract.
        \\- `main` runtime graph and extended IDE/test graph are planned separately on purpose.
        \\
    , .{});
}
