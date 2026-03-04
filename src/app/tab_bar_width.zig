const config_mod = @import("../config/lua_config.zig");
const widgets = @import("../ui/widgets.zig");

const TabBar = widgets.TabBar;

pub fn mapMode(mode: ?config_mod.TabBarWidthMode) TabBar.WidthMode {
    return switch (mode orelse .fixed) {
        .fixed => .fixed,
        .dynamic => .dynamic,
        .label_length => .label_length,
    };
}
