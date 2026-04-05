const app_shell = @import("../app_shell.zig");
const metal_text_diagnostic_runtime = @import("renderer/metal_text_diagnostic_runtime.zig");

const Shell = app_shell.Shell;

pub const View = struct {
    margin: f32 = 24.0,

    pub fn activate(self: View, shell: *Shell) bool {
        const placement = metal_text_diagnostic_runtime.previewPlacement(shell.rendererPtr(), self.margin);
        return shell.runMacosMetalAtlasUploadDiagnosticAt(placement.dest_x, placement.dest_y);
    }
};
