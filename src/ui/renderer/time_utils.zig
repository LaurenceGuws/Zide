const builtin = @import("builtin");
const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const std = @import("std");

const sdl = gl.c;
const target_has_sdl_runtime = !(builtin.target.os.tag == .linux and builtin.target.abi == .android);

pub fn waitTime(seconds: f64) void {
    if (seconds <= 0) return;
    const total_ns = @as(u64, @intFromFloat(seconds * std.time.ns_per_s));
    if (total_ns == 0) return;
    if (target_has_sdl_runtime) {
        const ms = @as(u32, @intFromFloat(seconds * 1000.0));
        sdl.SDL_Delay(ms);
        return;
    }
    std.Thread.sleep(total_ns);
}

pub fn secondsToMs(seconds: f64) f64 {
    return seconds * 1000.0;
}

pub fn getTime(start_counter: ?u64, perf_freq: ?f64) f64 {
    if (!target_has_sdl_runtime) {
        const counter = std.time.nanoTimestamp();
        if (start_counter) |start| {
            return @as(f64, @floatFromInt(counter - @as(i128, @intCast(start)))) / std.time.ns_per_s;
        }
        return @as(f64, @floatFromInt(counter)) / std.time.ns_per_s;
    }

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
