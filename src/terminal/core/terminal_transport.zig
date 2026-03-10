const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig");
const io_threads = @import("io_threads.zig");

pub const PtySize = pty_mod.PtySize;

pub const Transport = struct {
    ctx: *anyopaque,
    has_data_fn: *const fn (ctx: *anyopaque) bool,
    poll_exit_fn: *const fn (ctx: *anyopaque) anyerror!?i32,
    resize_fn: *const fn (ctx: *anyopaque, size: PtySize) anyerror!void,
    deinit_fn: *const fn (ctx: *anyopaque) void,
    is_alive_fn: *const fn (ctx: *anyopaque) bool,
    foreground_process_label_fn: *const fn (ctx: *anyopaque) ?[]const u8,
    has_foreground_process_outside_shell_fn: *const fn (ctx: *anyopaque) bool,

    pub fn fromSession(session: anytype) ?Transport {
        if (session.pty == null) return null;
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .has_data_fn = struct {
                fn call(ctx: *anyopaque) bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.pty != null and s.pty.?.hasData();
                }
            }.call,
            .poll_exit_fn = struct {
                fn call(ctx: *anyopaque) anyerror!?i32 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.pty) |*pty| return try pty.pollExit();
                    return null;
                }
            }.call,
            .resize_fn = struct {
                fn call(ctx: *anyopaque, size: PtySize) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.pty) |*pty| try pty.resize(size);
                }
            }.call,
            .deinit_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.pty) |*pty| pty.deinit();
                    s.pty = null;
                }
            }.call,
            .is_alive_fn = struct {
                fn call(ctx: *anyopaque) bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| pty.isAlive() else false;
                }
            }.call,
            .foreground_process_label_fn = struct {
                fn call(ctx: *anyopaque) ?[]const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| pty.foregroundProcessLabel() else null;
                }
            }.call,
            .has_foreground_process_outside_shell_fn = struct {
                fn call(ctx: *anyopaque) bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| pty.hasForegroundProcessOutsideShell() else false;
                }
            }.call,
        };
    }

    pub fn hasData(self: *const Transport) bool {
        return self.has_data_fn(self.ctx);
    }
    pub fn pollExit(self: *const Transport) !?i32 {
        return self.poll_exit_fn(self.ctx);
    }
    pub fn resize(self: *const Transport, size: PtySize) !void {
        try self.resize_fn(self.ctx, size);
    }
    pub fn deinit(self: *const Transport) void {
        self.deinit_fn(self.ctx);
    }
    pub fn isAlive(self: *const Transport) bool {
        return self.is_alive_fn(self.ctx);
    }
    pub fn foregroundProcessLabel(self: *const Transport) ?[]const u8 {
        return self.foreground_process_label_fn(self.ctx);
    }
    pub fn hasForegroundProcessOutsideShell(self: *const Transport) bool {
        return self.has_foreground_process_outside_shell_fn(self.ctx);
    }
};

pub fn openPty(self: anytype, shell: ?[:0]const u8, spawn_threads: bool) !void {
    const size = PtySize{
        .rows = self.core.primary.grid.rows,
        .cols = self.core.primary.grid.cols,
        .cell_width = self.cell_width,
        .cell_height = self.cell_height,
    };
    const pty = try pty_mod.Pty.init(self.allocator, size, shell);
    self.pty = pty;
    if (!spawn_threads) return;
    if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
        self.read_thread_running.store(true, .release);
        self.read_thread = try std.Thread.spawn(.{}, io_threads.readThreadMain, .{self});
        self.parse_thread_running.store(true, .release);
        self.parse_thread = try std.Thread.spawn(.{}, io_threads.parseThreadMain, .{self});
    }
}
