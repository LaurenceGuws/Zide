const builtin = @import("builtin");
const native_host = @import("native_host.zig");

const EGLDisplay = ?*anyopaque;
const EGLSurface = ?*anyopaque;
const EGLContext = ?*anyopaque;
const EGLConfig = ?*anyopaque;

const EGL_FALSE: u32 = 0;
const EGL_NONE: i32 = 0x3038;
const EGL_RED_SIZE: i32 = 0x3024;
const EGL_GREEN_SIZE: i32 = 0x3023;
const EGL_BLUE_SIZE: i32 = 0x3022;
const EGL_ALPHA_SIZE: i32 = 0x3021;
const EGL_RENDERABLE_TYPE: i32 = 0x3040;
const EGL_SURFACE_TYPE: i32 = 0x3033;
const EGL_WINDOW_BIT: i32 = 0x0004;
const EGL_OPENGL_ES2_BIT: i32 = 0x0004;
const EGL_CONTEXT_CLIENT_VERSION: i32 = 0x3098;

const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;

extern fn eglGetDisplay(native_display: ?*anyopaque) EGLDisplay;
extern fn eglInitialize(display: EGLDisplay, major: ?*i32, minor: ?*i32) u32;
extern fn eglChooseConfig(
    display: EGLDisplay,
    attrib_list: [*]const i32,
    configs: [*]EGLConfig,
    config_size: i32,
    num_config: *i32,
) u32;
extern fn eglCreateContext(
    display: EGLDisplay,
    config: EGLConfig,
    share_context: EGLContext,
    attrib_list: [*]const i32,
) EGLContext;
extern fn eglCreateWindowSurface(
    display: EGLDisplay,
    config: EGLConfig,
    native_window: ?*anyopaque,
    attrib_list: [*]const i32,
) EGLSurface;
extern fn eglDestroySurface(display: EGLDisplay, surface: EGLSurface) u32;
extern fn eglDestroyContext(display: EGLDisplay, context: EGLContext) u32;
extern fn eglMakeCurrent(
    display: EGLDisplay,
    draw: EGLSurface,
    read: EGLSurface,
    context: EGLContext,
) u32;
extern fn eglSwapBuffers(display: EGLDisplay, surface: EGLSurface) u32;
extern fn eglTerminate(display: EGLDisplay) u32;
extern fn eglGetError() u32;

extern fn glClearColor(red: f32, green: f32, blue: f32, alpha: f32) void;
extern fn glClear(mask: u32) void;

pub const ProbeStatus = enum(i32) {
    unavailable = 0,
    ready = 1,
    drawn = 2,
    surface_destroyed = 3,
    init_failed = 4,
    surface_failed = 5,
    make_current_failed = 6,
    swap_failed = 7,
};

const ProbeState = struct {
    display: EGLDisplay = null,
    config: EGLConfig = null,
    context: EGLContext = null,
    context_create_count: u32 = 0,
    surface: EGLSurface = null,
    bound_epoch: u64 = 0,
    surface_create_count: u32 = 0,
    last_status: ProbeStatus = .unavailable,
    last_error: u32 = 0,
    swap_count: u32 = 0,
};

var probe_state = ProbeState{};

fn noteError(status: ProbeStatus) ProbeStatus {
    probe_state.last_status = status;
    if (!builtin.is_test) {
        probe_state.last_error = eglGetError();
    }
    return status;
}

fn setStatus(status: ProbeStatus) ProbeStatus {
    probe_state.last_status = status;
    probe_state.last_error = 0;
    return status;
}

fn ensureDisplayContext() ProbeStatus {
    if (probe_state.display == null) {
        probe_state.display = if (builtin.is_test) @ptrFromInt(0xE001) else eglGetDisplay(null);
        if (probe_state.display == null) return noteError(.init_failed);
        if (!builtin.is_test and eglInitialize(probe_state.display, null, null) == EGL_FALSE) {
            return noteError(.init_failed);
        }
    }

    if (probe_state.config == null) {
        var config: EGLConfig = null;
        var config_count: i32 = 0;
        const config_attribs = [_]i32{
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
            EGL_RED_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_ALPHA_SIZE, 8,
            EGL_NONE,
        };
        if (!builtin.is_test and eglChooseConfig(probe_state.display, &config_attribs, @ptrCast(&config), 1, &config_count) == EGL_FALSE) {
            return noteError(.init_failed);
        }
        if (!builtin.is_test and (config_count <= 0 or config == null)) return noteError(.init_failed);
        probe_state.config = if (builtin.is_test) @ptrFromInt(0xE002) else config;
    }

    if (probe_state.context == null) {
        const context_attribs = [_]i32{
            EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL_NONE,
        };
        probe_state.context = if (builtin.is_test)
            @ptrFromInt(0xE003)
        else
            eglCreateContext(probe_state.display, probe_state.config, null, &context_attribs);
        if (probe_state.context == null) return noteError(.init_failed);
        probe_state.context_create_count += 1;
    }

    return setStatus(.ready);
}

fn destroySurface() void {
    if (probe_state.display != null and probe_state.surface != null and !builtin.is_test) {
        _ = eglMakeCurrent(probe_state.display, null, null, null);
        _ = eglDestroySurface(probe_state.display, probe_state.surface);
    }
    probe_state.surface = null;
    probe_state.bound_epoch = 0;
}

fn ensureWindowSurface(window: ?*anyopaque, epoch: u64, transition: native_host.SurfaceIdentityTransition) ProbeStatus {
    if (window == null) return setStatus(.unavailable);

    const init_status = ensureDisplayContext();
    if (init_status == .init_failed) return init_status;

    if (probe_state.surface == null or probe_state.bound_epoch != epoch or transition != .unchanged) {
        destroySurface();
        const surface_attribs = [_]i32{EGL_NONE};
        probe_state.surface = if (builtin.is_test)
            @ptrFromInt(0xE004)
        else
            eglCreateWindowSurface(probe_state.display, probe_state.config, window, &surface_attribs);
        if (probe_state.surface == null) return noteError(.surface_failed);
        probe_state.bound_epoch = epoch;
        probe_state.surface_create_count += 1;
    }

    return setStatus(.ready);
}

fn drawCurrent(epoch: u64) ProbeStatus {
    if (probe_state.display == null or probe_state.context == null or probe_state.surface == null) {
        return setStatus(.unavailable);
    }

    if (!builtin.is_test and eglMakeCurrent(probe_state.display, probe_state.surface, probe_state.surface, probe_state.context) == EGL_FALSE) {
        return noteError(.make_current_failed);
    }

    const phase: u32 = @intCast(epoch % 3);
    const red: f32 = if (phase == 0) 0.88 else 0.14;
    const green: f32 = if (phase == 1) 0.78 else 0.18;
    const blue: f32 = if (phase == 2) 0.82 else 0.22;
    if (!builtin.is_test) {
        glClearColor(red, green, blue, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        if (eglSwapBuffers(probe_state.display, probe_state.surface) == EGL_FALSE) {
            return noteError(.swap_failed);
        }
    }
    probe_state.swap_count += 1;
    return setStatus(.drawn);
}

pub fn reset() void {
    destroySurface();
    if (probe_state.display != null and probe_state.context != null and !builtin.is_test) {
        _ = eglDestroyContext(probe_state.display, probe_state.context);
    }
    if (probe_state.display != null and !builtin.is_test) {
        _ = eglTerminate(probe_state.display);
    }
    probe_state = .{};
}

pub fn noteSurfaceAvailable(
    window: ?*anyopaque,
    epoch: u64,
    transition: native_host.SurfaceIdentityTransition,
) ProbeStatus {
    const surface_status = ensureWindowSurface(window, epoch, transition);
    if (surface_status != .ready and surface_status != .drawn) return surface_status;
    return drawCurrent(epoch);
}

pub fn noteSurfaceRedrawNeeded() ProbeStatus {
    return drawCurrent(probe_state.bound_epoch);
}

pub fn noteSurfaceDestroyed() ProbeStatus {
    destroySurface();
    return setStatus(.surface_destroyed);
}

pub fn currentStatus() ProbeStatus {
    return probe_state.last_status;
}

pub fn currentSwapCount() u32 {
    return probe_state.swap_count;
}

pub fn currentBoundEpoch() u64 {
    return probe_state.bound_epoch;
}

pub fn currentContextCreateCount() u32 {
    return probe_state.context_create_count;
}

pub fn currentSurfaceCreateCount() u32 {
    return probe_state.surface_create_count;
}

test "probe recreates the surface when identity epoch changes" {
    const std = @import("std");

    reset();
    try std.testing.expectEqual(ProbeStatus.drawn, noteSurfaceAvailable(@ptrFromInt(0x1111), 1, .acquired));
    try std.testing.expectEqual(@as(u32, 1), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentSurfaceCreateCount());

    try std.testing.expectEqual(ProbeStatus.drawn, noteSurfaceAvailable(@ptrFromInt(0x1111), 1, .unchanged));
    try std.testing.expectEqual(@as(u32, 2), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 1), currentSurfaceCreateCount());

    try std.testing.expectEqual(ProbeStatus.drawn, noteSurfaceAvailable(@ptrFromInt(0x2222), 2, .replaced));
    try std.testing.expectEqual(@as(u32, 3), currentSwapCount());
    try std.testing.expectEqual(@as(u32, 1), currentContextCreateCount());
    try std.testing.expectEqual(@as(u32, 2), currentSurfaceCreateCount());

    try std.testing.expectEqual(ProbeStatus.surface_destroyed, noteSurfaceDestroyed());
    try std.testing.expectEqual(ProbeStatus.unavailable, noteSurfaceRedrawNeeded());
}
