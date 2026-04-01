const std = @import("std");
const pty_io = @import("../pty_io.zig");
const terminal_transport = @import("../terminal_transport.zig");
const pty_mod = @import("../../io/pty.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const input_mod = @import("../../input/input.zig");
const render_cache_mod = @import("../publication/render_cache.zig");
const input_modes = @import("../input_modes.zig");
const session_lifecycle = @import("session_lifecycle.zig");
const session_transport_runtime = @import("session_transport_runtime.zig");
const session_thread_runtime = @import("session_thread_runtime.zig");

const Pty = pty_mod.Pty;
const TerminalCore = terminal_core_mod.TerminalCore;
const RenderCache = render_cache_mod.RenderCache;
const InputSnapshot = @import("../pty_terminal_runtime.zig").InputSnapshot;

pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, options: anytype) !*@import("../pty_terminal_runtime.zig").PtyTerminalRuntime {
    const Session = @import("../pty_terminal_runtime.zig").PtyTerminalRuntime;
    const session = try allocator.create(Session);
    const has_scrollback_rows = comptime @hasField(@TypeOf(options), "scrollback_rows");
    const has_cursor_style = comptime @hasField(@TypeOf(options), "cursor_style");
    const scrollback_rows = if (has_scrollback_rows)
        options.scrollback_rows orelse @import("../pty_terminal_runtime.zig").default_scrollback_rows
    else
        @import("../pty_terminal_runtime.zig").default_scrollback_rows;
    const core = try TerminalCore.init(allocator, rows, cols, .{
        .scrollback_rows = scrollback_rows,
        .cursor_style = if (has_cursor_style) options.cursor_style else null,
    });
    session.* = .{
        .allocator = allocator,
        .runtime = .{
            .pty = null,
            .external_transport = null,
            .pty_write_mutex = .{},
            .read_thread = null,
            .read_thread_running = std.atomic.Value(bool).init(false),
            .parse_thread = null,
            .parse_thread_running = std.atomic.Value(bool).init(false),
            .io_mutex = .{},
            .io_wait_cond = .{},
            .io_buffer = .empty,
            .io_read_offset = 0,
            .child_exited = std.atomic.Value(bool).init(false),
            .child_exit_code = std.atomic.Value(i32).init(-1),
            .launch_shell_path = null,
            .tearing_down = false,
        },
        .core = core,
        .interaction = .{
            .bracketed_paste = false,
            .focus_reporting = false,
            .auto_repeat = true,
            .app_cursor_keys = false,
            .app_keypad = false,
            .mouse_alternate_scroll = true,
            .inband_resize_notifications_2048 = false,
            .report_color_scheme_2031 = false,
            .grapheme_cluster_shaping_2027 = false,
            .color_scheme_dark = true,
            .kitty_paste_events_5522 = false,
            .input = input_mod.InputState.init(),
            .input_snapshot = InputSnapshot.init(),
            .cell_width = 0,
            .cell_height = 0,
        },
        .control = .{
            .state_mutex = .{},
            .input_pressure = std.atomic.Value(bool).init(false),
            .last_parse_log_ms = 0,
            .parse_publishes_since_log = 0,
            .parse_bytes_since_log = 0,
            .last_parse_publish_ms = 0,
            .parse_bytes_since_publish = 0,
        },
        .publication = .{
            .output_pending = std.atomic.Value(bool).init(false),
            .pending_generation = std.atomic.Value(u64).init(0),
            .presented_generation = std.atomic.Value(u64).init(0),
            .alt_exit_pending = std.atomic.Value(bool).init(false),
            .alt_exit_time_ms = std.atomic.Value(i64).init(-1),
            .render_caches = .{ RenderCache.init(), RenderCache.init() },
            .render_cache_index = std.atomic.Value(u8).init(0),
            .view_cache_pending = std.atomic.Value(bool).init(false),
            .view_cache_request_offset = std.atomic.Value(u64).init(0),
        },
    };
    input_modes.publishSnapshot(session);
    return session;
}

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try session_transport_runtime.start(self, shell);
}

pub fn attachPtyTransport(self: anytype, pty: Pty) void {
    session_transport_runtime.attachPtyTransport(self, pty);
}

pub fn detachPtyTransport(self: anytype) void {
    session_transport_runtime.detachPtyTransport(self);
}

pub fn attachExternalTransport(self: anytype) void {
    session_transport_runtime.attachExternalTransport(self);
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    return try session_transport_runtime.enqueueExternalBytes(self, bytes);
}

pub fn closeExternalTransport(self: anytype) bool {
    return session_transport_runtime.closeExternalTransport(self);
}

pub fn reportExternalChildExit(self: anytype, code: ?i32) bool {
    return session_lifecycle.reportExternalChildExit(self, code);
}

pub fn deinit(self: anytype) void {
    session_thread_runtime.deinit(self);
}

pub fn prepareForShutdown(self: anytype) void {
    session_lifecycle.refreshChildExit(self);
    session_thread_runtime.prepareForShutdown(self);
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try session_transport_runtime.startNoThreads(self, shell);
}

pub fn setInputPressure(self: anytype, value: bool) void {
    self.control.input_pressure.store(value, .release);
}

pub fn poll(self: anytype) !void {
    session_lifecycle.maybeUpdateChildExit(self);
    return pty_io.poll(self);
}

pub fn refreshChildExit(self: anytype) void {
    session_lifecycle.refreshChildExit(self);
}

pub fn hasData(self: anytype) bool {
    return session_thread_runtime.hasData(self);
}

pub fn pollBacklogHint(self: anytype) bool {
    return session_thread_runtime.pollBacklogHint(self);
}

pub fn lockPtyWriter(self: anytype) ?@import("../pty_terminal_runtime.zig").PtyWriteGuard {
    return session_transport_runtime.lockPtyWriter(self);
}

pub fn takeExternalOutgoingBytes(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    return try session_transport_runtime.takeExternalOutgoingBytes(self, allocator);
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    try session_transport_runtime.writePtyBytes(self, bytes);
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try session_transport_runtime.resize(self, rows, cols);
}
