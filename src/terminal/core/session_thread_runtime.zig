const terminal_transport = @import("terminal_transport.zig");

pub fn deinit(self: anytype) void {
    stopThreads(self);
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        transport.deinit();
    }
    self.render_caches[0].deinit(self.allocator);
    self.render_caches[1].deinit(self.allocator);
    self.io_buffer.deinit(self.allocator);
    self.core.deinit(self);
    self.allocator.destroy(self);
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

fn stopThreads(self: anytype) void {
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
}
