const builtin = @import("builtin");
const android_gles_surface_status = @import("android_gles_surface_status.zig");
const android_shell_session = @import("android_shell_session.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const app_terminal_grid = @import("../app/terminal/terminal_grid.zig");
const android_gles_backend = @import("../ui/renderer/android_gles_backend.zig");
const native_host = @import("native_host.zig");
const renderer_mod = @import("../ui/renderer.zig");
const renderer_surface_host = @import("../ui/renderer/renderer_surface_host.zig");
const renderer_terminal_draw_host = @import("../ui/renderer/renderer_terminal_draw_host.zig");
const shared_types = @import("../types/mod.zig");
const host_lifecycle_runtime = @import("host_lifecycle_runtime.zig");
const std = @import("std");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const terminal_session_runtime_factory = @import("../app/terminal/terminal_session_runtime_factory.zig");
const widgets = @import("../ui/widgets.zig");

const android_runtime_font_path = "/data/data/uk.laurencegouws.zide/files/assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";

const RendererStatus = android_gles_surface_status.RendererStatus;

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
    pinchZoomActive: bool = false,
    productGridFitDirty: bool = true,
};

const ProductGridFitCommitInputs = struct {
    renderer: *renderer_mod.Renderer,
    widget: *widgets.TerminalWidget,
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

pub fn onCreate() u64 {
    app_logger.resetConfig();
    app_logger.setFilePathString("/data/user/0/uk.laurencegouws.zide/files/home/.local/state/zide/zide.log") catch {};
    app_logger.init() catch {};
    destroyRenderer();
    destroyTerminalWidget();
    android_gles_surface_status.reset();
    bridge_state = .{};
    return nextSequence();
}

pub fn onStart() u64 {
    host_lifecycle_runtime.noteWillEnterForeground(&bridge_state.app_host);
    return nextSequence();
}

pub fn onResume() u64 {
    host_lifecycle_runtime.noteDidEnterForeground(&bridge_state.app_host, &bridge_state.render_host);
    return nextSequence();
}

pub fn onPause() u64 {
    host_lifecycle_runtime.noteWillEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn onStop() u64 {
    host_lifecycle_runtime.noteDidEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn onWindowFocusChanged(focused: bool) u64 {
    host_lifecycle_runtime.noteWindowFocusFromInputRuntime(&bridge_state.app_host, focused);
    return nextSequence();
}

pub fn onSurfaceAvailable(width: i32, height: i32) u64 {
    host_lifecycle_runtime.noteSurfaceMetrics(&bridge_state.render_host, .{
        .logical_width = width,
        .logical_height = height,
        .drawable_width = width,
        .drawable_height = height,
        .display_scale = 1.0,
        .pixel_density = 1.0,
    });
    bridge_state.productGridFitDirty = true;
    return nextSequence();
}

pub fn onVisibleViewport(width: i32, height: i32, imeVisible: bool) u64 {
    bridge_state.app_host.noteTextInputActive(imeVisible);

    const surface = bridge_state.render_host.surface_metrics;
    bridge_state.render_host.noteVisibleViewport(.{
        .logical_width = @max(width, 1),
        .logical_height = @max(height, 1),
        .drawable_width = @max(width, 1),
        .drawable_height = @max(height, 1),
        .display_scale = scaleOrDefault(surface.display_scale),
        .pixel_density = scaleOrDefault(surface.pixel_density),
    });
    bridge_state.productGridFitDirty = true;
    bridge_state.render_host.noteRedrawRequested();
    return nextSequence();
}

pub fn applyPinchZoom(scale_factor: f32) i32 {
    if (!(scale_factor > 0.0) or std.math.isNan(scale_factor)) return 0;
    const renderer = bridge_state.renderer orelse return 1;
    const now = app_shell.getTime();
    const changed = renderer.applyPinchZoomForExternalHost(scale_factor, now) catch return 2;
    if (changed) {
        bridge_state.productGridFitDirty = true;
        if (bridge_state.terminal_widget) |*widget| {
            widget.invalidatePresentationGeometry();
        }
        bridge_state.render_host.noteRedrawRequested();
    }
    return 0;
}

pub fn setPinchActive(active: bool) i32 {
    bridge_state.pinchZoomActive = active;
    if (!active) {
        if (bridge_state.renderer) |renderer| {
            if (renderer.settleExternalHostTerminalFontScale()) {
                bridge_state.productGridFitDirty = true;
            }
        }
        if (bridge_state.terminal_widget) |*widget| {
            widget.invalidatePresentationGeometry();
        }
        bridge_state.render_host.noteRedrawRequested();
    }
    return 0;
}

pub fn onSurfaceAvailableFromJava(
    env: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) u64 {
    const nativeWindow = if (builtin.is_test)
        surface
    else
        ANativeWindow_fromSurface(env, surface);
    swapNativeWindow(nativeWindow);
    if (nativeWindow == null) return onSurfaceDestroyed();
    const seq = onSurfaceAvailable(width, height);
    submitLifecycleCriticalSurfaceFrame();
    return seq;
}

pub fn onSurfaceDestroyed() u64 {
    swapNativeWindow(null);
    host_lifecycle_runtime.noteSurfaceDestroyed(&bridge_state.app_host, &bridge_state.render_host);
    if (bridge_state.renderer) |renderer| {
        renderer.syncExternalHostState(bridge_state.app_host, bridge_state.render_host);
    }
    bridge_state.last_renderer_status = .surface_destroyed;
    return nextSequence();
}

pub fn onSurfaceRedrawNeeded() u64 {
    submitLifecycleCriticalSurfaceFrame();
    return nextSequence();
}

pub fn currentNativeWindowToken() usize {
    return @intFromPtr(bridge_state.render_host.androidNativeWindow() orelse return 0);
}

pub fn currentSurfaceEpoch() u64 {
    return bridge_state.render_host.surfaceIdentityEpoch();
}

pub fn currentSurfaceTransition() native_host.SurfaceIdentityTransition {
    return bridge_state.last_surface_transition;
}

pub fn currentRendererStatus() RendererStatus {
    return bridge_state.last_renderer_status;
}

pub fn currentRendererSwapCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.swap_count;
    }
    return android_gles_surface_status.currentSwapCount();
}

pub fn currentRendererBoundEpoch() u64 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.bound_epoch;
    }
    return android_gles_surface_status.currentBoundEpoch();
}

pub fn currentRendererContextCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.context_create_count;
    }
    return android_gles_surface_status.currentContextCreateCount();
}

pub fn currentRendererSurfaceCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.surface_create_count;
    }
    return android_gles_surface_status.currentSurfaceCreateCount();
}

pub fn currentRendererTextureCreateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureCreateCount();
}

pub fn currentRendererTextureAlive() bool {
    if (bridge_state.renderer != null) return false;
    return android_gles_surface_status.currentTextureAlive();
}

pub fn currentRendererTextureUploadCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureUploadCount();
}

pub fn currentRendererTextureUpdateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureUpdateCount();
}

pub fn currentRendererTextureResizeCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureResizeCount();
}

pub fn currentRendererTextureWidth() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureWidth();
}

pub fn currentRendererTextureHeight() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_surface_status.currentTextureHeight();
}

pub fn restartSession() i32 {
    destroyTerminalWidget();
    bridge_state.productGridFitDirty = true;
    android_shell_session.restart() catch return @intFromEnum(android_shell_session.lastStartStatus());
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn pollSession() i32 {
    refreshShellSurfaceAfterInput();
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn sessionAlive() bool {
    return android_shell_session.isAlive();
}

pub fn tickFrame() i32 {
    if (!android_shell_session.isAlive()) return 0;
    android_shell_session.poll() catch return 0;

    var pending_zoom_changed = false;
    if (!bridge_state.pinchZoomActive) {
        if (bridge_state.renderer) |renderer| {
            pending_zoom_changed = renderer.applyPendingZoomForExternalHost(app_shell.getTime()) catch false;
            if (pending_zoom_changed) {
                bridge_state.productGridFitDirty = true;
            }
            if (renderer.settleExternalHostTerminalFontScale()) {
                bridge_state.productGridFitDirty = true;
                if (bridge_state.terminal_widget) |*widget| {
                    widget.invalidatePresentationGeometry();
                }
                bridge_state.render_host.noteRedrawRequested();
            }
            if (pending_zoom_changed) {
                if (bridge_state.terminal_widget) |*widget| {
                    widget.invalidatePresentationGeometry();
                }
                bridge_state.render_host.noteRedrawRequested();
            }
        }
    }

    if (bridge_state.productGridFitDirty) {
        flushDirtyProductFitGridBeforeFrame();
    }

    const prep_result_ready = if (bridge_state.renderer) |renderer|
        renderer.terminalGlyphPrepResultNeedsRedraw()
    else
        false;

    const should_draw =
        bridge_state.render_host.hasSurface() and
        (android_shell_session.needsRedraw() or
            bridge_state.render_host.redraw_requested or
            bridge_state.pinchZoomActive or
            pending_zoom_changed or
            prep_result_ready);
    if (!should_draw) return 1;

    bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
    bridge_state.render_host.clearRedrawRequested();
    return 2;
}

pub fn sendCodepoint(codepoint: i32) i32 {
    if (codepoint < 0 or codepoint > 0x10ffff) return @intFromEnum(android_shell_session.SendStatus.send_failed);
    if (android_shell_session.currentScrollbackState().offset > 0) {
        _ = android_shell_session.followLiveBottom();
    }
    const status = android_shell_session.sendCodepoint(@intCast(codepoint));
    if (status == .ok) refreshShellSurfaceAfterInput();
    return @intFromEnum(status);
}

pub fn visibleRows() i32 {
    return @intCast(android_shell_session.currentScrollbackState().rows);
}

pub fn visibleCols() i32 {
    return @intCast(android_shell_session.currentVisibleCols());
}

pub fn scrollbackCount() i32 {
    return @intCast(android_shell_session.currentScrollbackState().count);
}

pub fn scrollbackOffset() i32 {
    return @intCast(android_shell_session.currentScrollbackState().offset);
}

pub fn setScrollbackOffset(offsetRows: i32) i32 {
    if (offsetRows < 0) return @intFromEnum(android_shell_session.ScrollbackStatus.failed);
    const status = android_shell_session.setScrollbackOffset(@intCast(offsetRows));
    if (status == .ok) refreshShellSurfaceAfterScrollbackChange();
    return @intFromEnum(status);
}

pub fn followLiveBottom() i32 {
    const status = android_shell_session.followLiveBottom();
    if (status == .ok) refreshShellSurfaceAfterScrollbackChange();
    return @intFromEnum(status);
}

pub fn beginWordSelectionAtCell(row: i32, col: i32) i32 {
    if (row < 0 or col < 0) return @intFromEnum(android_shell_session.SelectionStatus.no_visible_cell);
    const status = android_shell_session.beginWordSelectionAtVisibleCell(@intCast(row), @intCast(col));
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn extendSelectionGestureToCell(row: i32, col: i32) i32 {
    if (row < 0 or col < 0) return @intFromEnum(android_shell_session.SelectionStatus.no_visible_cell);
    const status = android_shell_session.extendSelectionGestureToVisibleCell(@intCast(row), @intCast(col));
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn finishSelectionGesture() i32 {
    const status = android_shell_session.finishSelectionGesture();
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn clearSelection() i32 {
    const status = android_shell_session.clearSelection();
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn updateSelectionStartAtCell(row: i32, col: i32) i32 {
    if (row < 0 or col < 0) return @intFromEnum(android_shell_session.SelectionStatus.no_visible_cell);
    const status = android_shell_session.updateSelectionEndpointAtVisibleCell(.start, @intCast(row), @intCast(col));
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn updateSelectionEndAtCell(row: i32, col: i32) i32 {
    if (row < 0 or col < 0) return @intFromEnum(android_shell_session.SelectionStatus.no_visible_cell);
    const status = android_shell_session.updateSelectionEndpointAtVisibleCell(.end, @intCast(row), @intCast(col));
    if (status == .ok) refreshShellSurfaceAfterSelectionChange();
    return @intFromEnum(status);
}

pub fn selectionActive() bool {
    return android_shell_session.currentSelectionViewportRect().active;
}

pub fn selectionRectLeft() i32 {
    return android_shell_session.currentSelectionViewportRect().left_px;
}

pub fn selectionRectTop() i32 {
    return android_shell_session.currentSelectionViewportRect().top_px;
}

pub fn selectionRectRight() i32 {
    return android_shell_session.currentSelectionViewportRect().right_px;
}

pub fn selectionRectBottom() i32 {
    return android_shell_session.currentSelectionViewportRect().bottom_px;
}

pub fn selectionStartRectLeft() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.start).left_px;
}

pub fn selectionStartRectTop() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.start).top_px;
}

pub fn selectionStartRectRight() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.start).right_px;
}

pub fn selectionStartRectBottom() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.start).bottom_px;
}

pub fn selectionEndRectLeft() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.end).left_px;
}

pub fn selectionEndRectTop() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.end).top_px;
}

pub fn selectionEndRectRight() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.end).right_px;
}

pub fn selectionEndRectBottom() i32 {
    return android_shell_session.currentSelectionEndpointViewportRect(.end).bottom_px;
}

pub fn selectionTextAlloc(allocator: std.mem.Allocator) !?[]u8 {
    return try android_shell_session.selectionTextAlloc(allocator);
}

/// Direct shell input must not depend on a separate Java refresh loop to become
/// visible. When input reaches the PTY successfully, Android-owned shell
/// hosting must poll terminal state immediately, invalidate widget
/// presentation, and hand redraw authority back to the paced product frame
/// loop instead of submitting a frame inline on the input path.
fn refreshShellSurfaceAfterInput() void {
    android_shell_session.poll() catch return;
    if (bridge_state.terminal_widget) |*widget| {
        widget.invalidatePresentationCache();
    }
    bridge_state.render_host.noteRedrawRequested();
}

fn refreshShellSurfaceAfterScrollbackChange() void {
    if (bridge_state.terminal_widget) |*widget| {
        widget.invalidatePresentationCache();
    }
    bridge_state.render_host.noteRedrawRequested();
}

fn refreshShellSurfaceAfterSelectionChange() void {
    if (bridge_state.terminal_widget) |*widget| {
        widget.invalidatePresentationCache();
    }
    bridge_state.render_host.noteRedrawRequested();
}

fn productFitGridCommitInputs() ?ProductGridFitCommitInputs {
    const renderer = bridge_state.renderer orelse return null;
    const widget = ensureTerminalWidget() orelse return null;
    return .{
        .renderer = renderer,
        .widget = widget,
    };
}

fn commitDirtyProductFitTerminalGrid(inputs: ProductGridFitCommitInputs) !void {
    try ensureProductFitTerminalGrid(inputs.renderer, inputs.widget);
    bridge_state.productGridFitDirty = false;
}

fn commitDirtyProductFitTerminalGridIfReady() void {
    if (!bridge_state.productGridFitDirty) return;
    const inputs = productFitGridCommitInputs() orelse return;
    commitDirtyProductFitTerminalGrid(inputs) catch return;
}

/// Android product-fit ownership seam: if product-fit state is dirty, create
/// the renderer if needed and flush the pending grid commit before any frame
/// draw/submission path enters live widget rendering.
fn flushDirtyProductFitGridBeforeFrame() void {
    if (!bridge_state.productGridFitDirty) return;
    _ = ensureAndroidGlesRenderer() catch return;
    commitDirtyProductFitTerminalGridIfReady();
}

/// Lifecycle/surface-critical direct submit seam. Surface-available and
/// redraw-needed remain the only direct frame submission authority on Android;
/// ordinary product work must stay on the paced product frame loop.
fn submitLifecycleCriticalSurfaceFrame() void {
    flushDirtyProductFitGridBeforeFrame();
    bridge_state.last_renderer_status = drawSharedRendererSurfaceFrame();
}

pub fn rendererActive() bool {
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
            .app_font_path = android_runtime_font_path,
            .editor_font_path = android_runtime_font_path,
            .terminal_font_path = android_runtime_font_path,
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
    try android_gles_backend.prepareFrameResources(renderer);
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
/// submission mechanics; debug/reporting, UI churn, and broad staging
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
        var widget = terminal_session_runtime_factory.initWidget(session, .kitty, false, false);
        widget.setUiFocused(true);
        bridge_state.terminal_widget = widget;
        bridge_state.terminal_widget_session = session;
    }
    return if (bridge_state.terminal_widget) |*widget| widget else null;
}

/// Live terminal draw is not allowed to own product-fit/grid resize decisions.
/// Callers must flush any required grid commit before entering frame draw, so
/// this path stays limited to viewport draw and presentation feedback staging.
fn drawLiveTerminalWidgetFrame(renderer: *renderer_mod.Renderer, widget: *widgets.TerminalWidget) void {
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
    if (resized) widget.invalidatePresentationGeometry();
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
    try std.testing.expectEqual(@as(u64, 1), onCreate());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);

    try std.testing.expectEqual(@as(u64, 2), onStart());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);

    try std.testing.expectEqual(@as(u64, 3), onResume());
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(bridge_state.app_host.active);
    try std.testing.expect(bridge_state.render_host.redraw_requested);

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 4), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(i32, 400), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expect(bridge_state.render_host.redraw_requested);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceTransition());
    try std.testing.expectEqual(RendererStatus.drawn, currentRendererStatus());

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 5), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 420, 210));
    try std.testing.expectEqual(@as(i32, 420), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.unchanged, currentSurfaceTransition());

    try std.testing.expectEqual(@as(u64, 6), onWindowFocusChanged(true));
    try std.testing.expect(bridge_state.app_host.surface_focused);
    try std.testing.expect(!bridge_state.app_host.text_input_active);

    try std.testing.expectEqual(@as(u64, 7), onPause());
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(!bridge_state.app_host.active);
    try std.testing.expect(!bridge_state.app_host.surface_focused);

    try std.testing.expectEqual(@as(u64, 8), onSurfaceDestroyed());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.retired, currentSurfaceTransition());
    try std.testing.expectEqual(RendererStatus.surface_destroyed, currentRendererStatus());

    try std.testing.expectEqual(@as(u64, 9), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 430, 220));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 3), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceTransition());

    try std.testing.expectEqual(@as(u64, 10), onStop());
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, bridge_state.app_host.lifecycle_state);
}

test "bridge can create and draw a shared android gles renderer for backend smoke" {
    try std.testing.expectEqual(@as(u64, 1), onCreate());
    try std.testing.expectEqual(@as(u64, 2), onResume());
    try std.testing.expectEqual(@as(u64, 3), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));

    try std.testing.expect(try ensureAndroidGlesRenderer());
    try std.testing.expect(!try ensureAndroidGlesRenderer());
    try std.testing.expect(try drawAndroidGlesRendererFrame());

    destroyRenderer();
    try std.testing.expectEqual(@as(?*renderer_mod.Renderer, null), bridge_state.renderer);
}

test "bridge visible viewport updates text-input ownership and effective sizing" {
    try std.testing.expectEqual(@as(u64, 1), onCreate());
    try std.testing.expectEqual(@as(u64, 2), onResume());
    try std.testing.expectEqual(@as(u64, 3), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expect(!bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 200), bridge_state.render_host.effectiveViewportMetrics().logical_height);

    try std.testing.expectEqual(@as(u64, 4), onVisibleViewport(400, 120, true));
    try std.testing.expect(bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 120), bridge_state.render_host.effectiveViewportMetrics().logical_height);
    try std.testing.expectEqual(RendererStatus.drawn, currentRendererStatus());

    try std.testing.expectEqual(@as(u64, 5), onVisibleViewport(400, 200, false));
    try std.testing.expect(!bridge_state.app_host.text_input_active);
    try std.testing.expectEqual(@as(i32, 200), bridge_state.render_host.effectiveViewportMetrics().logical_height);
}

test "bridge reports replaced when a live Android surface identity changes without retirement" {
    try std.testing.expectEqual(@as(u64, 1), onCreate());
    try std.testing.expectEqual(@as(u64, 2), onResume());

    try std.testing.expectEqual(@as(u64, 3), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceTransition());

    try std.testing.expectEqual(@as(u64, 4), onSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x2000), 410, 210));
    try std.testing.expectEqual(@as(usize, 0x2000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.replaced, currentSurfaceTransition());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
}
