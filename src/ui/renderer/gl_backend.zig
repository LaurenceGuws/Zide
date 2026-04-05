const std = @import("std");
const gl = @import("gl.zig");
const gl_resources = @import("gl_resources.zig");
const opengl_frame_runtime = @import("opengl_frame_runtime.zig");
const opengl_scene_target_runtime = @import("opengl_scene_target_runtime.zig");
const draw_ops = @import("draw_ops.zig");
const shape_utils = @import("shape_utils.zig");
const texture_draw = @import("texture_draw.zig");
const texture_utils = @import("texture_utils.zig");
const capability_contract = @import("capability_contract.zig");
const presentable_contract = @import("presentable_contract.zig");
const presentable_target = @import("presentable_target.zig");
const scene_target_state = @import("scene_target_state.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");

const sdl = gl.c;

pub const RenderTarget = presentable_target.PresentableTarget;
const PresentableSurface = presentable_contract.PresentableSurface;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const SceneTargetInvalidation = scene_target_state.SceneTargetInvalidation;
const RendererCapabilities = capability_contract.RendererCapabilities;

pub fn capabilities(renderer: anytype) RendererCapabilities {
    return .{
        .scene_composition_mode = if (renderer.runtime_profile == .full_ui)
            .offscreen_scene_target
        else
            .direct_main_target,
        .retained_targets = renderer.runtime_profile == .full_ui,
        .terminal_presentation_mode = if (renderer.runtime_profile == .full_ui)
            .retained_surface
        else
            .direct_main_target,
        .screenshot_mode = .direct_window_readback,
        .text_rendering_mode = if (renderer.runtime_profile == .full_ui)
            .gl_texture_atlas
        else
            .unavailable,
        .planned_text_rendering_mode = .gl_texture_atlas,
        .kitty_image_mode = .persistent_textures,
        .atlas_storage_mode = if (renderer.runtime_profile == .full_ui)
            .opengl_textures
        else
            .metal_textures,
        .planned_atlas_storage_mode = .opengl_textures,
        .raw_image_textures = true,
    };
}

fn glAttrName(attr: sdl_api.GlAttr) []const u8 {
    return switch (attr) {
        sdl.SDL_GL_CONTEXT_MAJOR_VERSION => "SDL_GL_CONTEXT_MAJOR_VERSION",
        sdl.SDL_GL_CONTEXT_MINOR_VERSION => "SDL_GL_CONTEXT_MINOR_VERSION",
        sdl.SDL_GL_CONTEXT_PROFILE_MASK => "SDL_GL_CONTEXT_PROFILE_MASK",
        sdl.SDL_GL_DOUBLEBUFFER => "SDL_GL_DOUBLEBUFFER",
        sdl.SDL_GL_RED_SIZE => "SDL_GL_RED_SIZE",
        sdl.SDL_GL_GREEN_SIZE => "SDL_GL_GREEN_SIZE",
        sdl.SDL_GL_BLUE_SIZE => "SDL_GL_BLUE_SIZE",
        sdl.SDL_GL_ALPHA_SIZE => "SDL_GL_ALPHA_SIZE",
        sdl.SDL_GL_DEPTH_SIZE => "SDL_GL_DEPTH_SIZE",
        sdl.SDL_GL_STENCIL_SIZE => "SDL_GL_STENCIL_SIZE",
        else => "SDL_GL_ATTR_UNKNOWN",
    };
}

fn requireGlAttribute(attr: sdl_api.GlAttr, value: c_int) !void {
    if (sdl_api.glSetAttribute(attr, value)) return;
    app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetAttribute failed attr={s} value={d} err={s}", .{
        glAttrName(attr),
        value,
        sdl_api.getError(),
    });
    return error.SdlGlAttributeFailed;
}

pub fn configureWindowAttributes() !void {
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
    try requireGlAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);
}

pub fn createBackendContext(window: *sdl.SDL_Window) !sdl.SDL_GLContext {
    const gl_context = sdl_api.glCreateContext(window) orelse return error.SdlGlContextFailed;
    if (!sdl_api.glMakeCurrent(window, gl_context)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_MakeCurrent failed err={s}", .{sdl_api.getError()});
        return error.SdlGlMakeCurrentFailed;
    }
    if (!sdl_api.glSetSwapInterval(1)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetSwapInterval failed interval=1 err={s}", .{sdl_api.getError()});
        return error.SdlSwapIntervalFailed;
    }
    return gl_context;
}

pub fn initRuntime(renderer: anytype) !void {
    try initGlResources(renderer);
    renderer.opengl_runtime.resources_ready = true;
    try renderer.initFonts();
    renderer.fonts_ready = true;
}

pub fn configureRuntimePolicy(renderer: anytype) void {
    if (!renderer.terminal_render_policy.recent_input_full_publication.force_full_enabled) return;
    if (!sdl_api.glSetSwapInterval(0)) {
        app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SetSwapInterval failed interval=0 err={s}", .{sdl_api.getError()});
    }
}

pub fn runStartupSmoke(window: *sdl.SDL_Window) !bool {
    const gl_context = try createBackendContext(window);
    defer sdl_api.glDeleteContext(gl_context);
    try gl.load();
    return true;
}

pub fn beginFrame(renderer: anytype) void {
    opengl_frame_runtime.beginFrame(renderer);
}

pub fn submitFrame(renderer: anytype) @import("present_trace_runtime.zig").FrameSubmission {
    return opengl_frame_runtime.submitFrame(renderer);
}

pub fn dumpWindowScreenshotPpm(renderer: anytype, path: []const u8) !void {
    return opengl_frame_runtime.dumpWindowScreenshotPpm(renderer, path);
}

pub fn dumpWindowScreenshotPpmSized(renderer: anytype, path: []const u8, out_width: i32, out_height: i32) !void {
    return opengl_frame_runtime.dumpWindowScreenshotPpmSized(renderer, path, out_width, out_height);
}

pub fn sceneTargetInvalidationForRefresh(
    renderer: anytype,
    changes: anytype,
    metrics: anytype,
) SceneTargetInvalidation {
    return scene_target_state.invalidationForRefresh(
        renderer.opengl_runtime.scene_target,
        changes,
        metrics,
        renderer.supportsSceneTargets(),
    );
}

pub fn mergePendingSceneTargetInvalidation(renderer: anytype, invalidation: SceneTargetInvalidation) void {
    renderer.opengl_runtime.scene_target.pending_invalidation.merge(invalidation);
}

pub fn whiteTexture(renderer: anytype) types.Texture {
    return renderer.opengl_runtime.white_texture;
}

pub fn drawSolidRect(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) bool {
    if (w <= 0 or h <= 0) return false;
    const dest = types.Rect{ .x = x, .y = y, .width = w, .height = h };
    const src = texture_draw.unitSrcRect();
    draw_ops.drawTextureRect(renderer, whiteTexture(renderer), src, dest, color, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    return true;
}

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    draw_ops.addTerminalRect(renderer, x, y, w, h, color);
}

pub fn addTerminalGlyphRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    renderer.terminal_text.glyph_cache.addRect(whiteTexture(renderer), x, y, w, h, color);
}

pub fn addTerminalGlyphQuad(
    renderer: anytype,
    texture: types.Texture,
    src: types.Rect,
    dest: types.Rect,
    color: types.Rgba,
    kind: types.TextureKind,
) void {
    renderer.terminal_text.glyph_cache.addQuad(texture, src, dest, color, renderer.text_render.bg_rgba, kind);
}

pub fn createPersistentTextureFromRgba(_: anytype, width: i32, height: i32, data: []const u8) ?types.Texture {
    return texture_utils.createTextureFromRgba(width, height, data, gl.c.GL_LINEAR);
}

pub fn createPersistentTextureFromRgb(_: anytype, width: i32, height: i32, data: []const u8) ?types.Texture {
    return texture_utils.createTextureFromRgb(width, height, data, gl.c.GL_LINEAR);
}

pub fn destroyPersistentTexture(_: anytype, texture: *types.Texture) void {
    texture_utils.destroyTexture(texture);
}

pub fn applyClipRect(renderer: anytype, clip: ?types.Rect) void {
    const active_clip = clip orelse {
        gl.Disable(gl.c.GL_SCISSOR_TEST);
        return;
    };
    if (active_clip.width <= 0 or active_clip.height <= 0) {
        gl.Enable(gl.c.GL_SCISSOR_TEST);
        gl.Scissor(0, 0, 0, 0);
        return;
    }
    gl.Enable(gl.c.GL_SCISSOR_TEST);
    const scale_x = @as(f32, @floatFromInt(renderer.target_pixel_width)) / @as(f32, @floatFromInt(renderer.target_width));
    const scale_y = @as(f32, @floatFromInt(renderer.target_pixel_height)) / @as(f32, @floatFromInt(renderer.target_height));
    const sx: i32 = @intFromFloat(active_clip.x * scale_x);
    const sy: i32 = @intFromFloat((@as(f32, @floatFromInt(renderer.target_height)) - (active_clip.y + active_clip.height)) * scale_y);
    const sw: i32 = @intFromFloat(active_clip.width * scale_x);
    const sh: i32 = @intFromFloat(active_clip.height * scale_y);
    const log = app_logger.logger("renderer.terminal_present");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            .info,
            "clip logical={d},{d} {d}x{d} scissor={d},{d} {d}x{d} target_logical={d}x{d} target_px={d}x{d} scale={d:.3},{d:.3}",
            .{
                @as(i32, @intFromFloat(active_clip.x)),
                @as(i32, @intFromFloat(active_clip.y)),
                @as(i32, @intFromFloat(active_clip.width)),
                @as(i32, @intFromFloat(active_clip.height)),
                sx,
                sy,
                sw,
                sh,
                renderer.target_width,
                renderer.target_height,
                renderer.target_pixel_width,
                renderer.target_pixel_height,
                scale_x,
                scale_y,
            },
        );
    }
    gl.Scissor(sx, sy, sw, sh);
}

pub fn clearThemeBackground(renderer: anytype) void {
    const bg = renderer.theme.background.toRgba();
    var rr = @as(f32, @floatFromInt(bg.r)) / 255.0;
    var gg = @as(f32, @floatFromInt(bg.g)) / 255.0;
    var bb = @as(f32, @floatFromInt(bg.b)) / 255.0;
    const aa = @as(f32, @floatFromInt(bg.a)) / 255.0;
    if (renderer.text_render.dst_linear_active) {
        rr = srgbToLinear(rr);
        gg = srgbToLinear(gg);
        bb = srgbToLinear(bb);
    }
    gl.ClearColor(rr, gg, bb, aa);
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
}

pub fn bindBatchPipeline(renderer: anytype) void {
    gl.UseProgram(renderer.opengl_runtime.shader_program);
    gl.BindVertexArray(renderer.opengl_runtime.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.opengl_runtime.vbo);
}

pub fn setTextureKind(renderer: anytype, kind: types.TextureKind) void {
    if (renderer.opengl_runtime.uniform_kind >= 0) {
        gl.Uniform1i(renderer.opengl_runtime.uniform_kind, @intFromEnum(kind));
    }
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize, vertex_size: usize) void {
    if (vertex_count <= renderer.opengl_runtime.vbo_capacity_vertices) return;
    var next_cap = renderer.opengl_runtime.vbo_capacity_vertices * 2;
    if (next_cap < 6) next_cap = 6;
    if (next_cap < vertex_count) next_cap = vertex_count;
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.opengl_runtime.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        @as(gl.GLsizeiptr, @intCast(vertex_size * next_cap)),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.opengl_runtime.vbo_capacity_vertices = next_cap;
}

pub fn syncTextRenderConfig(renderer: anytype) void {
    if (renderer.opengl_runtime.shader_program == 0) return;
    gl.UseProgram(renderer.opengl_runtime.shader_program);
    if (renderer.opengl_runtime.uniform_text_gamma >= 0) {
        gl.Uniform1f(renderer.opengl_runtime.uniform_text_gamma, renderer.text_render.gamma);
    }
    if (renderer.opengl_runtime.uniform_text_contrast >= 0) {
        gl.Uniform1f(renderer.opengl_runtime.uniform_text_contrast, renderer.text_render.contrast);
    }
    if (renderer.opengl_runtime.uniform_linear_correction >= 0) {
        gl.Uniform1i(renderer.opengl_runtime.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);
    }
}

fn deinitPresentables(renderer: anytype) void {
    destroyRenderTarget(&renderer.opengl_runtime.presentable_targets.terminal);
    destroyRenderTarget(&renderer.opengl_runtime.presentable_targets.terminal_scroll);
    destroyRenderTarget(&renderer.opengl_runtime.presentable_targets.editor);
}

pub fn ensurePresentable(renderer: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    switch (surface) {
        .terminal => {
            const recreated = ensureRenderTargetScaledForRenderer(
                renderer,
                &renderer.opengl_runtime.presentable_targets.terminal,
                width,
                height,
                gl.c.GL_NEAREST,
            );
            _ = ensureRenderTargetScaledForRenderer(
                renderer,
                &renderer.opengl_runtime.presentable_targets.terminal_scroll,
                width,
                height,
                gl.c.GL_NEAREST,
            );
            return recreated;
        },
        .editor => {
            return ensureRenderTargetScaledForRenderer(
                renderer,
                &renderer.opengl_runtime.presentable_targets.editor,
                width,
                height,
                gl.c.GL_NEAREST,
            );
        },
    }
}

pub fn beginPresentable(renderer: anytype, surface: PresentableSurface) bool {
    if (!renderer.capabilities().retained_targets) return false;
    switch (surface) {
        .terminal => return beginRenderTarget(renderer, renderer.opengl_runtime.presentable_targets.terminal),
        .editor => {
            @import("present_trace_runtime.zig").notePresentableUpdate(renderer, .editor);
            return beginRenderTarget(renderer, renderer.opengl_runtime.presentable_targets.editor);
        },
    }
}

pub fn presentableAvailable(renderer: anytype, surface: PresentableSurface) bool {
    if (!renderer.capabilities().retained_targets) return false;
    return switch (surface) {
        .terminal => renderer.opengl_runtime.presentable_targets.terminal != null,
        .editor => renderer.opengl_runtime.presentable_targets.editor != null,
    };
}

pub fn endPresentable(renderer: anytype, surface: PresentableSurface) void {
    if (!renderer.capabilities().retained_targets) return;
    switch (surface) {
        .terminal => {},
        .editor => @import("present_trace_runtime.zig").notePresentableEnded(renderer, .editor),
    }
    restoreCompositionTarget(renderer);
}

pub fn drawPresentable(renderer: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    if (!renderer.capabilities().retained_targets) return;
    switch (surface) {
        .terminal => if (renderer.opengl_runtime.presentable_targets.terminal) |target| {
            @import("present_trace_runtime.zig").notePresentableDraw(renderer, .terminal, draw.generation);
            const width = draw.width orelse return;
            const height = draw.height orelse return;
            const source_width = draw.source_width orelse width;
            const source_height = draw.source_height orelse height;
            const snapped_x = snapToDevicePixel(draw.x, renderer.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, renderer.scale.render_scale);
            const src = texture_draw.logicalTextureSrcRect(
                target.texture,
                @floatFromInt(target.logical_width),
                @floatFromInt(target.logical_height),
                source_width,
                source_height,
            );
            const dest = types.Rect{
                .x = snapped_x,
                .y = snapped_y,
                .width = width,
                .height = height,
            };
            const log = app_logger.logger("renderer.terminal_present");
            if (log.enabled_file or log.enabled_console) {
                log.logf(
                    .info,
                    "draw tex={d} tex_px={d}x{d} target_logical={d}x{d} src_rect={d:.2},{d:.2} {d:.2}x{d:.2} dest={d:.2},{d:.2} {d:.2}x{d:.2} framebuffer={d}x{d} target_px={d}x{d} window={d}x{d} render_scale={d:.3}",
                    .{
                        target.texture.id,
                        target.texture.width,
                        target.texture.height,
                        target.logical_width,
                        target.logical_height,
                        src.x,
                        src.y,
                        src.width,
                        src.height,
                        dest.x,
                        dest.y,
                        dest.width,
                        dest.height,
                        renderer.render_width,
                        renderer.render_height,
                        renderer.target_pixel_width,
                        renderer.target_pixel_height,
                        renderer.width,
                        renderer.height,
                        renderer.scale.render_scale,
                    },
                );
            }
            draw_ops.drawTextureRect(
                renderer,
                target.texture,
                src,
                dest,
                .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .linear_premul,
            );
        },
        .editor => if (renderer.opengl_runtime.presentable_targets.editor) |target| {
            @import("present_trace_runtime.zig").notePresentableDraw(renderer, .editor, null);
            const snapped_x = snapToDevicePixel(draw.x, renderer.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, renderer.scale.render_scale);
            const width = draw.width orelse @as(f32, @floatFromInt(target.logical_width));
            const height = draw.height orelse @as(f32, @floatFromInt(target.logical_height));
            const source_width = draw.source_width orelse width;
            const source_height = draw.source_height orelse height;
            const src = texture_draw.logicalTextureSrcRect(
                target.texture,
                @floatFromInt(target.logical_width),
                @floatFromInt(target.logical_height),
                source_width,
                source_height,
            );
            const dest = types.Rect{
                .x = snapped_x,
                .y = snapped_y,
                .width = width,
                .height = height,
            };
            draw_ops.drawTextureRect(
                renderer,
                target.texture,
                src,
                dest,
                .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .linear_premul,
            );
        },
    }
}

pub fn scrollPresentable(renderer: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    if (surface != .terminal) return false;
    if (renderer.opengl_runtime.presentable_targets.terminal) |target| {
        return scrollRenderTarget(
            renderer,
            renderer.opengl_runtime.presentable_targets.terminal,
            &renderer.opengl_runtime.presentable_targets.terminal_scroll,
            dx,
            dy,
            target.logical_width,
            target.logical_height,
        );
    }
    return false;
}

pub fn presentableInfo(renderer: anytype, surface: PresentableSurface) ?PresentableInfo {
    const target = switch (surface) {
        .terminal => renderer.opengl_runtime.presentable_targets.terminal,
        .editor => renderer.opengl_runtime.presentable_targets.editor,
    } orelse return null;
    return .{
        .width_px = target.texture.width,
        .height_px = target.texture.height,
        .logical_width = target.logical_width,
        .logical_height = target.logical_height,
    };
}

fn srgbToLinear(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn restoreCompositionTarget(renderer: anytype) void {
    if (renderer.present.main_composition_target == .offscreen_scene_target) {
        if (!opengl_scene_target_runtime.beginSceneFrame(renderer)) {
            renderer.present.main_composition_target = .default_target;
            bindDefaultTarget(renderer);
        }
        return;
    }
    bindDefaultTarget(renderer);
}

pub fn initGlResources(renderer: anytype) !void {
    const vertex_src =
        "#version 330 core\n" ++
        "layout (location = 0) in vec2 a_pos;\n" ++
        "layout (location = 1) in vec2 a_uv;\n" ++
        "layout (location = 2) in vec4 a_color;\n" ++
        "layout (location = 3) in vec4 a_bg_color;\n" ++
        "out vec2 v_uv;\n" ++
        "out vec4 v_color;\n" ++
        "out vec4 v_bg_color;\n" ++
        "uniform mat4 u_proj;\n" ++
        "void main() {\n" ++
        "    v_uv = a_uv;\n" ++
        "    v_color = a_color;\n" ++
        "    v_bg_color = a_bg_color;\n" ++
        "    gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n" ++
        "}\n";
    const fragment_src =
        "#version 330 core\n" ++
        "in vec2 v_uv;\n" ++
        "in vec4 v_color;\n" ++
        "in vec4 v_bg_color;\n" ++
        "out vec4 frag_color;\n" ++
        "uniform sampler2D u_tex;\n" ++
        "uniform int u_kind;\n" ++
        "uniform int u_dst_linear;\n" ++
        "uniform int u_linear_correction;\n" ++
        "uniform float u_text_gamma;\n" ++
        "uniform float u_text_contrast;\n" ++
        "vec3 srgb_to_linear(vec3 c) {\n" ++
        "    bvec3 cutoff = lessThanEqual(c, vec3(0.04045));\n" ++
        "    vec3 higher = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));\n" ++
        "    vec3 lower = c / vec3(12.92);\n" ++
        "    return mix(higher, lower, cutoff);\n" ++
        "}\n" ++
        "vec3 linear_to_srgb(vec3 c) {\n" ++
        "    bvec3 cutoff = lessThanEqual(c, vec3(0.0031308));\n" ++
        "    vec3 higher = pow(c, vec3(1.0 / 2.4)) * vec3(1.055) - vec3(0.055);\n" ++
        "    vec3 lower = c * vec3(12.92);\n" ++
        "    return mix(higher, lower, cutoff);\n" ++
        "}\n" ++
        "float luminance(vec3 c) {\n" ++
        "    return dot(c, vec3(0.2126, 0.7152, 0.0722));\n" ++
        "}\n" ++
        "float linear_to_srgb_1(float v) {\n" ++
        "    return v <= 0.0031308 ? v * 12.92 : pow(v, 1.0 / 2.4) * 1.055 - 0.055;\n" ++
        "}\n" ++
        "float srgb_to_linear_1(float v) {\n" ++
        "    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);\n" ++
        "}\n" ++
        "vec4 unlinearize_premul(vec4 c) {\n" ++
        "    if (c.a <= 0.0) return vec4(0.0);\n" ++
        "    vec3 rgb = c.rgb / vec3(c.a);\n" ++
        "    rgb = linear_to_srgb(rgb);\n" ++
        "    return vec4(rgb * c.a, c.a);\n" ++
        "}\n" ++
        "void main() {\n" ++
        "    vec4 tex = texture(u_tex, v_uv);\n" ++
        "    if (u_kind == 1) {\n" ++
        "        // Font coverage atlas. Sample the mask and apply it as alpha.\n" ++
        "        float mask = tex.r;\n" ++
        "        mask = pow(mask, u_text_gamma);\n" ++
        "        mask = clamp(mask * u_text_contrast, 0.0, 1.0);\n" ++
        "        vec4 color = v_color;\n" ++
        "        float cov = mask;\n" ++
        "        if (u_dst_linear != 0) {\n" ++
        "            color.rgb = srgb_to_linear(color.rgb);\n" ++
        "        }\n" ++
        "        if (u_dst_linear != 0 && u_linear_correction != 0 && v_bg_color.a > 0.0) {\n" ++
        "            vec3 bg = srgb_to_linear(v_bg_color.rgb);\n" ++
        "            float fg_l = luminance(color.rgb);\n" ++
        "            float bg_l = luminance(bg);\n" ++
        "            if (abs(fg_l - bg_l) > 0.001) {\n" ++
        "                float blend_l = srgb_to_linear_1(linear_to_srgb_1(fg_l) * cov + linear_to_srgb_1(bg_l) * (1.0 - cov));\n" ++
        "                cov = clamp((blend_l - bg_l) / (fg_l - bg_l), 0.0, 1.0);\n" ++
        "            }\n" ++
        "        }\n" ++
        "        float a = cov * v_color.a;\n" ++
        "        // Premultiplied output for correct edge blending.\n" ++
        "        vec4 outc = vec4(color.rgb * a, a);\n" ++
        "        if (u_dst_linear == 0) {\n" ++
        "            outc = unlinearize_premul(outc);\n" ++
        "        }\n" ++
        "        frag_color = outc;\n" ++
        "    } else if (u_kind == 2) {\n" ++
        "        // Linear premultiplied source (e.g. offscreen targets).\n" ++
        "        vec4 outc = tex;\n" ++
        "        if (u_dst_linear == 0) {\n" ++
        "            outc = unlinearize_premul(outc);\n" ++
        "        }\n" ++
        "        frag_color = outc;\n" ++
        "    } else {\n" ++
        "        if (u_dst_linear != 0) {\n" ++
        "            vec4 col = v_color;\n" ++
        "            col.rgb = srgb_to_linear(col.rgb);\n" ++
        "            tex.rgb = srgb_to_linear(tex.rgb);\n" ++
        "            frag_color = tex * col;\n" ++
        "        } else {\n" ++
        "            frag_color = tex * v_color;\n" ++
        "        }\n" ++
        "    }\n" ++
        "}\n";

    const vert = try compileShader(gl.c.GL_VERTEX_SHADER, vertex_src);
    defer gl.DeleteShader(vert);
    const frag = try compileShader(gl.c.GL_FRAGMENT_SHADER, fragment_src);
    defer gl.DeleteShader(frag);
    const program = try linkProgram(vert, frag);
    renderer.opengl_runtime.shader_program = program;
    gl.UseProgram(program);

    renderer.opengl_runtime.uniform_proj = gl.GetUniformLocation(program, "u_proj");
    renderer.opengl_runtime.uniform_tex = gl.GetUniformLocation(program, "u_tex");
    renderer.opengl_runtime.uniform_kind = gl.GetUniformLocation(program, "u_kind");
    renderer.opengl_runtime.uniform_dst_linear = gl.GetUniformLocation(program, "u_dst_linear");
    renderer.opengl_runtime.uniform_linear_correction = gl.GetUniformLocation(program, "u_linear_correction");
    renderer.opengl_runtime.uniform_text_gamma = gl.GetUniformLocation(program, "u_text_gamma");
    renderer.opengl_runtime.uniform_text_contrast = gl.GetUniformLocation(program, "u_text_contrast");
    if (renderer.opengl_runtime.uniform_tex >= 0) gl.Uniform1i(renderer.opengl_runtime.uniform_tex, 0);
    if (renderer.opengl_runtime.uniform_kind >= 0) gl.Uniform1i(renderer.opengl_runtime.uniform_kind, 0);
    if (renderer.opengl_runtime.uniform_dst_linear >= 0) gl.Uniform1i(renderer.opengl_runtime.uniform_dst_linear, 0);
    if (renderer.opengl_runtime.uniform_linear_correction >= 0) gl.Uniform1i(renderer.opengl_runtime.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);

    // Coverage tuning (applies only to font coverage atlas).
    if (renderer.opengl_runtime.uniform_text_gamma >= 0) gl.Uniform1f(renderer.opengl_runtime.uniform_text_gamma, clampPositive(renderer.text_render.gamma, 1.0));
    if (renderer.opengl_runtime.uniform_text_contrast >= 0) gl.Uniform1f(renderer.opengl_runtime.uniform_text_contrast, clampPositive(renderer.text_render.contrast, 1.0));

    gl.GenVertexArrays(1, &renderer.opengl_runtime.vao);
    gl.GenBuffers(1, &renderer.opengl_runtime.vbo);
    gl.BindVertexArray(renderer.opengl_runtime.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.opengl_runtime.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        gl_resources.computeBufferBytes(@sizeOf(@TypeOf(renderer.batch.vertices.items[0])), 6),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.opengl_runtime.vbo_capacity_vertices = 6;

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(@TypeOf(renderer.batch.vertices.items[0])), @ptrFromInt(0));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(
        1,
        2,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(2 * @sizeOf(f32)),
    );
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(
        2,
        4,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(4 * @sizeOf(f32)),
    );

    gl.EnableVertexAttribArray(3);
    gl.VertexAttribPointer(
        3,
        4,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(8 * @sizeOf(f32)),
    );

    gl.Enable(gl.c.GL_BLEND);
    gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA);
    gl.Disable(gl.c.GL_DEPTH_TEST);
    gl.Disable(gl.c.GL_CULL_FACE);

    renderer.opengl_runtime.white_texture = createSolidTexture(1, 1, .{ 255, 255, 255, 255 });
    updateProjection(renderer, renderer.render_width, renderer.render_height);
}

fn clampPositive(v: f32, fallback: f32) f32 {
    if (std.math.isFinite(v) and v > 0.0) return v;
    return fallback;
}

pub fn bindDefaultTarget(renderer: anytype) void {
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    renderer.text_render.dst_linear_active = false;
    renderer.target_pixel_width = renderer.render_width;
    renderer.target_pixel_height = renderer.render_height;
    updateProjection(renderer, renderer.width, renderer.height);
    if (renderer.opengl_runtime.uniform_dst_linear >= 0) {
        gl.UseProgram(renderer.opengl_runtime.shader_program);
        gl.Uniform1i(renderer.opengl_runtime.uniform_dst_linear, 0);
    }
}

pub fn beginRenderTarget(renderer: anytype, target: ?RenderTarget) bool {
    if (target) |t| {
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
        renderer.text_render.dst_linear_active = true;
        renderer.target_pixel_width = t.texture.width;
        renderer.target_pixel_height = t.texture.height;
        updateProjection(renderer, t.logical_width, t.logical_height);
        if (renderer.opengl_runtime.uniform_dst_linear >= 0) {
            gl.UseProgram(renderer.opengl_runtime.shader_program);
            gl.Uniform1i(renderer.opengl_runtime.uniform_dst_linear, 1);
        }
        return true;
    }
    return false;
}

pub fn ensureRenderTargetScaledForRenderer(
    renderer: anytype,
    target: *?RenderTarget,
    logical_width: i32,
    logical_height: i32,
    filter: i32,
) bool {
    const scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const width = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_width)) * scale))));
    const height = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_height)) * scale))));
    return ensureRenderTarget(target, width, height, logical_width, logical_height, filter);
}

pub fn scrollRenderTarget(
    renderer: anytype,
    target: ?RenderTarget,
    scratch: *?RenderTarget,
    dx: i32,
    dy: i32,
    width: i32,
    height: i32,
) bool {
    if (target == null) return false;
    if (dx == 0 and dy == 0) return true;
    const t = target.?;
    if (width <= 0 or height <= 0) return false;
    const abs_dx: i32 = if (dx < 0) -dx else dx;
    const abs_dy: i32 = if (dy < 0) -dy else dy;
    if (abs_dx >= width or abs_dy >= height) return false;
    if (!ensureRenderTarget(
        scratch,
        t.texture.width,
        t.texture.height,
        t.logical_width,
        t.logical_height,
        gl.c.GL_NEAREST,
    )) return false;
    const scratch_target = scratch.* orelse return false;

    const copy_w: i32 = width - abs_dx;
    const copy_h: i32 = height - abs_dy;
    const src_x: i32 = if (dx > 0) dx else 0;
    const src_y: i32 = if (dy > 0) dy else 0;
    const dst_x: i32 = if (dx > 0) 0 else -dx;
    const dst_y: i32 = if (dy > 0) 0 else -dy;

    gl.BindFramebuffer(gl.c.GL_READ_FRAMEBUFFER, t.fbo);
    gl.BindFramebuffer(gl.c.GL_DRAW_FRAMEBUFFER, scratch_target.fbo);
    gl.BlitFramebuffer(
        src_x,
        src_y,
        src_x + copy_w,
        src_y + copy_h,
        dst_x,
        dst_y,
        dst_x + copy_w,
        dst_y + copy_h,
        gl.c.GL_COLOR_BUFFER_BIT,
        gl.c.GL_NEAREST,
    );

    gl.BindFramebuffer(gl.c.GL_READ_FRAMEBUFFER, scratch_target.fbo);
    gl.BindFramebuffer(gl.c.GL_DRAW_FRAMEBUFFER, t.fbo);
    gl.BlitFramebuffer(
        0,
        0,
        width,
        height,
        0,
        0,
        width,
        height,
        gl.c.GL_COLOR_BUFFER_BIT,
        gl.c.GL_NEAREST,
    );

    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
    renderer.target_pixel_width = t.texture.width;
    renderer.target_pixel_height = t.texture.height;
    updateProjection(renderer, t.logical_width, t.logical_height);
    return true;
}

pub fn ensureRenderTarget(target: *?RenderTarget, width: i32, height: i32, logical_width: i32, logical_height: i32, filter: i32) bool {
    if (width <= 0 or height <= 0 or logical_width <= 0 or logical_height <= 0) return false;
    if (target.*) |t| {
        if (t.texture.width == width and t.texture.height == height and t.logical_width == logical_width and t.logical_height == logical_height) return false;
        destroyRenderTarget(target);
    }

    const texture = createTextureEmpty(width, height, filter);
    var fbo: gl.GLuint = 0;
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, fbo);
    gl.FramebufferTexture2D(gl.c.GL_FRAMEBUFFER, gl.c.GL_COLOR_ATTACHMENT0, gl.c.GL_TEXTURE_2D, texture.id, 0);
    const status = gl.CheckFramebufferStatus(gl.c.GL_FRAMEBUFFER);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    if (status != gl.c.GL_FRAMEBUFFER_COMPLETE) {
        gl.DeleteFramebuffers(1, &fbo);
        gl.DeleteTextures(1, &texture.id);
        return false;
    }

    target.* = .{ .texture = texture, .fbo = fbo, .logical_width = logical_width, .logical_height = logical_height };
    return true;
}

pub fn destroyRenderTarget(target: *?RenderTarget) void {
    if (target.*) |t| {
        gl.DeleteFramebuffers(1, &t.fbo);
        gl.DeleteTextures(1, &t.texture.id);
        target.* = null;
    }
}

pub fn deinitRuntime(renderer: anytype) void {
    deinitPresentables(renderer);
    destroyRenderTarget(&renderer.opengl_runtime.scene_target.target);
    if (renderer.opengl_runtime.resources_ready and renderer.opengl_runtime.white_texture.id != 0) {
        gl.DeleteTextures(1, &renderer.opengl_runtime.white_texture.id);
    }
    if (renderer.opengl_runtime.resources_ready) {
        gl_resources.destroy(.{
            .shader_program = renderer.opengl_runtime.shader_program,
            .vao = renderer.opengl_runtime.vao,
            .vbo = renderer.opengl_runtime.vbo,
            .uniform_proj = renderer.opengl_runtime.uniform_proj,
            .uniform_tex = renderer.opengl_runtime.uniform_tex,
        });
    }
    if (renderer.opengl_runtime.context) |context| sdl_api.glDeleteContext(context);
}

pub fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    renderer.target_width = width;
    renderer.target_height = height;
    const viewport_w = if (renderer.target_pixel_width > 0) renderer.target_pixel_width else width;
    const viewport_h = if (renderer.target_pixel_height > 0) renderer.target_pixel_height else height;
    gl.Viewport(0, 0, viewport_w, viewport_h);
    if (renderer.opengl_runtime.uniform_proj >= 0) {
        const w = @as(f32, @floatFromInt(width));
        const h = @as(f32, @floatFromInt(height));
        const proj = [_]f32{
            2.0 / w, 0,        0, 0,
            0,       -2.0 / h, 0, 0,
            0,       0,        1, 0,
            -1,      1,        0, 1,
        };
        gl.UseProgram(renderer.opengl_runtime.shader_program);
        gl.UniformMatrix4fv(renderer.opengl_runtime.uniform_proj, 1, gl.c.GL_FALSE, &proj);
    }
}

fn compileShader(kind: gl.GLenum, source: []const u8) !gl.GLuint {
    const shader = gl.CreateShader(kind);
    const src_ptr: [*]const gl.GLchar = @ptrCast(source.ptr);
    const src_len: gl.GLint = @intCast(source.len);
    const lengths = [_]gl.GLint{src_len};
    gl.ShaderSource(shader, 1, @ptrCast(&src_ptr), @ptrCast(&lengths));
    gl.CompileShader(shader);
    var status: gl.GLint = 0;
    gl.GetShaderiv(shader, gl.c.GL_COMPILE_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetShaderInfoLog(shader, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlShaderCompileFailed;
    }
    return shader;
}

fn linkProgram(vert: gl.GLuint, frag: gl.GLuint) !gl.GLuint {
    const program = gl.CreateProgram();
    gl.AttachShader(program, vert);
    gl.AttachShader(program, frag);
    gl.LinkProgram(program);
    var status: gl.GLint = 0;
    gl.GetProgramiv(program, gl.c.GL_LINK_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetProgramInfoLog(program, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlProgramLinkFailed;
    }
    return program;
}

fn createSolidTexture(width: i32, height: i32, rgba: [4]u8) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        &rgba,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn createTextureEmpty(width: i32, height: i32, filter: i32) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        null,
    );
    return .{ .id = id, .width = width, .height = height };
}
