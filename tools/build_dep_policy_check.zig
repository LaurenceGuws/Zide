const std = @import("std");

fn fail(msg: []const u8) noreturn {
    std.debug.print("build dep policy check failed: {s}\n", .{msg});
    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = std.fs.cwd().readFileAlloc(allocator, "build.zig", 2 * 1024 * 1024) catch |err| {
        std.debug.print("build dep policy check failed: unable to read build.zig: {s}\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(contents);

    const required = [_][]const u8{
        "configureAppExecutable(exe_terminal, app_link_ctx, \"zide-terminal\", false);",
        "configureAppExecutable(exe_editor, app_link_ctx, \"zide-editor\", true);",
        "configureAppExecutable(exe_ide, app_link_ctx, \"zide-ide\", true);",
    };
    for (required) |snippet| {
        if (std.mem.indexOf(u8, contents, snippet) == null) {
            fail(snippet);
        }
    }

    const forbidden = [_][]const u8{
        "exe_terminal.linkLibrary(treesitter);",
        "addTreeSitterIncludes(exe_terminal, treesitter);",
    };
    for (forbidden) |snippet| {
        if (std.mem.indexOf(u8, contents, snippet) != null) {
            fail(snippet);
        }
    }

    std.debug.print("build dep policy ok\n", .{});
}
