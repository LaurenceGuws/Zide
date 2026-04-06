const bootstrap_contract = @import("bootstrap_contract.zig");
const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");
const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const window_init = @import("window_init.zig");

pub const RendererRuntimeProfile = bootstrap_contract.RendererRuntimeProfile;

pub const InitBootstrapWindow = struct {
    window: *sdl_api.c.SDL_Window,
    render_host: native_host.PlatformRenderHost,
    render_surface_attachment: window_init.RenderSurfaceAttachment,
};

pub fn opsForBackend(backend: anytype) bootstrap_contract.BackendBootstrapOps {
    return switch (backend) {
        .opengl => gl_backend.bootstrapOps(),
        .metal => metal_backend.bootstrapOps(),
    };
}

pub fn initBootstrapWindow(
    width: i32,
    height: i32,
    title: [*:0]const u8,
    backend: anytype,
    runtime_profile: bootstrap_contract.RendererRuntimeProfile,
) !InitBootstrapWindow {
    const bootstrap_ops = opsForBackend(backend);
    try bootstrap_ops.configureWindowAttributes();
    if (!bootstrap_ops.supportsRuntimeProfile(runtime_profile)) {
        return error.RendererBackendRuntimeNotReady;
    }

    const graphics_binding = bootstrap_ops.graphics_binding;
    const window = try window_init.createWindow(width, height, title, graphics_binding);
    errdefer sdl_api.destroyWindow(window);

    const render_host = native_host.captureRenderHost(window, graphics_binding);
    const render_surface_attachment = try window_init.attachRenderSurface(render_host);
    errdefer {
        var cleanup = render_surface_attachment;
        window_init.deinitRenderSurfaceAttachment(&cleanup);
    }

    return .{
        .window = window,
        .render_host = render_host,
        .render_surface_attachment = render_surface_attachment,
    };
}

pub fn deinitBootstrapWindow(window_state: *InitBootstrapWindow) void {
    window_init.deinitRenderSurfaceAttachment(&window_state.render_surface_attachment);
    sdl_api.destroyWindow(window_state.window);
}

pub fn deinitRendererWindowResources(
    render_surface_attachment: *window_init.RenderSurfaceAttachment,
    window: *sdl_api.c.SDL_Window,
) void {
    window_init.deinitRenderSurfaceAttachment(render_surface_attachment);
    sdl_api.destroyWindow(window);
}

pub fn runStartupBackendSmoke(width: i32, height: i32, title: [*:0]const u8, backend: anytype) !bool {
    try window_init.initSdl();
    errdefer sdl_api.quit();

    var window_state = try initBootstrapWindow(width, height, title, backend, .backend_smoke);
    defer deinitBootstrapWindow(&window_state);
    const bootstrap_ops = opsForBackend(backend);

    return try bootstrap_ops.runStartupSmoke(
        window_state.window,
        window_state.render_surface_attachment,
        width,
        height,
    );
}
