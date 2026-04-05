const macos_metal_host = @import("../../platform/macos_metal_host.zig");
const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const windows_app_identity = @import("../../platform/windows_app_identity.zig");
const window_icon_runtime = @import("window_icon_runtime.zig");
const std = @import("std");

const sdl = sdl_api.c;
pub const GraphicsBinding = native_host.RenderSurfaceBinding;
pub const RenderSurfaceAttachment = union(enum) {
    none,
    opengl_window,
    macos_metal_host: macos_metal_host.Host,
};

fn sdlGraphicsBinding(binding: GraphicsBinding) sdl_api.WindowGraphicsBinding {
    return switch (binding) {
        .none => .none,
        .opengl => .opengl,
        .metal => .metal,
    };
}

pub fn initSdl() !void {
    windows_app_identity.applyCurrentProcess();

    if (std.c.getenv("SDL_APP_NAME")) |name| {
        sdl_api.setHint("SDL_APP_NAME", name);
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", name);
    } else {
        sdl_api.setHint("SDL_APP_NAME", windows_app_identity.displayNameZ());
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", windows_app_identity.displayNameZ());
    }

    if (std.c.getenv("SDL_APP_ID")) |app_id| {
        sdl_api.setHint("SDL_APP_ID", app_id);
    } else {
        sdl_api.setHint("SDL_APP_ID", windows_app_identity.appIdZ());
    }
    if (!sdl_api.init(sdl_api.defaultInitFlags())) {
        return error.SdlInitFailed;
    }
}

pub fn createWindow(
    width: i32,
    height: i32,
    title: [*:0]const u8,
    graphics_binding: GraphicsBinding,
) !*sdl.SDL_Window {
    const window = sdl_api.createWindow(
        title,
        @intCast(width),
        @intCast(height),
        sdlGraphicsBinding(graphics_binding),
    ) orelse return error.SdlWindowFailed;
    window_icon_runtime.applyWindowIcon(window);
    return window;
}

pub fn attachRenderSurface(render_host: native_host.PlatformRenderHost) !RenderSurfaceAttachment {
    return switch (render_host.binding) {
        .none => .none,
        .opengl => .opengl_window,
        .metal => .{ .macos_metal_host = macos_metal_host.prepareForRenderHost(render_host) orelse return error.MacosMetalAttachmentUnavailable },
    };
}

pub fn deinitRenderSurfaceAttachment(attachment: *RenderSurfaceAttachment) void {
    switch (attachment.*) {
        .macos_metal_host => |*host| macos_metal_host.deinit(host),
        else => {},
    }
    attachment.* = .none;
}
