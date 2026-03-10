const std = @import("std");
const types = @import("types.zig");
const app_logger = @import("../app_logger.zig");

const CursorPos = types.CursorPos;
const Selection = types.Selection;

pub const StoredSelection = struct {
    start_offset: usize,
    end_offset: usize,
    is_rectangular: bool = false,
};

pub const UndoSelectionState = struct {
    id: u64,
    cursor_offset: usize,
    selection: ?StoredSelection,
    selections: []StoredSelection,
};

pub const SelectionReplacementOp = struct {
    start: usize,
    end: usize,
    replacement: []const u8,
};

pub fn SelectionStateOps(comptime Editor: type) type {
    return struct {
        pub fn hasRectangularSelectionState(self: *Editor) bool {
            if (self.selection) |sel| {
                if (sel.is_rectangular) return true;
            }
            for (self.selections.items) |sel| {
                if (sel.is_rectangular) return true;
            }
            return false;
        }

        pub fn hasSelectionSetState(self: *Editor) bool {
            return self.selection != null or self.selections.items.len > 0;
        }

        pub fn collectSelectionAnchorsAndHeads(
            self: *Editor,
            anchors: *std.ArrayList(usize),
            heads: *std.ArrayList(usize),
        ) !void {
            if (self.selection) |sel| {
                try anchors.append(self.allocator, sel.start.offset);
                try heads.append(self.allocator, sel.end.offset);
            } else {
                try anchors.append(self.allocator, self.cursor.offset);
                try heads.append(self.allocator, self.cursor.offset);
            }
            for (self.selections.items) |sel| {
                try anchors.append(self.allocator, sel.start.offset);
                try heads.append(self.allocator, sel.end.offset);
            }
        }

        pub fn tryAppendCollapseOffset(self: *Editor, offsets: *std.ArrayList(usize), offset: usize) void {
            if (std.mem.indexOfScalar(usize, offsets.items, offset) != null) return;
            offsets.append(self.allocator, offset) catch |err| {
                const log = app_logger.logger("editor.input");
                log.logf(.warning, "append collapse offset failed offset={d}: {s}", .{ offset, @errorName(err) });
            };
        }

        pub fn extendSelectionSetWithHeads(self: *Editor, target_heads: []const usize) !void {
            var anchor_offsets = std.ArrayList(usize).empty;
            defer anchor_offsets.deinit(self.allocator);
            var head_offsets = std.ArrayList(usize).empty;
            defer head_offsets.deinit(self.allocator);
            try self.collectSelectionAnchorsAndHeads(&anchor_offsets, &head_offsets);
            std.debug.assert(anchor_offsets.items.len == target_heads.len);
            try self.restoreExtendedCaretSelections(anchor_offsets.items, target_heads);
        }

        pub fn clearSelections(self: *Editor) void {
            self.selections.clearRetainingCapacity();
        }

        pub fn primaryCaret(self: *Editor) CursorPos {
            return self.cursor;
        }

        pub fn auxiliaryCaretCount(self: *Editor) usize {
            var count: usize = 0;
            for (self.selections.items) |sel| {
                if (sel.normalized().isEmpty()) count += 1;
            }
            return count;
        }

        pub fn auxiliaryCaretAt(self: *Editor, index: usize) ?CursorPos {
            var seen: usize = 0;
            for (self.selections.items) |sel| {
                const norm = sel.normalized();
                if (!norm.isEmpty()) continue;
                if (seen == index) return norm.start;
                seen += 1;
            }
            return null;
        }

        pub fn storedSelectionFromSelection(sel: Selection) StoredSelection {
            return .{
                .start_offset = sel.start.offset,
                .end_offset = sel.end.offset,
                .is_rectangular = sel.is_rectangular,
            };
        }

        pub fn selectionFromStored(self: *Editor, stored: StoredSelection) Selection {
            const total = self.buffer.totalLen();
            const start = self.cursorPosForOffset(@min(stored.start_offset, total));
            const end = self.cursorPosForOffset(@min(stored.end_offset, total));
            return .{
                .start = start,
                .end = end,
                .is_rectangular = stored.is_rectangular,
            };
        }

        pub fn rectangularPasteLines(self: *Editor, text: []const u8) !?[][]const u8 {
            if (self.selections.items.len == 0) return null;
            for (self.selections.items) |sel| {
                if (!sel.is_rectangular) return null;
            }

            var line_count: usize = 1;
            for (text) |byte| {
                if (byte == '\n') line_count += 1;
            }
            var clipboard_lines = try self.allocator.alloc([]const u8, line_count);
            errdefer self.allocator.free(clipboard_lines);
            var start: usize = 0;
            var line_idx: usize = 0;
            for (text, 0..) |byte, idx| {
                if (byte != '\n') continue;
                const raw = text[start..idx];
                clipboard_lines[line_idx] = if (raw.len > 0 and raw[raw.len - 1] == '\r') raw[0 .. raw.len - 1] else raw;
                line_idx += 1;
                start = idx + 1;
            }
            const raw_tail = text[start..];
            clipboard_lines[line_idx] = if (raw_tail.len > 0 and raw_tail[raw_tail.len - 1] == '\r') raw_tail[0 .. raw_tail.len - 1] else raw_tail;

            const lines = try self.allocator.alloc([]const u8, self.selections.items.len);
            errdefer self.allocator.free(lines);
            if (clipboard_lines.len == 1) {
                for (lines) |*line| {
                    line.* = clipboard_lines[0];
                }
            } else if (clipboard_lines.len == self.selections.items.len) {
                for (lines, clipboard_lines) |*line, clip_line| {
                    line.* = clip_line;
                }
            } else {
                for (lines, 0..) |*line, idx| {
                    line.* = clipboard_lines[idx % clipboard_lines.len];
                }
            }
            self.allocator.free(clipboard_lines);
            return lines;
        }

        pub fn captureUndoSelectionState(self: *Editor) !u64 {
            const id = self.next_undo_selection_state_id;
            self.next_undo_selection_state_id +|= 1;

            var extra = try self.allocator.alloc(StoredSelection, self.selections.items.len);
            for (self.selections.items, 0..) |sel, idx| {
                extra[idx] = storedSelectionFromSelection(sel);
            }

            try self.undo_selection_states.append(self.allocator, .{
                .id = id,
                .cursor_offset = self.cursor.offset,
                .selection = if (self.selection) |sel| storedSelectionFromSelection(sel) else null,
                .selections = extra,
            });
            return id;
        }

        pub fn restoreUndoSelectionState(self: *Editor, state_id: u64) !bool {
            for (self.undo_selection_states.items) |state| {
                if (state.id != state_id) continue;
                const total = self.buffer.totalLen();
                self.cursor = self.cursorPosForOffset(@min(state.cursor_offset, total));
                self.preferred_visual_col = null;
                self.selection = if (state.selection) |sel| self.selectionFromStored(sel) else null;
                self.clearSelections();
                for (state.selections) |sel| {
                    try self.selections.append(self.allocator, self.selectionFromStored(sel));
                }
                return true;
            }
            return false;
        }

        pub fn annotateLastUndoSelectionState(self: *Editor, before_id: u64, after_id: u64) void {
            self.buffer.annotateLastUndoState(before_id, after_id);
        }

        pub fn beginTrackedUndoGroup(self: *Editor) !u64 {
            const before_id = try self.captureUndoSelectionState();
            self.buffer.beginUndoGroup();
            self.buffer.annotateCurrentUndoGroupBefore(before_id);
            return before_id;
        }

        pub fn endTrackedUndoGroup(self: *Editor) !void {
            const after_id = try self.captureUndoSelectionState();
            try self.buffer.endUndoGroup();
            self.buffer.annotateClosedUndoGroupAfter(after_id);
        }

        pub fn addSelection(self: *Editor, selection: Selection) !void {
            try self.selections.append(self.allocator, selection);
        }

        pub fn selectionCount(self: *Editor) usize {
            return self.selections.items.len;
        }

        pub fn selectionAt(self: *Editor, index: usize) ?Selection {
            if (index >= self.selections.items.len) return null;
            return self.selections.items[index];
        }

        pub fn normalizeSelections(self: *Editor) !void {
            if (self.selections.items.len == 0) return;
            for (self.selections.items) |*sel| {
                sel.* = sel.normalized();
            }
            std.sort.block(Selection, self.selections.items, {}, struct {
                fn lessThan(_: void, a: Selection, b: Selection) bool {
                    return a.start.offset < b.start.offset;
                }
            }.lessThan);

            var merged = std.ArrayList(Selection).empty;
            defer merged.deinit(self.allocator);
            try merged.append(self.allocator, self.selections.items[0]);
            for (self.selections.items[1..]) |sel| {
                var last = &merged.items[merged.items.len - 1];
                if (!sel.is_rectangular and !last.is_rectangular and sel.start.offset <= last.end.offset) {
                    if (sel.end.offset > last.end.offset) {
                        last.end = sel.end;
                    }
                } else {
                    try merged.append(self.allocator, sel);
                }
            }
            self.selections.clearRetainingCapacity();
            try self.selections.appendSlice(self.allocator, merged.items);
        }

        pub fn addRectSelection(self: *Editor, start: CursorPos, end: CursorPos) !void {
            try self.selections.append(self.allocator, .{
                .start = start,
                .end = end,
                .is_rectangular = true,
            });
        }

        pub fn expandRectSelection(self: *Editor, start_line: usize, end_line: usize, start_col: usize, end_col: usize) !void {
            if (start_line > end_line) return;
            var line = start_line;
            while (line <= end_line) : (line += 1) {
                const line_start = self.buffer.lineStart(line);
                const line_len = self.buffer.lineLen(line);
                const start_clamped = @min(start_col, line_len);
                const end_clamped = @min(end_col, line_len);
                const start = CursorPos{ .line = line, .col = start_clamped, .offset = line_start + start_clamped };
                const end = CursorPos{ .line = line, .col = end_clamped, .offset = line_start + end_clamped };
                try self.addRectSelection(start, end);
            }
        }

        pub fn expandRectSelectionVisual(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize) !void {
            return self.expandRectSelectionVisualWithClusters(start_line, end_line, start_col_vis, end_col_vis, null);
        }

        pub fn expandRectSelectionVisualWithClusters(
            self: *Editor,
            start_line: usize,
            end_line: usize,
            start_col_vis: usize,
            end_col_vis: usize,
            provider: ?*const Editor.ClusterProvider,
        ) !void {
            if (start_line > end_line) return;
            var line = start_line;
            while (line <= end_line) : (line += 1) {
                const line_start = self.buffer.lineStart(line);
                const line_text = try self.getLineAlloc(line);
                defer self.allocator.free(line_text);
                const clusters = if (provider) |cluster_provider| cluster_provider.getClusters(cluster_provider.ctx, line, line_text) else null;
                const start_byte = self.byteIndexForVisualColumn(line_text, start_col_vis, clusters);
                const end_byte = self.byteIndexForVisualColumn(line_text, end_col_vis, clusters);
                const start = CursorPos{ .line = line, .col = start_byte, .offset = line_start + start_byte };
                const end = CursorPos{ .line = line, .col = end_byte, .offset = line_start + end_byte };
                try self.addRectSelection(start, end);
            }
        }

        pub fn normalizeSelectionsDescending(self: *Editor) !void {
            try self.normalizeSelections();
            if (self.selections.items.len == 0) return;
            std.sort.block(Selection, self.selections.items, {}, struct {
                fn lessThan(_: void, a: Selection, b: Selection) bool {
                    return a.start.offset > b.start.offset;
                }
            }.lessThan);
        }

        pub fn duplicateNormalizedSelectionsDescending(self: *Editor) ![]Selection {
            try self.normalizeSelectionsDescending();
            return self.allocator.dupe(Selection, self.selections.items);
        }

        pub fn addCaretUp(self: *Editor) !bool {
            return self.addCaretVertical(-1);
        }

        pub fn addCaretDown(self: *Editor) !bool {
            return self.addCaretVertical(1);
        }

        pub fn addCaretVertical(self: *Editor, delta: i32) !bool {
            if (delta == 0) return false;
            if (self.selection != null) return false;
            if (self.auxiliaryCaretCount() != self.selections.items.len) return false;

            var caret_offsets = std.ArrayList(usize).empty;
            defer caret_offsets.deinit(self.allocator);

            try caret_offsets.append(self.allocator, self.primaryCaret().offset);
            var idx: usize = 0;
            while (idx < self.auxiliaryCaretCount()) : (idx += 1) {
                const caret = self.auxiliaryCaretAt(idx) orelse continue;
                if (caret.offset == self.primaryCaret().offset) continue;
                if (std.mem.indexOfScalar(usize, caret_offsets.items, caret.offset) != null) continue;
                try caret_offsets.append(self.allocator, caret.offset);
            }

            var added_any = false;
            for (caret_offsets.items) |offset| {
                const caret = self.cursorPosForOffset(offset);
                const target_line = if (delta < 0) blk: {
                    if (caret.line == 0) continue;
                    break :blk caret.line - 1;
                } else blk: {
                    if (caret.line + 1 >= self.buffer.lineCount()) continue;
                    break :blk caret.line + 1;
                };
                const target_col = @min(caret.col, self.buffer.lineLen(target_line));
                const target_offset = self.buffer.lineStart(target_line) + target_col;
                if (target_offset == self.cursor.offset) continue;
                if (std.mem.indexOfScalar(usize, caret_offsets.items, target_offset) != null) continue;
                try self.selections.append(self.allocator, .{
                    .start = .{ .line = target_line, .col = target_col, .offset = target_offset },
                    .end = .{ .line = target_line, .col = target_col, .offset = target_offset },
                });
                try caret_offsets.append(self.allocator, target_offset);
                added_any = true;
            }

            if (added_any) {
                try self.normalizeSelections();
            }
            return added_any;
        }

        pub fn cursorPosForOffset(self: *Editor, offset: usize) CursorPos {
            const line = self.buffer.lineIndexForOffset(offset);
            const line_start = self.buffer.lineStart(line);
            return .{
                .line = line,
                .col = offset - line_start,
                .offset = offset,
            };
        }

        pub fn shiftCaretOffsets(caret_offsets: *std.ArrayList(usize), delta: isize) void {
            if (delta == 0) return;
            for (caret_offsets.items) |*offset| {
                const shifted = @as(isize, @intCast(offset.*)) + delta;
                offset.* = @intCast(shifted);
            }
        }

        pub fn hasOnlyCaretSelections(self: *Editor) bool {
            return self.auxiliaryCaretCount() > 0 and self.auxiliaryCaretCount() == self.selections.items.len;
        }

        pub fn collectCaretOffsets(self: *Editor) !std.ArrayList(usize) {
            var caret_offsets = std.ArrayList(usize).empty;
            errdefer caret_offsets.deinit(self.allocator);

            try caret_offsets.append(self.allocator, self.primaryCaret().offset);
            var idx: usize = 0;
            while (idx < self.auxiliaryCaretCount()) : (idx += 1) {
                const caret = self.auxiliaryCaretAt(idx) orelse continue;
                if (std.mem.indexOfScalar(usize, caret_offsets.items, caret.offset) != null) continue;
                try caret_offsets.append(self.allocator, caret.offset);
            }
            return caret_offsets;
        }

        pub fn collectCaretOffsetsDescending(self: *Editor) !std.ArrayList(usize) {
            const caret_offsets = try self.collectCaretOffsets();
            std.sort.block(usize, caret_offsets.items, {}, struct {
                fn lessThan(_: void, a: usize, b: usize) bool {
                    return a > b;
                }
            }.lessThan);
            return caret_offsets;
        }

        pub fn restoreCaretSelections(self: *Editor, caret_offsets: []const usize, primary_offset: usize) !void {
            self.clearSelections();
            self.cursor = self.cursorPosForOffset(primary_offset);
            for (caret_offsets) |offset| {
                if (offset == primary_offset) continue;
                const caret = self.cursorPosForOffset(offset);
                try self.selections.append(self.allocator, .{
                    .start = caret,
                    .end = caret,
                });
            }
            if (self.selections.items.len > 0) {
                try self.normalizeSelections();
                var idx: usize = 0;
                while (idx < self.selections.items.len) {
                    if (self.selections.items[idx].start.offset == primary_offset and self.selections.items[idx].isEmpty()) {
                        _ = self.selections.orderedRemove(idx);
                    } else {
                        idx += 1;
                    }
                }
            }
        }

        pub fn restoreExtendedCaretSelections(self: *Editor, anchor_offsets: []const usize, target_offsets: []const usize) !void {
            std.debug.assert(anchor_offsets.len == target_offsets.len);
            std.debug.assert(anchor_offsets.len > 0);

            self.preferred_visual_col = null;
            self.clearSelections();

            const primary_anchor = self.cursorPosForOffset(anchor_offsets[0]);
            const primary_target = self.cursorPosForOffset(target_offsets[0]);
            self.cursor = primary_target;
            self.selection = if (primary_anchor.offset == primary_target.offset)
                null
            else
                .{ .start = primary_anchor, .end = primary_target };

            var idx: usize = 1;
            while (idx < anchor_offsets.len) : (idx += 1) {
                const anchor = self.cursorPosForOffset(anchor_offsets[idx]);
                const target = self.cursorPosForOffset(target_offsets[idx]);
                try self.selections.append(self.allocator, if (anchor.offset == target.offset)
                    .{ .start = target, .end = target }
                else
                    .{ .start = anchor, .end = target });
            }
        }

        pub fn moveCaretSetHorizontal(self: *Editor, delta: isize) !void {
            var caret_offsets = try self.collectCaretOffsets();
            defer caret_offsets.deinit(self.allocator);
            const primary_offset = caret_offsets.items[0];

            const total = self.buffer.totalLen();
            for (caret_offsets.items) |*offset| {
                if (delta < 0) {
                    if (offset.* > 0) offset.* -= 1;
                } else if (delta > 0) {
                    if (offset.* < total) offset.* += 1;
                }
            }

            self.preferred_visual_col = null;
            self.selection = null;
            try self.restoreCaretSelections(caret_offsets.items, if (delta < 0) if (primary_offset > 0) primary_offset - 1 else 0 else @min(primary_offset + 1, total));
        }

        pub fn moveCaretSetToLineBoundary(self: *Editor, to_start: bool) !void {
            var caret_offsets = try self.collectCaretOffsets();
            defer caret_offsets.deinit(self.allocator);
            var primary_offset = caret_offsets.items[0];

            for (caret_offsets.items) |*offset| {
                const caret = self.cursorPosForOffset(offset.*);
                if (to_start) {
                    offset.* = self.buffer.lineStart(caret.line);
                } else {
                    offset.* = self.buffer.lineStart(caret.line) + self.buffer.lineLen(caret.line);
                }
                if (offset == &caret_offsets.items[0]) primary_offset = offset.*;
            }

            self.preferred_visual_col = null;
            self.selection = null;
            try self.restoreCaretSelections(caret_offsets.items, primary_offset);
        }

        pub fn moveCaretSetByWord(self: *Editor, left: bool) !void {
            var caret_offsets = try self.collectCaretOffsets();
            defer caret_offsets.deinit(self.allocator);

            for (caret_offsets.items) |*offset| {
                offset.* = if (left) self.wordLeftOffset(offset.*) else self.wordRightOffset(offset.*);
            }

            self.preferred_visual_col = null;
            self.selection = null;
            try self.restoreCaretSelections(caret_offsets.items, caret_offsets.items[0]);
        }

        pub fn extendCaretSetToOffsets(self: *Editor, target_offsets: []const usize) !void {
            var anchor_offsets = try self.collectCaretOffsets();
            defer anchor_offsets.deinit(self.allocator);
            try self.restoreExtendedCaretSelections(anchor_offsets.items, target_offsets);
        }

        pub fn adjustPrimaryOffsetForReplacement(primary_offset: *usize, start: usize, end: usize, replacement_len: usize) void {
            const deleted_len = end - start;
            if (primary_offset.* > end) {
                primary_offset.* = @intCast(@as(isize, @intCast(primary_offset.*)) + @as(isize, @intCast(replacement_len)) - @as(isize, @intCast(deleted_len)));
            } else if (primary_offset.* >= start) {
                primary_offset.* = start + replacement_len;
            }
        }

        pub fn applySelectionReplacementOps(
            self: *Editor,
            ops: []const SelectionReplacementOp,
            initial_primary_offset: usize,
        ) !void {
            var changed = false;
            var caret_offsets = std.ArrayList(usize).empty;
            defer caret_offsets.deinit(self.allocator);
            var primary_offset = initial_primary_offset;

            for (ops) |op| {
                const delete_len = op.end - op.start;
                if (delete_len > 0) {
                    const start_point = self.pointForByte(op.start);
                    const end_point = self.pointForByte(op.end);
                    try self.buffer.deleteRange(op.start, delete_len);
                    self.applyHighlightEdit(op.start, op.end, op.start, start_point, end_point);
                    changed = true;
                }
                if (op.replacement.len > 0) {
                    const insert_point = self.pointForByte(op.start);
                    try self.buffer.insertBytes(op.start, op.replacement);
                    self.applyHighlightEdit(op.start, op.start, op.start + op.replacement.len, insert_point, insert_point);
                    changed = true;
                }
                shiftCaretOffsets(&caret_offsets, @as(isize, @intCast(op.replacement.len)) - @as(isize, @intCast(delete_len)));
                adjustPrimaryOffsetForReplacement(&primary_offset, op.start, op.end, op.replacement.len);
                try caret_offsets.append(self.allocator, op.start + op.replacement.len);
            }

            if (changed) self.noteTextChanged();
            try self.restoreCaretSelections(caret_offsets.items, primary_offset);
            self.selection = null;
        }

        pub fn isWordByte(byte: u8) bool {
            return std.ascii.isAlphanumeric(byte) or byte == '_';
        }

        pub fn byteAt(self: *Editor, offset: usize) ?u8 {
            if (offset >= self.buffer.totalLen()) return null;
            var buf: [1]u8 = undefined;
            return if (self.buffer.readRange(offset, &buf) == 1) buf[0] else null;
        }

        pub fn wordLeftOffset(self: *Editor, offset: usize) usize {
            if (offset == 0) return 0;
            var idx = offset - 1;
            while (idx > 0) : (idx -= 1) {
                const byte = self.byteAt(idx) orelse break;
                if (isWordByte(byte)) break;
            }
            while (idx > 0) {
                const prev = self.byteAt(idx - 1) orelse break;
                if (!isWordByte(prev)) break;
                idx -= 1;
            }
            return idx;
        }

        pub fn wordRightOffset(self: *Editor, offset: usize) usize {
            const total = self.buffer.totalLen();
            var idx = offset;
            while (idx < total) : (idx += 1) {
                const byte = self.byteAt(idx) orelse break;
                if (!isWordByte(byte)) break;
            }
            while (idx < total) : (idx += 1) {
                const byte = self.byteAt(idx) orelse break;
                if (isWordByte(byte)) break;
            }
            return idx;
        }

        pub fn extendPrimarySelectionToOffset(self: *Editor, target_offset: usize) void {
            const anchor = if (self.selection) |sel| sel.normalized().start else self.cursor;
            const target = self.cursorPosForOffset(target_offset);
            self.cursor = target;
            self.preferred_visual_col = null;
            self.clearSelections();
            if (anchor.offset == target.offset) {
                self.selection = null;
                return;
            }
            self.selection = .{ .start = anchor, .end = target };
        }
    };
}
