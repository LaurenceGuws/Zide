const builtin = @import("builtin");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");
const app_top_bar_model_runtime = @import("top_bar_model_runtime.zig");
const window_caption_buttons_runtime = @import("window_caption_buttons_runtime.zig");
const shared_types = @import("../types/mod.zig");

const Rect = shared_types.layout.Rect;
const Shell = app_shell.Shell;
const SharedTopBar = @import("../ui/widgets/shared_top_bar.zig").SharedTopBar;

pub const CaptionButton = window_caption_buttons_runtime.CaptionButton;

pub const Geometry = struct {
    enabled: bool,
    band: Rect,
    content_width: f32,
    caption_rect: Rect,
    sink_rect: Rect,
    minimize_rect: Rect,
    maximize_rect: Rect,
    close_rect: Rect,
    resize_border_px: f32,
};

pub fn isIntegratedActive(app_mode: app_bootstrap.AppMode) bool {
    return builtin.os.tag == .windows and app_modes.ide.supportsEditorSurface(app_mode);
}

pub fn computeGeometry(
    shell: *Shell,
    top_bar: *SharedTopBar,
    band: Rect,
    app_mode: app_bootstrap.AppMode,
) Geometry {
    if (!isIntegratedActive(app_mode) or band.height <= 0 or band.width <= 0) {
        return .{
            .enabled = false,
            .band = band,
            .content_width = 0,
            .caption_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .sink_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .minimize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .maximize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .close_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .resize_border_px = 0,
        };
    }

    const content_width = top_bar.contentWidth(shell, app_top_bar_model_runtime.forMode(app_mode));
    const rects = window_caption_buttons_runtime.computeRects(shell, band, content_width);
    return .{
        .enabled = true,
        .band = band,
        .content_width = content_width,
        .caption_rect = rects.caption_rect,
        .sink_rect = rects.sink_rect,
        .minimize_rect = rects.minimize_rect,
        .maximize_rect = rects.maximize_rect,
        .close_rect = rects.close_rect,
        .resize_border_px = rects.resize_border_px,
    };
}

pub fn buttonAt(geometry: Geometry, x: f32, y: f32) ?CaptionButton {
    if (!geometry.enabled) return null;
    return window_caption_buttons_runtime.buttonAt(geometry, x, y);
}

pub fn captionDragAt(geometry: Geometry, x: f32, y: f32) bool {
    if (!geometry.enabled) return false;
    return window_caption_buttons_runtime.captionDragAt(geometry, x, y);
}

pub fn windowChromeContract(geometry: Geometry) app_shell.WindowChromeContract {
    if (!geometry.enabled) return .{};
    return window_caption_buttons_runtime.windowChromeContract(.top_bar_integrated, geometry);
}
