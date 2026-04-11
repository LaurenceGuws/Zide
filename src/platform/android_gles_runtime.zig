const builtin = @import("builtin");
const native_host = @import("native_host.zig");

const target_has_android_egl = builtin.target.os.tag == .linux and builtin.target.abi == .android;

pub const EGLDisplay = ?*anyopaque;
pub const EGLSurface = ?*anyopaque;
pub const EGLContext = ?*anyopaque;
pub const EGLConfig = ?*anyopaque;

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

const egl = if (target_has_android_egl) struct {
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
} else struct {
    fn eglGetDisplay(_: ?*anyopaque) EGLDisplay {
        unreachable;
    }
    fn eglInitialize(_: EGLDisplay, _: ?*i32, _: ?*i32) u32 {
        unreachable;
    }
    fn eglChooseConfig(_: EGLDisplay, _: [*]const i32, _: [*]EGLConfig, _: i32, _: *i32) u32 {
        unreachable;
    }
    fn eglCreateContext(_: EGLDisplay, _: EGLConfig, _: EGLContext, _: [*]const i32) EGLContext {
        unreachable;
    }
    fn eglCreateWindowSurface(_: EGLDisplay, _: EGLConfig, _: ?*anyopaque, _: [*]const i32) EGLSurface {
        unreachable;
    }
    fn eglDestroySurface(_: EGLDisplay, _: EGLSurface) u32 {
        unreachable;
    }
    fn eglDestroyContext(_: EGLDisplay, _: EGLContext) u32 {
        unreachable;
    }
    fn eglMakeCurrent(_: EGLDisplay, _: EGLSurface, _: EGLSurface, _: EGLContext) u32 {
        unreachable;
    }
    fn eglSwapBuffers(_: EGLDisplay, _: EGLSurface) u32 {
        unreachable;
    }
    fn eglTerminate(_: EGLDisplay) u32 {
        unreachable;
    }
    fn eglGetError() u32 {
        unreachable;
    }
};

pub const RuntimeStatus = enum {
    ready,
    init_failed,
    surface_failed,
    make_current_failed,
    swap_failed,
};

pub const State = struct {
    display: EGLDisplay = null,
    config: EGLConfig = null,
    context: EGLContext = null,
    surface: EGLSurface = null,
    bound_epoch: u64 = 0,
    context_create_count: u32 = 0,
    surface_create_count: u32 = 0,
    swap_count: u32 = 0,
    last_error: u32 = 0,
};

fn noteError(state: *State, status: RuntimeStatus) RuntimeStatus {
    state.last_error = if (!target_has_android_egl or builtin.is_test) 0 else egl.eglGetError();
    return status;
}

fn setReady(state: *State) RuntimeStatus {
    state.last_error = 0;
    return .ready;
}

pub fn ensureDisplayContext(state: *State) RuntimeStatus {
    if (!target_has_android_egl and !builtin.is_test) return .init_failed;

    if (state.display == null) {
        state.display = if (builtin.is_test) @ptrFromInt(0xE001) else egl.eglGetDisplay(null);
        if (state.display == null) return noteError(state, .init_failed);
        if (!builtin.is_test and egl.eglInitialize(state.display, null, null) == EGL_FALSE) {
            return noteError(state, .init_failed);
        }
    }

    if (state.config == null) {
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
        if (!builtin.is_test and egl.eglChooseConfig(state.display, &config_attribs, @ptrCast(&config), 1, &config_count) == EGL_FALSE) {
            return noteError(state, .init_failed);
        }
        if (!builtin.is_test and (config_count <= 0 or config == null)) return noteError(state, .init_failed);
        state.config = if (builtin.is_test) @ptrFromInt(0xE002) else config;
    }

    if (state.context == null) {
        const context_attribs = [_]i32{
            EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL_NONE,
        };
        state.context = if (builtin.is_test)
            @ptrFromInt(0xE003)
        else
            egl.eglCreateContext(state.display, state.config, null, &context_attribs);
        if (state.context == null) return noteError(state, .init_failed);
        state.context_create_count += 1;
    }

    return setReady(state);
}

pub fn destroySurface(state: *State) void {
    if (state.display != null and state.surface != null and !builtin.is_test) {
        _ = egl.eglMakeCurrent(state.display, null, null, null);
        _ = egl.eglDestroySurface(state.display, state.surface);
    }
    state.surface = null;
    state.bound_epoch = 0;
}

pub fn ensureWindowSurface(
    state: *State,
    window: ?*anyopaque,
    epoch: u64,
    transition: native_host.SurfaceIdentityTransition,
) RuntimeStatus {
    if (window == null) return .surface_failed;

    const init_status = ensureDisplayContext(state);
    if (init_status != .ready) return init_status;

    if (state.surface == null or state.bound_epoch != epoch or transition != .unchanged) {
        destroySurface(state);
        const surface_attribs = [_]i32{EGL_NONE};
        state.surface = if (builtin.is_test)
            @ptrFromInt(0xE004)
        else
            egl.eglCreateWindowSurface(state.display, state.config, window, &surface_attribs);
        if (state.surface == null) return noteError(state, .surface_failed);
        state.bound_epoch = epoch;
        state.surface_create_count += 1;
    }

    return setReady(state);
}

pub fn makeCurrent(state: *State) RuntimeStatus {
    if (state.display == null or state.context == null or state.surface == null) {
        return .make_current_failed;
    }
    if (!builtin.is_test and egl.eglMakeCurrent(state.display, state.surface, state.surface, state.context) == EGL_FALSE) {
        return noteError(state, .make_current_failed);
    }
    return setReady(state);
}

pub fn swapBuffers(state: *State) RuntimeStatus {
    if (state.display == null or state.surface == null) return .swap_failed;
    if (!builtin.is_test and egl.eglSwapBuffers(state.display, state.surface) == EGL_FALSE) {
        return noteError(state, .swap_failed);
    }
    state.swap_count += 1;
    return setReady(state);
}

pub fn reset(state: *State) void {
    destroySurface(state);
    if (state.display != null and state.context != null and !builtin.is_test) {
        _ = egl.eglDestroyContext(state.display, state.context);
    }
    if (state.display != null and !builtin.is_test) {
        _ = egl.eglTerminate(state.display);
    }
    state.* = .{};
}

test "runtime recreates the surface when identity epoch changes" {
    const std = @import("std");

    var state: State = .{};
    try std.testing.expectEqual(RuntimeStatus.ready, ensureWindowSurface(&state, @ptrFromInt(0x1111), 1, .acquired));
    try std.testing.expectEqual(@as(u32, 1), state.context_create_count);
    try std.testing.expectEqual(@as(u32, 1), state.surface_create_count);
    try std.testing.expectEqual(@as(u64, 1), state.bound_epoch);

    try std.testing.expectEqual(RuntimeStatus.ready, ensureWindowSurface(&state, @ptrFromInt(0x1111), 1, .unchanged));
    try std.testing.expectEqual(@as(u32, 1), state.context_create_count);
    try std.testing.expectEqual(@as(u32, 1), state.surface_create_count);

    try std.testing.expectEqual(RuntimeStatus.ready, ensureWindowSurface(&state, @ptrFromInt(0x2222), 2, .replaced));
    try std.testing.expectEqual(@as(u32, 1), state.context_create_count);
    try std.testing.expectEqual(@as(u32, 2), state.surface_create_count);
    try std.testing.expectEqual(@as(u64, 2), state.bound_epoch);
    try std.testing.expectEqual(RuntimeStatus.ready, makeCurrent(&state));
    try std.testing.expectEqual(RuntimeStatus.ready, swapBuffers(&state));
    try std.testing.expectEqual(@as(u32, 1), state.swap_count);

    reset(&state);
    try std.testing.expectEqual(@as(?*anyopaque, null), state.surface);
    try std.testing.expectEqual(@as(?*anyopaque, null), state.context);
}
