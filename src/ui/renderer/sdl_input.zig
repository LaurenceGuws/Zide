const std = @import("std");
const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const sdl = gl.c;

pub const SdlInput = struct {
    drain: std.ArrayList(sdl.SDL_Event) = .{},

    pub fn init(self: *SdlInput, allocator: std.mem.Allocator, capacity: usize) !void {
        self.drain = std.ArrayList(sdl.SDL_Event).empty;
        try self.drain.ensureTotalCapacity(allocator, capacity);
    }

    pub fn deinit(self: *SdlInput, allocator: std.mem.Allocator) void {
        self.drain.deinit(allocator);
    }

    pub fn drainEvents(self: *SdlInput) void {
        self.drain.clearRetainingCapacity();
        var event: sdl.SDL_Event = undefined;
        while (sdl_api.pollEvent(&event)) {
            if (self.drain.items.len >= self.drain.capacity) break;
            self.drain.appendAssumeCapacity(event);
        }
    }
};
