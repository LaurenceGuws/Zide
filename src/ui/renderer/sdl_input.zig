const std = @import("std");
const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const sdl = gl.c;

pub const InputQueue = struct {
    mutex: std.Thread.Mutex = .{},
    events: []sdl.SDL_Event = &.{},
    head: usize = 0,
    tail: usize = 0,
    count: usize = 0,
    dropped: usize = 0,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !InputQueue {
        return .{
            .events = try allocator.alloc(sdl.SDL_Event, capacity),
        };
    }

    pub fn deinit(self: *InputQueue, allocator: std.mem.Allocator) void {
        if (self.events.len == 0) return;
        allocator.free(self.events);
        self.events = &.{};
        self.head = 0;
        self.tail = 0;
        self.count = 0;
        self.dropped = 0;
    }

    pub fn push(self: *InputQueue, event: sdl.SDL_Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.events.len == 0) return;

        if (self.count == self.events.len) {
            self.head = (self.head + 1) % self.events.len;
            self.count -= 1;
            self.dropped +|= 1;
        }

        self.events[self.tail] = event;
        self.tail = (self.tail + 1) % self.events.len;
        self.count += 1;
    }

    pub fn drain(self: *InputQueue, out: *std.ArrayList(sdl.SDL_Event)) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == 0) return;
        if (out.capacity < self.count) return;

        var idx = self.head;
        for (0..self.count) |_| {
            out.appendAssumeCapacity(self.events[idx]);
            idx = (idx + 1) % self.events.len;
        }
        self.head = 0;
        self.tail = 0;
        self.count = 0;
    }
};

pub const SdlInput = struct {
    queue: InputQueue = .{},
    drain: std.ArrayList(sdl.SDL_Event) = .{},
    thread: ?std.Thread = null,
    thread_running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    wait_mutex: std.Thread.Mutex = .{},
    wait_cond: std.Thread.Condition = .{},

    pub fn init(self: *SdlInput, allocator: std.mem.Allocator, capacity: usize) !void {
        self.queue = try InputQueue.init(allocator, capacity);
        self.drain = std.ArrayList(sdl.SDL_Event).empty;
        try self.drain.ensureTotalCapacity(allocator, capacity);
    }

    pub fn deinit(self: *SdlInput, allocator: std.mem.Allocator) void {
        self.drain.deinit(allocator);
        self.queue.deinit(allocator);
    }

    pub fn startThread(self: *SdlInput) !void {
        self.thread_running.store(true, .release);
        self.pending.store(false, .release);
        self.thread = try std.Thread.spawn(.{}, threadMain, .{self});
        self.wake();
    }

    pub fn stopThread(self: *SdlInput) void {
        if (!self.thread_running.load(.acquire)) return;
        self.thread_running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn wake(self: *SdlInput) void {
        self.wait_mutex.lock();
        self.pending.store(true, .release);
        self.wait_cond.signal();
        self.wait_mutex.unlock();
    }

    pub fn wait(self: *SdlInput, seconds: f64) void {
        if (seconds <= 0) return;
        const total_ns = @as(u64, @intFromFloat(seconds * std.time.ns_per_s));
        if (total_ns == 0) return;

        if (self.pending.load(.acquire)) return;
        self.wait_mutex.lock();
        defer self.wait_mutex.unlock();
        if (self.pending.load(.acquire)) return;
        _ = self.wait_cond.timedWait(&self.wait_mutex, total_ns) catch {};
    }

    pub fn drainEvents(self: *SdlInput) void {
        self.drain.clearRetainingCapacity();
        self.queue.drain(&self.drain);
        if (self.drain.items.len > 0) {
            self.pending.store(false, .release);
        }
    }
};

fn threadMain(self: *SdlInput) void {
    var event: sdl.SDL_Event = undefined;
    while (self.thread_running.load(.acquire)) {
        if (sdl_api.waitEventTimeout(&event, 8)) {
            self.queue.push(event);
            self.wake();
            while (sdl_api.pollEvent(&event)) {
                self.queue.push(event);
            }
            self.wake();
        }
    }
}
