const std = @import("std");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const publication_flow = @import("../publication/publication_flow.zig");

pub fn deinit(self: anytype) void {
    prepareForShutdown(self);
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        transport.deinit();
    }
    if (self.runtime.launch_shell_path) |path| {
        self.allocator.free(path);
        self.runtime.launch_shell_path = null;
    }
    self.publication.render_caches[0].deinit(self.allocator);
    self.publication.render_caches[1].deinit(self.allocator);
    self.runtime.io_buffer.deinit(self.allocator);
    self.core.deinit(self);
    self.allocator.destroy(self);
}

pub fn prepareForShutdown(self: anytype) void {
    if (!self.runtime.tearing_down) {
        self.runtime.tearing_down = true;
    }
    stopThreads(self);
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        transport.deinit();
    }
}

pub fn hasData(self: anytype) bool {
    if (self.runtime.read_thread != null) {
        if (self.runtime.parse_thread != null) {
            return publication_flow.outputPending(self) or hasUnreadBufferedIo(self);
        }
        if (publication_flow.outputPending(self)) return true;
        return hasUnreadBufferedIo(self);
    }
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        return transport.hasData();
    }
    return false;
}

pub fn pollBacklogHint(self: anytype) bool {
    return hasData(self) or @import("../publication/publication_flow.zig").hasPublishedGenerationBacklog(self);
}

fn hasUnreadBufferedIo(self: anytype) bool {
    var pending = false;
    self.runtime.io_mutex.lock();
    if (self.runtime.io_buffer.items.len > self.runtime.io_read_offset) {
        pending = true;
    }
    self.runtime.io_mutex.unlock();
    return pending;
}

fn stopThreads(self: anytype) void {
    if (self.runtime.read_thread) |thread| {
        self.runtime.read_thread_running.store(false, .release);
        thread.join();
        self.runtime.read_thread = null;
    }
    if (self.runtime.parse_thread) |thread| {
        self.runtime.parse_thread_running.store(false, .release);
        self.runtime.io_wait_cond.signal();
        thread.join();
        self.runtime.parse_thread = null;
    }
}

test "hasData stays true for threaded session while unread parse buffer remains" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    const session = try session_runtime.init(allocator, 24, 80, .{});
    defer {
        session.runtime.read_thread = null;
        session.runtime.parse_thread = null;
        session.deinit();
    }

    session.runtime.read_thread = undefined;
    session.runtime.parse_thread = undefined;
    publication_flow.clearPublishedOutputPending(session);
    try session.runtime.io_buffer.appendSlice(session.allocator, "queued");
    session.runtime.io_read_offset = 0;

    try std.testing.expect(hasData(session));
}
