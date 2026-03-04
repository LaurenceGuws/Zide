const app_bootstrap = @import("../../bootstrap.zig");
const shared_types = @import("../../../types/mod.zig");

const layout_types = shared_types.layout;

pub const TerminalStrip = struct {
    offset_y: f32,
    draw_height: f32,
};

pub fn computeLayoutForMode(
    app_mode: app_bootstrap.AppMode,
    width: f32,
    height: f32,
    options_bar_height: f32,
    tab_bar_height: f32,
    side_nav_width: f32,
    status_bar_height: f32,
    terminal_height: f32,
    show_terminal: bool,
    terminal_tab_bar_visible: bool,
) layout_types.WidgetLayout {
    switch (app_mode) {
        .terminal => {
            const mode_tab_bar_h = if (terminal_tab_bar_visible) tab_bar_height else 0;
            const mode_terminal_h = if (show_terminal) @max(0, height - mode_tab_bar_h) else 0;
            return .{
                .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .tab_bar = .{ .x = 0, .y = 0, .width = width, .height = mode_tab_bar_h },
                .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .editor = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .terminal = .{ .x = 0, .y = mode_tab_bar_h, .width = width, .height = mode_terminal_h },
                .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
        },
        .editor => {
            return .{
                .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .editor = .{ .x = 0, .y = 0, .width = width, .height = height },
                .terminal = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
        },
        .font_sample => {
            return .{
                .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .editor = .{ .x = 0, .y = 0, .width = width, .height = height },
                .terminal = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
        },
        .ide => {},
    }

    const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
    const effective_terminal_h = if (show_terminal) @min(terminal_height, max_terminal_h) else 0;
    const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - effective_terminal_h);
    const editor_width = @max(0, width - side_nav_width);

    return .{
        .window = .{ .x = 0, .y = 0, .width = width, .height = height },
        .options_bar = .{ .x = 0, .y = 0, .width = width, .height = options_bar_height },
        .tab_bar = .{ .x = side_nav_width, .y = options_bar_height, .width = editor_width, .height = tab_bar_height },
        .side_nav = .{ .x = 0, .y = options_bar_height, .width = side_nav_width, .height = height - status_bar_height - options_bar_height },
        .editor = .{ .x = side_nav_width, .y = options_bar_height + tab_bar_height, .width = editor_width, .height = editor_height },
        .terminal = .{ .x = side_nav_width, .y = height - status_bar_height - effective_terminal_h, .width = editor_width, .height = effective_terminal_h },
        .status_bar = .{ .x = 0, .y = height - status_bar_height, .width = width, .height = status_bar_height },
    };
}

pub fn terminalEffectiveHeightForSizing(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    layout_terminal_height: f32,
    terminal_height: f32,
) f32 {
    if (app_mode == .ide and !show_terminal) return terminal_height;
    return layout_terminal_height;
}

pub fn terminalStrip(app_mode: app_bootstrap.AppMode, layout_terminal_height: f32) TerminalStrip {
    if (app_mode == .ide) {
        return .{
            .offset_y = 2,
            .draw_height = @max(0, layout_terminal_height - 2),
        };
    }
    return .{
        .offset_y = 0,
        .draw_height = layout_terminal_height,
    };
}

pub fn configReloadNoticeY(
    app_mode: app_bootstrap.AppMode,
    terminal_tab_bar_visible: bool,
    layout: layout_types.WidgetLayout,
    margin: f32,
) f32 {
    if (app_mode == .terminal and terminal_tab_bar_visible) {
        return layout.tab_bar.y + layout.tab_bar.height + margin;
    }
    if (app_mode == .ide) {
        return layout.options_bar.y + layout.options_bar.height + margin;
    }
    return margin;
}
