const macos_host = @import("macos_host.zig");
const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");

pub const Host = struct {
    target: macos_host.MetalAttachmentTarget,
    sdl_metal_view: sdl_api.MetalView,
    metal_layer: *anyopaque,
    attached: bool = false,

    pub fn prepare(
        target: macos_host.MetalAttachmentTarget,
        sdl_metal_view: sdl_api.MetalView,
        metal_layer: *anyopaque,
    ) Host {
        return .{
            .target = target,
            .sdl_metal_view = sdl_metal_view,
            .metal_layer = metal_layer,
            .attached = true,
        };
    }

    pub fn cocoaWindow(self: Host) *anyopaque {
        return self.target.cocoa_window;
    }

    pub fn cocoaView(self: Host) *anyopaque {
        return self.target.cocoa_view orelse @ptrCast(self.sdl_metal_view);
    }

    pub fn layer(self: Host) *anyopaque {
        return self.metal_layer;
    }
};

pub fn deinit(host: *Host) void {
    if (!host.attached) return;
    sdl_api.metalDestroyView(host.sdl_metal_view);
    host.attached = false;
}

pub fn prepareForRenderHost(
    render_host: native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) ?Host {
    const target = macos_host.metalAttachmentTarget(render_host) orelse return null;
    const sdl_metal_view = sdl_api.metalCreateView(window) orelse return null;
    const metal_layer = sdl_api.metalGetLayer(sdl_metal_view) orelse {
        sdl_api.metalDestroyView(sdl_metal_view);
        return null;
    };
    return Host.prepare(target, sdl_metal_view, metal_layer);
}
