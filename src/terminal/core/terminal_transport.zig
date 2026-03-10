const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig");
const io_threads = @import("io_threads.zig");
const input_mod = @import("../input/input.zig");
const types = @import("../model/types.zig");

pub const PtySize = pty_mod.PtySize;

pub const ExternalTransport = struct {
    allocator: std.mem.Allocator,
    pending: std.ArrayList(u8),
    read_offset: usize,
    alive: bool,

    pub fn init(allocator: std.mem.Allocator) ExternalTransport {
        return .{
            .allocator = allocator,
            .pending = .empty,
            .read_offset = 0,
            .alive = true,
        };
    }

    pub fn deinit(self: *ExternalTransport) void {
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn enqueue(self: *ExternalTransport, bytes: []const u8) !void {
        try self.pending.appendSlice(self.allocator, bytes);
    }

    pub fn read(self: *ExternalTransport, buffer: []u8) ?usize {
        const available = if (self.pending.items.len > self.read_offset)
            self.pending.items.len - self.read_offset
        else
            0;
        if (available == 0) return null;

        const n = @min(buffer.len, available);
        std.mem.copyForwards(u8, buffer[0..n], self.pending.items[self.read_offset .. self.read_offset + n]);
        self.read_offset += n;
        if (self.read_offset >= self.pending.items.len) {
            self.pending.items.len = 0;
            self.read_offset = 0;
        } else if (self.read_offset > 4096 and self.read_offset > self.pending.items.len / 2) {
            const remaining = self.pending.items.len - self.read_offset;
            std.mem.copyForwards(u8, self.pending.items[0..remaining], self.pending.items[self.read_offset..self.pending.items.len]);
            self.pending.items.len = remaining;
            self.read_offset = 0;
        }
        return n;
    }

    pub fn hasData(self: *const ExternalTransport) bool {
        return self.pending.items.len > self.read_offset;
    }
};

pub const Writer = struct {
    ctx: *anyopaque,
    mutex: *std.Thread.Mutex,
    write_bytes_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!usize,
    send_key_action_fn: *const fn (ctx: *anyopaque, key: types.Key, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) anyerror!bool,
    send_key_action_event_fn: *const fn (ctx: *anyopaque, event: input_mod.KeyInputEvent) anyerror!bool,
    send_keypad_fn: *const fn (ctx: *anyopaque, key: input_mod.KeypadKey, mod: types.Modifier, app_keypad: bool, key_mode_flags: u32) anyerror!bool,
    send_char_action_fn: *const fn (ctx: *anyopaque, char: u32, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) anyerror!bool,
    send_char_action_event_fn: *const fn (ctx: *anyopaque, event: input_mod.CharInputEvent) anyerror!bool,
    report_mouse_event_fn: *const fn (ctx: *anyopaque, input: *input_mod.InputState, event: types.MouseEvent, rows: u16, cols: u16) anyerror!bool,
    send_text_fn: *const fn (ctx: *anyopaque, text: []const u8) anyerror!void,

    pub fn fromSession(session: anytype) ?Writer {
        if (session.pty == null) return null;
        const SessionPtr = @TypeOf(session);
        session.pty_write_mutex.lock();
        return .{
            .ctx = @ptrCast(session),
            .mutex = &session.pty_write_mutex,
            .write_bytes_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!usize {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try pty.write(bytes) else 0;
                }
            }.call,
            .send_key_action_fn = struct {
                fn call(ctx: *anyopaque, key: types.Key, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input_mod.sendKeyAction(pty, key, mod, key_mode_flags, action) else false;
                }
            }.call,
            .send_key_action_event_fn = struct {
                fn call(ctx: *anyopaque, event: input_mod.KeyInputEvent) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input_mod.sendKeyActionEvent(pty, event) else false;
                }
            }.call,
            .send_keypad_fn = struct {
                fn call(ctx: *anyopaque, key: input_mod.KeypadKey, mod: types.Modifier, app_keypad: bool, key_mode_flags: u32) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input_mod.sendKeypad(pty, key, mod, app_keypad, key_mode_flags) else false;
                }
            }.call,
            .send_char_action_fn = struct {
                fn call(ctx: *anyopaque, char: u32, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input_mod.sendCharAction(pty, char, mod, key_mode_flags, action) else false;
                }
            }.call,
            .send_char_action_event_fn = struct {
                fn call(ctx: *anyopaque, event: input_mod.CharInputEvent) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input_mod.sendCharActionEvent(pty, event) else false;
                }
            }.call,
            .report_mouse_event_fn = struct {
                fn call(ctx: *anyopaque, input: *input_mod.InputState, event: types.MouseEvent, rows: u16, cols: u16) anyerror!bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return if (s.pty) |*pty| try input.reportMouseEvent(pty, event, rows, cols) else false;
                }
            }.call,
            .send_text_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.pty) |*pty| try input_mod.sendText(pty, text);
                }
            }.call,
        };
    }

    pub fn exists(session: anytype) bool {
        return fromSessionUnlocked(session);
    }

    fn fromSessionUnlocked(session: anytype) bool {
        return session.pty != null;
    }

    pub fn write(self: *Writer, bytes: []const u8) !usize {
        return self.write_bytes_fn(self.ctx, bytes);
    }
    pub fn sendKeyAction(self: *Writer, key: types.Key, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) !bool {
        return self.send_key_action_fn(self.ctx, key, mod, key_mode_flags, action);
    }
    pub fn sendKeyActionEvent(self: *Writer, event: input_mod.KeyInputEvent) !bool {
        return self.send_key_action_event_fn(self.ctx, event);
    }
    pub fn sendKeypad(self: *Writer, key: input_mod.KeypadKey, mod: types.Modifier, app_keypad: bool, key_mode_flags: u32) !bool {
        return self.send_keypad_fn(self.ctx, key, mod, app_keypad, key_mode_flags);
    }
    pub fn sendCharAction(self: *Writer, char: u32, mod: types.Modifier, key_mode_flags: u32, action: input_mod.KeyAction) !bool {
        return self.send_char_action_fn(self.ctx, char, mod, key_mode_flags, action);
    }
    pub fn sendCharActionEvent(self: *Writer, event: input_mod.CharInputEvent) !bool {
        return self.send_char_action_event_fn(self.ctx, event);
    }
    pub fn reportMouseEvent(self: *Writer, input: *input_mod.InputState, event: types.MouseEvent, rows: u16, cols: u16) !bool {
        return self.report_mouse_event_fn(self.ctx, input, event, rows, cols);
    }
    pub fn sendText(self: *Writer, text: []const u8) !void {
        try self.send_text_fn(self.ctx, text);
    }
    pub fn unlock(self: *Writer) void {
        self.mutex.unlock();
    }
};

pub const Transport = struct {
    ctx: *anyopaque,
    read_fn: *const fn (ctx: *anyopaque, buffer: []u8) anyerror!?usize,
    wait_for_data_fn: *const fn (ctx: *anyopaque, timeout_ms: i32) bool,
    has_data_fn: *const fn (ctx: *anyopaque) bool,
    poll_exit_fn: *const fn (ctx: *anyopaque) anyerror!?i32,
    resize_fn: *const fn (ctx: *anyopaque, size: PtySize) anyerror!void,
    deinit_fn: *const fn (ctx: *anyopaque) void,
    is_alive_fn: *const fn (ctx: *anyopaque) bool,
    foreground_process_label_fn: *const fn (ctx: *anyopaque) ?[]const u8,
    has_foreground_process_outside_shell_fn: *const fn (ctx: *anyopaque) bool,

    pub fn fromSession(session: anytype) ?Transport {
        const SessionPtr = @TypeOf(session);
        if (session.pty != null) {
            return .{
                .ctx = @ptrCast(session),
                .read_fn = struct {
                    fn call(ctx: *anyopaque, buffer: []u8) anyerror!?usize {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.pty) |*pty| try pty.read(buffer) else null;
                    }
                }.call,
                .wait_for_data_fn = struct {
                    fn call(ctx: *anyopaque, timeout_ms: i32) bool {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.pty) |*pty| pty.waitForData(timeout_ms) else false;
                    }
                }.call,
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
        if (session.external_transport != null) {
            return .{
                .ctx = @ptrCast(session),
                .read_fn = struct {
                    fn call(ctx: *anyopaque, buffer: []u8) anyerror!?usize {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.external_transport) |*transport| transport.read(buffer) else null;
                    }
                }.call,
                .wait_for_data_fn = struct {
                    fn call(ctx: *anyopaque, _: i32) bool {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.external_transport) |*transport| transport.hasData() else false;
                    }
                }.call,
                .has_data_fn = struct {
                    fn call(ctx: *anyopaque) bool {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.external_transport) |*transport| transport.hasData() else false;
                    }
                }.call,
                .poll_exit_fn = struct {
                    fn call(_: *anyopaque) anyerror!?i32 {
                        return null;
                    }
                }.call,
                .resize_fn = struct {
                    fn call(_: *anyopaque, _: PtySize) anyerror!void {}
                }.call,
                .deinit_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        if (s.external_transport) |*transport| transport.deinit();
                        s.external_transport = null;
                    }
                }.call,
                .is_alive_fn = struct {
                    fn call(ctx: *anyopaque) bool {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        return if (s.external_transport) |*transport| transport.alive else false;
                    }
                }.call,
                .foreground_process_label_fn = struct {
                    fn call(_: *anyopaque) ?[]const u8 {
                        return null;
                    }
                }.call,
                .has_foreground_process_outside_shell_fn = struct {
                    fn call(_: *anyopaque) bool {
                        return false;
                    }
                }.call,
            };
        }
        return null;
    }

    pub fn exists(session: anytype) bool {
        return session.pty != null or session.external_transport != null;
    }

    pub fn read(self: *const Transport, buffer: []u8) !?usize {
        return self.read_fn(self.ctx, buffer);
    }
    pub fn waitForData(self: *const Transport, timeout_ms: i32) bool {
        return self.wait_for_data_fn(self.ctx, timeout_ms);
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
    attachPty(self, pty);
    if (!spawn_threads) return;
    if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
        self.read_thread_running.store(true, .release);
        self.read_thread = try std.Thread.spawn(.{}, io_threads.readThreadMain, .{self});
        self.parse_thread_running.store(true, .release);
        self.parse_thread = try std.Thread.spawn(.{}, io_threads.parseThreadMain, .{self});
    }
}

pub fn attachPty(self: anytype, pty: pty_mod.Pty) void {
    detachExternalTransport(self);
    self.pty = pty;
}

pub fn detachPty(self: anytype) void {
    self.pty = null;
}

pub fn attachExternalTransport(self: anytype) void {
    if (self.external_transport == null) {
        self.external_transport = ExternalTransport.init(self.allocator);
    } else if (self.pty != null) {
        detachPty(self);
    }
}

pub fn detachExternalTransport(self: anytype) void {
    if (self.external_transport) |*transport| {
        transport.deinit();
        self.external_transport = null;
    }
}

pub fn closeExternalTransport(self: anytype) bool {
    if (self.external_transport) |*transport| {
        transport.alive = false;
        return true;
    }
    return false;
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    if (self.external_transport) |*transport| {
        try transport.enqueue(bytes);
        return true;
    }
    return false;
}
