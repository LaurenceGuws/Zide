const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

/// Status bar at the bottom
pub const StatusBar = struct {
    pub const SearchUi = struct {
        active: bool,
        query: []const u8,
        match_count: usize,
        active_index: ?usize,
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
    } {
        _ = isLight;
        return .{
            .text = theme.ui_text,
            .muted = theme.ui_text_inactive,
            .caret = theme.ui_accent,
            .underline = theme.ui_border,
        };
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
        mode: []const u8,
        file_path: ?[]const u8,
        line: usize,
        col: usize,
        modified: bool,
        search: ?SearchUi,
    ) void {
        const theme = shell.theme();
        const scale = shell.uiScaleFactor();
        const bar_bg = theme.ui_bar_bg;
        // Background
        shell.drawRect(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), bar_bg);

        // Line/column (reserve space on right)
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ line + 1, col + 1 }) catch |err| {
            const log = app_logger.logger("ui.status-bar");
                            log.logf(.warning, "status bar cursor position format failed err={s}", .{ @errorName(err) });
            return;
        };
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * shell.charWidth();
        const pos_start = width - pos_width - 16 * scale;

        // Mode indicator
        const mode_bg = if (std.mem.eql(u8, mode, "INSERT"))
            theme.string
        else if (std.mem.eql(u8, mode, "VISUAL"))
            theme.keyword
        else
            theme.function;

        const mode_width: f32 = 80 * scale;
        const text_y: f32 = y + (self.height - shell.charHeight()) / 2;
        const text_x: f32 = 8 * scale;
        const mouse = self.last_mouse;
        const pressed = self.mouse_down_left;
        const mode_hover = mouse.x >= 0 and mouse.x <= mode_width and mouse.y >= y and mouse.y <= y + self.height;
        const mode_bg_final = if (mode_hover and pressed) theme.ui_pressed else if (mode_hover) theme.ui_hover else mode_bg;
        shell.drawRect(0, @intFromFloat(y), @intFromFloat(mode_width), @intFromFloat(self.height), mode_bg_final);
        shell.drawTextOnBg(mode, text_x, text_y, if (mode_hover) theme.ui_text else theme.background, mode_bg_final);

        // Search panel sits between mode and file path when active.
        var x: f32 = 88 * scale;
        if (search) |search_ui| {
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
                shell.drawTextOnBg(label, label_x, text_y, palette.muted, bar_bg);
                shell.drawTextOnBg(":", label_x + label_w, text_y, palette.muted, bar_bg);

                const query_x = label_x + label_w + 2 * shell.charWidth();
                const query_available = @max(@as(f32, 0), box_w - (query_x - box_x) - meta_w - 12 * scale);
                const query_text = if (search_ui.query.len > 0) search_ui.query else "type to search";
                const query_color = if (search_ui.query.len > 0) palette.text else palette.muted;
                const result = common.drawTruncatedTextOnBg(shell, query_text, query_x, text_y, query_color, bar_bg, query_available);
                const underline_y = y + self.height - 4 * scale;
                shell.drawRect(
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
                    shell.drawRect(
                        @intFromFloat(caret_x),
                        @intFromFloat(y + 3 * scale),
                        @intFromFloat(@max(@as(f32, 1), 2 * scale)),
                        @intFromFloat(@max(@as(f32, 1), self.height - 6 * scale)),
                        palette.caret,
                    );
                }
                shell.drawTextOnBg(meta, box_x + box_w - meta_w, text_y, palette.muted, bar_bg);
                x = box_x + box_w + 16 * scale;
            }
        }

        // File path
        if (file_path) |path| {
            const available = pos_start - 16 * scale - x;
            const result = common.drawTruncatedTextOnBg(shell, path, x, text_y, theme.ui_text, bar_bg, available);
            const in_path = mouse.x >= x and mouse.x <= x + result.drawn_width and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_path) {
                common.drawTooltip(shell, path, mouse.x, mouse.y);
            }
            x += result.drawn_width + 16 * scale;
        }

        // Modified indicator
        if (modified) {
            const indicator = "[+]";
            const indicator_width = @as(f32, @floatFromInt(indicator.len)) * shell.charWidth();
            if (x + indicator_width <= pos_start - 8 * scale) {
                shell.drawTextOnBg(indicator, x, text_y, theme.ui_modified, bar_bg);
            }
        }

        const pos_hover = mouse.x >= pos_start and mouse.x <= pos_start + pos_width and mouse.y >= y and mouse.y <= y + self.height;
        if (pos_hover) {
            const bg = if (pressed) theme.ui_pressed else theme.ui_hover;
            shell.drawRect(@intFromFloat(pos_start - 4 * scale), @intFromFloat(y + 2 * scale), @intFromFloat(pos_width + 8 * scale), @intFromFloat(self.height - 4 * scale), bg);
        }
        shell.drawTextOnBg(pos_str, pos_start, text_y, if (pos_hover) theme.ui_text else theme.ui_text_inactive, bar_bg);
    }
};
