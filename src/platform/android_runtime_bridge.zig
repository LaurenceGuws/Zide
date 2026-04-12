const builtin = @import("builtin");
const android_gles_probe = @import("android_gles_probe.zig");
const android_host = @import("android_host.zig");
const android_shell_session = @import("android_shell_session.zig");
const app_shell = @import("../app_shell.zig");
const app_terminal_grid = @import("../app/terminal/terminal_grid.zig");
const native_host = @import("native_host.zig");
const renderer_mod = @import("../ui/renderer.zig");
const renderer_surface_host = @import("../ui/renderer/renderer_surface_host.zig");
const renderer_terminal_draw_host = @import("../ui/renderer/renderer_terminal_draw_host.zig");
const shared_types = @import("../types/mod.zig");
const std = @import("std");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const terminal_session_bootstrap = @import("../app/terminal/terminal_session_bootstrap.zig");
const widgets = @import("../ui/widgets.zig");

const android_terminal_runtime_font_path = "/data/data/dev.zide.terminal/files/assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";

const RendererStatus = android_gles_probe.ProbeStatus;

extern fn ANativeWindow_fromSurface(env: ?*anyopaque, surface: ?*anyopaque) ?*anyopaque;
extern fn ANativeWindow_release(window: *anyopaque) void;

const BridgeState = struct {
    seq: u64 = 0,
    app_host: native_host.PlatformAppHost = .{
        .kind = .android_activity,
        .lifecycle_state = .started,
    },
    last_renderer_status: RendererStatus = .unavailable,
    last_surface_transition: native_host.SurfaceIdentityTransition = .unchanged,
    renderer: ?*renderer_mod.Renderer = null,
    terminal_widget_session: ?*terminal_runtime.TerminalRuntimeShell = null,
    terminal_widget: ?widgets.TerminalWidget = null,
    render_host: native_host.PlatformRenderHost = .{
        .binding = .none,
        .surface_availability = .unavailable,
        .surface_metrics = .{},
        .native_handles = .{},
    },
    pinch_zoom_active: bool = false,
};

var bridge_state = BridgeState{};

fn scaleOrDefault(value: f32) f32 {
    return if (value > 0.0) value else 1.0;
}

fn nextSequence() u64 {
    bridge_state.seq += 1;
    return bridge_state.seq;
}

fn destroyRenderer() void {
    const renderer = bridge_state.renderer orelse return;
    renderer.deinit();
    bridge_state.renderer = null;
}

fn destroyTerminalWidget() void {
    if (bridge_state.terminal_widget) |*widget| {
        widget.deinit();
        bridge_state.terminal_widget = null;
    }
    bridge_state.terminal_widget_session = null;
}

fn releaseNativeWindow(window: ?*anyopaque) void {
    if (builtin.is_test) return;
    const value = window orelse return;
    ANativeWindow_release(value);
}

fn swapNativeWindow(window: ?*anyopaque) void {
    releaseNativeWindow(bridge_state.render_host.androidNativeWindow());
    bridge_state.last_surface_transition = bridge_state.render_host.noteAndroidNativeWindow(window);
}

pub fn noteCreate() u64 {
    destroyRenderer();
    destroyTerminalWidget();
    android_gles_probe.reset();
    bridge_state = .{};
    return nextSequence();
}

pub fn noteStart() u64 {
    _ = android_host.noteWillEnterForeground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteResume() u64 {
    _ = android_host.noteDidEnterForeground(&bridge_state.app_host, &bridge_state.render_host);
    return nextSequence();
}

pub fn notePause() u64 {
    _ = android_host.noteWillEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteStop() u64 {
    _ = android_host.noteDidEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteWindowFocusChanged(focused: bool) u64 {
    _ = android_host.noteSurfaceFocus(&bridge_state.app_host, focused);
    return nextSequence();
}

pub fn noteSurfaceAvailable(width: i32, height: i32) u64 {
    _ = android_host.noteSurfaceMetrics(&bridge_state.app_host, &bridge_state.render_host, .{
        .logical_width = width,
        .logical_height = height,
        .drawable_width = width,
        .drawable_height = height,
        .display_scale = 1.0,
        .pixel_density = 1.0,
    });
    return nextSequence();
}

pub fn noteVisibleViewport(width: i32, height: i32, ime_visible: bool) u64 {
    bridge_state.app_host.noteTextInputActive(ime_visible);

    const surface = bridge_state.render_host.surface_metrics;
    bridge_state.render_host.noteVisibleViewport(.{
        .logical_width = @max(width, 1),
        .logical_height = @max(height, 1),
        .drawable_width = @max(width, 1),
        .drawable_height = @max(height, 1),
        .display_scale = scaleOrDefault(surface.display_scale),
        .pixel_density = scaleOrDefault(surface.pixel_density),
    });
    bridge_state.render_host.noteRedrawRequested();
    if (bridge_state.render_host.hasSurface()) {
        bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    }
    return nextSequence();
}

pub fn applyTerminalPinchZoom(scale_factor: f32) i32 {
    if (!(scale_factor > 0.0) or std.math.isNan(scale_factor)) return 0;
    const renderer = bridge_state.renderer orelse return 1;
    const now = app_shell.getTime();
    const changed = renderer.applyPinchZoomForExternalHost(scale_factor, now) catch return 2;
    if (changed) {
        if (bridge_state.terminal_widget) |*widget| {
            widget.invalidatePresentationCache();
        }
    }
    if (bridge_state.render_host.hasSurface()) {
        bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    }
    return 0;
}

pub fn setTerminalPinchActive(active: bool) i32 {
    bridge_state.pinch_zoom_active = active;
    if (!active and bridge_state.render_host.hasSurface()) {
        bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    }
    return 0;
}

pub fn noteSurfaceAvailableFromJava(
    env: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) u64 {
    const native_window = if (builtin.is_test)
        surface
    else
        ANativeWindow_fromSurface(env, surface);
    swapNativeWindow(native_window);
    if (native_window == null) return noteSurfaceDestroyed();
    const seq = noteSurfaceAvailable(width, height);
    bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    return seq;
}

pub fn noteSurfaceDestroyed() u64 {
    swapNativeWindow(null);
    _ = android_host.noteSurfaceDestroyed(&bridge_state.app_host, &bridge_state.render_host);
    if (bridge_state.renderer) |renderer| {
        renderer.syncExternalHostState(bridge_state.app_host, bridge_state.render_host);
    }
    bridge_state.last_renderer_status = .surface_destroyed;
    return nextSequence();
}

pub fn noteSurfaceRedrawNeeded() u64 {
    bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    return nextSequence();
}

pub fn currentNativeWindowToken() usize {
    return @intFromPtr(bridge_state.render_host.androidNativeWindow() orelse return 0);
}

pub fn currentSurfaceIdentityEpoch() u64 {
    return bridge_state.render_host.surfaceIdentityEpoch();
}

pub fn currentSurfaceIdentityTransition() native_host.SurfaceIdentityTransition {
    return bridge_state.last_surface_transition;
}

pub fn currentRendererStatus() RendererStatus {
    return bridge_state.last_renderer_status;
}

pub fn currentRendererSwapCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.swap_count;
    }
    return android_gles_probe.currentSwapCount();
}

pub fn currentRendererBoundEpoch() u64 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.bound_epoch;
    }
    return android_gles_probe.currentBoundEpoch();
}

pub fn currentRendererContextCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.context_create_count;
    }
    return android_gles_probe.currentContextCreateCount();
}

pub fn currentRendererSurfaceCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.surface_create_count;
    }
    return android_gles_probe.currentSurfaceCreateCount();
}

pub fn currentRendererTextureCreateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureCreateCount();
}

pub fn currentRendererTextureAlive() bool {
    if (bridge_state.renderer != null) return false;
    return android_gles_probe.currentTextureAlive();
}

pub fn currentRendererTextureUploadCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureUploadCount();
}

pub fn currentRendererTextureUpdateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureUpdateCount();
}

pub fn currentRendererTextureResizeCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureResizeCount();
}

pub fn currentRendererTextureWidth() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureWidth();
}

pub fn currentRendererTextureHeight() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureHeight();
}

pub fn restartShellSession() i32 {
    destroyTerminalWidget();
    android_shell_session.restart() catch return @intFromEnum(android_shell_session.lastStartStatus());
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn pollShellSession() i32 {
    android_shell_session.pollAndRefresh() catch return @intFromEnum(android_shell_session.lastStartStatus());
    if (bridge_state.render_host.hasSurface()) {
        bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    }
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn isShellSessionAlive() bool {
    return android_shell_session.isAlive();
}

pub fn sendShellCodepoint(codepoint: i32) i32 {
    if (codepoint < 0 or codepoint > 0x10ffff) return @intFromEnum(android_shell_session.SendStatus.send_failed);
    return @intFromEnum(android_shell_session.sendCodepoint(@intCast(codepoint)));
}

pub fn sharedShellRendererActive() bool {
    return bridge_state.renderer != null and bridge_state.terminal_widget_session != null and bridge_state.render_host.hasSurface();
}

pub fn ensureAndroidGlesRenderer() !bool {
    if (bridge_state.renderer != null) return false;
    if (!bridge_state.render_host.hasSurface()) return false;

    const renderer = try renderer_mod.Renderer.initExternalHostBackendSmoke(
        std.heap.c_allocator,
        bridge_state.app_host,
        bridge_state.render_host,
        .{
            .app_font_path = android_terminal_runtime_font_path,
            .editor_font_path = android_terminal_runtime_font_path,
            .terminal_font_path = android_terminal_runtime_font_path,
            .renderer_backend = .android_gles,
            .runtime_profile = .backend_smoke,
        },
    );
    bridge_state.renderer = renderer;
    return true;
}

pub fn drawAndroidGlesRendererFrame() !bool {
    const renderer = bridge_state.renderer orelse return false;
    renderer.syncExternalHostState(bridge_state.app_host, bridge_state.render_host);
    if (!renderer.beginFrame()) return false;
    if (ensureTerminalWidget()) |widget| {
        drawLiveTerminalWidgetFrame(renderer, widget);
        const submission = renderer.submitFrame();
        widget.completePendingPresentationFeedback(submission);
        return submission.succeeded;
    }
    drawBackendSmokeFrame(renderer);
    return renderer.submitFrame().succeeded;
}

/// Render-path rule: callers must justify any work that reaches this entry.
/// This path should stay limited to frame-critical surface sync, draw, and
/// submission mechanics; debug/reporting, transcript churn, and broad staging
/// work do not belong here.
fn drawSharedRendererSurfaceFrame() RendererStatus {
    _ = ensureAndroidGlesRenderer() catch return .init_failed;
    return if (drawAndroidGlesRendererFrame() catch false) .drawn else .surface_failed;
}

fn ensureTerminalWidget() ?*widgets.TerminalWidget {
    const session = android_shell_session.activeRuntimeShell() orelse {
        destroyTerminalWidget();
        return null;
    };
    if (bridge_state.terminal_widget_session != session) {
        destroyTerminalWidget();
        var widget = terminal_session_bootstrap.initWidget(session, .kitty, false, false);
        widget.setUiFocused(true);
        bridge_state.terminal_widget = widget;
        bridge_state.terminal_widget_session = session;
    }
    return if (bridge_state.terminal_widget) |*widget| widget else null;
}

/// Current debt: product-fit grid sizing still lives in the draw path.
/// Keep scrutiny high here; any resize/layout work that is not truly needed
/// for this frame should be staged out of the render path.
fn drawLiveTerminalWidgetFrame(renderer: *renderer_mod.Renderer, widget: *widgets.TerminalWidget) void {
    if (!bridge_state.pinch_zoom_active) {
        ensureProductFitTerminalGrid(renderer, widget) catch {};
    }
    const viewport = bridge_state.render_host.effectiveViewportMetrics();
    const width = @as(f32, @floatFromInt(@max(viewport.logical_width, 1)));
    const height = @as(f32, @floatFromInt(@max(viewport.logical_height, 1)));
    var shell: app_shell.Shell = .{ .renderer = renderer };
    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    const draw_outcome = widget.draw(
        &shell,
        0.0,
        0.0,
        width,
        height,
        input,
    );
    widget.stagePresentationFeedback(draw_outcome);
}

fn ensureProductFitTerminalGrid(renderer: *renderer_mod.Renderer, widget: *widgets.TerminalWidget) !void {
    const viewport = bridge_state.render_host.effectiveViewportMetrics();
    const grid = app_terminal_grid.computeWithEnvOverride(
        @floatFromInt(@max(viewport.logical_width, 1)),
        @floatFromInt(@max(viewport.logical_height, 1)),
        renderer.terminalCellGeometry(),
        1,
        1,
    );
    const resized = try android_shell_session.resizeToGrid(grid.cols, grid.rows, grid.cell_width, grid.cell_height);
    if (resized) widget.invalidatePresentationCache();
}

fn drawBackendSmokeFrame(renderer: *renderer_mod.Renderer) void {
    const width = @as(f32, @floatFromInt(@max(renderer.width, 1)));
    const height = @as(f32, @floatFromInt(@max(renderer.height, 1)));
    const inset = @max(8.0, @min(width, height) * 0.03);
    const preview_band_height = @max(72.0, @min(height * 0.22, 160.0));
    const preview_y = @max(inset, height - inset - preview_band_height);
    const preview_x = inset;
    const preview_w = @max(1.0, width - (inset * 2.0));
    _ = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
        renderer,
        preview_x,
        preview_y,
        preview_w,
        preview_band_height,
        .{ .r = 20, .g = 44, .b = 118, .a = 255 },
    );

    const preview_px = @as(i32, @intFromFloat(std.math.round(preview_x)));
    const preview_py = @as(i32, @intFromFloat(std.math.round(preview_y)));
    const preview_ph = @as(i32, @intFromFloat(std.math.round(preview_band_height)));
    const preview_top = preview_py + 18;
    const cell_w = @max(28, @as(i32, @intFromFloat(std.math.round(preview_w * 0.08))));
    const cell_h = @max(24, @min(42, @divTrunc(preview_ph, 3)));
    const gap = @max(10, cell_w / 4);
    const grid_x = preview_px + 18;
    const grid_y = preview_top;
    const colors = [_]renderer_mod.Color{
        .{ .r = 255, .g = 95, .b = 86, .a = 255 },
        .{ .r = 255, .g = 194, .b = 46, .a = 255 },
        .{ .r = 89, .g = 196, .b = 255, .a = 255 },
        .{ .r = 87, .g = 227, .b = 137, .a = 255 },
    };
    inline for (colors, 0..) |color, idx| {
        renderer_terminal_draw_host.addTerminalRect(
            renderer,
            grid_x + (@as(i32, @intCast(idx)) * (cell_w + gap)),
            grid_y,
            cell_w,
            cell_h,
            color,
        );
    }
    renderer_terminal_draw_host.addTerminalRect(
        renderer,
        grid_x,
        grid_y + cell_h,
        (cell_w * 4) + (gap * 3),
        cell_h,
        renderer_mod.Color{ .r = 19, .g = 28, .b = 44, .a = 255 },
    );
    renderer_terminal_draw_host.addTerminalGlyphRect(
        renderer,
        grid_x + @divTrunc(cell_w, 3),
        grid_y + cell_h + @divTrunc(cell_h, 4),
        @max(3, @divTrunc(cell_w, 6)),
        @max(6, @divTrunc(cell_h, 2)),
        renderer_mod.Color{ .r = 250, .g = 250, .b = 250, .a = 255 },
    );
    renderer_terminal_draw_host.addTerminalGlyphRect(
        renderer,
        grid_x + cell_w + gap + @divTrunc(cell_w, 6),
        grid_y + (cell_h * 2) - 6,
        @max(8, (cell_w * 2) + gap),
        4,
        renderer_mod.Color{ .r = 250, .g = 250, .b = 250, .a = 255 },
    );
}

test "bridge routes Android lifecycle and surface truth through shared host state" {
    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);

    try std.testing.expectEqual(@as(u64, 2), noteStart());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);

    try std.testing.expectEqual(@as(u64, 3), noteResume());
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(bridge_state.app_host.active);
    try std.testing.expect(bridge_state.render_host.redraw_requested);

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 4), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(i32, 400), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expect(bridge_state.render_host.redraw_requested);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(RendererStatus.drawn, currentRendererStatus());

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 5), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 420, 210));
    try std.testing.expectEqual(@as(i32, 420), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.unchanged, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 6), noteWindowFocusChanged(true));
    try std.testing.expect(bridge_state.app_host.surface_focused);
    try std.testing.expect(!bridge_state.app_host.text_input_active);

    try std.testing.expectEqual(@as(u64, 7), notePause());
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(!bridge_state.app_host.active);
    try std.testing.expect(!bridge_state.app_host.surface_focused);

    try std.testing.expectEqual(@as(u64, 8), noteSurfaceDestroyed());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.retired, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(RendererStatus.surface_destroyed, currentRendererStatus());

    try std.testing.expectEqual(@as(u64, 9), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 430, 220));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 3), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 10), noteStop());
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, bridge_state.app_host.lifecycle_state);
}

test "bridge can create and draw a shared android gles renderer for backend smoke" {
    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(@as(u64, 2), noteResume());
    try std.testing.expectEqual(@as(u64, 3), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));

    try std.testing.expect(try ensureAndroidGlesRenderer());
    try std.testing.expect(!try ensureAndroidGlesRenderer());
    try std.testing.expect(try drawAndroidGlesRendererFrame());

    destroyRenderer();
    try std.testing.expectEqual(@as(?*renderer_mod.Renderer, null), bridge_state.renderer);
}

test "bridge visible viewport updates text-input ownership and effective sizing" {
    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(@as(u64, 2), noteResume());
    try std.testing.expectEqual(@as(u64, 3), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expect(!bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 200), bridge_state.render_host.effectiveViewportMetrics().logical_height);

    try std.testing.expectEqual(@as(u64, 4), noteVisibleViewport(400, 120, true));
    try std.testing.expect(bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 120), bridge_state.render_host.effectiveViewportMetrics().logical_height);
    try std.testing.expectEqual(RendererStatus.drawn, currentRendererStatus());

    try std.testing.expectEqual(@as(u64, 5), noteVisibleViewport(400, 200, false));
    try std.testing.expect(!bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 200), bridge_state.render_host.effectiveViewportMetrics().logical_height);
}

test "bridge reports replaced when a live Android surface identity changes without retirement" {
    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(@as(u64, 2), noteResume());

    try std.testing.expectEqual(@as(u64, 3), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 4), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x2000), 410, 210));
    try std.testing.expectEqual(@as(usize, 0x2000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.replaced, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
}
