const std = @import("std");
const app_logger = @import("../app_logger.zig");

pub fn NavigationOps(comptime Editor: type) type {
    return struct {
        pub fn moveCursorLeft(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetHorizontal(-1) catch |err| {
                    log.logf(.warning, "move caret set left failed: {s}", .{@errorName(err)});
                };
                return;
            }
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var collapsed = std.ArrayList(usize).empty;
                defer collapsed.deinit(self.allocator);
                if (self.selection) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
                } else {
                    self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
                }
                for (self.selections.items) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
                }
                self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                    log.logf(.warning, "restore collapsed carets (left) failed: {s}", .{@errorName(err)});
                };
                self.selection = null;
                return;
            }
            if (self.cursor.offset == 0) return;
            self.cursor.offset -= 1;
            self.updateCursorPosition();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorRight(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetHorizontal(1) catch |err| {
                    log.logf(.warning, "move caret set right failed: {s}", .{@errorName(err)});
                };
                return;
            }
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var collapsed = std.ArrayList(usize).empty;
                defer collapsed.deinit(self.allocator);
                if (self.selection) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
                } else {
                    self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
                }
                for (self.selections.items) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
                }
                self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                    log.logf(.warning, "restore collapsed carets (right) failed: {s}", .{@errorName(err)});
                };
                self.selection = null;
                return;
            }
            const total = self.buffer.totalLen();
            if (self.cursor.offset >= total) return;
            self.cursor.offset += 1;
            self.updateCursorPosition();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorUp(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) return;
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var collapsed = std.ArrayList(usize).empty;
                defer collapsed.deinit(self.allocator);
                if (self.selection) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
                } else {
                    self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
                }
                for (self.selections.items) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
                }
                self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                    log.logf(.warning, "restore collapsed carets (up) failed: {s}", .{@errorName(err)});
                };
                self.selection = null;
                return;
            }
            if (self.cursor.line == 0) return;
            const target_col = self.cursor.col;
            self.cursor.line -= 1;
            const line_len = self.buffer.lineLen(self.cursor.line);
            self.cursor.col = @min(target_col, line_len);
            self.updateCursorOffset();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorDown(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) return;
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var collapsed = std.ArrayList(usize).empty;
                defer collapsed.deinit(self.allocator);
                if (self.selection) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
                } else {
                    self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
                }
                for (self.selections.items) |sel| {
                    self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
                }
                self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                    log.logf(.warning, "restore collapsed carets (down) failed: {s}", .{@errorName(err)});
                };
                self.selection = null;
                return;
            }
            const line_count = self.buffer.lineCount();
            if (self.cursor.line + 1 >= line_count) return;
            const target_col = self.cursor.col;
            self.cursor.line += 1;
            const line_len = self.buffer.lineLen(self.cursor.line);
            self.cursor.col = @min(target_col, line_len);
            self.updateCursorOffset();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorToLineStart(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetToLineBoundary(true) catch |err| {
                    log.logf(.warning, "move caret set to line start failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.cursor.col = 0;
            self.updateCursorOffset();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorToLineEnd(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetToLineBoundary(false) catch |err| {
                    log.logf(.warning, "move caret set to line end failed: {s}", .{@errorName(err)});
                };
                return;
            }
            const line_len = self.buffer.lineLen(self.cursor.line);
            self.cursor.col = line_len;
            self.updateCursorOffset();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorWordLeft(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetByWord(true) catch |err| {
                    log.logf(.warning, "move caret set word-left failed: {s}", .{@errorName(err)});
                };
                return;
            }
            const target = self.wordLeftOffset(self.cursor.offset);
            self.setCursorOffsetNoClear(target);
            self.selection = null;
            self.clearSelections();
        }

        pub fn moveCursorWordRight(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasOnlyCaretSelections()) {
                self.moveCaretSetByWord(false) catch |err| {
                    log.logf(.warning, "move caret set word-right failed: {s}", .{@errorName(err)});
                };
                return;
            }
            const target = self.wordRightOffset(self.cursor.offset);
            self.setCursorOffsetNoClear(target);
            self.selection = null;
            self.clearSelections();
        }

        pub fn extendSelectionLeft(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (left) failed: {s}", .{@errorName(err)});
                    return;
                };
                for (target_heads.items) |*offset| {
                    if (offset.* > 0) offset.* -= 1;
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (left) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.extendPrimarySelectionToOffset(if (self.cursor.offset > 0) self.cursor.offset - 1 else 0);
        }

        pub fn extendSelectionRight(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (right) failed: {s}", .{@errorName(err)});
                    return;
                };
                const total = self.buffer.totalLen();
                for (target_heads.items) |*offset| {
                    if (offset.* < total) offset.* += 1;
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (right) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            const total = self.buffer.totalLen();
            self.extendPrimarySelectionToOffset(if (self.cursor.offset < total) self.cursor.offset + 1 else total);
        }

        pub fn extendSelectionToLineStart(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (line-start) failed: {s}", .{@errorName(err)});
                    return;
                };
                for (target_heads.items) |*offset| {
                    const caret = self.cursorPosForOffset(offset.*);
                    offset.* = self.buffer.lineStart(caret.line);
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (line-start) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.extendPrimarySelectionToOffset(self.buffer.lineStart(self.cursor.line));
        }

        pub fn extendSelectionToLineEnd(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (line-end) failed: {s}", .{@errorName(err)});
                    return;
                };
                for (target_heads.items) |*offset| {
                    const caret = self.cursorPosForOffset(offset.*);
                    offset.* = self.buffer.lineStart(caret.line) + self.buffer.lineLen(caret.line);
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (line-end) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.extendPrimarySelectionToOffset(self.buffer.lineStart(self.cursor.line) + self.buffer.lineLen(self.cursor.line));
        }

        pub fn extendSelectionWordLeft(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (word-left) failed: {s}", .{@errorName(err)});
                    return;
                };
                for (target_heads.items) |*offset| {
                    offset.* = self.wordLeftOffset(offset.*);
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (word-left) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.extendPrimarySelectionToOffset(self.wordLeftOffset(self.cursor.offset));
        }

        pub fn extendSelectionWordRight(self: *Editor) void {
            const log = app_logger.logger("editor.input");
            if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
                var anchors = std.ArrayList(usize).empty;
                defer anchors.deinit(self.allocator);
                var target_heads = std.ArrayList(usize).empty;
                defer target_heads.deinit(self.allocator);
                self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                    log.logf(.warning, "collect selection anchors/heads (word-right) failed: {s}", .{@errorName(err)});
                    return;
                };
                for (target_heads.items) |*offset| {
                    offset.* = self.wordRightOffset(offset.*);
                }
                self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                    log.logf(.warning, "restore extended carets (word-right) failed: {s}", .{@errorName(err)});
                };
                return;
            }
            self.extendPrimarySelectionToOffset(self.wordRightOffset(self.cursor.offset));
        }

        pub fn setCursor(self: *Editor, line: usize, col: usize) void {
            self.cursor.line = line;
            self.cursor.col = col;
            self.updateCursorOffset();
            self.preferred_visual_col = null;
            self.selection = null;
            self.clearSelections();
        }

        pub fn setCursorPreservePreferred(self: *Editor, line: usize, col: usize) void {
            self.cursor.line = line;
            self.cursor.col = col;
            self.updateCursorOffset();
            self.selection = null;
            self.clearSelections();
        }

        pub fn setCursorNoClear(self: *Editor, line: usize, col: usize) void {
            self.cursor.line = line;
            self.cursor.col = col;
            self.updateCursorOffset();
            self.preferred_visual_col = null;
        }

        pub fn setCursorOffsetNoClear(self: *Editor, offset: usize) void {
            self.cursor.offset = offset;
            self.updateCursorPosition();
            self.preferred_visual_col = null;
        }

        pub fn updateCursorPosition(self: *Editor) void {
            self.cursor.line = self.buffer.lineIndexForOffset(self.cursor.offset);
            const line_start = self.buffer.lineStart(self.cursor.line);
            self.cursor.col = self.cursor.offset - line_start;
        }

        pub fn updateCursorOffset(self: *Editor) void {
            const line_start = self.buffer.lineStart(self.cursor.line);
            self.cursor.offset = line_start + self.cursor.col;
        }
    };
}
