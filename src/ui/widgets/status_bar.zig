const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const renderer_chrome_band_host = @import("../renderer/renderer_chrome_band_host.zig");
const renderer_surface_host = @import("../renderer/renderer_surface_host.zig");
const common = @import("common.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Band = renderer_chrome_band_host.Band;

/// Status bar at the bottom
pub const StatusBar = struct {
    pub const PassiveMode = enum {
        editor,
        terminal,
    };

    pub const ActiveMode = union(enum) {
        path: PromptUi,
        search: SearchUi,
    };

    pub const EditorModeUi = struct {
        mode: []const u8,
        imported_theme_name: ?[]const u8,
        file_path: ?[]const u8,
        line: usize,
        col: usize,
        modified: bool,
    };

    pub const SearchUi = struct {
        active: bool,
        query: []const u8,
        select_all: bool,
        match_count: usize,
        active_index: ?usize,
    };

    pub const PromptUi = struct {
        active: bool,
        label: []const u8,
        value: []const u8,
        select_all: bool,
        placeholder: []const u8,
        error_text: ?[]const u8,
    };

    height: f32 = 24,
    last_mouse: shared_types.input.MousePos = .{ .x = 0, .y = 0 },
    mouse_down_left: bool = false,

    fn isLight(color: Color) bool {
        const luma = @as(u32, color.r) * 299 + @as(u32, color.g) * 587 + @as(u32, color.b) * 114;
        return luma >= 128000;
    }

    fn searchFieldPalette(theme: *const app_shell.Theme) struct {
        text: Color,
        muted: Color,
        caret: Color,
        underline: Color,
        selection_bg: Color,
        selection_text: Color,
    } {
        _ = isLight;
        return .{
            .text = theme.ui_text,
            .muted = theme.ui_text_inactive,
            .caret = theme.ui_accent,
            .underline = theme.ui_border,
            .selection_bg = theme.ui_accent,
            .selection_text = theme.background,
        };
    }

    fn drawFieldText(
        shell: *Shell,
        text_y: f32,
        field_y: f32,
        field_h: f32,
        query_x: f32,
        query_available: f32,
        text: []const u8,
        text_color: Color,
        bg_color: Color,
        selection_bg: Color,
        selection_text: Color,
        select_all: bool,
    ) struct {
        drawn_width: f32,
    } {
        if (select_all and text.len > 0) {
            renderer_surface_host.drawRect(shell.rendererPtr(),
                @intFromFloat(query_x),
                @intFromFloat(field_y + 2),
                @intFromFloat(@max(@as(f32, 1), query_available)),
                @intFromFloat(@max(@as(f32, 1), field_h - 4)),
                selection_bg,
            );
            const result = common.drawTruncatedTextOnBg(shell, text, query_x, text_y, selection_text, selection_bg, query_available);
            return .{ .drawn_width = result.drawn_width };
        }
        const result = common.drawTruncatedTextOnBg(shell, text, query_x, text_y, text_color, bg_color, query_available);
        return .{ .drawn_width = result.drawn_width };
    }

    pub fn updateInput(self: *StatusBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
        self.mouse_down_left = input.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)];
    }

    pub fn draw(
        self: *StatusBar,
        shell: *Shell,
        width: f32,
        y: f32,
        passive_mode: PassiveMode,
        editor_ui: EditorModeUi,
        active_mode: ?ActiveMode,
    ) void {
        const theme = shell.theme();
        const scale = shell.uiScaleFactor();
        const bar_bg = theme.ui_bar_bg;
        var band = Band.init(shell, bar_bg);
        defer band.flush();
        // Background
        band.fillRect(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), bar_bg);

        // Line/column (reserve space on right)
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ editor_ui.line + 1, editor_ui.col + 1 }) catch |err| {
            const log = app_logger.logger("ui.status-bar");
            log.logf(.warning, "status bar cursor position format failed err={s}", .{@errorName(err)});
            return;
        };
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * shell.charWidth();
        var theme_buf: [96]u8 = undefined;
        const theme_label = if (editor_ui.imported_theme_name) |name|
            std.fmt.bufPrint(&theme_buf, "Theme {s}", .{name}) catch null
        else
            null;
        const theme_width = if (theme_label) |label| @as(f32, @floatFromInt(label.len)) * shell.charWidth() else 0;
        const theme_gap = if (theme_label != null) 20 * scale else 0;
        const pos_start = width - pos_width - 16 * scale;
        const theme_start = pos_start - theme_gap - theme_width;

        // Mode indicator
        const mode_text = switch (passive_mode) {
            .editor => editor_ui.mode,
            .terminal => "TERMINAL",
        };
        const mode_bg = if (std.mem.eql(u8, mode_text, "INSERT"))
            theme.string
        else if (std.mem.eql(u8, mode_text, "VISUAL"))
            theme.keyword
        else
            theme.function;

        const mode_width: f32 = 80 * scale;
        const text_y: f32 = y + (self.height - shell.charHeight()) / 2;
        const text_x: f32 = 8 * scale;
        const mouse = self.last_mouse;
        const pressed = self.mouse_down_left;
        const window_focused = shell.windowFocused();
        const mode_hover = window_focused and mouse.x >= 0 and mouse.x <= mode_width and mouse.y >= y and mouse.y <= y + self.height;
        const mode_bg_final = if (mode_hover and pressed) theme.ui_pressed else if (mode_hover) theme.ui_hover else mode_bg;
        band.fillRect(0, @intFromFloat(y), @intFromFloat(mode_width), @intFromFloat(self.height), mode_bg_final);
        shell.drawTextOnBg(mode_text, text_x, text_y, if (mode_hover) theme.ui_text else theme.background, mode_bg_final);

        // Active mode field sits between mode and file path when active.
        var x: f32 = 88 * scale;
        if (active_mode) |active| switch (active) {
            .path => |prompt_ui| {
                const palette = searchFieldPalette(theme);
                const label = prompt_ui.label;
                const box_x = x;
                const label_w = @as(f32, @floatFromInt(label.len)) * shell.charWidth();
                const box_w = @min(@max(@as(f32, 280 * scale), width * 0.34), @max(@as(f32, 0), pos_start - x - 24 * scale));
                if (box_w > 64 * scale) {
                    const label_x = box_x;
                    band.drawTextOnBg(label, label_x, text_y, palette.muted);
                    band.drawTextOnBg(":", label_x + label_w, text_y, palette.muted);

                    const query_x = label_x + label_w + 2 * shell.charWidth();
                    const query_available = @max(@as(f32, 0), box_w - (query_x - box_x) - 12 * scale);
                    const query_text = if (prompt_ui.value.len > 0) prompt_ui.value else prompt_ui.placeholder;
                    const query_color = if (prompt_ui.value.len > 0) palette.text else palette.muted;
                    const result = drawFieldText(
                        shell,
                        text_y,
                        y,
                        self.height,
                        query_x,
                        query_available,
                        query_text,
                        query_color,
                        bar_bg,
                        palette.selection_bg,
                        palette.selection_text,
                        prompt_ui.select_all and prompt_ui.value.len > 0,
                    );
                    const underline_y = y + self.height - 4 * scale;
                    band.fillRect(
                        @intFromFloat(query_x),
                        @intFromFloat(underline_y),
                        @intFromFloat(@max(@as(f32, 1), query_available)),
                        @intFromFloat(@max(@as(f32, 1), scale)),
                        palette.underline,
                    );
                    if (prompt_ui.active) {
                        shell.setTextInputRect(
                            @intFromFloat(query_x),
                            @intFromFloat(y),
                            @intFromFloat(@max(@as(f32, 1), query_available)),
                            @intFromFloat(self.height),
                        );
                        const caret_x = @min(query_x + result.drawn_width + shell.charWidth() * 0.1, query_x + query_available - 2 * scale);
                        renderer_surface_host.drawRect(shell.rendererPtr(),
                            @intFromFloat(caret_x),
                            @intFromFloat(y + 3 * scale),
                            @intFromFloat(@max(@as(f32, 1), 2 * scale)),
                            @intFromFloat(@max(@as(f32, 1), self.height - 6 * scale)),
                            palette.caret,
                        );
                    }
                    x = box_x + box_w + 16 * scale;
                    if (prompt_ui.error_text) |error_text| {
                        const error_x = box_x + box_w + 8 * scale;
                        const available = @max(@as(f32, 0), pos_start - error_x - 8 * scale);
                        if (available > shell.charWidth() * 6) {
                            _ = common.drawTruncatedTextOnBg(shell, error_text, error_x, text_y, theme.ui_modified, bar_bg, available);
                        }
                    }
                }
            },
            .search => |search_ui| {
                const palette = searchFieldPalette(theme);
                const label = "Find";
                const box_x = x;
                const label_w = @as(f32, @floatFromInt(label.len)) * shell.charWidth();

                var meta_buf: [32]u8 = undefined;
                const meta = if (search_ui.match_count == 0)
                    std.fmt.bufPrint(&meta_buf, "0 hits", .{}) catch ""
                else if (search_ui.active_index) |idx|
                    std.fmt.bufPrint(&meta_buf, "{d}/{d}", .{ idx + 1, search_ui.match_count }) catch ""
                else
                    std.fmt.bufPrint(&meta_buf, "{d} hits", .{search_ui.match_count}) catch "";
                const meta_w = @as(f32, @floatFromInt(meta.len)) * shell.charWidth();
                const box_w = @min(@max(@as(f32, 220 * scale), width * 0.28), @max(@as(f32, 0), pos_start - x - 24 * scale));
                if (box_w > 64 * scale) {
                    const label_x = box_x;
                    band.drawTextOnBg(label, label_x, text_y, palette.muted);
                    band.drawTextOnBg(":", label_x + label_w, text_y, palette.muted);

                    const query_x = label_x + label_w + 2 * shell.charWidth();
                    const query_available = @max(@as(f32, 0), box_w - (query_x - box_x) - meta_w - 12 * scale);
                    const query_text = if (search_ui.query.len > 0) search_ui.query else "type to search";
                    const query_color = if (search_ui.query.len > 0) palette.text else palette.muted;
                    const result = drawFieldText(
                        shell,
                        text_y,
                        y,
                        self.height,
                        query_x,
                        query_available,
                        query_text,
                        query_color,
                        bar_bg,
                        palette.selection_bg,
                        palette.selection_text,
                        search_ui.select_all and search_ui.query.len > 0,
                    );
                    const underline_y = y + self.height - 4 * scale;
                    band.fillRect(
                        @intFromFloat(query_x),
                        @intFromFloat(underline_y),
                        @intFromFloat(@max(@as(f32, 1), query_available)),
                        @intFromFloat(@max(@as(f32, 1), scale)),
                        palette.underline,
                    );
                    if (search_ui.active) {
                        shell.setTextInputRect(
                            @intFromFloat(query_x),
                            @intFromFloat(y),
                            @intFromFloat(@max(@as(f32, 1), query_available)),
                            @intFromFloat(self.height),
                        );
                        const caret_x = @min(query_x + result.drawn_width + shell.charWidth() * 0.1, query_x + query_available - 2 * scale);
                        renderer_surface_host.drawRect(shell.rendererPtr(),
                            @intFromFloat(caret_x),
                            @intFromFloat(y + 3 * scale),
                            @intFromFloat(@max(@as(f32, 1), 2 * scale)),
                            @intFromFloat(@max(@as(f32, 1), self.height - 6 * scale)),
                            palette.caret,
                        );
                    }
                    band.drawTextOnBg(meta, box_x + box_w - meta_w, text_y, palette.muted);
                    x = box_x + box_w + 16 * scale;
                }
            },
        };

        // File path
        if (editor_ui.file_path) |path| {
            const available = (if (theme_label != null) theme_start else pos_start) - 16 * scale - x;
            const result = common.drawTruncatedTextOnBg(shell, path, x, text_y, theme.ui_text, bar_bg, available);
            const in_path = window_focused and mouse.x >= x and mouse.x <= x + result.drawn_width and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_path) {
                common.drawTooltip(shell, path, mouse.x, mouse.y);
            }
            x += result.drawn_width + 16 * scale;
        }

        // Modified indicator
        if (editor_ui.modified) {
            const indicator = "[+]";
            const indicator_width = @as(f32, @floatFromInt(indicator.len)) * shell.charWidth();
            if (x + indicator_width <= (if (theme_label != null) theme_start else pos_start) - 8 * scale) {
                band.drawTextOnBg(indicator, x, text_y, theme.ui_modified);
            }
        }

        if (theme_label) |label| {
            const theme_hover = window_focused and mouse.x >= theme_start and mouse.x <= theme_start + theme_width and mouse.y >= y and mouse.y <= y + self.height;
            if (theme_hover) {
                const bg = if (pressed) theme.ui_pressed else theme.ui_hover;
                band.fillRect(@intFromFloat(theme_start - 4 * scale), @intFromFloat(y + 2 * scale), @intFromFloat(theme_width + 8 * scale), @intFromFloat(self.height - 4 * scale), bg);
            }
            band.drawTextOnBg(label, theme_start, text_y, if (theme_hover) theme.ui_text else theme.ui_text_inactive);
        }

        const pos_hover = window_focused and mouse.x >= pos_start and mouse.x <= pos_start + pos_width and mouse.y >= y and mouse.y <= y + self.height;
        if (pos_hover) {
            const bg = if (pressed) theme.ui_pressed else theme.ui_hover;
            band.fillRect(@intFromFloat(pos_start - 4 * scale), @intFromFloat(y + 2 * scale), @intFromFloat(pos_width + 8 * scale), @intFromFloat(self.height - 4 * scale), bg);
        }
        band.drawTextOnBg(pos_str, pos_start, text_y, if (pos_hover) theme.ui_text else theme.ui_text_inactive);
    }
};
