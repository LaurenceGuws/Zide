const app_bootstrap = @import("bootstrap.zig");
const widgets = @import("../ui/widgets.zig");

pub fn forMode(app_mode: app_bootstrap.AppMode) *const widgets.SharedTopBarModel {
    _ = app_mode;
    return &widgets.shared_top_bar_model.editor_ide_model;
}
