const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");
const terminal_font = @import("../terminal_font.zig");

pub fn atlasUploadHooksForFontInit(renderer: anytype) ?terminal_font.AtlasUploadHooks {
    return metal_backend.terminalFontAtlasUploadHooksForRenderer(renderer);
}

pub fn syncTextRenderConfig(renderer: anytype) void {
    if (renderer.capabilities().text_rendering_mode != .gl_texture_atlas) return;
    gl_backend.syncTextRenderConfig(renderer);
}
