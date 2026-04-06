const bootstrap_contract = @import("bootstrap_contract.zig");
const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");
const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const window_init = @import("window_init.zig");

pub fn opsForBackend(backend: anytype) bootstrap_contract.BackendBootstrapOps {
    return switch (backend) {
        .opengl => gl_backend.bootstrapOps(),
        .metal => metal_backend.bootstrapOps(),
    };
}

pub fn runStartupBackendSmoke(width: i32, height: i32, title: [*:0]const u8, backend: anytype) !bool {
    try window_init.initSdl();
    errdefer sdl_api.quit();

    const bootstrap_ops = opsForBackend(backend);
    try bootstrap_ops.configureWindowAttributes();

    const graphics_binding = bootstrap_ops.graphics_binding;
    const window = try window_init.createWindow(width, height, title, graphics_binding);
    defer sdl_api.destroyWindow(window);

    const render_host = native_host.captureRenderHost(window, graphics_binding);
    var render_surface_attachment = try window_init.attachRenderSurface(render_host);
    defer window_init.deinitRenderSurfaceAttachment(&render_surface_attachment);

    return try bootstrap_ops.runStartupSmoke(window, render_surface_attachment, width, height);
}
