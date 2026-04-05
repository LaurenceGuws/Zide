const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");
const presentable_contract = @import("presentable_contract.zig");
const presentable_target = @import("presentable_target.zig");
const PresentableTarget = presentable_target.PresentableTarget;
pub const PresentableTargetState = presentable_target.PresentableTargetState;

pub const PresentableSurface = presentable_contract.PresentableSurface;
pub const PresentableDraw = presentable_contract.PresentableDraw;

pub fn deinit(self: anytype) void {
    switch (self.backend) {
        .opengl => gl_backend.deinitPresentables(self),
        .metal => metal_backend.deinitPresentables(self),
    }
}

pub fn ensurePresentable(self: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    return switch (self.backend) {
        .opengl => gl_backend.ensurePresentable(self, surface, width, height),
        .metal => metal_backend.ensurePresentable(self, surface, width, height),
    };
}

pub fn beginPresentable(self: anytype, surface: PresentableSurface) bool {
    return switch (self.backend) {
        .opengl => gl_backend.beginPresentable(self, surface),
        .metal => metal_backend.beginPresentable(self, surface),
    };
}

pub fn presentableAvailable(self: anytype, surface: PresentableSurface) bool {
    return switch (self.backend) {
        .opengl => gl_backend.presentableAvailable(self, surface),
        .metal => metal_backend.presentableAvailable(self, surface),
    };
}

pub fn endPresentable(self: anytype, surface: PresentableSurface) void {
    switch (self.backend) {
        .opengl => gl_backend.endPresentable(self, surface),
        .metal => metal_backend.endPresentable(self, surface),
    }
}

pub fn drawPresentable(self: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    switch (self.backend) {
        .opengl => gl_backend.drawPresentable(self, surface, draw),
        .metal => metal_backend.drawPresentable(self, surface, draw),
    }
}

pub fn scrollPresentable(self: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    return switch (self.backend) {
        .opengl => gl_backend.scrollPresentable(self, surface, dx, dy),
        .metal => metal_backend.scrollPresentable(self, surface, dx, dy),
    };
}
