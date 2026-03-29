const std = @import("std");

var shutdown_started = std.atomic.Value(u8).init(0);
var shell_deinitialized = std.atomic.Value(u8).init(0);

pub fn reset() void {
    shutdown_started.store(0, .monotonic);
    shell_deinitialized.store(0, .monotonic);
}

pub fn noteShutdownBegin() void {
    shutdown_started.store(1, .release);
}

pub fn noteShellDeinitialized() void {
    shell_deinitialized.store(1, .release);
}

pub fn shutdownStarted() bool {
    return shutdown_started.load(.acquire) != 0;
}

pub fn shellDeinitialized() bool {
    return shell_deinitialized.load(.acquire) != 0;
}
