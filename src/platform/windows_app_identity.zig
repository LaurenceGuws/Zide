const builtin = @import("builtin");
const root = @import("root");
const std = @import("std");

const win32 = if (builtin.os.tag == .windows) struct {
    pub extern "shell32" fn SetCurrentProcessExplicitAppUserModelID(app_id: [*:0]const u16) callconv(.winapi) i32;
} else struct {};

pub fn displayNameZ() [*:0]const u8 {
    if (@hasDecl(root, "zide_app_identity_name")) return @field(root, "zide_app_identity_name");
    return "Zide";
}

pub fn appIdZ() [*:0]const u8 {
    if (@hasDecl(root, "zide_app_identity_id")) return @field(root, "zide_app_identity_id");
    return "LaurenceGuws.Zide";
}

pub fn displayName() []const u8 {
    return std.mem.span(displayNameZ());
}

pub fn appId() []const u8 {
    return std.mem.span(appIdZ());
}

pub fn applyCurrentProcess() void {
    if (builtin.os.tag != .windows) return;
    const app_id_utf16 = utf8ToUtf16LeZAlloc(std.heap.c_allocator, appId()) catch return;
    defer std.heap.c_allocator.free(app_id_utf16);
    _ = win32.SetCurrentProcessExplicitAppUserModelID(app_id_utf16.ptr);
}

fn utf8ToUtf16LeZAlloc(allocator: std.mem.Allocator, s: []const u8) ![:0]u16 {
    const tmp = try std.unicode.utf8ToUtf16LeAlloc(allocator, s);
    defer allocator.free(tmp);
    var buf = try allocator.alloc(u16, tmp.len + 1);
    std.mem.copyForwards(u16, buf[0..tmp.len], tmp);
    buf[tmp.len] = 0;
    return buf[0..tmp.len :0];
}
