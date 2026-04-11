const std = @import("std");
const builtin = @import("builtin");
const c_api = @import("../terminal/ffi/c_api.zig");
const ffi_shared = @import("../terminal/ffi/shared.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");

const initial_cols: u16 = 80;
const initial_rows: u16 = 24;
const initial_cell_width: u16 = 8;
const initial_cell_height: u16 = 16;
const shell_path: [:0]const u8 = "/system/bin/sh";
const transcript_path = "/data/data/dev.zide.terminal/files/zide_terminal_shell.log";

pub const StartStatus = enum(i32) {
    none = 0,
    started = 1,
    unsupported = 2,
    create_failed = 3,
    resize_failed = 4,
    start_failed = 5,
    send_failed = 6,
    poll_failed = 7,
    snapshot_failed = 8,
};

const Session = struct {
    handle: ?*c_api.ZideTerminalHandle,
    cols: u16,
    rows: u16,
    cell_width: u16,
    cell_height: u16,

    fn deinit(self: *Session) void {
        c_api.zide_terminal_destroy(self.handle);
        self.handle = null;
    }
};

var session: ?Session = null;
var last_start_status: StartStatus = .none;

pub fn transcriptPath() []const u8 {
    return transcript_path;
}

pub fn lastStartStatus() StartStatus {
    return last_start_status;
}

pub fn activeRuntimeShell() ?*terminal_runtime.TerminalRuntimeShell {
    const active = session orelse return null;
    const handle = ffi_shared.fromOpaqueActive(active.handle) orelse return null;
    return handle.shell;
}

pub fn isAlive() bool {
    const active = session orelse return false;
    return c_api.zide_terminal_is_alive(active.handle) != 0;
}

pub const SendStatus = enum(i32) {
    ok = 0,
    no_session = 1,
    send_failed = 2,
};

pub fn sendText(text: []const u8) SendStatus {
    const active = session orelse return .no_session;
    if (text.len == 0) return .ok;
    if (c_api.zide_terminal_send_text(active.handle, text.ptr, text.len) != 0) {
        return .send_failed;
    }
    return .ok;
}

pub fn sendCodepoint(cp: u21) SendStatus {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(cp, &buf) catch return .send_failed;
    return sendText(buf[0..len]);
}

pub fn resizeToGrid(cols: u16, rows: u16, cell_width: u16, cell_height: u16) !bool {
    const active = session orelse return false;
    if (cols == 0 or rows == 0 or cell_width == 0 or cell_height == 0) return false;
    if (active.cols == cols and active.rows == rows and active.cell_width == cell_width and active.cell_height == cell_height) {
        return false;
    }

    if (c_api.zide_terminal_resize(active.handle, cols, rows, cell_width, cell_height) != 0) {
        last_start_status = .resize_failed;
        return error.ResizeFailed;
    }

    session = .{
        .handle = active.handle,
        .cols = cols,
        .rows = rows,
        .cell_width = cell_width,
        .cell_height = cell_height,
    };
    try pollAndRefresh();
    return true;
}

pub fn restart() !void {
    if (!(builtin.target.os.tag == .linux and builtin.target.abi == .android)) {
        last_start_status = .unsupported;
        return error.Unsupported;
    }

    stop();
    std.fs.deleteFileAbsolute(transcript_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) {
        last_start_status = .create_failed;
        return error.CreateFailed;
    }
    errdefer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, initial_cols, initial_rows, initial_cell_width, initial_cell_height) != 0) {
        last_start_status = .resize_failed;
        return error.ResizeFailed;
    }

    if (c_api.zide_terminal_start(handle, shell_path.ptr) != 0) {
        last_start_status = .start_failed;
        return error.StartFailed;
    }

    session = .{
        .handle = handle,
        .cols = initial_cols,
        .rows = initial_rows,
        .cell_width = initial_cell_width,
        .cell_height = initial_cell_height,
    };
    last_start_status = .started;
    try pollAndRefresh();
}

pub fn stop() void {
    if (session) |*active| {
        active.deinit();
        session = null;
    }
}

pub fn pollAndRefresh() !void {
    const active = session orelse return;

    if (c_api.zide_terminal_poll(active.handle) != 0) {
        last_start_status = .poll_failed;
        return error.PollFailed;
    }

    var events: c_api.ZideTerminalEventBuffer = .{};
    if (c_api.zide_terminal_event_drain(active.handle, &events) != 0) {
        last_start_status = .poll_failed;
        return error.EventDrainFailed;
    }
    defer c_api.zide_terminal_events_free(&events);

    var snapshot: c_api.ZideTerminalSnapshot = .{};
    const request = snapshotRequest();
    if (c_api.zide_terminal_snapshot_acquire(active.handle, &request, &snapshot) != 0) {
        last_start_status = .snapshot_failed;
        return error.SnapshotAcquireFailed;
    }
    defer c_api.zide_terminal_snapshot_release(&snapshot);

    try writeTranscriptSnapshot(&snapshot);
}

fn writeTranscriptSnapshot(snapshot: *const c_api.ZideTerminalSnapshot) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.heap.page_allocator);

    var lines = std.ArrayList(std.ArrayList(u8)).empty;
    defer {
        for (lines.items) |*line| line.deinit(std.heap.page_allocator);
        lines.deinit(std.heap.page_allocator);
    }

    var last_nonempty_row: usize = 0;
    var saw_nonempty = false;

    var row: usize = 0;
    while (row < snapshot.rows) : (row += 1) {
        var line = try snapshotRowText(snapshot, row);
        const trimmed = std.mem.trimRight(u8, line.items, " ");
        if (trimmed.len != line.items.len) {
            try line.resize(std.heap.page_allocator, trimmed.len);
        }
        if (line.items.len > 0) {
            last_nonempty_row = row;
            saw_nonempty = true;
        }
        try lines.append(std.heap.page_allocator, line);
    }

    const line_count = if (saw_nonempty) last_nonempty_row + 1 else 0;
    row = 0;
    while (row < line_count) : (row += 1) {
        try out.appendSlice(std.heap.page_allocator, lines.items[row].items);
        if (row + 1 < line_count) try out.append(std.heap.page_allocator, '\n');
    }

    const file = try std.fs.createFileAbsolute(transcript_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(out.items);
}

fn snapshotRowText(snapshot: *const c_api.ZideTerminalSnapshot, row: usize) !std.ArrayList(u8) {
    var line = std.ArrayList(u8).empty;
    errdefer line.deinit(std.heap.page_allocator);
    if (snapshot.cells == null) return line;
    const cells = snapshot.cells.?[0..snapshot.cell_count];
    const snapshot_cols: usize = @intCast(snapshot.cols);
    var col: usize = 0;
    while (col < snapshot_cols) : (col += 1) {
        const idx = row * snapshot_cols + col;
        const cell = cells[idx];
        if (cell.width == 0) continue;
        const cp = cell.codepoint;
        try line.append(std.heap.page_allocator, if (cp == 0 or cp > 0x7f) ' ' else @intCast(cp));
    }
    return line;
}

fn snapshotRequest() c_api.ZideTerminalSnapshotRequest {
    return .{
        .abi_version = c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION,
        .struct_size = @sizeOf(c_api.ZideTerminalSnapshotRequest),
        .reserved0 = 0,
        .reserved1 = 0,
    };
}

test "shell transcript path is stable" {
    try std.testing.expectEqualStrings(
        "/data/data/dev.zide.terminal/files/zide_terminal_shell.log",
        transcriptPath(),
    );
}
