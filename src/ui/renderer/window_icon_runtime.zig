const sdl_api = @import("../../platform/sdl_api.zig");
const windows_app_identity = @import("../../platform/windows_app_identity.zig");
const app_logger = @import("../../app_logger.zig");
const std = @import("std");
const builtin = @import("builtin");
const image_decode = @import("../image_decode.zig");
const gl = @import("gl.zig");

const sdl = gl.c;

fn linuxWindowIconPath() []const u8 {
    const app_id = windows_app_identity.appId();
    if (std.mem.eql(u8, app_id, "LaurenceGuws.Zide.Terminal") or
        std.mem.indexOf(u8, app_id, "zide-terminal") != null or
        std.mem.indexOf(u8, app_id, "Zide.Terminal") != null)
    {
        return "assets/icon/zide_terminal_taskbar.png";
    }
    return "assets/icon/color_icon.png";
}

pub fn applyWindowIcon(window: *sdl.SDL_Window) void {
    if (builtin.os.tag != .linux) return;

    const log = app_logger.logger("sdl.window");
    const icon_path = linuxWindowIconPath();
    const file = std.fs.cwd().readFileAlloc(std.heap.c_allocator, icon_path, 8 * 1024 * 1024) catch |err| {
        log.logf(.warning, "window icon read failed path={s} err={s}", .{ icon_path, @errorName(err) });
        return;
    };
    defer std.heap.c_allocator.free(file);

    const decoded = image_decode.decodePngRgba(std.heap.c_allocator, file) catch |err| {
        log.logf(.warning, "window icon decode failed path={s} err={s}", .{ icon_path, @errorName(err) });
        return;
    };
    defer std.heap.c_allocator.free(decoded.data);

    const width: i32 = @intCast(decoded.width);
    const height: i32 = @intCast(decoded.height);
    const surface = sdl_api.createSurfaceFromRgba(width, height, decoded.data) orelse {
        log.logf(.warning, "window icon surface creation failed path={s} err={s}", .{ icon_path, sdl_api.getError() });
        return;
    };
    defer sdl_api.destroySurface(surface);

    if (!sdl_api.setWindowIcon(window, surface)) {
        log.logf(.warning, "window icon apply failed path={s} err={s}", .{ icon_path, sdl_api.getError() });
    }
}
