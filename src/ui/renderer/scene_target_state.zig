const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const gl_presentable_target = @import("gl_presentable_target.zig");

const RenderTarget = gl_presentable_target.PresentableTarget;

pub const SceneTargetInvalidation = packed struct(u8) {
    uninitialized: bool = false,
    drawable_resize: bool = false,
    display_change: bool = false,
    render_scale_change: bool = false,
    target_recreate_failure: bool = false,
    _padding: u3 = 0,

    pub fn any(self: SceneTargetInvalidation) bool {
        return self.uninitialized or
            self.drawable_resize or
            self.display_change or
            self.render_scale_change or
            self.target_recreate_failure;
    }

    pub fn merge(self: *SceneTargetInvalidation, other: SceneTargetInvalidation) void {
        self.uninitialized = self.uninitialized or other.uninitialized;
        self.drawable_resize = self.drawable_resize or other.drawable_resize;
        self.display_change = self.display_change or other.display_change;
        self.render_scale_change = self.render_scale_change or other.render_scale_change;
        self.target_recreate_failure = self.target_recreate_failure or other.target_recreate_failure;
    }
};

pub const SceneTargetContract = struct {
    logical_width: i32 = 0,
    logical_height: i32 = 0,
    drawable_width: i32 = 0,
    drawable_height: i32 = 0,
    display_index: i32 = -1,
    render_scale: f32 = 1.0,
};

pub const SceneTargetState = struct {
    target: ?RenderTarget = null,
    contract: SceneTargetContract = .{},
    invalidation: SceneTargetInvalidation = .{ .uninitialized = true },
    pending_invalidation: SceneTargetInvalidation = .{},
    ready: bool = false,
};

pub fn contractFromDisplayMetrics(metrics: platform_window.DisplayMetrics) SceneTargetContract {
    return .{
        .logical_width = metrics.window_w,
        .logical_height = metrics.window_h,
        .drawable_width = metrics.drawable_w,
        .drawable_height = metrics.drawable_h,
        .display_index = metrics.display_index,
        .render_scale = metrics.render_scale,
    };
}

pub fn invalidationForRefresh(
    scene_target: SceneTargetState,
    changes: anytype,
    metrics: platform_window.DisplayMetrics,
    scene_targets_supported: bool,
) SceneTargetInvalidation {
    if (!scene_targets_supported) return .{};
    const next = contractFromDisplayMetrics(metrics);
    const previous = scene_target.contract;
    var reasons: SceneTargetInvalidation = .{};

    if (!scene_target.ready and scene_target.target == null) {
        reasons.uninitialized = true;
    }
    if (changes.resized or changes.pixel_size_changed or
        previous.drawable_width != next.drawable_width or
        previous.drawable_height != next.drawable_height or
        previous.logical_width != next.logical_width or
        previous.logical_height != next.logical_height)
    {
        reasons.drawable_resize = true;
    }
    if (changes.display_changed or previous.display_index != next.display_index) {
        reasons.display_change = true;
    }
    if (changes.display_scale_changed or !std.math.approxEqAbs(f32, previous.render_scale, next.render_scale, 0.0001)) {
        reasons.render_scale_change = true;
    }

    return reasons;
}

pub fn logState(
    logger: app_logger.Logger,
    event: []const u8,
    contract: SceneTargetContract,
    invalidation: SceneTargetInvalidation,
    ready: bool,
) void {
    if (!(logger.enabled_console or logger.enabled_file)) return;
    logger.logf(
        .info,
        "event={s} ready={d} logical={d}x{d} drawable={d}x{d} display={d} render_scale={d:.3} invalidation=uninitialized:{d},drawable_resize:{d},display_change:{d},render_scale_change:{d},target_recreate_failure:{d}",
        .{
            event,
            @intFromBool(ready),
            contract.logical_width,
            contract.logical_height,
            contract.drawable_width,
            contract.drawable_height,
            contract.display_index,
            contract.render_scale,
            @intFromBool(invalidation.uninitialized),
            @intFromBool(invalidation.drawable_resize),
            @intFromBool(invalidation.display_change),
            @intFromBool(invalidation.render_scale_change),
            @intFromBool(invalidation.target_recreate_failure),
        },
    );
}
