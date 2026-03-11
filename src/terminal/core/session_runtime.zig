const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const pty_io = @import("pty_io.zig");
const resize_reflow = @import("resize_reflow.zig");
const terminal_transport = @import("terminal_transport.zig");
const pty_mod = @import("../io/pty.zig");
const terminal_core_mod = @import("terminal_core.zig");
const input_mod = @import("../input/input.zig");
const render_cache_mod = @import("render_cache.zig");
const input_modes = @import("input_modes.zig");

const Pty = pty_mod.Pty;
const TerminalCore = terminal_core_mod.TerminalCore;
const RenderCache = render_cache_mod.RenderCache;
const InputSnapshot = @import("terminal_session.zig").InputSnapshot;

pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, options: anytype) !*@import("terminal_session.zig").TerminalSession {
    const Session = @import("terminal_session.zig").TerminalSession;
    const session = try allocator.create(Session);
    const scrollback_rows = options.scrollback_rows orelse @import("terminal_session.zig").default_scrollback_rows;
    const log = app_logger.logger("terminal.core");
    log.logf(.info, "terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, scrollback_rows });
    const core = try TerminalCore.init(allocator, rows, cols, .{
        .scrollback_rows = scrollback_rows,
        .cursor_style = options.cursor_style,
    });
    session.* = .{
        .allocator = allocator,
        .pty = null,
        .external_transport = null,
        .core = core,
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
        .pty_write_mutex = .{},
        .cell_width = 0,
        .cell_height = 0,
        .read_thread = null,
        .read_thread_running = std.atomic.Value(bool).init(false),
        .parse_thread = null,
        .parse_thread_running = std.atomic.Value(bool).init(false),
        .state_mutex = .{},
        .io_mutex = .{},
        .io_wait_cond = .{},
        .io_buffer = .empty,
        .io_read_offset = 0,
        .output_pending = std.atomic.Value(bool).init(false),
        .output_generation = std.atomic.Value(u64).init(0),
        .presented_generation = std.atomic.Value(u64).init(0),
        .input_pressure = std.atomic.Value(bool).init(false),
        .alt_exit_pending = std.atomic.Value(bool).init(false),
        .alt_exit_time_ms = std.atomic.Value(i64).init(-1),
        .last_parse_log_ms = 0,
        .parse_publishes_since_log = 0,
        .parse_bytes_since_log = 0,
        .last_parse_publish_ms = 0,
        .parse_bytes_since_publish = 0,
        .render_caches = .{ RenderCache.init(), RenderCache.init() },
        .render_cache_index = std.atomic.Value(u8).init(0),
        .view_cache_pending = std.atomic.Value(bool).init(false),
        .view_cache_request_offset = std.atomic.Value(u64).init(0),
        .child_exited = std.atomic.Value(bool).init(false),
        .child_exit_code = std.atomic.Value(i32).init(-1),
    };
    input_modes.publishSnapshot(session);
    return session;
}

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try terminal_transport.openPty(self, shell, true);
}

pub fn attachPtyTransport(self: anytype, pty: Pty) void {
    terminal_transport.attachPty(self, pty);
}

pub fn detachPtyTransport(self: anytype) void {
    terminal_transport.detachPty(self);
}

pub fn attachExternalTransport(self: anytype) void {
    terminal_transport.attachExternalTransport(self);
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    return try terminal_transport.enqueueExternalBytes(self, bytes);
}

pub fn closeExternalTransport(self: anytype) bool {
    return terminal_transport.closeExternalTransport(self);
}

pub fn deinit(self: anytype) void {
    if (self.read_thread) |thread| {
        self.read_thread_running.store(false, .release);
        thread.join();
        self.read_thread = null;
    }
    if (self.parse_thread) |thread| {
        self.parse_thread_running.store(false, .release);
        self.io_wait_cond.signal();
        thread.join();
        self.parse_thread = null;
    }
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        transport.deinit();
    }
    self.render_caches[0].deinit(self.allocator);
    self.render_caches[1].deinit(self.allocator);
    self.io_buffer.deinit(self.allocator);
    self.core.deinit(self);
    self.allocator.destroy(self);
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try terminal_transport.openPty(self, shell, false);
}

pub fn setInputPressure(self: anytype, value: bool) void {
    self.input_pressure.store(value, .release);
}

pub fn poll(self: anytype) !void {
    maybeUpdateChildExit(self);
    return pty_io.poll(self);
}

pub fn refreshChildExit(self: anytype) void {
    maybeUpdateChildExit(self);
}

fn maybeUpdateChildExit(self: anytype) void {
    if (self.child_exited.load(.acquire)) return;
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        if (transport.pollExit() catch |err| blk: {
            const log = app_logger.logger("terminal.pty");
            log.logf(.warning, "pty pollExit failed err={s}", .{@errorName(err)});
            break :blk null;
        }) |code| {
            self.child_exit_code.store(code, .release);
            self.child_exited.store(true, .release);

            const log = app_logger.logger("terminal.pty");
            log.logf(.info, "pty child exited code={d}", .{code});
        }
    }
}

pub fn hasData(self: anytype) bool {
    if (self.read_thread != null) {
        if (self.parse_thread != null) {
            return self.output_pending.load(.acquire);
        }
        if (self.output_pending.load(.acquire)) return true;
        var pending = false;
        self.io_mutex.lock();
        if (self.io_buffer.items.len > self.io_read_offset) {
            pending = true;
        }
        self.io_mutex.unlock();
        return pending;
    }
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        return transport.hasData();
    }
    return false;
}

pub fn pollBacklogHint(self: anytype) bool {
    return hasData(self) or @import("session_rendering.zig").hasPublishedGenerationBacklog(self);
}

pub fn lockPtyWriter(self: anytype) ?@import("terminal_session.zig").PtyWriteGuard {
    return terminal_transport.Writer.fromSession(self);
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    var writer = lockPtyWriter(self) orelse return;
    defer writer.unlock();
    _ = try writer.write(bytes);
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try resize_reflow.resize(self, rows, cols);
    try reportInBandResize2048(self, rows, cols);
}

fn reportInBandResize2048(self: anytype, rows: u16, cols: u16) !void {
    if (!self.inband_resize_notifications_2048) return;
    if (lockPtyWriter(self)) |writer_guard| {
        var writer = writer_guard;
        const rows_px: u32 = @as(u32, rows) * @as(u32, self.cell_height);
        const cols_px: u32 = @as(u32, cols) * @as(u32, self.cell_width);
        var buf: [64]u8 = undefined;
        const seq = try std.fmt.bufPrint(
            &buf,
            "\x1b[48;{d};{d};{d};{d}t",
            .{ rows, cols, rows_px, cols_px },
        );
        defer writer.unlock();
        _ = try writer.write(seq);
    }
}
