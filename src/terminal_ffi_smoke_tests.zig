const std = @import("std");
const app_logger = @import("app_logger.zig");
const c_api = @import("terminal/ffi/c_api.zig");

test "ffi non-pty snapshot and event ownership smoke" {
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION, c_api.zide_terminal_snapshot_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_EVENT_ABI_VERSION, c_api.zide_terminal_event_abi_version());

    var handle: ?*c_api.ZideTerminalHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_create(null, &handle));
    defer c_api.zide_terminal_destroy(handle);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_resize(handle, 80, 24, 8, 16));

    const vt = "\x1b]0;ffi-title\x07\x1b]52;c;ZmZpLWNsaXA=\x07";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_feed_output(handle, vt.ptr, vt.len));

    var snapshot: c_api.ZideTerminalSnapshot = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_snapshot_acquire(handle, &snapshot));
    defer c_api.zide_terminal_snapshot_release(&snapshot);

    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION, snapshot.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalSnapshot)), snapshot.struct_size);
    try std.testing.expectEqual(@as(u32, 24), snapshot.rows);
    try std.testing.expectEqual(@as(u32, 80), snapshot.cols);
    try std.testing.expectEqual(@as(usize, 24 * 80), snapshot.cell_count);
    try std.testing.expect(snapshot.cells != null);
    try std.testing.expect(snapshot.title_ptr != null);
    try std.testing.expectEqualStrings("ffi-title", ptrBytes(snapshot.title_ptr, snapshot.title_len));

    var title: c_api.ZideTerminalStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_current_title(handle, &title));
    defer c_api.zide_terminal_string_free(&title);
    try std.testing.expectEqualStrings("ffi-title", ptrBytes(title.ptr, title.len));

    var cwd: c_api.ZideTerminalStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_current_cwd(handle, &cwd));
    defer c_api.zide_terminal_string_free(&cwd);
    try std.testing.expectEqual(@as(usize, 0), cwd.len);

    try std.testing.expectEqualStrings("ok", std.mem.span(c_api.zide_terminal_status_string(0)));
    try std.testing.expectEqualStrings("invalid_argument", std.mem.span(c_api.zide_terminal_status_string(1)));
    try std.testing.expectEqualStrings("unknown_status", std.mem.span(c_api.zide_terminal_status_string(99)));

    var events: c_api.ZideTerminalEventBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
    defer c_api.zide_terminal_events_free(&events);
    try std.testing.expectEqual(@as(usize, 2), events.count);

    var saw_title = false;
    var saw_clipboard = false;
    for (events.events.?[0..events.count]) |event| {
        const payload = ptrBytes(event.data_ptr, event.data_len);
        switch (event.kind) {
            @intFromEnum(c_api.ZideTerminalEventKind.title_changed) => {
                saw_title = std.mem.eql(u8, payload, "ffi-title");
            },
            @intFromEnum(c_api.ZideTerminalEventKind.clipboard_write) => {
                saw_clipboard = std.mem.eql(u8, payload, "ffi-clip");
            },
            else => {},
        }
    }

    try std.testing.expect(saw_title);
    try std.testing.expect(saw_clipboard);
}

test "ffi snapshot and event release zero exported structs" {
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_create(null, &handle));
    defer c_api.zide_terminal_destroy(handle);

    var snapshot: c_api.ZideTerminalSnapshot = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_snapshot_acquire(handle, &snapshot));
    c_api.zide_terminal_snapshot_release(&snapshot);
    try std.testing.expectEqual(@as(u32, 0), snapshot.abi_version);
    try std.testing.expectEqual(@as(u32, 0), snapshot.struct_size);
    try std.testing.expectEqual(@as(usize, 0), snapshot.cell_count);
    try std.testing.expectEqual(@as(?*anyopaque, null), snapshot._ctx);

    const vt = "\x1b]0;ffi-title\x07";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_feed_output(handle, vt.ptr, vt.len));

    var events: c_api.ZideTerminalEventBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
    c_api.zide_terminal_events_free(&events);
    try std.testing.expectEqual(@as(usize, 0), events.count);
    try std.testing.expectEqual(@as(?*anyopaque, null), events._ctx);
}

test "ffi child_exit event carries exit code and present flag" {
    if (@import("builtin").os.tag == .windows) return;

    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_create(null, &handle));
    defer c_api.zide_terminal_destroy(handle);
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_resize(handle, 40, 8, 8, 16));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_start(handle, "/bin/sh"));

    const command = "exit 7\n";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_send_bytes(handle, command.ptr, command.len));

    const deadline = std.time.milliTimestamp() + 4000;
    var saw_child_exit = false;
    while (std.time.milliTimestamp() < deadline) {
        try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_poll(handle));

        {
            var events: c_api.ZideTerminalEventBuffer = .{};
            try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
            defer c_api.zide_terminal_events_free(&events);

            if (events.events) |event_ptr| {
                for (event_ptr[0..events.count]) |event| {
                    if (event.kind != @intFromEnum(c_api.ZideTerminalEventKind.child_exit)) continue;
                    try std.testing.expectEqual(@as(usize, 0), event.data_len);
                    try std.testing.expect(event.data_ptr == null);
                    try std.testing.expectEqual(@as(i32, 7), event.int0);
                    try std.testing.expectEqual(@as(i32, 1), event.int1);
                    saw_child_exit = true;
                }
            }
        }
        if (saw_child_exit) break;
        std.Thread.sleep(20 * std.time.ns_per_ms);
    }

    try std.testing.expect(saw_child_exit);

    var code: i32 = -1;
    var has_status: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_child_exit_status(handle, &code, &has_status));
    try std.testing.expectEqual(@as(u8, 1), has_status);
    try std.testing.expectEqual(@as(i32, 7), code);
}

fn ptrBytes(ptr: ?[*]const u8, len: usize) []const u8 {
    if (len == 0) return "";
    return (ptr orelse unreachable)[0..len];
}
