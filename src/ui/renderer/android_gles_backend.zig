const builtin = @import("builtin");
const bootstrap_contract = @import("bootstrap_contract.zig");
const capability_contract = @import("capability_contract.zig");
const android_gles_runtime = @import("../../platform/android_gles_runtime.zig");
const draw_ops = @import("draw_ops.zig");
const gl_resources = @import("gl_resources.zig");
const shared_gl = @import("gl.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const native_host = @import("../../platform/native_host.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_frame_host = @import("renderer_frame_host.zig");
const scene_target_state = @import("scene_target_state.zig");
const surface_draw = @import("surface_draw.zig");
const std = @import("std");
const types = @import("types.zig");
const window_init = @import("window_init.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const target_has_android_gles = builtin.target.os.tag == .linux and builtin.target.abi == .android;

const gl = if (target_has_android_gles) struct {
    extern fn glClearColor(red: f32, green: f32, blue: f32, alpha: f32) void;
    extern fn glClear(mask: u32) void;
    extern fn glEnable(cap: u32) void;
    extern fn glDisable(cap: u32) void;
    extern fn glScissor(x: i32, y: i32, width: i32, height: i32) void;
    extern fn glViewport(x: i32, y: i32, width: i32, height: i32) void;
    extern fn glCreateShader(type_: u32) u32;
    extern fn glShaderSource(shader: u32, count: i32, string: [*]const [*]const u8, length: ?[*]const i32) void;
    extern fn glCompileShader(shader: u32) void;
    extern fn glGetShaderiv(shader: u32, pname: u32, params: *i32) void;
    extern fn glGetShaderInfoLog(shader: u32, max_length: i32, length: ?*i32, info_log: [*]u8) void;
    extern fn glDeleteShader(shader: u32) void;
    extern fn glCreateProgram() u32;
    extern fn glAttachShader(program: u32, shader: u32) void;
    extern fn glLinkProgram(program: u32) void;
    extern fn glGetProgramiv(program: u32, pname: u32, params: *i32) void;
    extern fn glGetProgramInfoLog(program: u32, max_length: i32, length: ?*i32, info_log: [*]u8) void;
    extern fn glUseProgram(program: u32) void;
    extern fn glDeleteProgram(program: u32) void;
    extern fn glGetUniformLocation(program: u32, name: [*:0]const u8) i32;
    extern fn glUniform1i(location: i32, v0: i32) void;
    extern fn glUniform1f(location: i32, v0: f32) void;
    extern fn glUniformMatrix4fv(location: i32, count: i32, transpose: u8, value: [*]const f32) void;
    extern fn glGenVertexArrays(n: i32, arrays: [*]u32) void;
    extern fn glBindVertexArray(array: u32) void;
    extern fn glDeleteVertexArrays(n: i32, arrays: [*]const u32) void;
    extern fn glGenBuffers(n: i32, buffers: [*]u32) void;
    extern fn glBindBuffer(target: u32, buffer: u32) void;
    extern fn glBufferData(target: u32, size: isize, data: ?*const anyopaque, usage: u32) void;
    extern fn glBufferSubData(target: u32, offset: isize, size: isize, data: *const anyopaque) void;
    extern fn glDeleteBuffers(n: i32, buffers: [*]const u32) void;
    extern fn glEnableVertexAttribArray(index: u32) void;
    extern fn glVertexAttribPointer(index: u32, size: i32, type_: u32, normalized: u8, stride: i32, pointer: ?*const anyopaque) void;
    extern fn glGenTextures(n: i32, textures: [*]u32) void;
    extern fn glBindTexture(target: u32, texture: u32) void;
    extern fn glTexParameteri(target: u32, pname: u32, param: i32) void;
    extern fn glTexImage2D(target: u32, level: i32, internalformat: i32, width: i32, height: i32, border: i32, format: u32, type_: u32, pixels: ?*const anyopaque) void;
    extern fn glTexSubImage2D(target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type_: u32, pixels: ?*const anyopaque) void;
    extern fn glDeleteTextures(n: i32, textures: [*]const u32) void;
    extern fn glActiveTexture(texture: u32) void;
    extern fn glPixelStorei(pname: u32, param: i32) void;
    extern fn glBlendFunc(sfactor: u32, dfactor: u32) void;
    extern fn glDrawArrays(mode: u32, first: i32, count: i32) void;
} else struct {
    fn glClearColor(_: f32, _: f32, _: f32, _: f32) void {
        unreachable;
    }
    fn glClear(_: u32) void {
        unreachable;
    }
    fn glEnable(_: u32) void {
        unreachable;
    }
    fn glDisable(_: u32) void {
        unreachable;
    }
    fn glScissor(_: i32, _: i32, _: i32, _: i32) void {
        unreachable;
    }
    fn glViewport(_: i32, _: i32, _: i32, _: i32) void {
        unreachable;
    }
    fn glCreateShader(_: u32) u32 {
        unreachable;
    }
    fn glShaderSource(_: u32, _: i32, _: [*]const [*]const u8, _: ?[*]const i32) void {
        unreachable;
    }
    fn glCompileShader(_: u32) void {
        unreachable;
    }
    fn glGetShaderiv(_: u32, _: u32, _: *i32) void {
        unreachable;
    }
    fn glGetShaderInfoLog(_: u32, _: i32, _: ?*i32, _: [*]u8) void {
        unreachable;
    }
    fn glDeleteShader(_: u32) void {
        unreachable;
    }
    fn glCreateProgram() u32 {
        unreachable;
    }
    fn glAttachShader(_: u32, _: u32) void {
        unreachable;
    }
    fn glLinkProgram(_: u32) void {
        unreachable;
    }
    fn glGetProgramiv(_: u32, _: u32, _: *i32) void {
        unreachable;
    }
    fn glGetProgramInfoLog(_: u32, _: i32, _: ?*i32, _: [*]u8) void {
        unreachable;
    }
    fn glUseProgram(_: u32) void {
        unreachable;
    }
    fn glDeleteProgram(_: u32) void {
        unreachable;
    }
    fn glGetUniformLocation(_: u32, _: [*:0]const u8) i32 {
        unreachable;
    }
    fn glUniform1i(_: i32, _: i32) void {
        unreachable;
    }
    fn glUniform1f(_: i32, _: f32) void {
        unreachable;
    }
    fn glUniformMatrix4fv(_: i32, _: i32, _: u8, _: [*]const f32) void {
        unreachable;
    }
    fn glGenVertexArrays(_: i32, _: [*]u32) void {
        unreachable;
    }
    fn glBindVertexArray(_: u32) void {
        unreachable;
    }
    fn glDeleteVertexArrays(_: i32, _: [*]const u32) void {
        unreachable;
    }
    fn glGenBuffers(_: i32, _: [*]u32) void {
        unreachable;
    }
    fn glBindBuffer(_: u32, _: u32) void {
        unreachable;
    }
    fn glBufferData(_: u32, _: isize, _: ?*const anyopaque, _: u32) void {
        unreachable;
    }
    fn glBufferSubData(_: u32, _: isize, _: isize, _: *const anyopaque) void {
        unreachable;
    }
    fn glDeleteBuffers(_: i32, _: [*]const u32) void {
        unreachable;
    }
    fn glEnableVertexAttribArray(_: u32) void {
        unreachable;
    }
    fn glVertexAttribPointer(_: u32, _: i32, _: u32, _: u8, _: i32, _: ?*const anyopaque) void {
        unreachable;
    }
    fn glGenTextures(_: i32, _: [*]u32) void {
        unreachable;
    }
    fn glBindTexture(_: u32, _: u32) void {
        unreachable;
    }
    fn glTexParameteri(_: u32, _: u32, _: i32) void {
        unreachable;
    }
    fn glTexImage2D(_: u32, _: i32, _: i32, _: i32, _: i32, _: i32, _: u32, _: u32, _: ?*const anyopaque) void {
        unreachable;
    }
    fn glTexSubImage2D(_: u32, _: i32, _: i32, _: i32, _: i32, _: i32, _: u32, _: u32, _: ?*const anyopaque) void {
        unreachable;
    }
    fn glDeleteTextures(_: i32, _: [*]const u32) void {
        unreachable;
    }
    fn glActiveTexture(_: u32) void {
        unreachable;
    }
    fn glPixelStorei(_: u32, _: i32) void {
        unreachable;
    }
    fn glBlendFunc(_: u32, _: u32) void {
        unreachable;
    }
    fn glDrawArrays(_: u32, _: i32, _: i32) void {
        unreachable;
    }
};

const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;
const GL_SCISSOR_TEST: u32 = 0x0C11;

pub const RendererCapabilities = capability_contract.RendererCapabilities;
pub const SceneTargetInvalidation = scene_target_state.SceneTargetInvalidation;

fn supportsRuntimeProfileForBootstrap(_: bootstrap_contract.RendererRuntimeProfile) bool {
    return false;
}

pub fn bootstrapOps() bootstrap_contract.BackendBootstrapOps {
    return .{
        .graphics_binding = .none,
        .supportsRuntimeProfile = supportsRuntimeProfileForBootstrap,
        .configureWindowAttributes = configureWindowAttributes,
        .runStartupSmoke = runStartupSmokeForBootstrap,
    };
}

pub fn configureWindowAttributes() !void {}

pub fn runStartupSmokeForBootstrap(
    _: *sdl_api.c.SDL_Window,
    _: window_init.RenderSurfaceAttachment,
    _: i32,
    _: i32,
) !bool {
    return error.AndroidGlesBootstrapUnavailable;
}

pub fn capabilities(_: anytype) RendererCapabilities {
    return .{
        .scene_composition_mode = .direct_main_target,
        .retained_targets = false,
        .terminal_presentation_mode = .direct_main_target,
        .screenshot_mode = .unavailable,
        .text_rendering_mode = .gl_texture_atlas,
        .planned_text_rendering_mode = .gl_texture_atlas,
        .kitty_image_mode = .unsupported,
        .atlas_storage_mode = .opengl_textures,
        .planned_atlas_storage_mode = .opengl_textures,
        .raw_image_textures = false,
    };
}

pub fn initRuntime(renderer: anytype) !void {
    switch (android_gles_runtime.ensureDisplayContext(&renderer.backend.runtime.androidGlesState().runtime)) {
        .ready => {},
        .init_failed => return error.AndroidGlesInitFailed,
        .surface_failed, .make_current_failed, .swap_failed => return error.AndroidGlesInitFailed,
    }
}

pub fn deinitRuntime(renderer: anytype) void {
    destroyGlResources(renderer);
    renderer.backend.runtime.androidGlesState().queued_surface_draws.deinit(renderer.allocator);
    android_gles_runtime.reset(&renderer.backend.runtime.androidGlesState().runtime);
}

pub fn configureRuntimePolicy(_: anytype) void {}

pub fn beginFrame(renderer: anytype) void {
    const state = renderer.backend.runtime.androidGlesState();
    state.queued_surface_draws.clearRetainingCapacity();
    renderer.backend.runtime.androidGlesState().frame_begin_count += 1;
    if (!target_has_android_gles and !builtin.is_test) {
        renderer_frame_host.noteFrameBeginFailed(renderer);
        return;
    }

    const native_window = renderer.render_host.androidNativeWindow() orelse {
        renderer_frame_host.noteFrameBeginFailed(renderer);
        return;
    };
    const epoch = renderer.render_host.surfaceIdentityEpoch();
    const transition = runtimeTransition(state.runtime.bound_epoch, epoch, native_window);
    switch (android_gles_runtime.ensureWindowSurface(&state.runtime, native_window, epoch, transition)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => {
            renderer_frame_host.noteFrameBeginFailed(renderer);
            return;
        },
    }
    switch (android_gles_runtime.makeCurrent(&state.runtime)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => {
            renderer_frame_host.noteFrameBeginFailed(renderer);
            return;
        },
    }
    bindSharedGlApi();
    if (!state.resources.resources_ready or !renderer.fonts_ready) {
        renderer_frame_host.noteFrameBeginFailed(renderer);
        return;
    }
    syncTextRenderConfig(renderer);

    renderer.present.main_composition_target = .default_target;
    renderer.text_render.dst_linear_active = false;
    renderer.target_pixel_width = renderer.render_width;
    renderer.target_pixel_height = renderer.render_height;
    updateProjection(renderer, renderer.width, renderer.height);
    const bg: types.Rgba = if (renderer.runtime_profile == .backend_smoke)
        .{ .r = 10, .g = 16, .b = 24, .a = 255 }
    else
        renderer.theme.background.toRgba();
    if (!builtin.is_test) {
        gl.glViewport(0, 0, @max(renderer.render_width, 1), @max(renderer.render_height, 1));
        gl.glClearColor(
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        );
        gl.glClear(GL_COLOR_BUFFER_BIT);
    }
    renderer_frame_host.noteFrameReady(renderer);
}

/// Frame-entry scrutiny: backend beginFrame must not lazily initialize GL
/// resources or fonts. Android surface acquisition can legally bind/make
/// current before the first normal frame, so callers must prepare backend
/// frame resources explicitly through this preframe seam.
pub fn prepareFrameResources(renderer: anytype) !void {
    const state = renderer.backend.runtime.androidGlesState();
    if (!target_has_android_gles and !builtin.is_test) return error.AndroidGlesInitFailed;

    const native_window = renderer.render_host.androidNativeWindow() orelse return error.AndroidGlesInitFailed;
    const epoch = renderer.render_host.surfaceIdentityEpoch();
    const transition = runtimeTransition(state.runtime.bound_epoch, epoch, native_window);
    switch (android_gles_runtime.ensureWindowSurface(&state.runtime, native_window, epoch, transition)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => return error.AndroidGlesInitFailed,
    }
    switch (android_gles_runtime.makeCurrent(&state.runtime)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => return error.AndroidGlesInitFailed,
    }
    bindSharedGlApi();

    if (!state.resources.resources_ready) {
        try initGlResources(renderer);
        state.resources.resources_ready = true;
    }
    if (!renderer.fonts_ready) {
        try renderer.initFonts();
        renderer.fonts_ready = true;
    }
    syncTextRenderConfig(renderer);
}

fn bindSharedGlApi() void {
    if (!target_has_android_gles or builtin.is_test) return;
    shared_gl.CreateShader = @ptrCast(&gl.glCreateShader);
    shared_gl.ShaderSource = @ptrCast(&gl.glShaderSource);
    shared_gl.CompileShader = @ptrCast(&gl.glCompileShader);
    shared_gl.GetShaderiv = @ptrCast(&gl.glGetShaderiv);
    shared_gl.GetShaderInfoLog = @ptrCast(&gl.glGetShaderInfoLog);
    shared_gl.DeleteShader = @ptrCast(&gl.glDeleteShader);
    shared_gl.CreateProgram = @ptrCast(&gl.glCreateProgram);
    shared_gl.AttachShader = @ptrCast(&gl.glAttachShader);
    shared_gl.LinkProgram = @ptrCast(&gl.glLinkProgram);
    shared_gl.GetProgramiv = @ptrCast(&gl.glGetProgramiv);
    shared_gl.GetProgramInfoLog = @ptrCast(&gl.glGetProgramInfoLog);
    shared_gl.UseProgram = @ptrCast(&gl.glUseProgram);
    shared_gl.DeleteProgram = @ptrCast(&gl.glDeleteProgram);
    shared_gl.GetUniformLocation = @ptrCast(&gl.glGetUniformLocation);
    shared_gl.Uniform1i = @ptrCast(&gl.glUniform1i);
    shared_gl.Uniform1f = @ptrCast(&gl.glUniform1f);
    shared_gl.UniformMatrix4fv = @ptrCast(&gl.glUniformMatrix4fv);
    shared_gl.GenVertexArrays = @ptrCast(&gl.glGenVertexArrays);
    shared_gl.BindVertexArray = @ptrCast(&gl.glBindVertexArray);
    shared_gl.DeleteVertexArrays = @ptrCast(&gl.glDeleteVertexArrays);
    shared_gl.GenBuffers = @ptrCast(&gl.glGenBuffers);
    shared_gl.BindBuffer = @ptrCast(&gl.glBindBuffer);
    shared_gl.BufferData = @ptrCast(&gl.glBufferData);
    shared_gl.BufferSubData = @ptrCast(&gl.glBufferSubData);
    shared_gl.DeleteBuffers = @ptrCast(&gl.glDeleteBuffers);
    shared_gl.EnableVertexAttribArray = @ptrCast(&gl.glEnableVertexAttribArray);
    shared_gl.VertexAttribPointer = @ptrCast(&gl.glVertexAttribPointer);
    shared_gl.GenTextures = @ptrCast(&gl.glGenTextures);
    shared_gl.BindTexture = @ptrCast(&gl.glBindTexture);
    shared_gl.TexParameteri = @ptrCast(&gl.glTexParameteri);
    shared_gl.TexImage2D = @ptrCast(&gl.glTexImage2D);
    shared_gl.TexSubImage2D = @ptrCast(&gl.glTexSubImage2D);
    shared_gl.DeleteTextures = @ptrCast(&gl.glDeleteTextures);
    shared_gl.ActiveTexture = @ptrCast(&gl.glActiveTexture);
    shared_gl.PixelStorei = @ptrCast(&gl.glPixelStorei);
    shared_gl.Enable = @ptrCast(&gl.glEnable);
    shared_gl.Disable = @ptrCast(&gl.glDisable);
    shared_gl.BlendFunc = @ptrCast(&gl.glBlendFunc);
    shared_gl.Viewport = @ptrCast(&gl.glViewport);
    shared_gl.Scissor = @ptrCast(&gl.glScissor);
    shared_gl.ClearColor = @ptrCast(&gl.glClearColor);
    shared_gl.Clear = @ptrCast(&gl.glClear);
    shared_gl.DrawArrays = @ptrCast(&gl.glDrawArrays);
}

pub fn submitFrame(renderer: anytype) present_trace_runtime.FrameSubmission {
    const state = renderer.backend.runtime.androidGlesState();
    state.frame_submit_count += 1;
    if (renderer.present.frame_execution_state != .ready) {
        return renderer_frame_host.finishFrameSubmission(renderer, .{
            .kind = switch (renderer.present.frame_execution_state) {
                .begin_failed => .begin_failed,
                .abandoned => .abandoned,
                .not_attempted => .not_attempted,
                .ready => .submit_failed,
            },
            .present_ms = 0,
        });
    }

    flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
    const swap_start = std.time.nanoTimestamp();
    const swap_status = android_gles_runtime.swapBuffers(&state.runtime);
    const swap_end = std.time.nanoTimestamp();
    return renderer_frame_host.finishFrameSubmission(renderer, .{
        .kind = if (swap_status == .ready) .submitted else .submit_failed,
        .present_ms = @as(f64, @floatFromInt(swap_end - swap_start)) / std.time.ns_per_ms,
    });
}

pub fn dumpWindowScreenshotPpm(_: anytype, _: []const u8) !void {
    return error.AndroidGlesScreenshotUnavailable;
}

pub fn dumpWindowScreenshotPpmSized(_: anytype, _: []const u8, _: i32, _: i32) !void {
    return error.AndroidGlesScreenshotUnavailable;
}

pub fn clearDiagnosticFont(_: anytype) void {}

pub fn sceneTargetInvalidationForRefresh(_: anytype, _: anytype, _: anytype) SceneTargetInvalidation {
    return .{};
}

pub fn whiteTexture(renderer: anytype) types.Texture {
    return renderer.backend.runtime.androidGlesState().resources.white_texture;
}

pub fn flushQueuedSurfaceDrawsBeforeImmediateWork(renderer: anytype) void {
    replayRecordedSurfaceDraws(renderer);
    renderer.backend.runtime.androidGlesState().queued_surface_draws.clearRetainingCapacity();
}

pub fn bindBatchPipeline(renderer: anytype) void {
    shared_gl.UseProgram(renderer.backend.runtime.androidGlesState().resources.shader_program);
    shared_gl.BindVertexArray(renderer.backend.runtime.androidGlesState().resources.vao);
    shared_gl.BindBuffer(shared_gl.c.GL_ARRAY_BUFFER, renderer.backend.runtime.androidGlesState().resources.vbo);
}

pub fn setTextureKind(renderer: anytype, kind: types.TextureKind) void {
    if (renderer.backend.runtime.androidGlesState().resources.uniform_kind >= 0) {
        shared_gl.Uniform1i(renderer.backend.runtime.androidGlesState().resources.uniform_kind, @intFromEnum(kind));
    }
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize, vertex_size: usize) void {
    if (vertex_count <= renderer.backend.runtime.androidGlesState().resources.vbo_capacity_vertices) return;
    var next_cap = renderer.backend.runtime.androidGlesState().resources.vbo_capacity_vertices * 2;
    if (next_cap < 6) next_cap = 6;
    if (next_cap < vertex_count) next_cap = vertex_count;
    shared_gl.BindBuffer(shared_gl.c.GL_ARRAY_BUFFER, renderer.backend.runtime.androidGlesState().resources.vbo);
    shared_gl.BufferData(
        shared_gl.c.GL_ARRAY_BUFFER,
        @intCast(vertex_size * next_cap),
        null,
        shared_gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.backend.runtime.androidGlesState().resources.vbo_capacity_vertices = next_cap;
}

pub fn mergePendingSceneTargetInvalidation(_: anytype, _: SceneTargetInvalidation) void {}

pub fn ensurePresentable(_: anytype, _: i32, _: i32) bool {
    return false;
}

pub fn refreshTerminalPresentable(
    _: anytype,
    _: anytype,
    _: ?*const anyopaque,
    _: anytype,
) @import("backend_dispatch.zig").TerminalPresentableRefreshResult {
    return .unsupported;
}

pub fn drawPresentableBackdrop(_: anytype, _: f32, _: f32, _: f32, _: f32, _: types.Rgba) void {}

pub fn drawPresentable(_: anytype, _: anytype) void {}

pub fn scrollPresentable(_: anytype, _: i32, _: i32) bool {
    return false;
}

pub fn presentableInfo(_: anytype) ?@import("presentable_contract.zig").PresentableInfo {
    return null;
}

pub fn applyClipRect(renderer: anytype, clip: ?types.Rect) void {
    if (renderer.target_width <= 0 or renderer.target_height <= 0 or renderer.target_pixel_width <= 0 or renderer.target_pixel_height <= 0) {
        shared_gl.Disable(shared_gl.c.GL_SCISSOR_TEST);
        return;
    }
    const active_clip = clip orelse {
        shared_gl.Disable(shared_gl.c.GL_SCISSOR_TEST);
        return;
    };
    if (active_clip.width <= 0 or active_clip.height <= 0) {
        shared_gl.Enable(shared_gl.c.GL_SCISSOR_TEST);
        shared_gl.Scissor(0, 0, 0, 0);
        return;
    }
    shared_gl.Enable(shared_gl.c.GL_SCISSOR_TEST);
    const scale_x = @as(f32, @floatFromInt(renderer.target_pixel_width)) / @as(f32, @floatFromInt(renderer.target_width));
    const scale_y = @as(f32, @floatFromInt(renderer.target_pixel_height)) / @as(f32, @floatFromInt(renderer.target_height));
    const sx: i32 = @intFromFloat(active_clip.x * scale_x);
    const sy: i32 = @intFromFloat((@as(f32, @floatFromInt(renderer.target_height)) - (active_clip.y + active_clip.height)) * scale_y);
    const sw: i32 = @intFromFloat(active_clip.width * scale_x);
    const sh: i32 = @intFromFloat(active_clip.height * scale_y);
    shared_gl.Scissor(sx, sy, sw, sh);
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
    bg_rgba: types.Rgba,
    kind: types.TextureKind,
) void {
    renderer.terminal_text.glyph_cache.addQuad(texture, src, dest, color, bg_rgba, kind);
}

pub fn createPersistentImageFromRgba(_: anytype, _: i32, _: i32, _: []const u8) ?surface_draw.GpuImageRef {
    return null;
}

pub fn createPersistentImageFromRgb(_: anytype, _: i32, _: i32, _: []const u8) ?surface_draw.GpuImageRef {
    return null;
}

pub fn destroyPersistentImage(_: anytype, _: *surface_draw.GpuImageRef) void {}

pub fn drawPersistentImage(_: anytype, _: surface_draw.GpuImageRef, _: ?types.Rect, _: types.Rect, _: types.Rgba) bool {
    return false;
}

pub fn drawRawImage(_: anytype, _: anytype, _: i32, _: i32, _: []const u8, _: types.Rect, _: types.Rgba) bool {
    return false;
}

pub fn recordSurfaceDraw(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    switch (draw) {
        .solid => {},
        else => return false,
    }
    renderer.backend.runtime.androidGlesState().queued_surface_draws.append(renderer.allocator, draw) catch return false;
    return true;
}

fn appendSolidPixels(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) bool {
    if (w <= 0 or h <= 0) return false;
    const clip_rect = if (renderer.currentClipRect()) |clip|
        metal_text_sample_runtime.pixelClipRect(renderer, clip)
    else
        null;
    renderer.backend.runtime.androidGlesState().queued_surface_draws.append(renderer.allocator, .{
        .solid = .{
            .dest_rect = .{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .width = @floatFromInt(w),
                .height = @floatFromInt(h),
            },
            .color = color,
            .clip_rect = clip_rect,
        },
    }) catch return false;
    return true;
}

fn runtimeTransition(bound_epoch: u64, current_epoch: u64, native_window: ?*anyopaque) native_host.SurfaceIdentityTransition {
    if (native_window == null) return .retired;
    if (bound_epoch == current_epoch) return .unchanged;
    if (bound_epoch == 0) return .acquired;
    return .replaced;
}

fn replayRecordedSurfaceDraws(renderer: anytype) void {
    const draws = renderer.backend.runtime.androidGlesState().queued_surface_draws.items;
    for (draws) |draw| {
        switch (draw) {
            .solid => |solid| _ = executeRecordedSurfaceSolid(renderer, solid),
            else => {},
        }
    }
}

fn destroyGlResources(renderer: anytype) void {
    const resources = &renderer.backend.runtime.androidGlesState().resources;
    if (!resources.resources_ready) return;
    if (resources.white_texture.id != 0) {
        var texture_id = resources.white_texture.id;
        shared_gl.DeleteTextures(1, &texture_id);
        resources.white_texture = .{ .id = 0, .width = 0, .height = 0 };
    }
    if (resources.vbo != 0) {
        const vbo = resources.vbo;
        shared_gl.DeleteBuffers(1, &vbo);
        resources.vbo = 0;
    }
    if (resources.vao != 0) {
        const vao = resources.vao;
        shared_gl.DeleteVertexArrays(1, &vao);
        resources.vao = 0;
    }
    if (resources.shader_program != 0) {
        shared_gl.DeleteProgram(resources.shader_program);
        resources.shader_program = 0;
    }
    resources.resources_ready = false;
    resources.vbo_capacity_vertices = 0;
    resources.uniform_proj = -1;
    resources.uniform_tex = -1;
    resources.uniform_kind = -1;
    resources.uniform_text_gamma = -1;
    resources.uniform_text_contrast = -1;
    resources.uniform_dst_linear = -1;
    resources.uniform_linear_correction = -1;
}

fn initGlResources(renderer: anytype) !void {
    const vertex_src =
        "#version 300 es\n" ++
        "precision mediump float;\n" ++
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
        "#version 300 es\n" ++
        "precision mediump float;\n" ++
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
        "        vec4 outc = vec4(color.rgb * a, a);\n" ++
        "        if (u_dst_linear == 0) {\n" ++
        "            outc = unlinearize_premul(outc);\n" ++
        "        }\n" ++
        "        frag_color = outc;\n" ++
        "    } else if (u_kind == 2) {\n" ++
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

    const vert = try compileShader(shared_gl.c.GL_VERTEX_SHADER, vertex_src);
    defer shared_gl.DeleteShader(vert);
    const frag = try compileShader(shared_gl.c.GL_FRAGMENT_SHADER, fragment_src);
    defer shared_gl.DeleteShader(frag);
    const program = try linkProgram(vert, frag);
    const resources = &renderer.backend.runtime.androidGlesState().resources;
    resources.shader_program = program;
    shared_gl.UseProgram(program);

    resources.uniform_proj = shared_gl.GetUniformLocation(program, "u_proj");
    resources.uniform_tex = shared_gl.GetUniformLocation(program, "u_tex");
    resources.uniform_kind = shared_gl.GetUniformLocation(program, "u_kind");
    resources.uniform_dst_linear = shared_gl.GetUniformLocation(program, "u_dst_linear");
    resources.uniform_linear_correction = shared_gl.GetUniformLocation(program, "u_linear_correction");
    resources.uniform_text_gamma = shared_gl.GetUniformLocation(program, "u_text_gamma");
    resources.uniform_text_contrast = shared_gl.GetUniformLocation(program, "u_text_contrast");
    if (resources.uniform_tex >= 0) shared_gl.Uniform1i(resources.uniform_tex, 0);
    if (resources.uniform_kind >= 0) shared_gl.Uniform1i(resources.uniform_kind, 0);
    if (resources.uniform_dst_linear >= 0) shared_gl.Uniform1i(resources.uniform_dst_linear, 0);
    if (resources.uniform_linear_correction >= 0) {
        shared_gl.Uniform1i(resources.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);
    }
    if (resources.uniform_text_gamma >= 0) shared_gl.Uniform1f(resources.uniform_text_gamma, clampPositive(renderer.text_render.gamma, 1.0));
    if (resources.uniform_text_contrast >= 0) shared_gl.Uniform1f(resources.uniform_text_contrast, clampPositive(renderer.text_render.contrast, 1.0));

    shared_gl.GenVertexArrays(1, &resources.vao);
    shared_gl.GenBuffers(1, &resources.vbo);
    shared_gl.BindVertexArray(resources.vao);
    shared_gl.BindBuffer(shared_gl.c.GL_ARRAY_BUFFER, resources.vbo);
    shared_gl.BufferData(
        shared_gl.c.GL_ARRAY_BUFFER,
        gl_resources.computeBufferBytes(@sizeOf(draw_ops.Vertex), 6),
        null,
        shared_gl.c.GL_DYNAMIC_DRAW,
    );
    resources.vbo_capacity_vertices = 6;

    shared_gl.EnableVertexAttribArray(0);
    shared_gl.VertexAttribPointer(0, 2, shared_gl.c.GL_FLOAT, shared_gl.c.GL_FALSE, @sizeOf(draw_ops.Vertex), @ptrFromInt(0));
    shared_gl.EnableVertexAttribArray(1);
    shared_gl.VertexAttribPointer(1, 2, shared_gl.c.GL_FLOAT, shared_gl.c.GL_FALSE, @sizeOf(draw_ops.Vertex), @ptrFromInt(2 * @sizeOf(f32)));
    shared_gl.EnableVertexAttribArray(2);
    shared_gl.VertexAttribPointer(2, 4, shared_gl.c.GL_FLOAT, shared_gl.c.GL_FALSE, @sizeOf(draw_ops.Vertex), @ptrFromInt(4 * @sizeOf(f32)));
    shared_gl.EnableVertexAttribArray(3);
    shared_gl.VertexAttribPointer(3, 4, shared_gl.c.GL_FLOAT, shared_gl.c.GL_FALSE, @sizeOf(draw_ops.Vertex), @ptrFromInt(8 * @sizeOf(f32)));

    shared_gl.Enable(shared_gl.c.GL_BLEND);
    shared_gl.BlendFunc(shared_gl.c.GL_SRC_ALPHA, shared_gl.c.GL_ONE_MINUS_SRC_ALPHA);
    shared_gl.Disable(shared_gl.c.GL_DEPTH_TEST);
    shared_gl.Disable(shared_gl.c.GL_CULL_FACE);

    resources.white_texture = createSolidTexture(1, 1, .{ 255, 255, 255, 255 });
}

fn syncTextRenderConfig(renderer: anytype) void {
    if (!renderer.text_render.config_dirty) return;
    const resources = &renderer.backend.runtime.androidGlesState().resources;
    if (resources.shader_program == 0) return;
    shared_gl.UseProgram(resources.shader_program);
    if (resources.uniform_text_gamma >= 0) {
        shared_gl.Uniform1f(resources.uniform_text_gamma, renderer.text_render.gamma);
    }
    if (resources.uniform_text_contrast >= 0) {
        shared_gl.Uniform1f(resources.uniform_text_contrast, renderer.text_render.contrast);
    }
    if (resources.uniform_linear_correction >= 0) {
        shared_gl.Uniform1i(resources.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);
    }
    renderer.text_render.config_dirty = false;
}

fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    renderer.target_width = width;
    renderer.target_height = height;
    const viewport_w = if (renderer.target_pixel_width > 0) renderer.target_pixel_width else width;
    const viewport_h = if (renderer.target_pixel_height > 0) renderer.target_pixel_height else height;
    shared_gl.Viewport(0, 0, viewport_w, viewport_h);
    if (renderer.backend.runtime.androidGlesState().resources.uniform_proj >= 0) {
        const w = @as(f32, @floatFromInt(width));
        const h = @as(f32, @floatFromInt(height));
        const proj = [_]f32{
            2.0 / w, 0,        0, 0,
            0,       -2.0 / h, 0, 0,
            0,       0,        1, 0,
            -1,      1,        0, 1,
        };
        shared_gl.UseProgram(renderer.backend.runtime.androidGlesState().resources.shader_program);
        shared_gl.UniformMatrix4fv(renderer.backend.runtime.androidGlesState().resources.uniform_proj, 1, shared_gl.c.GL_FALSE, &proj);
    }
}

fn clampPositive(v: f32, fallback: f32) f32 {
    if (std.math.isFinite(v) and v > 0.0) return v;
    return fallback;
}

fn compileShader(kind: shared_gl.GLenum, source: []const u8) !shared_gl.GLuint {
    const shader = shared_gl.CreateShader(kind);
    const src_ptr: [*]const shared_gl.GLchar = @ptrCast(source.ptr);
    const src_len: shared_gl.GLint = @intCast(source.len);
    const lengths = [_]shared_gl.GLint{src_len};
    shared_gl.ShaderSource(shader, 1, @ptrCast(&src_ptr), @ptrCast(&lengths));
    shared_gl.CompileShader(shader);
    var status: shared_gl.GLint = 0;
    shared_gl.GetShaderiv(shader, shared_gl.c.GL_COMPILE_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: shared_gl.GLsizei = 0;
        shared_gl.GetShaderInfoLog(shader, @intCast(log_buf.len), &len, @ptrCast(&log_buf));
        return error.GlShaderCompileFailed;
    }
    return shader;
}

fn linkProgram(vert: shared_gl.GLuint, frag: shared_gl.GLuint) !shared_gl.GLuint {
    const program = shared_gl.CreateProgram();
    shared_gl.AttachShader(program, vert);
    shared_gl.AttachShader(program, frag);
    shared_gl.LinkProgram(program);
    var status: shared_gl.GLint = 0;
    shared_gl.GetProgramiv(program, shared_gl.c.GL_LINK_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: shared_gl.GLsizei = 0;
        shared_gl.GetProgramInfoLog(program, @intCast(log_buf.len), &len, @ptrCast(&log_buf));
        return error.GlProgramLinkFailed;
    }
    return program;
}

fn createSolidTexture(width: i32, height: i32, rgba: [4]u8) types.Texture {
    var id: shared_gl.GLuint = 0;
    shared_gl.GenTextures(1, &id);
    shared_gl.BindTexture(shared_gl.c.GL_TEXTURE_2D, id);
    shared_gl.TexParameteri(shared_gl.c.GL_TEXTURE_2D, shared_gl.c.GL_TEXTURE_MIN_FILTER, shared_gl.c.GL_NEAREST);
    shared_gl.TexParameteri(shared_gl.c.GL_TEXTURE_2D, shared_gl.c.GL_TEXTURE_MAG_FILTER, shared_gl.c.GL_NEAREST);
    shared_gl.TexParameteri(shared_gl.c.GL_TEXTURE_2D, shared_gl.c.GL_TEXTURE_WRAP_S, shared_gl.c.GL_CLAMP_TO_EDGE);
    shared_gl.TexParameteri(shared_gl.c.GL_TEXTURE_2D, shared_gl.c.GL_TEXTURE_WRAP_T, shared_gl.c.GL_CLAMP_TO_EDGE);
    shared_gl.PixelStorei(shared_gl.c.GL_UNPACK_ALIGNMENT, 1);
    shared_gl.TexImage2D(
        shared_gl.c.GL_TEXTURE_2D,
        0,
        shared_gl.c.GL_RGBA,
        width,
        height,
        0,
        shared_gl.c.GL_RGBA,
        shared_gl.c.GL_UNSIGNED_BYTE,
        &rgba,
    );
    return .{ .id = id, .width = width, .height = height };
}

const PixelRect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

fn executeRecordedSurfaceSolid(renderer: anytype, solid: surface_draw.SolidColorDraw) bool {
    var rect = pixelRectFromFloatRect(solid.dest_rect) orelse return false;
    rect = clampPixelRect(rect, renderer.render_width, renderer.render_height) orelse return false;
    if (solid.clip_rect) |clip_rect| {
        rect = intersectPixelRects(rect, .{
            .x = clip_rect.x,
            .y = clip_rect.y,
            .width = clip_rect.width,
            .height = clip_rect.height,
        }) orelse return false;
    }
    if (builtin.is_test) return true;

    gl.glEnable(GL_SCISSOR_TEST);
    defer gl.glDisable(GL_SCISSOR_TEST);
    gl.glScissor(rect.x, renderer.render_height - (rect.y + rect.height), rect.width, rect.height);
    gl.glClearColor(
        @as(f32, @floatFromInt(solid.color.r)) / 255.0,
        @as(f32, @floatFromInt(solid.color.g)) / 255.0,
        @as(f32, @floatFromInt(solid.color.b)) / 255.0,
        @as(f32, @floatFromInt(solid.color.a)) / 255.0,
    );
    gl.glClear(GL_COLOR_BUFFER_BIT);
    return true;
}

fn pixelRectFromFloatRect(rect: types.Rect) ?PixelRect {
    const x0 = @as(i32, @intFromFloat(std.math.round(rect.x)));
    const y0 = @as(i32, @intFromFloat(std.math.round(rect.y)));
    const x1 = @as(i32, @intFromFloat(std.math.round(rect.x + rect.width)));
    const y1 = @as(i32, @intFromFloat(std.math.round(rect.y + rect.height)));
    const width = x1 - x0;
    const height = y1 - y0;
    if (width <= 0 or height <= 0) return null;
    return .{ .x = x0, .y = y0, .width = width, .height = height };
}

fn clampPixelRect(rect: PixelRect, width: i32, height: i32) ?PixelRect {
    const x0 = std.math.clamp(rect.x, 0, width);
    const y0 = std.math.clamp(rect.y, 0, height);
    const x1 = std.math.clamp(rect.x + rect.width, 0, width);
    const y1 = std.math.clamp(rect.y + rect.height, 0, height);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{
        .x = x0,
        .y = y0,
        .width = x1 - x0,
        .height = y1 - y0,
    };
}

fn intersectPixelRects(lhs: PixelRect, rhs: PixelRect) ?PixelRect {
    const x0 = @max(lhs.x, rhs.x);
    const y0 = @max(lhs.y, rhs.y);
    const x1 = @min(lhs.x + lhs.width, rhs.x + rhs.width);
    const y1 = @min(lhs.y + lhs.height, rhs.y + rhs.height);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{
        .x = x0,
        .y = y0,
        .width = x1 - x0,
        .height = y1 - y0,
    };
}
