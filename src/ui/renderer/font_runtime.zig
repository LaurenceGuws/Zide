const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const hb = terminal_font_mod.c;
const RenderingOptions = terminal_font_mod.RenderingOptions;
const scale_utils = @import("scale_utils.zig");
const font_manager = @import("font_manager.zig");
const text_input = @import("text_input.zig");
const gl = @import("gl.zig");
const app_logger = @import("../../app_logger.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const renderer_root = @import("../renderer.zig");
const TerminalDisableLigaturesStrategy = renderer_root.TerminalDisableLigaturesStrategy;

pub const ScaleState = struct {
    render_scale: f32 = 1.0,
    user_zoom: f32 = 1.0,
    user_zoom_target: f32 = 1.0,
    ui_scale: f32 = 1.0,
    last_zoom_request_time: f64 = 0.0,
    last_zoom_apply_time: f64 = 0.0,
    wayland_scale_cache: ?f32 = null,
    wayland_scale_last_update: f64 = 0.0,
};

pub fn initScaleState(
    allocator: std.mem.Allocator,
    display_metrics: platform_window.DisplayMetrics,
) ScaleState {
    var wayland_scale = scale_utils.WaylandScaleState{
        .cache = null,
        .last_update = -1000.0,
    };
    const ui_scale = scale_utils.queryUiScale(allocator, display_metrics.dpi, 0.0, &wayland_scale);
    return .{
        .render_scale = display_metrics.render_scale,
        .user_zoom = 1.0,
        .user_zoom_target = 1.0,
        .ui_scale = ui_scale,
        .last_zoom_request_time = 0.0,
        .last_zoom_apply_time = 0.0,
        .wayland_scale_cache = wayland_scale.cache,
        .wayland_scale_last_update = wayland_scale.last_update,
    };
}

pub fn setFontRenderingOptions(self: anytype, opts: RenderingOptions) void {
    self.font_config.font_rendering = opts;
}

pub fn setTextRenderingConfig(self: anytype, gamma: ?f32, contrast: ?f32, linear_correction: ?bool) void {
    if (gamma) |v| {
        if (v > 0) self.text_render.gamma = v;
    }
    if (contrast) |v| {
        if (v > 0) self.text_render.contrast = v;
    }
    if (linear_correction) |v| {
        self.text_render.linear_correction = v;
    }

    if (self.shader_program != 0) {
        gl.UseProgram(self.shader_program);
        if (self.uniform_text_gamma >= 0) gl.Uniform1f(self.uniform_text_gamma, self.text_render.gamma);
        if (self.uniform_text_contrast >= 0) gl.Uniform1f(self.uniform_text_contrast, self.text_render.contrast);
        if (self.uniform_linear_correction >= 0) gl.Uniform1i(self.uniform_linear_correction, if (self.text_render.linear_correction) 1 else 0);
    }
}

pub fn setTerminalLigatureConfig(self: anytype, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
    if (strategy) |s| self.font_config.terminal_disable_ligatures = s;
    if (features_raw) |raw| setFontFeatureListRaw(self, &self.font_config.terminal_font_features_raw, &self.font_config.terminal_font_features, raw);
}

pub fn setEditorLigatureConfig(self: anytype, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
    if (strategy) |s| self.font_config.editor_disable_ligatures = s;
    if (features_raw) |raw| setFontFeatureListRaw(self, &self.font_config.editor_font_features_raw, &self.font_config.editor_font_features, raw);
}

fn setFontFeatureListRaw(self: anytype, raw_slot: *?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t), raw: []const u8) void {
    const log = app_logger.logger("renderer.font");
    if (raw_slot.*) |owned| {
        self.allocator.free(owned);
        raw_slot.* = null;
    }
    raw_slot.* = self.allocator.dupe(u8, raw) catch |err| blk: {
        log.logf(.warning, "font feature raw dup failed len={d} err={s}", .{ raw.len, @errorName(err) });
        break :blk null;
    };
    rebuildFontFeaturesList(self, raw_slot.*, list);
}

fn rebuildFontFeaturesList(self: anytype, raw_opt: ?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t)) void {
    const log = app_logger.logger("renderer.font");
    list.items.len = 0;
    const raw = raw_opt orelse return;
    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |piece| {
        const token = std.mem.trim(u8, piece, " \t\r\n");
        if (token.len == 0) continue;
        var feature: hb.hb_feature_t = undefined;
        if (hb.hb_feature_from_string(token.ptr, @intCast(token.len), &feature) != 0) {
            list.append(self.allocator, feature) catch |err| {
                log.logf(.warning, "font feature append failed token={s} err={s}", .{ token, @errorName(err) });
                return;
            };
        }
    }
}

fn hbTag(a: u8, b: u8, cch: u8, d: u8) u32 {
    return (@as(u32, a) << 24) | (@as(u32, b) << 16) | (@as(u32, cch) << 8) | @as(u32, d);
}

const hb_feature_all: u32 = 0xFFFFFFFF;

pub fn collectShapeFeatures(self: anytype, domain: anytype, disable_programming_ligatures: bool, out: []hb.hb_feature_t) usize {
    var len: usize = 0;
    const base = switch (domain) {
        .terminal => self.font_config.terminal_font_features.items,
        .editor => if (self.font_config.editor_font_features_raw != null)
            self.font_config.editor_font_features.items
        else
            self.font_config.terminal_font_features.items,
    };

    for (base) |f| {
        if (len >= out.len) break;
        out[len] = f;
        len += 1;
    }

    if (disable_programming_ligatures and len < out.len) {
        out[len] = .{
            .tag = hbTag('c', 'a', 'l', 't'),
            .value = 0,
            .start = 0,
            .end = hb_feature_all,
        };
        len += 1;
    }
    return len;
}

pub fn queryUiScale(self: anytype) f32 {
    const metrics = platform_window.collectDisplayMetrics(self.window);
    var wayland = scale_utils.WaylandScaleState{
        .cache = self.scale.wayland_scale_cache,
        .last_update = self.scale.wayland_scale_last_update,
    };
    const scale = scale_utils.queryUiScale(self.allocator, metrics.dpi, renderer_root.getTime(), &wayland);
    self.scale.wayland_scale_cache = wayland.cache;
    self.scale.wayland_scale_last_update = wayland.last_update;
    return scale;
}

pub fn applyFontScale(self: anytype) !void {
    try font_manager.applyFontScale(self);
    text_input.reapplyRect(&self.input.text_input_state, self.window);
}

pub fn queueUserZoom(self: anytype, delta: f32, now: f64) bool {
    const result = scale_utils.queueUserZoom(self.scale.user_zoom_target, delta, now, 0.5, 3.0);
    self.scale.user_zoom_target = result.next_target;
    self.scale.last_zoom_request_time = result.request_time;
    return result.changed;
}

pub fn resetUserZoomTarget(self: anytype, now: f64) bool {
    const result = scale_utils.resetUserZoomTarget(self.scale.user_zoom_target, now);
    self.scale.user_zoom_target = result.next_target;
    self.scale.last_zoom_request_time = result.request_time;
    return result.changed;
}

pub fn refreshUiScale(self: anytype) !bool {
    const metrics = platform_window.collectDisplayMetrics(self.window);
    var wayland = scale_utils.WaylandScaleState{
        .cache = self.scale.wayland_scale_cache,
        .last_update = self.scale.wayland_scale_last_update,
    };
    const next = scale_utils.queryUiScale(self.allocator, metrics.dpi, renderer_root.getTime(), &wayland);
    self.scale.wayland_scale_cache = wayland.cache;
    self.scale.wayland_scale_last_update = wayland.last_update;
    const next_render = metrics.render_scale;
    const scale_changed = !std.math.approxEqAbs(f32, next, self.scale.ui_scale, 0.0001);
    const render_changed = !std.math.approxEqAbs(f32, next_render, self.scale.render_scale, 0.0001);
    if (!scale_changed and !render_changed) return false;
    const log = app_logger.logger("ui.scale");
    const layout_size = self.base_font_size * next * self.scale.user_zoom;
    const raster_size = layout_size * next_render;
    log.logf(.info, "ui_scale window={d:.3} render={d:.3}->{d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
        next,
        self.scale.render_scale,
        next_render,
        self.scale.user_zoom,
        self.font_size,
        layout_size,
    });
    log.logf(.info, "ui_scale layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
    self.scale.ui_scale = next;
    self.scale.render_scale = next_render;
    try applyFontScale(self);
    return true;
}

pub fn applyPendingZoom(self: anytype, now: f64) !bool {
    const result = scale_utils.applyPendingZoom(
        self.scale.user_zoom,
        self.scale.user_zoom_target,
        now,
        self.scale.last_zoom_request_time,
        self.scale.last_zoom_apply_time,
        0.04,
        0.02,
    );
    if (!result.changed) return false;
    self.scale.user_zoom = result.next_zoom;
    const log = app_logger.logger("ui.scale");
    const layout_size = self.base_font_size * self.scale.ui_scale * self.scale.user_zoom;
    const raster_size = layout_size * self.scale.render_scale;
    log.logf(.info, "ui_zoom window={d:.3} render={d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
        self.scale.ui_scale,
        self.scale.render_scale,
        self.scale.user_zoom,
        self.font_size,
        layout_size,
    });
    log.logf(.info, "ui_zoom layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
    try applyFontScale(self);
    log.logf(
        .info,
        "ui_zoom_effective base={d:.2} ui={d:.3} zoom={d:.3} target={d:.3} render={d:.3} font={d:.2} term_cell={d:.2}x{d:.2}",
        .{
            self.base_font_size,
            self.scale.ui_scale,
            self.scale.user_zoom,
            self.scale.user_zoom_target,
            self.scale.render_scale,
            self.font_size,
            self.terminal_cell_width,
            self.terminal_cell_height,
        },
    );
    self.scale.last_zoom_apply_time = result.apply_time;
    return true;
}

pub fn fontForSize(self: anytype, size: f32) ?*@import("../terminal_font.zig").TerminalFont {
    return font_manager.fontForSize(self, size);
}
