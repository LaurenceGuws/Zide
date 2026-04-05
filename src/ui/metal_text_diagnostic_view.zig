const std = @import("std");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub const View = struct {
    margin: f32 = 24.0,

    pub fn activate(self: View, shell: *Shell) bool {
        const geometry = shell.uiGeometryContext();
        const scale = if (geometry.ui_scale > 0.0) geometry.ui_scale else 1.0;
        const inset = @as(i32, @intFromFloat(std.math.round(self.margin * scale)));
        return shell.runMacosMetalAtlasUploadDiagnosticAt(inset, inset);
    }
};
