pub const Action = enum {
    new_file,
    open_file,
    save,
    save_as,
    find,
    replace,
    replace_all,
    cycle_imported_theme_prev,
    cycle_imported_theme,
};

pub const MenuKind = enum {
    file,
    edit,
    view,
};

pub const MenuLabel = struct {
    title: []const u8,
    menu: ?MenuKind,
};

pub const MenuItem = struct {
    label: []const u8,
    action: Action,
};

pub const Menu = struct {
    kind: MenuKind,
    items: []const MenuItem,
};

pub const SharedTopBarModel = struct {
    labels: []const MenuLabel,
    menus: []const Menu,

    pub fn itemsFor(self: *const SharedTopBarModel, menu: MenuKind) []const MenuItem {
        for (self.menus) |entry| {
            if (entry.kind == menu) return entry.items;
        }
        return &.{};
    }
};

const top_labels = [_]MenuLabel{
    .{ .title = "File", .menu = .file },
    .{ .title = "Edit", .menu = .edit },
    .{ .title = "Selection", .menu = null },
    .{ .title = "View", .menu = .view },
    .{ .title = "Go", .menu = null },
    .{ .title = "Run", .menu = null },
    .{ .title = "Terminal", .menu = null },
    .{ .title = "Help", .menu = null },
};

const file_items = [_]MenuItem{
    .{ .label = "New", .action = .new_file },
    .{ .label = "Open...", .action = .open_file },
    .{ .label = "Save", .action = .save },
    .{ .label = "Save As...", .action = .save_as },
};

const edit_items = [_]MenuItem{
    .{ .label = "Find", .action = .find },
    .{ .label = "Replace", .action = .replace },
    .{ .label = "Replace All", .action = .replace_all },
};

const view_items = [_]MenuItem{
    .{ .label = "Previous Imported Theme", .action = .cycle_imported_theme_prev },
    .{ .label = "Next Imported Theme", .action = .cycle_imported_theme },
};

const menus = [_]Menu{
    .{ .kind = .file, .items = &file_items },
    .{ .kind = .edit, .items = &edit_items },
    .{ .kind = .view, .items = &view_items },
};

pub const editor_ide_model = SharedTopBarModel{
    .labels = &top_labels,
    .menus = &menus,
};
