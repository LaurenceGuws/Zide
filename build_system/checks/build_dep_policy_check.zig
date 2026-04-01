const std = @import("std");

fn fail(msg: []const u8) noreturn {
    std.debug.print("build dep policy check failed: {s}\n", .{msg});
    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const app_graph = std.fs.cwd().readFileAlloc(allocator, "build_system/app_graph.zig", 2 * 1024 * 1024) catch |err| {
        std.debug.print("build dep policy check failed: unable to read build_system/app_graph.zig: {s}\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(app_graph);

    const target_factory = std.fs.cwd().readFileAlloc(allocator, "build_system/target_factory.zig", 2 * 1024 * 1024) catch |err| {
        std.debug.print("build dep policy check failed: unable to read build_system/target_factory.zig: {s}\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(target_factory);

    const target_config = std.fs.cwd().readFileAlloc(allocator, "build_system/target_config.zig", 2 * 1024 * 1024) catch |err| {
        std.debug.print("build dep policy check failed: unable to read build_system/target_config.zig: {s}\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(target_config);

    const required = [_][]const u8{
        "configureAppExecutable(exe, app_link_ctx, \"zide\", target_profile.app_main);",
        "target_config.configureAppExecutable(exe, ctx, name, profile);",
        "if (std.mem.eql(u8, target_name, \"zide-terminal\") and profile.include_treesitter) {",
    };
    if (std.mem.indexOf(u8, app_graph, required[0]) == null) fail(required[0]);
    if (std.mem.indexOf(u8, target_factory, required[1]) == null) fail(required[1]);
    if (std.mem.indexOf(u8, target_config, required[2]) == null) fail(required[2]);

    const focused_required = [_][]const u8{
        ".terminal, .editor => {",
        "spec.profile,",
    };
    for (focused_required) |snippet| {
        if (std.mem.indexOf(u8, app_graph, snippet) == null) fail(snippet);
    }

    std.debug.print("build dep policy ok\n", .{});
}
