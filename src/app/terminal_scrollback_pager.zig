const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../app_logger.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const TerminalSession = terminal_mod.TerminalSession;

fn shellSingleQuoteAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '\'');
    for (value) |ch| {
        if (ch == '\'') {
            try out.appendSlice(allocator, "'\\''");
        } else {
            try out.append(allocator, ch);
        }
    }
    try out.append(allocator, '\'');
    return out.toOwnedSlice(allocator);
}

pub fn openInPager(
    allocator: std.mem.Allocator,
    term: *TerminalSession,
) !bool {
    const log = app_logger.logger("terminal.scrollback.pager");
    const text = try term.scrollbackAnsiTextAlloc(allocator);
    defer allocator.free(text);
    if (text.len == 0) return false;

    var dir = try std.fs.cwd().makeOpenPath(".tmp", .{});
    defer dir.close();

    const nanos = std.time.nanoTimestamp();
    const file_name = try std.fmt.allocPrint(allocator, "terminal-scrollback-{d}.txt", .{nanos});
    defer allocator.free(file_name);

    {
        var file = try dir.createFile(file_name, .{ .truncate = true });
        defer file.close();
        try file.writeAll(text);
    }

    const path = try std.fs.path.join(allocator, &.{ ".tmp", file_name });
    defer allocator.free(path);
    const abs_path = std.fs.cwd().realpathAlloc(allocator, path) catch try allocator.dupe(u8, path);
    defer allocator.free(abs_path);
    const shell_path = try shellSingleQuoteAlloc(allocator, abs_path);
    defer allocator.free(shell_path);

    if (builtin.os.tag == .windows) {
        const cmd = try std.fmt.allocPrint(
            allocator,
            "\x15more \"{s}\"\r",
            .{abs_path},
        );
        defer allocator.free(cmd);
        term.sendText(cmd) catch |err| {
            log.logf(.warning, "open scrollback pager (windows) send failed: {s}", .{@errorName(err)});
            return false;
        };
        return true;
    }

    const script_name = try std.fmt.allocPrint(allocator, "terminal-scrollback-{d}.sh", .{nanos});
    defer allocator.free(script_name);
    const script_path = try std.fs.path.join(allocator, &.{ ".tmp", script_name });
    defer allocator.free(script_path);
    const script_abs_path = std.fs.cwd().realpathAlloc(allocator, script_path) catch try allocator.dupe(u8, script_path);
    defer allocator.free(script_abs_path);
    const shell_script_path = try shellSingleQuoteAlloc(allocator, script_abs_path);
    defer allocator.free(shell_script_path);

    {
        var script = try dir.createFile(script_name, .{ .truncate = true });
        defer script.close();
        const script_body = try std.fmt.allocPrint(
            allocator,
            "#!/usr/bin/env sh\nif [ -n \"${{PAGER:-}}\" ]; then if [ \"${{PAGER##*/}}\" = \"page\" ]; then cat {s} | \"$PAGER\" -o; else \"$PAGER\" {s}; fi; elif command -v less >/dev/null 2>&1; then less -R -+F {s}; elif command -v more >/dev/null 2>&1; then more {s}; else cat {s}; fi\nrm -f \"$0\"\n",
            .{ shell_path, shell_path, shell_path, shell_path, shell_path },
        );
        defer allocator.free(script_body);
        try script.writeAll(script_body);
    }

    const cmd = try std.fmt.allocPrint(
        allocator,
        "\x15sh {s}\r",
        .{shell_script_path},
    );
    defer allocator.free(cmd);
    term.sendText(cmd) catch |err| {
        log.logf(.warning, "open scrollback pager send failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}
