const std = @import("std");
const app_logger = @import("../src/app_logger.zig");
const c_api = @import("../src/terminal/ffi/c_api.zig");

test "ffi non-pty snapshot and event ownership smoke" {
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION, c_api.zide_terminal_snapshot_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_EVENT_ABI_VERSION, c_api.zide_terminal_event_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_SCROLLBACK_ABI_VERSION, c_api.zide_terminal_scrollback_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_RENDERER_METADATA_ABI_VERSION, c_api.zide_terminal_renderer_metadata_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_METADATA_ABI_VERSION, c_api.zide_terminal_metadata_abi_version());
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_REDRAW_STATE_ABI_VERSION, c_api.zide_terminal_redraw_state_abi_version());

    var rounded_box_meta: c_api.ZideTerminalRendererMetadata = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_renderer_metadata(0x256D, &rounded_box_meta));
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_RENDERER_METADATA_ABI_VERSION, rounded_box_meta.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalRendererMetadata)), rounded_box_meta.struct_size);
    try std.testing.expectEqual(@as(u32, 0x256D), rounded_box_meta.codepoint);
    try std.testing.expect((rounded_box_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.box)) != 0);
    try std.testing.expect((rounded_box_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.box_rounded)) != 0);

    var braille_meta: c_api.ZideTerminalRendererMetadata = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_renderer_metadata(0x28FF, &braille_meta));
    try std.testing.expect((braille_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.braille)) != 0);
    try std.testing.expect((braille_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.graph)) != 0);

    var rounded_powerline_meta: c_api.ZideTerminalRendererMetadata = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_renderer_metadata(0xE0B5, &rounded_powerline_meta));
    try std.testing.expect((rounded_powerline_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.powerline)) != 0);
    try std.testing.expect((rounded_powerline_meta.glyph_class_flags & @intFromEnum(c_api.ZideTerminalGlyphClassFlags.powerline_rounded)) != 0);
    try std.testing.expect((rounded_powerline_meta.damage_policy_flags & @intFromEnum(c_api.ZideTerminalDamagePolicyFlags.advisory_bounds)) != 0);
    try std.testing.expect((rounded_powerline_meta.damage_policy_flags & @intFromEnum(c_api.ZideTerminalDamagePolicyFlags.full_redraw_safe_default)) != 0);

    var handle: ?*c_api.ZideTerminalHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_create(null, &handle));
    defer c_api.zide_terminal_destroy(handle);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_resize(handle, 80, 24, 8, 16));

    {
        var resize_events: c_api.ZideTerminalEventBuffer = .{};
        try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &resize_events));
        defer c_api.zide_terminal_events_free(&resize_events);
        try std.testing.expectEqual(c_api.ZIDE_TERMINAL_EVENT_ABI_VERSION, resize_events.abi_version);
        try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalEventBuffer)), resize_events.struct_size);
        try std.testing.expectEqual(@as(usize, 1), resize_events.count);
        try std.testing.expectEqual(
            @as(c_int, @intFromEnum(c_api.ZideTerminalEventKind.redraw_ready)),
            resize_events.events.?[0].kind,
        );
    }

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
    try std.testing.expect(snapshot.generation > 0);
    try std.testing.expectEqual(@as(u8, 1), c_api.zide_terminal_needs_redraw(handle));

    var published_generation: u64 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_published_generation(handle, &published_generation));
    try std.testing.expectEqual(snapshot.generation, published_generation);

    var redraw_state: c_api.ZideTerminalRedrawState = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_redraw_state(handle, &redraw_state));
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_REDRAW_STATE_ABI_VERSION, redraw_state.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalRedrawState)), redraw_state.struct_size);
    try std.testing.expectEqual(snapshot.generation, redraw_state.published_generation);
    try std.testing.expectEqual(@as(u64, 0), redraw_state.acknowledged_generation);
    try std.testing.expectEqual(@as(u8, 1), redraw_state.needs_redraw);

    var acknowledged_generation: u64 = 99;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_acknowledged_generation(handle, &acknowledged_generation));
    try std.testing.expectEqual(@as(u64, 0), acknowledged_generation);
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_present_ack(handle, snapshot.generation));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_acknowledged_generation(handle, &acknowledged_generation));
    try std.testing.expectEqual(snapshot.generation, acknowledged_generation);
    try std.testing.expectEqual(@as(u8, 0), c_api.zide_terminal_needs_redraw(handle));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_redraw_state(handle, &redraw_state));
    try std.testing.expectEqual(snapshot.generation, redraw_state.published_generation);
    try std.testing.expectEqual(snapshot.generation, redraw_state.acknowledged_generation);
    try std.testing.expectEqual(@as(u8, 0), redraw_state.needs_redraw);
    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_terminal_present_ack(handle, snapshot.generation + 1));

    var metadata: c_api.ZideTerminalMetadata = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_metadata_acquire(handle, &metadata));
    defer c_api.zide_terminal_metadata_release(&metadata);
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_METADATA_ABI_VERSION, metadata.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalMetadata)), metadata.struct_size);
    try std.testing.expectEqualStrings("ffi-title", ptrBytes(metadata.title_ptr, metadata.title_len));
    try std.testing.expectEqual(@as(usize, 0), metadata.cwd_len);
    try std.testing.expectEqual(@as(u32, 0), metadata.scrollback_count);

    try std.testing.expectEqualStrings("ok", std.mem.span(c_api.zide_terminal_status_string(0)));
    try std.testing.expectEqualStrings("invalid_argument", std.mem.span(c_api.zide_terminal_status_string(1)));
    try std.testing.expectEqualStrings("unknown_status", std.mem.span(c_api.zide_terminal_status_string(99)));

    var events: c_api.ZideTerminalEventBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
    defer c_api.zide_terminal_events_free(&events);
    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_EVENT_ABI_VERSION, events.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalEventBuffer)), events.struct_size);
    try std.testing.expectEqual(@as(usize, 3), events.count);

    var saw_title = false;
    var saw_clipboard = false;
    var saw_redraw = false;
    for (events.events.?[0..events.count]) |event| {
        const payload = ptrBytes(event.data_ptr, event.data_len);
        switch (event.kind) {
            @intFromEnum(c_api.ZideTerminalEventKind.redraw_ready) => {
                saw_redraw = true;
            },
            @intFromEnum(c_api.ZideTerminalEventKind.title_changed) => {
                saw_title = std.mem.eql(u8, payload, "ffi-title");
            },
            @intFromEnum(c_api.ZideTerminalEventKind.clipboard_write) => {
                saw_clipboard = std.mem.eql(u8, payload, "ffi-clip");
            },
            else => {},
        }
    }

    try std.testing.expect(saw_redraw);
    try std.testing.expect(saw_title);
    try std.testing.expect(saw_clipboard);
}

test "ffi scrollback acquire exports copied rows" {
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    const cfg = c_api.ZideTerminalCreateConfig{
        .rows = 4,
        .cols = 12,
        .scrollback_rows = 128,
        .cursor_shape = 0,
        .cursor_blink = 1,
    };
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_create(&cfg, &handle));
    defer c_api.zide_terminal_destroy(handle);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_resize(handle, 12, 4, 8, 16));

    const lines =
        "hist-00\r\n" ++
        "hist-01\r\n" ++
        "hist-02\r\n" ++
        "hist-03\r\n" ++
        "hist-04\r\n" ++
        "hist-05\r\n";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_feed_output(handle, lines.ptr, lines.len));

    var metadata: c_api.ZideTerminalMetadata = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_metadata_acquire(handle, &metadata));
    defer c_api.zide_terminal_metadata_release(&metadata);
    const count = metadata.scrollback_count;
    try std.testing.expect(count > 0);

    var scrollback: c_api.ZideTerminalScrollbackBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_scrollback_acquire(handle, 0, 0, &scrollback));
    defer c_api.zide_terminal_scrollback_release(&scrollback);

    try std.testing.expectEqual(c_api.ZIDE_TERMINAL_SCROLLBACK_ABI_VERSION, scrollback.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalScrollbackBuffer)), scrollback.struct_size);
    try std.testing.expectEqual(count, scrollback.total_rows);
    try std.testing.expectEqual(@as(u32, 0), scrollback.start_row);
    try std.testing.expectEqual(count, scrollback.row_count);
    try std.testing.expectEqual(@as(u32, 12), scrollback.cols);
    try std.testing.expectEqual(@as(usize, @as(usize, count) * 12), scrollback.cell_count);
    try std.testing.expect(scrollback.cells != null);

    try std.testing.expect(scrollbackRowContains(&scrollback, 0, "hist-"));

    if (count >= 2) {
        var one_row: c_api.ZideTerminalScrollbackBuffer = .{};
        try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_scrollback_acquire(handle, 1, 1, &one_row));
        defer c_api.zide_terminal_scrollback_release(&one_row);
        try std.testing.expectEqual(@as(u32, 1), one_row.start_row);
        try std.testing.expectEqual(@as(u32, 1), one_row.row_count);
        try std.testing.expectEqual(@as(usize, 12), one_row.cell_count);
    }

    var invalid: c_api.ZideTerminalScrollbackBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_terminal_scrollback_acquire(handle, count + 1, 0, &invalid));
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

    var scrollback: c_api.ZideTerminalScrollbackBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_scrollback_acquire(handle, 0, 0, &scrollback));
    c_api.zide_terminal_scrollback_release(&scrollback);
    try std.testing.expectEqual(@as(u32, 0), scrollback.abi_version);
    try std.testing.expectEqual(@as(u32, 0), scrollback.struct_size);
    try std.testing.expectEqual(@as(usize, 0), scrollback.cell_count);
    try std.testing.expectEqual(@as(?*anyopaque, null), scrollback._ctx);

    const vt = "\x1b]0;ffi-title\x07";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_feed_output(handle, vt.ptr, vt.len));

    var events: c_api.ZideTerminalEventBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
    c_api.zide_terminal_events_free(&events);
    try std.testing.expectEqual(@as(u32, 0), events.abi_version);
    try std.testing.expectEqual(@as(u32, 0), events.struct_size);
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
    var saw_redraw = false;
    while (std.time.milliTimestamp() < deadline) {
        try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_poll(handle));

        {
            var events: c_api.ZideTerminalEventBuffer = .{};
            try std.testing.expectEqual(@as(c_int, 0), c_api.zide_terminal_event_drain(handle, &events));
            defer c_api.zide_terminal_events_free(&events);
            try std.testing.expectEqual(c_api.ZIDE_TERMINAL_EVENT_ABI_VERSION, events.abi_version);
            try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideTerminalEventBuffer)), events.struct_size);

            if (events.events) |event_ptr| {
                for (event_ptr[0..events.count]) |event| {
                    if (event.kind == @intFromEnum(c_api.ZideTerminalEventKind.redraw_ready)) {
                        saw_redraw = true;
                    }
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

    try std.testing.expect(saw_redraw);
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

fn scrollbackRowContains(scrollback: *const c_api.ZideTerminalScrollbackBuffer, row: usize, needle: []const u8) bool {
    if (scrollback.cells == null or scrollback.cols == 0) return false;
    const cols: usize = @intCast(scrollback.cols);
    const start = row * cols;
    const cells = scrollback.cells.?[0..scrollback.cell_count];
    if (start + cols > cells.len) return false;

    var line: [256]u8 = [_]u8{0} ** 256;
    var len: usize = 0;
    for (cells[start .. start + cols]) |cell| {
        if (cell.width == 0) continue;
        const cp = cell.codepoint;
        const ch: u8 = if (cp == 0 or cp > 0x7f) ' ' else @intCast(cp);
        if (len < line.len) {
            line[len] = ch;
            len += 1;
        }
    }
    while (len > 0 and line[len - 1] == ' ') {
        len -= 1;
    }
    return std.mem.indexOf(u8, line[0..len], needle) != null;
}
