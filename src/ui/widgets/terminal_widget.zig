const std = @import("std");
const builtin = @import("builtin");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");
const draw_mod = @import("terminal_widget_draw.zig");
const input_mod = @import("terminal_widget_input.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const KittyImage = terminal_mod.KittyImage;
const KittyPlacement = terminal_mod.KittyPlacement;

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    pub const BlinkStyle = enum {
        kitty,
        off,
    };

    pub const PendingOpen = open_mod.PendingOpen;

    session: *TerminalSession,
    blink_style: BlinkStyle = .kitty,
    last_scroll_offset: usize = 0,
    kitty: kitty_mod.KittyState,
    hover: hover_mod.HoverState = .{},
    pending_open: ?PendingOpen = null,
    last_draw_log_time: f64 = 0,
    blink_last_slow_on: bool = true,
    blink_last_fast_on: bool = true,
    blink_last_active: bool = false,
    cursor_blink_pause_until: f64 = 0,
    terminal_texture_ready: bool = false,
    last_render_generation: u64 = 0,
    last_cell_w_i: i32 = 0,
    last_cell_h_i: i32 = 0,
    last_render_scale: f32 = 0,

    pub fn init(session: *TerminalSession, blink_style: BlinkStyle) TerminalWidget {
        return .{
            .session = session,
            .blink_style = blink_style,
            .last_scroll_offset = 0,
            .kitty = kitty_mod.KittyState.init(session.allocator),
            .hover = .{},
            .pending_open = null,
            .last_draw_log_time = 0,
            .blink_last_slow_on = true,
            .blink_last_fast_on = true,
            .blink_last_active = false,
            .terminal_texture_ready = false,
            .last_render_generation = 0,
            .last_cell_w_i = 0,
            .last_cell_h_i = 0,
            .last_render_scale = 0,
        };
    }

    pub fn updateBlink(self: *TerminalWidget, now: f64) bool {
        if (self.blink_style == .off) {
            self.blink_last_active = false;
            return false;
        }
        const cache = self.session.renderCache();
        var has_slow = false;
        var has_fast = false;
        for (cache.cells.items) |cell| {
            if (!cell.attrs.blink) continue;
            if (cell.attrs.blink_fast) {
                has_fast = true;
            } else {
                has_slow = true;
            }
            if (has_slow and has_fast) break;
        }
        if (!has_slow and !has_fast) {
            self.blink_last_active = false;
            return false;
        }
        const slow_on = @mod(now, 2.0) < 1.0;
        const fast_on = @mod(now, 1.0) < 0.5;
        var changed = false;
        if (has_slow) {
            if (!self.blink_last_active or slow_on != self.blink_last_slow_on) {
                changed = true;
            }
            self.blink_last_slow_on = slow_on;
        }
        if (has_fast) {
            if (!self.blink_last_active or fast_on != self.blink_last_fast_on) {
                changed = true;
            }
            self.blink_last_fast_on = fast_on;
        }
        self.blink_last_active = true;
        return changed;
    }

    pub fn noteInput(self: *TerminalWidget, now: f64) void {
        self.cursor_blink_pause_until = now + 0.4;
    }

    pub fn deinit(self: *TerminalWidget) void {
        if (self.pending_open) |req| {
            self.session.allocator.free(req.path);
            self.pending_open = null;
        }
        self.kitty.deinit(self.session.allocator);
    }

    pub fn takePendingOpenRequest(self: *TerminalWidget) ?PendingOpen {
        const value = self.pending_open;
        self.pending_open = null;
        return value;
    }

    pub fn copySelectionToClipboard(self: *TerminalWidget, shell: *Shell) bool {
        const selection = self.session.selectionState() orelse return false;
        const sel_snapshot = self.session.snapshot();
        const rows_snapshot = sel_snapshot.rows;
        const cols_snapshot = sel_snapshot.cols;
        const history = self.session.scrollbackCount();
        const total_lines_copy = history + rows_snapshot;
        if (rows_snapshot == 0 or cols_snapshot == 0 or total_lines_copy == 0) return false;

        var start_sel = selection.start;
        var end_sel = selection.end;
        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
            const tmp = start_sel;
            start_sel = end_sel;
            end_sel = tmp;
        }
        start_sel.row = @min(start_sel.row, total_lines_copy - 1);
        end_sel.row = @min(end_sel.row, total_lines_copy - 1);
        start_sel.col = @min(start_sel.col, cols_snapshot - 1);
        end_sel.col = @min(end_sel.col, cols_snapshot - 1);

        var text = std.ArrayList(u8).empty;
        defer text.deinit(self.session.allocator);

        var row_idx: usize = start_sel.row;
        while (row_idx <= end_sel.row and row_idx < total_lines_copy) : (row_idx += 1) {
            const row_cells = blk: {
                if (row_idx < history) {
                    if (self.session.scrollbackRow(row_idx)) |history_row| break :blk history_row;
                }
                const grid_row = row_idx - history;
                const row_start = grid_row * cols_snapshot;
                break :blk sel_snapshot.cells[row_start .. row_start + cols_snapshot];
            };

            const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
            const col_end = if (row_idx == end_sel.row) end_sel.col else cols_snapshot - 1;
            var col_idx: usize = col_start;
            while (col_idx <= col_end and col_idx < cols_snapshot) : (col_idx += 1) {
                const cell = row_cells[col_idx];
                if (cell.x != 0 or cell.y != 0) {
                    continue;
                }
                if (cell.codepoint == 0) {
                    text.append(self.session.allocator, ' ') catch return false;
                    continue;
                }
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                if (len > 0) {
                    text.appendSlice(self.session.allocator, buf[0..len]) catch return false;
                }
            }

            while (text.items.len > 0 and text.items[text.items.len - 1] == ' ') {
                _ = text.pop();
            }

            if (row_idx != end_sel.row) {
                text.append(self.session.allocator, '\n') catch return false;
            }
        }

        text.append(self.session.allocator, 0) catch return false;
        const cstr: [*:0]const u8 = @ptrCast(text.items.ptr);
        shell.setClipboardText(cstr);
        return true;
    }

    pub fn pasteClipboardFromSystem(self: *TerminalWidget, shell: *Shell) bool {
        const clip = shell.getClipboardText() orelse return false;
        if (self.session.scrollOffset() > 0) {
            self.session.setScrollOffset(0);
        }
        if (self.session.bracketedPasteEnabled()) {
            self.session.sendText("\x1b[200~") catch return false;
            var filtered = std.ArrayList(u8).empty;
            defer filtered.deinit(self.session.allocator);
            for (clip) |b| {
                if (b == 0x1b or b == 0x03) continue;
                filtered.append(self.session.allocator, b) catch return false;
            }
            if (filtered.items.len > 0) {
                self.session.sendText(filtered.items) catch return false;
            }
            self.session.sendText("\x1b[201~") catch return false;
        } else {
            self.session.sendText(clip) catch return false;
        }
        return true;
    }

    pub fn draw(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        input: shared_types.input.InputSnapshot,
    ) void {
        draw_mod.draw(self, shell, x, y, width, height, input);
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        allow_input: bool,
        scroll_dragging: *bool,
        scroll_grab_offset: *f32,
        suppress_shortcuts: bool,
        input_batch: *shared_types.input.InputBatch,
    ) !bool {
        return input_mod.handleInput(
            self,
            shell,
            x,
            y,
            width,
            height,
            allow_input,
            scroll_dragging,
            scroll_grab_offset,
            suppress_shortcuts,
            input_batch,
        );
    }
};
