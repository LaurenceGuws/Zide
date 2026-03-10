const std = @import("std");
const scrollback_view = @import("scrollback_view.zig");
const terminal_transport = @import("terminal_transport.zig");

pub const SessionMetadata = struct {
    title: []const u8,
    cwd: []const u8,
    scrollback_count: usize,
    scrollback_offset: usize,
    alive: bool,
    exit_code: ?i32,
};

pub const CloseConfirmSignals = struct {
    foreground_process: bool = false,
    semantic_command: bool = false,
    alt_screen: bool = false,
    mouse_reporting: bool = false,

    pub fn any(self: CloseConfirmSignals) bool {
        return self.foreground_process or self.semantic_command or self.alt_screen or self.mouse_reporting;
    }
};

fn copyTextInto(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) ![]const u8 {
    out.clearRetainingCapacity();
    try out.appendSlice(allocator, text);
    return out.items;
}

pub fn copyMetadata(
    self: anytype,
    allocator: std.mem.Allocator,
    title_out: *std.ArrayList(u8),
    cwd_out: *std.ArrayList(u8),
) !SessionMetadata {
    self.lock();
    defer self.unlock();

    const title = if (terminal_transport.Transport.fromSession(self)) |transport|
        (transport.foregroundProcessLabel() orelse self.core.title)
    else
        self.core.title;
    const cwd = self.core.cwd;
    const scrollback = scrollback_view.scrollbackInfo(self);
    const scroll_offset: usize = if (self.core.active == .alt) 0 else self.core.history.scrollOffset();
    const alive = if (terminal_transport.Transport.fromSession(self)) |transport| transport.isAlive() else false;
    const exit_code = if (self.child_exited.load(.acquire))
        self.child_exit_code.load(.acquire)
    else
        null;

    return .{
        .title = try copyTextInto(allocator, title_out, title),
        .cwd = try copyTextInto(allocator, cwd_out, cwd),
        .scrollback_count = scrollback.total_rows,
        .scrollback_offset = scroll_offset,
        .alive = alive,
        .exit_code = exit_code,
    };
}

pub fn closeConfirmSignals(self: anytype) CloseConfirmSignals {
    var signals = CloseConfirmSignals{};
    if (!isAlive(self)) return signals;

    if (terminal_transport.Transport.fromSession(self)) |transport| {
        signals.foreground_process = transport.hasForegroundProcessOutsideShell();
    }
    signals.semantic_command = self.core.semantic_prompt.input_active or self.core.semantic_prompt.output_active;
    signals.alt_screen = self.core.active == .alt;
    signals.mouse_reporting = self.mouseReportingEnabled();
    return signals;
}

pub fn shouldConfirmClose(self: anytype) bool {
    return closeConfirmSignals(self).any();
}

pub fn isAlive(self: anytype) bool {
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        return transport.isAlive();
    }
    return false;
}
