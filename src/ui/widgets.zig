const mode_build = @import("../app/mode_build.zig");

pub const TabBar = @import("widgets/tab_bar.zig").TabBar;
pub const SharedTopBar = @import("widgets/shared_top_bar.zig").SharedTopBar;
pub const SharedTopBarModel = @import("widgets/shared_top_bar_model.zig").SharedTopBarModel;
pub const shared_top_bar_model = @import("widgets/shared_top_bar_model.zig");
pub const SideNav = @import("widgets/side_nav.zig").SideNav;
pub const StatusBar = @import("widgets/status_bar.zig").StatusBar;
pub const TerminalWidget = @import("widgets/terminal_widget.zig").TerminalWidget;

const editor_widget_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const EditorWidget = opaque {};
    pub const ClusterCache = struct {
        pub fn init(_: anytype) @This() {
            return .{};
        }

        pub fn beginFrame(_: *@This(), _: u64) void {}

        pub fn clear(_: *@This()) void {}

        pub fn deinit(_: *@This()) void {}
    };
} else @import("widgets/editor_widget.zig");

pub const EditorWidget = editor_widget_mod.EditorWidget;
pub const EditorClusterCache = editor_widget_mod.ClusterCache;
