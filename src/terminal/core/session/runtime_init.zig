const std = @import("std");
const pty_mod = @import("../../io/pty.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const input_mod = @import("../../input/input.zig");
const render_cache_mod = @import("../publication/render_cache.zig");
const input_modes = @import("../input_modes.zig");
const input_snapshot_mod = @import("input_snapshot.zig");

const TerminalCore = terminal_core_mod.TerminalCore;
const RenderCache = render_cache_mod.RenderCache;
const InputSnapshot = input_snapshot_mod.InputSnapshot;

const default_scrollback_rows: usize = 1000;

pub fn init(self_type: type, allocator: std.mem.Allocator, rows: u16, cols: u16, options: anytype) !*self_type {
    const Session = self_type;
    const session = try allocator.create(Session);
    const has_scrollback_rows = comptime @hasField(@TypeOf(options), "scrollback_rows");
    const has_cursor_style = comptime @hasField(@TypeOf(options), "cursor_style");
    const scrollback_rows = if (has_scrollback_rows)
        options.scrollback_rows orelse default_scrollback_rows
    else
        default_scrollback_rows;
    const core = try TerminalCore.init(allocator, rows, cols, .{
        .scrollback_rows = scrollback_rows,
        .cursor_style = if (has_cursor_style) options.cursor_style else null,
    });
    session.* = .{
        .allocator = allocator,
        .session = .{
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
        },
        .core = core,
    };
    input_modes.publishSnapshot(session);
    return session;
}
