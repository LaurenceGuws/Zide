const std = @import("std");
const app_logger = @import("../app_logger.zig");
const SelectionReplacementOp = @import("selection_state.zig").SelectionReplacementOp;

pub fn EditOps(comptime Editor: type) type {
    return struct {
        pub fn pointForByte(self: *Editor, byte_offset: usize) @TypeOf(self.pointForByte(byte_offset)) {
            const line = self.buffer.lineIndexForOffset(byte_offset);
            const line_start = self.buffer.lineStart(line);
            return .{
                .row = @as(u32, @intCast(line)),
                .column = @as(u32, @intCast(byte_offset - line_start)),
            };
        }

        pub fn replaceByteRangeInternal(
            self: *Editor,
            start: usize,
            end: usize,
            replacement: []const u8,
            refresh_search: bool,
        ) !void {
            const len = end - start;
            if (len > 0) {
                const start_point = self.pointForByte(start);
                const end_point = self.pointForByte(end);
                try self.buffer.deleteRange(start, len);
                self.applyHighlightEdit(start, end, start, start_point, end_point);
            }
            if (replacement.len > 0) {
                const insert_point = self.pointForByte(start);
                try self.buffer.insertBytes(start, replacement);
                self.applyHighlightEdit(start, start, start + replacement.len, insert_point, insert_point);
            }
            self.setCursorOffsetNoClear(start + replacement.len);
            self.selection = null;
            self.clearSelections();
            if (refresh_search) {
                self.noteTextChanged();
            } else {
                self.noteTextChangedNoSearchRefresh();
            }
        }

        pub fn insertChar(self: *Editor, char: u8) !void {
            self.preferred_visual_col = null;
            if (self.selections.items.len > 0) {
                if (self.hasOnlyCaretSelections()) {
                    _ = try self.beginTrackedUndoGroup();
                    errdefer self.endTrackedUndoGroup() catch |err| {
                        const log = app_logger.logger("editor.core");
                        log.logf(.warning, "tracked undo cleanup failed (insert char caret set): {s}", .{@errorName(err)});
                    };
                    var caret_offsets = try self.collectCaretOffsetsDescending();
                    defer caret_offsets.deinit(self.allocator);
                    var new_offsets = std.ArrayList(usize).empty;
                    defer new_offsets.deinit(self.allocator);
                    var primary_offset = self.cursor.offset;
                    const bytes = [_]u8{char};
                    for (caret_offsets.items) |offset| {
                        const insert_point = self.pointForByte(offset);
                        try self.buffer.insertBytes(offset, &bytes);
                        self.applyHighlightEdit(offset, offset, offset + 1, insert_point, insert_point);
                        self.adjustPrimaryOffsetForReplacement(&primary_offset, offset, offset, 1);
                        self.shiftCaretOffsets(&new_offsets, 1);
                        try new_offsets.append(self.allocator, offset + 1);
                    }
                    self.noteTextChanged();
                    try self.restoreCaretSelections(new_offsets.items, primary_offset);
                    try self.endTrackedUndoGroup();
                    return;
                }
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert char selection set): {s}", .{@errorName(err)});
                };
                const selections = try self.duplicateNormalizedSelectionsDescending();
                defer self.allocator.free(selections);
                const bytes = [_]u8{char};
                var ops = std.ArrayList(SelectionReplacementOp).empty;
                defer ops.deinit(self.allocator);
                for (selections) |sel| {
                    const norm = sel.normalized();
                    try ops.append(self.allocator, .{
                        .start = norm.start.offset,
                        .end = norm.end.offset,
                        .replacement = &bytes,
                    });
                }
                try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selection != null) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert char primary selection): {s}", .{@errorName(err)});
                };
                try self.deleteSelection();
                const bytes = [_]u8{char};
                const insert_start = self.cursor.offset;
                const insert_point = self.pointForByte(insert_start);
                try self.buffer.insertBytes(insert_start, &bytes);
                self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
                self.cursor.offset += 1;
                self.updateCursorPosition();
                self.noteTextChanged();
                try self.endTrackedUndoGroup();
                return;
            }
            const before_id = try self.captureUndoSelectionState();
            const bytes = [_]u8{char};
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, &bytes);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
            self.cursor.offset += 1;
            self.updateCursorPosition();
            self.noteTextChanged();
            const after_id = try self.captureUndoSelectionState();
            self.annotateLastUndoSelectionState(before_id, after_id);
        }

        pub fn insertText(self: *Editor, text: []const u8) !void {
            self.preferred_visual_col = null;
            if (self.selections.items.len > 0) {
                if (self.hasOnlyCaretSelections()) {
                    _ = try self.beginTrackedUndoGroup();
                    errdefer self.endTrackedUndoGroup() catch |err| {
                        const log = app_logger.logger("editor.core");
                        log.logf(.warning, "tracked undo cleanup failed (insert text caret set): {s}", .{@errorName(err)});
                    };
                    var caret_offsets = try self.collectCaretOffsetsDescending();
                    defer caret_offsets.deinit(self.allocator);
                    var new_offsets = std.ArrayList(usize).empty;
                    defer new_offsets.deinit(self.allocator);
                    var primary_offset = self.cursor.offset;
                    for (caret_offsets.items) |offset| {
                        const insert_point = self.pointForByte(offset);
                        try self.buffer.insertBytes(offset, text);
                        self.applyHighlightEdit(offset, offset, offset + text.len, insert_point, insert_point);
                        self.adjustPrimaryOffsetForReplacement(&primary_offset, offset, offset, text.len);
                        self.shiftCaretOffsets(&new_offsets, @intCast(text.len));
                        try new_offsets.append(self.allocator, offset + text.len);
                    }
                    self.noteTextChanged();
                    try self.restoreCaretSelections(new_offsets.items, primary_offset);
                    try self.endTrackedUndoGroup();
                    return;
                }
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert text selection set): {s}", .{@errorName(err)});
                };
                const selections = try self.duplicateNormalizedSelectionsDescending();
                defer self.allocator.free(selections);
                const rect_lines = try self.rectangularPasteLines(text);
                defer if (rect_lines) |lines| self.allocator.free(lines);
                var ops = std.ArrayList(SelectionReplacementOp).empty;
                defer ops.deinit(self.allocator);
                for (selections, 0..) |sel, idx| {
                    const norm = sel.normalized();
                    const replacement = if (rect_lines) |lines| lines[selections.len - 1 - idx] else text;
                    try ops.append(self.allocator, .{
                        .start = norm.start.offset,
                        .end = norm.end.offset,
                        .replacement = replacement,
                    });
                }
                try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selection != null) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert text primary selection): {s}", .{@errorName(err)});
                };
                try self.deleteSelection();
                const insert_start = self.cursor.offset;
                const insert_point = self.pointForByte(insert_start);
                try self.buffer.insertBytes(insert_start, text);
                self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
                self.cursor.offset += text.len;
                self.updateCursorPosition();
                self.noteTextChanged();
                try self.endTrackedUndoGroup();
                return;
            }
            const before_id = try self.captureUndoSelectionState();
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, text);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
            self.cursor.offset += text.len;
            self.updateCursorPosition();
            self.noteTextChanged();
            const after_id = try self.captureUndoSelectionState();
            self.annotateLastUndoSelectionState(before_id, after_id);
        }

        pub fn insertNewline(self: *Editor) !void {
            try self.insertChar('\n');
        }

        pub fn deleteCharBackward(self: *Editor) !void {
            self.preferred_visual_col = null;
            if (self.hasOnlyCaretSelections()) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (backspace caret set): {s}", .{@errorName(err)});
                };
                var caret_offsets = try self.collectCaretOffsetsDescending();
                defer caret_offsets.deinit(self.allocator);
                var new_offsets = std.ArrayList(usize).empty;
                defer new_offsets.deinit(self.allocator);
                var primary_offset = self.cursor.offset;
                var changed = false;
                for (caret_offsets.items) |offset| {
                    if (offset == 0) {
                        try new_offsets.append(self.allocator, 0);
                        continue;
                    }
                    const delete_start = offset - 1;
                    const delete_end = offset;
                    const start_point = self.pointForByte(delete_start);
                    const end_point = self.pointForByte(delete_end);
                    try self.buffer.deleteRange(delete_start, 1);
                    self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
                    self.adjustPrimaryOffsetForReplacement(&primary_offset, delete_start, delete_end, 0);
                    self.shiftCaretOffsets(&new_offsets, -1);
                    try new_offsets.append(self.allocator, delete_start);
                    changed = true;
                }
                if (changed) self.noteTextChanged();
                try self.restoreCaretSelections(new_offsets.items, primary_offset);
                self.selection = null;
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selections.items.len > 0) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (backspace selection set): {s}", .{@errorName(err)});
                };
                const selections = try self.duplicateNormalizedSelectionsDescending();
                defer self.allocator.free(selections);
                var ops = std.ArrayList(SelectionReplacementOp).empty;
                defer ops.deinit(self.allocator);
                for (selections) |sel| {
                    const norm = sel.normalized();
                    var delete_start = norm.start.offset;
                    var delete_len: usize = norm.end.offset - norm.start.offset;
                    if (delete_len == 0 and delete_start > 0) {
                        delete_start -= 1;
                        delete_len = 1;
                    }
                    try ops.append(self.allocator, .{
                        .start = delete_start,
                        .end = delete_start + delete_len,
                        .replacement = "",
                    });
                }
                try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selection) |_| {
                try self.deleteSelection();
                return;
            }
            if (self.cursor.offset == 0) return;
            const before_id = try self.captureUndoSelectionState();
            const start = self.cursor.offset - 1;
            const end = self.cursor.offset;
            const start_point = self.pointForByte(start);
            const end_point = self.pointForByte(end);
            try self.buffer.deleteRange(start, 1);
            self.applyHighlightEdit(start, end, start, start_point, end_point);
            self.cursor.offset -= 1;
            self.updateCursorPosition();
            self.noteTextChanged();
            const after_id = try self.captureUndoSelectionState();
            self.annotateLastUndoSelectionState(before_id, after_id);
        }

        pub fn deleteCharForward(self: *Editor) !void {
            self.preferred_visual_col = null;
            if (self.hasOnlyCaretSelections()) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (delete forward caret set): {s}", .{@errorName(err)});
                };
                var caret_offsets = try self.collectCaretOffsetsDescending();
                defer caret_offsets.deinit(self.allocator);
                var new_offsets = std.ArrayList(usize).empty;
                defer new_offsets.deinit(self.allocator);
                var primary_offset = self.cursor.offset;
                var changed = false;
                const total = self.buffer.totalLen();
                for (caret_offsets.items) |offset| {
                    if (offset >= total) {
                        try new_offsets.append(self.allocator, offset);
                        continue;
                    }
                    const delete_start = offset;
                    const delete_end = offset + 1;
                    const start_point = self.pointForByte(delete_start);
                    const end_point = self.pointForByte(delete_end);
                    try self.buffer.deleteRange(delete_start, 1);
                    self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
                    self.adjustPrimaryOffsetForReplacement(&primary_offset, delete_start, delete_end, 0);
                    self.shiftCaretOffsets(&new_offsets, -1);
                    try new_offsets.append(self.allocator, delete_start);
                    changed = true;
                }
                if (changed) self.noteTextChanged();
                try self.restoreCaretSelections(new_offsets.items, primary_offset);
                self.selection = null;
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selections.items.len > 0) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (delete forward selection set): {s}", .{@errorName(err)});
                };
                const selections = try self.duplicateNormalizedSelectionsDescending();
                defer self.allocator.free(selections);
                var ops = std.ArrayList(SelectionReplacementOp).empty;
                defer ops.deinit(self.allocator);
                for (selections) |sel| {
                    const norm = sel.normalized();
                    const delete_start = norm.start.offset;
                    var delete_len: usize = norm.end.offset - norm.start.offset;
                    if (delete_len == 0 and delete_start < self.buffer.totalLen()) {
                        delete_len = 1;
                    }
                    try ops.append(self.allocator, .{
                        .start = delete_start,
                        .end = delete_start + delete_len,
                        .replacement = "",
                    });
                }
                try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selection) |_| {
                try self.deleteSelection();
                return;
            }
            const total = self.buffer.totalLen();
            if (self.cursor.offset >= total) return;
            const before_id = try self.captureUndoSelectionState();
            const start = self.cursor.offset;
            const end = self.cursor.offset + 1;
            const start_point = self.pointForByte(start);
            const end_point = self.pointForByte(end);
            try self.buffer.deleteRange(start, 1);
            self.applyHighlightEdit(start, end, start, start_point, end_point);
            self.noteTextChanged();
            const after_id = try self.captureUndoSelectionState();
            self.annotateLastUndoSelectionState(before_id, after_id);
        }

        pub fn deleteSelection(self: *Editor) !void {
            self.preferred_visual_col = null;
            if (self.hasOnlyCaretSelections()) {
                var caret_offsets = try self.collectCaretOffsets();
                defer caret_offsets.deinit(self.allocator);
                try self.restoreCaretSelections(caret_offsets.items, self.cursor.offset);
                self.selection = null;
                return;
            }
            if (self.selections.items.len > 0) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (delete selection set): {s}", .{@errorName(err)});
                };
                const selections = try self.duplicateNormalizedSelectionsDescending();
                defer self.allocator.free(selections);
                var ops = std.ArrayList(SelectionReplacementOp).empty;
                defer ops.deinit(self.allocator);
                for (selections) |sel| {
                    const norm = sel.normalized();
                    try ops.append(self.allocator, .{
                        .start = norm.start.offset,
                        .end = norm.end.offset,
                        .replacement = "",
                    });
                }
                try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
                try self.endTrackedUndoGroup();
                return;
            }
            if (self.selection) |sel| {
                const before_id = try self.captureUndoSelectionState();
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    const start = norm.start.offset;
                    const end = norm.end.offset;
                    const start_point = self.pointForByte(start);
                    const end_point = self.pointForByte(end);
                    try self.buffer.deleteRange(start, len);
                    self.applyHighlightEdit(start, end, start, start_point, end_point);
                    self.cursor = norm.start;
                    self.noteTextChanged();
                }
                self.selection = null;
                const after_id = try self.captureUndoSelectionState();
                self.annotateLastUndoSelectionState(before_id, after_id);
            }
        }
    };
}
