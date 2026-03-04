const std = @import("std");

pub const ModeKind = enum {
    ide,
    editor,
    terminal,
};

pub const TabId = u64;

pub const ViewKind = enum {
    editor,
    terminal,
};

pub const FocusTarget = struct {
    view: ViewKind,
    tab_id: TabId,
};

pub const ModeCapabilities = struct {
    supports_tabs: bool = true,
    supports_reorder: bool = false,
    supports_mixed_views: bool = false,
};

pub const Diagnostics = struct {
    note: []const u8 = "",

    pub fn none() Diagnostics {
        return .{};
    }
};

