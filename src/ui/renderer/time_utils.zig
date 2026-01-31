const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const sdl_input = @import("sdl_input.zig");
const std = @import("std");

const sdl = gl.c;

pub fn waitTime(seconds: f64, active_input: ?*sdl_input.SdlInput) void {
    if (seconds <= 0) return;
    const total_ns = @as(u64, @intFromFloat(seconds * std.time.ns_per_s));
    if (total_ns == 0) return;

    if (active_input) |input| {
        input.wait(seconds);
        return;
    }
    const ms = @as(u32, @intFromFloat(seconds * 1000.0));
    sdl.SDL_Delay(ms);
}

pub fn getTime(start_counter: ?u64, perf_freq: ?f64) f64 {
    if (start_counter) |start| {
        const counter = sdl_api.getPerformanceCounter();
        if (perf_freq) |freq| {
            if (freq <= 0) return 0.0;
            return @as(f64, @floatFromInt(counter - start)) / freq;
        }
        return 0.0;
    }

    const counter = sdl_api.getPerformanceCounter();
    const freq = sdl_api.getPerformanceFrequency();
    if (freq == 0) return 0.0;
    return @as(f64, @floatFromInt(counter)) / @as(f64, @floatFromInt(freq));
}
