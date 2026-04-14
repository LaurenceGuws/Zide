const builtin = @import("builtin");
const android_gles_runtime = @import("android_gles_runtime.zig");
const native_host = @import("native_host.zig");

const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;
const GL_TEXTURE_2D: u32 = 0x0DE1;
const GL_RGBA: u32 = 0x1908;
const GL_UNSIGNED_BYTE: u32 = 0x1401;

extern fn glClearColor(red: f32, green: f32, blue: f32, alpha: f32) void;
extern fn glClear(mask: u32) void;
extern fn glGenTextures(n: i32, textures: [*]u32) void;
extern fn glBindTexture(target: u32, texture: u32) void;
extern fn glIsTexture(texture: u32) u8;
extern fn glTexImage2D(target: u32, level: i32, internalformat: i32, width: i32, height: i32, border: i32, format: u32, type_: u32, pixels: ?*const anyopaque) void;
extern fn glTexSubImage2D(target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type_: u32, pixels: ?*const anyopaque) void;

pub const RendererStatus = enum(i32) {
    unavailable = 0,
    ready = 1,
    drawn = 2,
    surface_destroyed = 3,
    init_failed = 4,
    surface_failed = 5,
    make_current_failed = 6,
    swap_failed = 7,
};

const RendererState = struct {
    runtime: android_gles_runtime.State = .{},
    texture: u32 = 0,
    texture_create_count: u32 = 0,
    texture_alive: bool = false,
    texture_upload_count: u32 = 0,
    texture_update_count: u32 = 0,
    texture_resize_count: u32 = 0,
    texture_width: i32 = 0,
    texture_height: i32 = 0,
    last_status: RendererStatus = .unavailable,
    swap_count: u32 = 0,
};

var renderer_state = RendererState{};

fn setError(status: RendererStatus) RendererStatus {
    renderer_state.last_status = status;
    return status;
}

fn setStatus(status: RendererStatus) RendererStatus {
    renderer_state.last_status = status;
    return status;
}

fn ensureDisplayContext() RendererStatus {
    return switch (android_gles_runtime.ensureDisplayContext(&renderer_state.runtime)) {
        .ready => setStatus(.ready),
        .init_failed => setError(.init_failed),
        .surface_failed => setError(.init_failed),
        .make_current_failed => setError(.init_failed),
        .swap_failed => setError(.init_failed),
    };
}

fn destroySurface() void {
    android_gles_runtime.destroySurface(&renderer_state.runtime);
}

fn ensureWindowSurface(window: ?*anyopaque, epoch: u64, transition: native_host.SurfaceIdentityTransition) RendererStatus {
    if (window == null) return setStatus(.unavailable);

    const init_status = ensureDisplayContext();
    if (init_status == .init_failed) return init_status;

    return switch (android_gles_runtime.ensureWindowSurface(&renderer_state.runtime, window, epoch, transition)) {
        .ready => setStatus(.ready),
        .init_failed => setError(.init_failed),
        .surface_failed => setError(.surface_failed),
        .make_current_failed => setError(.surface_failed),
        .swap_failed => setError(.surface_failed),
    };
}

fn drawCurrent(epoch: u64, width: i32, height: i32) RendererStatus {
    if (renderer_state.runtime.display == null or renderer_state.runtime.context == null or renderer_state.runtime.surface == null) {
        return setStatus(.unavailable);
    }

    switch (android_gles_runtime.makeCurrent(&renderer_state.runtime)) {
        .ready => {},
        .make_current_failed => return setError(.make_current_failed),
        .init_failed, .surface_failed, .swap_failed => return setError(.make_current_failed),
    }

    ensureRendererTexture(width, height);

    const phase: u32 = @intCast(epoch % 3);
    const red: f32 = if (phase == 0) 0.88 else 0.14;
    const green: f32 = if (phase == 1) 0.78 else 0.18;
    const blue: f32 = if (phase == 2) 0.82 else 0.22;
    if (!builtin.is_test) {
        glClearColor(red, green, blue, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        switch (android_gles_runtime.swapBuffers(&renderer_state.runtime)) {
            .ready => {},
            .swap_failed => return setError(.swap_failed),
            .init_failed, .surface_failed, .make_current_failed => return setError(.swap_failed),
        }
    }
    renderer_state.swap_count += 1;
    return setStatus(.drawn);
}

fn ensureRendererTexture(width: i32, height: i32) void {
    const texture_width = if (width > 0) width else 2;
    const texture_height = if (height > 0) height else 2;
    if (builtin.is_test) {
        if (renderer_state.texture == 0) {
            renderer_state.texture = 1;
            renderer_state.texture_create_count += 1;
            uploadRendererTexture(texture_width, texture_height);
        } else if (renderer_state.texture_width != texture_width or renderer_state.texture_height != texture_height) {
            renderer_state.texture_resize_count += 1;
            uploadRendererTexture(texture_width, texture_height);
        }
        renderer_state.texture_update_count += 1;
        renderer_state.texture_alive = renderer_state.texture != 0;
        return;
    }

    if (renderer_state.texture != 0 and glIsTexture(renderer_state.texture) != 0) {
        glBindTexture(GL_TEXTURE_2D, renderer_state.texture);
        if (renderer_state.texture_width != texture_width or renderer_state.texture_height != texture_height) {
            renderer_state.texture_resize_count += 1;
            uploadRendererTexture(texture_width, texture_height);
        }
        updateRendererTexture();
        renderer_state.texture_alive = true;
        return;
    }

    var texture: u32 = 0;
    glGenTextures(1, @ptrCast(&texture));
    if (texture == 0) {
        renderer_state.texture = 0;
        renderer_state.texture_alive = false;
        return;
    }

    glBindTexture(GL_TEXTURE_2D, texture);
    renderer_state.texture = texture;
    renderer_state.texture_create_count += 1;
    uploadRendererTexture(texture_width, texture_height);
    renderer_state.texture_alive = glIsTexture(renderer_state.texture) != 0;
}

fn uploadRendererTexture(width: i32, height: i32) void {
    glTexImage2D(GL_TEXTURE_2D, 0, @intCast(GL_RGBA), width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    renderer_state.texture_upload_count += 1;
    renderer_state.texture_width = width;
    renderer_state.texture_height = height;
}

fn updateRendererTexture() void {
    const phase: u8 = @intCast(renderer_state.swap_count % 255);
    const pixel = [_]u8{
        phase,
        0x80,
        0xFF - phase,
        0xFF,
    };
    glBindTexture(GL_TEXTURE_2D, renderer_state.texture);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, @ptrCast(&pixel));
    renderer_state.texture_update_count += 1;
}

pub fn reset() void {
    android_gles_runtime.reset(&renderer_state.runtime);
    renderer_state = .{};
}

pub fn onSurfaceAvailable(
    window: ?*anyopaque,
    epoch: u64,
    transition: native_host.SurfaceIdentityTransition,
    width: i32,
    height: i32,
) RendererStatus {
    const surface_status = ensureWindowSurface(window, epoch, transition);
    if (surface_status != .ready and surface_status != .drawn) return surface_status;
    return drawCurrent(epoch, width, height);
}

pub fn onSurfaceRedrawNeeded() RendererStatus {
    return drawCurrent(renderer_state.runtime.bound_epoch, renderer_state.texture_width, renderer_state.texture_height);
}

pub fn onSurfaceDestroyed() RendererStatus {
    destroySurface();
    return setStatus(.surface_destroyed);
}

pub fn currentStatus() RendererStatus {
    return renderer_state.last_status;
}

pub fn currentSwapCount() u32 {
    return renderer_state.swap_count;
}

pub fn currentBoundEpoch() u64 {
    return renderer_state.runtime.bound_epoch;
}

pub fn currentContextCreateCount() u32 {
    return renderer_state.runtime.context_create_count;
}

pub fn currentSurfaceCreateCount() u32 {
    return renderer_state.runtime.surface_create_count;
}

pub fn currentTextureCreateCount() u32 {
    return renderer_state.texture_create_count;
}

pub fn currentTextureAlive() bool {
    return renderer_state.texture_alive;
}

pub fn currentTextureUploadCount() u32 {
    return renderer_state.texture_upload_count;
}

pub fn currentTextureUpdateCount() u32 {
    return renderer_state.texture_update_count;
}

pub fn currentTextureResizeCount() u32 {
    return renderer_state.texture_resize_count;
}

pub fn currentTextureWidth() i32 {
    return renderer_state.texture_width;
}

pub fn currentTextureHeight() i32 {
    return renderer_state.texture_height;
}

test "surface status recreates the surface when identity epoch changes" {
    const std = @import("std");

    reset();
    try std.testing.expectEqual(RendererStatus.drawn, onSurfaceAvailable(@ptrFromInt(0x1111), 1, .acquired, 400, 200));
    try std.testing.expectEqual(@as(u32, 1), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentSurfaceCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureUploadCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureUpdateCount());
    try std.testing.expectEqual(@as(u32, 0), currentTextureResizeCount());
    try std.testing.expectEqual(@as(i32, 400), currentTextureWidth());
    try std.testing.expectEqual(@as(i32, 200), currentTextureHeight());
    try std.testing.expect(currentTextureAlive());

    try std.testing.expectEqual(RendererStatus.drawn, onSurfaceAvailable(@ptrFromInt(0x1111), 1, .unchanged, 420, 210));
    try std.testing.expectEqual(@as(u32, 2), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentSurfaceCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureCreateCount());
    try std.testing.expectEqual(@as(u32, 2), currentTextureUploadCount());
    try std.testing.expectEqual(@as(u32, 2), currentTextureUpdateCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureResizeCount());
    try std.testing.expectEqual(@as(i32, 420), currentTextureWidth());
    try std.testing.expectEqual(@as(i32, 210), currentTextureHeight());
    try std.testing.expect(currentTextureAlive());

    try std.testing.expectEqual(RendererStatus.drawn, onSurfaceAvailable(@ptrFromInt(0x2222), 2, .replaced, 430, 220));
    try std.testing.expectEqual(@as(u32, 3), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 2), currentSurfaceCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentTextureCreateCount());
    try std.testing.expectEqual(@as(u32, 3), currentTextureUploadCount());
    try std.testing.expectEqual(@as(u32, 3), currentTextureUpdateCount());
    try std.testing.expectEqual(@as(u32, 2), currentTextureResizeCount());
    try std.testing.expectEqual(@as(i32, 430), currentTextureWidth());
    try std.testing.expectEqual(@as(i32, 220), currentTextureHeight());
    try std.testing.expect(currentTextureAlive());

    try std.testing.expectEqual(RendererStatus.surface_destroyed, onSurfaceDestroyed());
    try std.testing.expectEqual(RendererStatus.unavailable, onSurfaceRedrawNeeded());
}
