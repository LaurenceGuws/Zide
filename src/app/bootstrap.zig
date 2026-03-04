const std = @import("std");

pub const AppMode = enum {
    ide,
    editor,
    terminal,
    font_sample,
};

pub fn parseAppMode(allocator: std.mem.Allocator) AppMode {
    const args = std.process.argsAlloc(allocator) catch return .ide;
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--terminal") or std.mem.eql(u8, arg, "terminal")) {
            return .terminal;
        }
        if (std.mem.eql(u8, arg, "--editor") or std.mem.eql(u8, arg, "editor")) {
            return .editor;
        }
        if (std.mem.eql(u8, arg, "--ide") or std.mem.eql(u8, arg, "ide")) {
            return .ide;
        }
        if (std.mem.startsWith(u8, arg, "--mode=")) {
            const value = arg["--mode=".len..];
            if (modeFromArg(value)) |mode| return mode;
        } else if (std.mem.eql(u8, arg, "--mode") and i + 1 < args.len) {
            i += 1;
            if (modeFromArg(args[i])) |mode| return mode;
        }
    }

    return .ide;
}

pub fn modeFromArg(value: []const u8) ?AppMode {
    if (std.mem.eql(u8, value, "terminal")) return .terminal;
    if (std.mem.eql(u8, value, "editor")) return .editor;
    if (std.mem.eql(u8, value, "ide")) return .ide;
    if (std.mem.eql(u8, value, "font") or std.mem.eql(u8, value, "fonts") or std.mem.eql(u8, value, "font-sample")) return .font_sample;
    return null;
}

