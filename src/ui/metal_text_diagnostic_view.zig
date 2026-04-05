const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub const View = struct {
    margin: f32 = 24.0,

    pub fn activate(self: View, shell: *Shell) bool {
        return shell.rendererPtr().runMetalAtlasUploadDiagnostic(self.margin);
    }
};
