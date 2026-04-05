const opengl_presentable_runtime = @import("opengl_presentable_runtime.zig");
const presentable_target = @import("presentable_target.zig");
const PresentableTarget = presentable_target.PresentableTarget;

pub const PresentableTargetState = struct {
    terminal: ?PresentableTarget = null,
    terminal_scroll: ?PresentableTarget = null,
    editor: ?PresentableTarget = null,
};

pub const PresentableSurface = enum {
    terminal,
    editor,
};

pub const PresentableDraw = struct {
    x: f32,
    y: f32,
    width: ?f32 = null,
    height: ?f32 = null,
    source_width: ?f32 = null,
    source_height: ?f32 = null,
    generation: ?u64 = null,
};

pub fn deinit(self: anytype) void {
    if (!self.capabilities().retained_targets) return;
    opengl_presentable_runtime.deinit(self);
}

pub fn ensurePresentable(self: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    if (!self.capabilities().retained_targets) return false;
    return opengl_presentable_runtime.ensurePresentable(self, surface, width, height);
}

pub fn beginPresentable(self: anytype, surface: PresentableSurface) bool {
    if (!self.capabilities().retained_targets) return false;
    return opengl_presentable_runtime.beginPresentable(self, surface);
}

pub fn presentableAvailable(self: anytype, surface: PresentableSurface) bool {
    if (!self.capabilities().retained_targets) return false;
    return opengl_presentable_runtime.presentableAvailable(self, surface);
}

pub fn endPresentable(self: anytype, surface: PresentableSurface) void {
    if (!self.capabilities().retained_targets) return;
    opengl_presentable_runtime.endPresentable(self, surface);
}

pub fn drawPresentable(self: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    if (!self.capabilities().retained_targets) return;
    opengl_presentable_runtime.drawPresentable(self, surface, draw);
}

pub fn scrollPresentable(self: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    if (!self.capabilities().retained_targets) return false;
    return opengl_presentable_runtime.scrollPresentable(self, surface, dx, dy);
}
