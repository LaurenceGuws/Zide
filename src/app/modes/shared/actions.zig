const types = @import("types.zig");

pub const TabAction = union(enum) {
    create,
    close: types.TabId,
    activate: types.TabId,
    move: struct {
        from_index: usize,
        to_index: usize,
    },
    activate_by_index: usize,
    next,
    prev,
};

pub const FocusAction = union(enum) {
    set: types.FocusTarget,
    clear,
};

pub const ThemeAction = struct {
    reload_requested: bool = false,
};

pub const ModeAction = union(enum) {
    tab: TabAction,
    focus: FocusAction,
    theme: ThemeAction,
};
