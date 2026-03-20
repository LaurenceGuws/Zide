const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");
const model = @import("shared_top_bar_model.zig");

const Shell = app_shell.Shell;
const LayoutRect = shared_types.layout.Rect;

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: Rect, mouse: shared_types.input.MousePos) bool {
        return mouse.x >= self.x and mouse.x <= self.x + self.w and mouse.y >= self.y and mouse.y <= self.y + self.h;
    }
};

pub fn contentWidth(shell: *Shell, model_: *const model.SharedTopBarModel, bar_height: f32) f32 {
    const scale = shell.uiScaleFactor();
    const y = (bar_height - shell.charHeight()) / 2;
    var x: f32 = 10 * scale;
    var max_right: f32 = 0;
    for (model_.labels) |label| {
        const rect = labelRect(shell, x, y, label.title);
        max_right = rect.x + rect.w;
        x += rect.w + 4 * scale;
    }
    return max_right + scale;
}

pub fn labelRectAt(shell: *Shell, x: f32, y: f32, title: []const u8) Rect {
    return labelRect(shell, x, y, title);
}

pub fn labelAt(shell: *Shell, model_: *const model.SharedTopBarModel, bar: LayoutRect, mouse: shared_types.input.MousePos) ?model.MenuLabel {
    const scale = shell.uiScaleFactor();
    const y = bar.y + (bar.height - shell.charHeight()) / 2;
    var x = bar.x + 10 * scale;
    for (model_.labels) |label| {
        const rect = labelRect(shell, x, y, label.title);
        if (rect.contains(mouse)) return label;
        x += rect.w + 4 * scale;
    }
    return null;
}

pub fn menuAnchorRect(shell: *Shell, model_: *const model.SharedTopBarModel, bar: LayoutRect, menu: model.MenuKind) ?Rect {
    const scale = shell.uiScaleFactor();
    const y = bar.y + (bar.height - shell.charHeight()) / 2;
    var x = bar.x + 10 * scale;
    for (model_.labels) |label| {
        const rect = labelRect(shell, x, y, label.title);
        if (label.menu != null and label.menu.? == menu) return rect;
        x += rect.w + 4 * scale;
    }
    return null;
}

pub fn menuRect(shell: *Shell, model_: *const model.SharedTopBarModel, bar: LayoutRect, menu: model.MenuKind) Rect {
    const scale = shell.uiScaleFactor();
    const anchor = menuAnchorRect(shell, model_, bar, menu).?;
    const items = model_.itemsFor(menu);
    var max_label_len: usize = 0;
    for (items) |item| {
        max_label_len = @max(max_label_len, item.label.len);
    }
    const pad_x: f32 = 10 * scale;
    const item_h: f32 = shell.charHeight() + 10 * scale;
    const menu_w = @as(f32, @floatFromInt(max_label_len)) * shell.charWidth() + pad_x * 2;
    return .{
        .x = anchor.x,
        .y = bar.y + bar.height + 4 * scale,
        .w = menu_w + 18 * scale,
        .h = item_h * @as(f32, @floatFromInt(items.len)) + 8 * scale,
    };
}

pub fn itemRect(shell: *Shell, model_: *const model.SharedTopBarModel, bar: LayoutRect, menu: model.MenuKind, item_index: usize) Rect {
    const scale = shell.uiScaleFactor();
    const base = menuRect(shell, model_, bar, menu);
    const item_h: f32 = shell.charHeight() + 10 * scale;
    return .{
        .x = base.x + 4 * scale,
        .y = base.y + 4 * scale + item_h * @as(f32, @floatFromInt(item_index)),
        .w = base.w - 8 * scale,
        .h = item_h,
    };
}

pub fn menuItemAt(shell: *Shell, model_: *const model.SharedTopBarModel, bar: LayoutRect, menu: model.MenuKind, mouse: shared_types.input.MousePos) ?model.Action {
    const items = model_.itemsFor(menu);
    for (items, 0..) |item, idx| {
        if (itemRect(shell, model_, bar, menu, idx).contains(mouse)) return item.action;
    }
    return null;
}

fn labelRect(shell: *Shell, x: f32, y: f32, label: []const u8) Rect {
    const scale = shell.uiScaleFactor();
    const text_w = @as(f32, @floatFromInt(label.len)) * shell.charWidth();
    const pad_x: f32 = 6 * scale;
    const pad_y: f32 = 4 * scale;
    return .{
        .x = x - pad_x,
        .y = y - pad_y,
        .w = text_w + pad_x * 2,
        .h = shell.charHeight() + pad_y * 2,
    };
}
