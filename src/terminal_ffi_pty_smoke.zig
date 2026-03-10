const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("app_logger.zig");
const c_api = @import("terminal/ffi/c_api.zig");

pub fn main() !void {
    if (builtin.os.tag == .windows) return;
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) return error.CreateFailed;
    defer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, 60, 12, 8, 16) != 0) return error.ResizeFailed;
    if (c_api.zide_terminal_start(handle, "/bin/sh") != 0) return error.StartFailed;

    const command =
        "printf '\\033]0;ffi-pty-title\\007\\033]7;file://localhost/tmp/ffi-pty\\007ffi-pty\\n'; exit 7\n";
    if (c_api.zide_terminal_send_bytes(handle, command.ptr, command.len) != 0) return error.SendFailed;

    const deadline = std.time.milliTimestamp() + 4000;
    var saw_marker = false;
    var saw_child_exit = false;
    var saw_metadata = false;
    var saw_redraw = false;

    while (std.time.milliTimestamp() < deadline) {
        if (c_api.zide_terminal_poll(handle) != 0) return error.PollFailed;

        {
            var snapshot: c_api.ZideTerminalSnapshot = .{};
            if (c_api.zide_terminal_snapshot_acquire(handle, &snapshot) != 0) return error.SnapshotAcquireFailed;
            defer c_api.zide_terminal_snapshot_release(&snapshot);

            if (snapshotContains(&snapshot, "ffi-pty")) saw_marker = true;
        }

        {
            var metadata: c_api.ZideTerminalMetadata = .{};
            if (c_api.zide_terminal_metadata_acquire(handle, &metadata) != 0) return error.MetadataAcquireFailed;
            defer c_api.zide_terminal_metadata_release(&metadata);
            saw_metadata =
                std.mem.eql(u8, ptrBytes(metadata.title_ptr, metadata.title_len), "ffi-pty-title") and
                std.mem.eql(u8, ptrBytes(metadata.cwd_ptr, metadata.cwd_len), "/tmp/ffi-pty");
        }

        {
            var events: c_api.ZideTerminalEventBuffer = .{};
            if (c_api.zide_terminal_event_drain(handle, &events) != 0) return error.EventDrainFailed;
            defer c_api.zide_terminal_events_free(&events);

            if (events.events) |event_ptr| {
                for (event_ptr[0..events.count]) |event| {
                    if (event.kind == @intFromEnum(c_api.ZideTerminalEventKind.redraw_ready)) {
                        saw_redraw = true;
                    }
                    if (event.kind == @intFromEnum(c_api.ZideTerminalEventKind.child_exit)) {
                        if (event.int0 != 7 or event.int1 != 1) return error.UnexpectedChildExitEvent;
                        saw_child_exit = true;
                    }
                }
            }
        }

        if (saw_marker and saw_child_exit and saw_metadata and saw_redraw) {
            var code: i32 = -1;
            var has_status: u8 = 0;
            if (c_api.zide_terminal_child_exit_status(handle, &code, &has_status) != 0) return error.ChildExitStatusFailed;
            if (has_status != 1 or code != 7) return error.UnexpectedChildExitStatus;
            return;
        }

        std.Thread.sleep(20 * std.time.ns_per_ms);
    }

    if (!saw_marker) return error.MissingMarker;
    if (!saw_redraw) return error.MissingRedrawReady;
    if (!saw_child_exit) return error.MissingChildExit;
    if (!saw_metadata) return error.MissingMetadata;
}

fn snapshotContains(snapshot: *const c_api.ZideTerminalSnapshot, needle: []const u8) bool {
    if (snapshot.cells == null) return false;
    const cells = snapshot.cells.?[0..snapshot.cell_count];
    const cols = snapshot.cols;
    var row: u32 = 0;
    while (row < snapshot.rows) : (row += 1) {
        var line = std.ArrayList(u8).empty;
        defer line.deinit(std.heap.page_allocator);

        var col: u32 = 0;
        while (col < cols) : (col += 1) {
            const idx: usize = @intCast(row * cols + col);
            const cell = cells[idx];
            if (cell.width == 0) continue;
            const cp = cell.codepoint;
            if (cp == 0 or cp > 0x7f) {
                line.append(std.heap.page_allocator, ' ') catch return false;
                continue;
            }
            line.append(std.heap.page_allocator, @intCast(cp)) catch return false;
        }

        if (std.mem.indexOf(u8, line.items, needle) != null) return true;
    }
    return false;
}

fn ptrBytes(ptr: ?[*]const u8, len: usize) []const u8 {
    if (len == 0) return "";
    return (ptr orelse unreachable)[0..len];
}
