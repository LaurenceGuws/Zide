const gl = @import("gl.zig");
const platform_window = @import("../../platform/window.zig");

const sdl = gl.c;

pub const WindowSizes = struct {
    width: i32,
    height: i32,
    render_width: i32,
    render_height: i32,
};

pub fn refresh(window: *sdl.SDL_Window) WindowSizes {
    const window_size = platform_window.getWindowSize(window);
    const drawable = platform_window.getDrawableSize(window);
    return .{
        .width = window_size.w,
        .height = window_size.h,
        .render_width = drawable.w,
        .render_height = drawable.h,
    };
}
