const std = @import("std");

pub const BufferKind = enum(u8) {
    original,
    add,
};

pub const Leaf = struct {
    buffer: BufferKind,
    start: usize,
    len: usize,
};

pub const Node = struct {
    left: ?*Node,
    right: ?*Node,
    leaf: ?Leaf,
    byte_len: usize,
    line_breaks: usize,
    height: u8,
};

pub const Rope = struct {
    allocator: std.mem.Allocator,
    root: ?*Node,
    original: []const u8,
    owns_original: bool,
    add: std.ArrayList(u8),
    undo_stack: std.ArrayList(UndoOp),
    redo_stack: std.ArrayList(UndoOp),
    history_suspended: bool,
    group_depth: u32,
    group_dirty: bool,
    const target_leaf_bytes: usize = 2048;
    const max_undo_bytes: usize = 8 * 1024 * 1024;
    const max_undo_ops: usize = 1000;

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*Rope {
        var rope = try allocator.create(Rope);
        errdefer allocator.destroy(rope);
        rope.* = .{
            .allocator = allocator,
            .root = null,
            .original = try allocator.dupe(u8, initial),
            .owns_original = true,
            .add = .{},
            .undo_stack = .{},
            .redo_stack = .{},
            .history_suspended = false,
            .group_depth = 0,
            .group_dirty = false,
        };
        errdefer allocator.free(rope.original);
        if (initial.len > 0) {
            rope.root = try rope.createLeafNode(.original, 0, initial.len);
        }
        return rope;
    }

    pub fn initOwnedOriginal(allocator: std.mem.Allocator, original: []u8) !*Rope {
        var rope = try allocator.create(Rope);
        errdefer allocator.destroy(rope);
        rope.* = .{
            .allocator = allocator,
            .root = null,
            .original = original,
            .owns_original = true,
            .add = .{},
            .undo_stack = .{},
            .redo_stack = .{},
            .history_suspended = false,
            .group_depth = 0,
            .group_dirty = false,
        };
        errdefer allocator.free(original);
        if (original.len > 0) {
            rope.root = try rope.createLeafNode(.original, 0, original.len);
        }
        return rope;
    }

    pub fn deinit(self: *Rope) void {
        if (self.owns_original) {
            self.allocator.free(self.original);
        }
        self.add.deinit(self.allocator);
        freeUndoStack(self, &self.undo_stack);
        freeUndoStack(self, &self.redo_stack);
        if (self.root) |root| {
            self.destroyNode(root);
        }
        self.allocator.destroy(self);
    }

    pub fn totalLen(self: *Rope) usize {
        if (self.root) |root| return root.byte_len;
        return 0;
    }

    pub fn insert(self: *Rope, offset: usize, data: []const u8) !void {
        if (data.len == 0) return;
        if (data.len > max_undo_bytes) {
            clearHistory(self);
            self.history_suspended = true;
            defer self.history_suspended = false;
            try self.insertNoHistory(offset, data);
            return;
        }
        if (self.history_suspended) {
            try self.insertNoHistory(offset, data);
            return;
        }
        if (self.tryMergeUndoInsert(offset, data)) |merged| {
            if (merged) {
                try self.insertNoHistory(offset, data);
                try clearRedoStack(self);
                self.markGroupDirty();
                return;
            }
        }
        const op = try createUndoOp(self, .insert, offset, data);
        try self.insertNoHistory(offset, data);
        try clearRedoStack(self);
        try self.undo_stack.append(self.allocator, op);
        trimUndoStack(self);
        self.markGroupDirty();
    }

    pub fn deleteRange(self: *Rope, start: usize, len: usize) !void {
        if (len == 0) return;
        if (len > max_undo_bytes) {
            clearHistory(self);
            self.history_suspended = true;
            defer self.history_suspended = false;
            try self.deleteRangeNoHistory(start, len);
            return;
        }
        if (self.history_suspended) {
            try self.deleteRangeNoHistory(start, len);
            return;
        }
        const deleted = try self.readRangeAlloc(start, len);
        if (self.tryMergeUndoDelete(start, deleted)) |merged| {
            if (merged) {
                try self.deleteRangeNoHistory(start, len);
                try clearRedoStack(self);
                self.allocator.free(deleted);
                self.markGroupDirty();
                return;
            }
        }
        const op = UndoOp{ .kind = .delete, .pos = start, .text = deleted };
        try self.deleteRangeNoHistory(start, len);
        try clearRedoStack(self);
        try self.undo_stack.append(self.allocator, op);
        trimUndoStack(self);
        self.markGroupDirty();
    }

    pub fn canUndo(self: *Rope) bool {
        return self.undo_stack.items.len > 0;
    }

    pub fn canRedo(self: *Rope) bool {
        return self.redo_stack.items.len > 0;
    }

    pub const UndoResult = struct {
        changed: bool,
        cursor: ?usize,
        state: ?u64,
    };

    pub fn undo(self: *Rope) !UndoResult {
        if (self.undo_stack.items.len == 0) return .{ .changed = false, .cursor = null, .state = null };
        self.history_suspended = true;
        defer self.history_suspended = false;
        const first = self.undo_stack.pop() orelse return .{ .changed = false, .cursor = null, .state = null };
        if (first.kind != .boundary) {
            const cursor_pos = undoCursorPos(first);
            switch (first.kind) {
                .insert => try self.deleteRangeNoHistory(first.pos, first.text.len),
                .delete => try self.insertNoHistory(first.pos, first.text),
                .boundary => {},
            }
            try self.redo_stack.append(self.allocator, first);
            return .{ .changed = true, .cursor = cursor_pos, .state = first.before_state };
        }

        const end_marker = first;
        var temp = std.ArrayList(UndoOp).empty;
        defer temp.deinit(self.allocator);
        var cursor_pos: ?usize = null;
        while (self.undo_stack.items.len > 0) {
            const op = self.undo_stack.pop() orelse break;
            if (op.kind == .boundary) {
                try self.redo_stack.append(self.allocator, op);
                for (temp.items) |temp_op| {
                    try self.redo_stack.append(self.allocator, temp_op);
                }
                try self.redo_stack.append(self.allocator, end_marker);
                return .{ .changed = temp.items.len > 0, .cursor = cursor_pos, .state = end_marker.before_state orelse op.before_state };
            }
            cursor_pos = undoCursorPos(op);
            switch (op.kind) {
                .insert => try self.deleteRangeNoHistory(op.pos, op.text.len),
                .delete => try self.insertNoHistory(op.pos, op.text),
                .boundary => {},
            }
            try temp.append(self.allocator, op);
        }
        // No start marker found; drop end marker.
        freeUndoOp(self, end_marker);
        for (temp.items) |temp_op| {
            try self.redo_stack.append(self.allocator, temp_op);
        }
        return .{ .changed = temp.items.len > 0, .cursor = cursor_pos, .state = null };
    }

    pub fn redo(self: *Rope) !UndoResult {
        if (self.redo_stack.items.len == 0) return .{ .changed = false, .cursor = null, .state = null };
        self.history_suspended = true;
        defer self.history_suspended = false;
        const first = self.redo_stack.pop() orelse return .{ .changed = false, .cursor = null, .state = null };
        if (first.kind != .boundary) {
            const cursor_pos = redoCursorPos(first);
            switch (first.kind) {
                .insert => try self.insertNoHistory(first.pos, first.text),
                .delete => try self.deleteRangeNoHistory(first.pos, first.text.len),
                .boundary => {},
            }
            try self.undo_stack.append(self.allocator, first);
            return .{ .changed = true, .cursor = cursor_pos, .state = first.after_state };
        }

        const end_marker = first;
        var temp = std.ArrayList(UndoOp).empty;
        defer temp.deinit(self.allocator);
        var cursor_pos: ?usize = null;
        while (self.redo_stack.items.len > 0) {
            const op = self.redo_stack.pop() orelse break;
            if (op.kind == .boundary) {
                try self.undo_stack.append(self.allocator, op);
                for (temp.items) |temp_op| {
                    try self.undo_stack.append(self.allocator, temp_op);
                }
                try self.undo_stack.append(self.allocator, end_marker);
                return .{ .changed = temp.items.len > 0, .cursor = cursor_pos, .state = end_marker.after_state };
            }
            cursor_pos = redoCursorPos(op);
            switch (op.kind) {
                .insert => try self.insertNoHistory(op.pos, op.text),
                .delete => try self.deleteRangeNoHistory(op.pos, op.text.len),
                .boundary => {},
            }
            try temp.append(self.allocator, op);
        }
        freeUndoOp(self, end_marker);
        for (temp.items) |temp_op| {
            try self.undo_stack.append(self.allocator, temp_op);
        }
        return .{ .changed = temp.items.len > 0, .cursor = cursor_pos, .state = null };
    }

    pub fn beginUndoGroup(self: *Rope) void {
        if (self.group_depth == 0) {
            const marker = boundaryOp(self) catch return;
            self.undo_stack.append(self.allocator, marker) catch {
                freeUndoOp(self, marker);
                return;
            };
            trimUndoStack(self);
            self.group_dirty = false;
        }
        self.group_depth += 1;
    }

    pub fn endUndoGroup(self: *Rope) !void {
        if (self.group_depth == 0) return;
        self.group_depth -= 1;
        if (self.group_depth == 0 and self.group_dirty) {
            const marker = boundaryOp(self) catch return;
            self.undo_stack.append(self.allocator, marker) catch {
                freeUndoOp(self, marker);
                return;
            };
            trimUndoStack(self);
            self.group_dirty = false;
            return;
        }
        if (self.group_depth == 0 and !self.group_dirty) {
            if (self.undo_stack.items.len > 0) {
                const last_index = self.undo_stack.items.len - 1;
                if (self.undo_stack.items[last_index].kind == .boundary) {
                    const marker = self.undo_stack.pop().?;
                    freeUndoOp(self, marker);
                }
            }
        }
    }

    pub fn annotateLastUndoState(self: *Rope, before_state: ?u64, after_state: ?u64) void {
        if (self.undo_stack.items.len == 0) return;
        const last = &self.undo_stack.items[self.undo_stack.items.len - 1];
        if (last.kind == .boundary) return;
        if (before_state) |id| {
            if (last.before_state == null) last.before_state = id;
        }
        if (after_state) |id| {
            last.after_state = id;
        }
    }

    pub fn annotateCurrentUndoGroupBefore(self: *Rope, before_state: u64) void {
        if (self.undo_stack.items.len == 0) return;
        const last = &self.undo_stack.items[self.undo_stack.items.len - 1];
        if (last.kind != .boundary) return;
        last.before_state = before_state;
    }

    pub fn annotateClosedUndoGroupAfter(self: *Rope, after_state: u64) void {
        if (self.undo_stack.items.len == 0) return;
        const last = &self.undo_stack.items[self.undo_stack.items.len - 1];
        if (last.kind != .boundary) return;
        last.after_state = after_state;
    }

    fn insertNoHistory(self: *Rope, offset: usize, data: []const u8) !void {
        if (data.len == 0) return;
        const total = self.totalLen();
        if (offset > total) return error.OutOfBounds;
        const add_start = self.add.items.len;
        try self.add.appendSlice(self.allocator, data);
        const new_leaf = try self.createLeafNode(.add, add_start, data.len);
        const parts = try self.split(self.root, offset);
        var merged = try self.join(parts.left, new_leaf);
        merged = try self.join(merged, parts.right);
        self.root = merged;
    }

    fn deleteRangeNoHistory(self: *Rope, start: usize, len: usize) !void {
        if (len == 0) return;
        const total = self.totalLen();
        if (start > total or start + len > total) return error.OutOfBounds;
        const parts = try self.split(self.root, start);
        const tail = try self.split(parts.right, len);
        if (tail.left) |mid| {
            self.destroyNode(mid);
        }
        self.root = try self.join(parts.left, tail.right);
    }

    pub fn readRange(self: *Rope, start: usize, out: []u8) usize {
        if (out.len == 0) return 0;
        const total = self.totalLen();
        if (start >= total) return 0;
        var written: usize = 0;
        self.readNode(self.root, start, out, &written);
        return written;
    }

    pub fn readRangeAlloc(self: *Rope, start: usize, len: usize) ![]u8 {
        const total = self.totalLen();
        if (start >= total or len == 0) return try self.allocator.alloc(u8, 0);
        const readable = if (start + len > total) total - start else len;
        var out = try self.allocator.alloc(u8, readable);
        const written = self.readRange(start, out);
        if (written < readable) {
            out = try self.allocator.realloc(out, written);
        }
        return out;
    }

    pub fn lineCount(self: *Rope) usize {
        if (self.root) |root| return root.line_breaks + 1;
        return 1;
    }

    pub fn lineStart(self: *Rope, line_index: usize) usize {
        if (line_index == 0) return 0;
        const total_lines = self.lineCount();
        if (line_index >= total_lines) return self.totalLen();
        const newline_offset = self.findNthNewline(self.root, line_index);
        return newline_offset + 1;
    }

    pub fn lineLen(self: *Rope, line_index: usize) usize {
        const total_lines = self.lineCount();
        if (line_index >= total_lines) return 0;
        const start = self.lineStart(line_index);
        if (line_index + 1 < total_lines) {
            const next_start = self.lineStart(line_index + 1);
            return if (next_start > start) next_start - start - 1 else 0;
        }
        const total = self.totalLen();
        return if (total > start) total - start else 0;
    }

    pub fn lineIndexForOffset(self: *Rope, offset: usize) usize {
        const total = self.totalLen();
        if (offset >= total) {
            const total_lines = self.lineCount();
            return if (total_lines == 0) 0 else total_lines - 1;
        }
        return self.countLineBreaksBefore(self.root, offset);
    }

    fn createLeafNode(self: *Rope, buffer: BufferKind, start: usize, len: usize) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .left = null,
            .right = null,
            .leaf = Leaf{ .buffer = buffer, .start = start, .len = len },
            .byte_len = len,
            .line_breaks = self.countLineBreaks(buffer, start, len),
            .height = 1,
        };
        return node;
    }

    fn createInternalNode(self: *Rope, left: ?*Node, right: ?*Node) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .left = left,
            .right = right,
            .leaf = null,
            .byte_len = 0,
            .line_breaks = 0,
            .height = 1,
        };
        self.updateNode(node);
        return node;
    }

    fn destroyNode(self: *Rope, node: *Node) void {
        if (node.left) |left| self.destroyNode(left);
        if (node.right) |right| self.destroyNode(right);
        self.allocator.destroy(node);
    }

    fn countLineBreaks(self: *Rope, buffer: BufferKind, start: usize, len: usize) usize {
        const data = switch (buffer) {
            .original => self.original,
            .add => self.add.items,
        };
        if (len == 0) return 0;
        var count: usize = 0;
        const slice = data[start .. start + len];
        for (slice) |byte| {
            if (byte == '\n') count += 1;
        }
        return count;
    }

    fn nodeHeight(node: ?*Node) u8 {
        if (node) |n| return n.height;
        return 0;
    }

    fn nodeLen(node: ?*Node) usize {
        if (node) |n| return n.byte_len;
        return 0;
    }

    fn nodeBreaks(node: ?*Node) usize {
        if (node) |n| return n.line_breaks;
        return 0;
    }

    fn updateNode(self: *Rope, node: *Node) void {
        if (node.leaf != null) {
            node.left = null;
            node.right = null;
            node.byte_len = node.leaf.?.len;
            node.line_breaks = self.countLineBreaks(node.leaf.?.buffer, node.leaf.?.start, node.leaf.?.len);
            node.height = 1;
            return;
        }
        node.byte_len = nodeLen(node.left) + nodeLen(node.right);
        node.line_breaks = nodeBreaks(node.left) + nodeBreaks(node.right);
        const left_h = nodeHeight(node.left);
        const right_h = nodeHeight(node.right);
        node.height = 1 + @as(u8, @intCast(@max(left_h, right_h)));
    }

    fn rotateLeft(self: *Rope, node: *Node) *Node {
        const right = node.right.?;
        node.right = right.left;
        right.left = node;
        self.updateNode(node);
        self.updateNode(right);
        return right;
    }

    fn rotateRight(self: *Rope, node: *Node) *Node {
        const left = node.left.?;
        node.left = left.right;
        left.right = node;
        self.updateNode(node);
        self.updateNode(left);
        return left;
    }

    fn rebalance(self: *Rope, node: *Node) *Node {
        const left_h = nodeHeight(node.left);
        const right_h = nodeHeight(node.right);
        const balance = @as(i16, @intCast(left_h)) - @as(i16, @intCast(right_h));
        if (balance > 1) {
            const left = node.left.?;
            if (nodeHeight(left.left) < nodeHeight(left.right)) {
                node.left = self.rotateLeft(left);
            }
            return self.rotateRight(node);
        }
        if (balance < -1) {
            const right = node.right.?;
            if (nodeHeight(right.right) < nodeHeight(right.left)) {
                node.right = self.rotateRight(right);
            }
            return self.rotateLeft(node);
        }
        self.updateNode(node);
        return node;
    }

    fn join(self: *Rope, left: ?*Node, right: ?*Node) !?*Node {
        if (left == null) return right;
        if (right == null) return left;
        const left_h = nodeHeight(left);
        const right_h = nodeHeight(right);
        if (left_h > right_h + 1) {
            var left_node = left.?;
            left_node.right = try self.join(left_node.right, right);
            self.updateNode(left_node);
            return self.rebalance(left_node);
        }
        if (right_h > left_h + 1) {
            var right_node = right.?;
            right_node.left = try self.join(left, right_node.left);
            self.updateNode(right_node);
            return self.rebalance(right_node);
        }
        return self.createInternalNode(left, right);
    }

    const SplitPair = struct {
        left: ?*Node,
        right: ?*Node,
    };

    fn split(self: *Rope, node: ?*Node, offset: usize) !SplitPair {
        if (node == null) return .{ .left = null, .right = null };
        const n = node.?;
        if (offset == 0) return .{ .left = null, .right = n };
        if (offset >= n.byte_len) return .{ .left = n, .right = null };
        if (n.leaf != null) {
            const leaf = n.leaf.?;
            const left_len = offset;
            const right_len = leaf.len - offset;
            const left_node = if (left_len > 0) try self.createLeafNode(leaf.buffer, leaf.start, left_len) else null;
            const right_node = if (right_len > 0) try self.createLeafNode(leaf.buffer, leaf.start + offset, right_len) else null;
            self.allocator.destroy(n);
            return .{ .left = left_node, .right = right_node };
        }
        const left_len = nodeLen(n.left);
        if (offset < left_len) {
            const parts = try self.split(n.left, offset);
            n.left = parts.right;
            const new_right = self.rebalance(n);
            return .{ .left = parts.left, .right = new_right };
        }
        if (offset == left_len) {
            const left_node = n.left;
            const right_node = n.right;
            self.allocator.destroy(n);
            return .{ .left = left_node, .right = right_node };
        }
        const parts = try self.split(n.right, offset - left_len);
        n.right = parts.left;
        const new_left = self.rebalance(n);
        return .{ .left = new_left, .right = parts.right };
    }

    fn readNode(self: *Rope, node: ?*Node, start: usize, out: []u8, written: *usize) void {
        if (node == null) return;
        if (written.* >= out.len) return;
        const n = node.?;
        if (n.leaf != null) {
            if (start >= n.byte_len) return;
            const leaf = n.leaf.?;
            const data = switch (leaf.buffer) {
                .original => self.original,
                .add => self.add.items,
            };
            const slice = data[leaf.start .. leaf.start + leaf.len];
            const local_start = start;
            const readable = @min(slice.len - local_start, out.len - written.*);
            std.mem.copyForwards(u8, out[written.* .. written.* + readable], slice[local_start .. local_start + readable]);
            written.* += readable;
            return;
        }
        const left_len = nodeLen(n.left);
        if (start < left_len) {
            self.readNode(n.left, start, out, written);
            self.readNode(n.right, 0, out, written);
        } else {
            self.readNode(n.right, start - left_len, out, written);
        }
    }

    fn findNthNewline(self: *Rope, node: ?*Node, n: usize) usize {
        if (node == null) return 0;
        const cur = node.?;
        if (cur.leaf != null) {
            const leaf = cur.leaf.?;
            const data = switch (leaf.buffer) {
                .original => self.original,
                .add => self.add.items,
            };
            var count: usize = 0;
            const slice = data[leaf.start .. leaf.start + leaf.len];
            for (slice, 0..) |byte, idx| {
                if (byte == '\n') {
                    count += 1;
                    if (count == n) return idx;
                }
            }
            return cur.byte_len;
        }
        const left_breaks = nodeBreaks(cur.left);
        const left_len = nodeLen(cur.left);
        if (n <= left_breaks) {
            return self.findNthNewline(cur.left, n);
        }
        return left_len + self.findNthNewline(cur.right, n - left_breaks);
    }

    fn countLineBreaksBefore(self: *Rope, node: ?*Node, offset: usize) usize {
        if (node == null or offset == 0) return 0;
        const cur = node.?;
        if (cur.leaf != null) {
            const leaf = cur.leaf.?;
            const data = switch (leaf.buffer) {
                .original => self.original,
                .add => self.add.items,
            };
            const limit = @min(offset, leaf.len);
            var count: usize = 0;
            for (data[leaf.start .. leaf.start + limit]) |byte| {
                if (byte == '\n') count += 1;
            }
            return count;
        }
        const left_len = nodeLen(cur.left);
        if (offset <= left_len) {
            return self.countLineBreaksBefore(cur.left, offset);
        }
        return nodeBreaks(cur.left) + self.countLineBreaksBefore(cur.right, offset - left_len);
    }

    fn tryMergeUndoInsert(self: *Rope, pos: usize, data: []const u8) ?bool {
        if (self.undo_stack.items.len == 0) return null;
        const last_index = self.undo_stack.items.len - 1;
        const last = &self.undo_stack.items[last_index];
        if (last.kind != .insert) return null;
        if (last.text.len + data.len > max_undo_bytes) return null;
        if (last.pos + last.text.len != pos) return null;
        const new_len = last.text.len + data.len;
        var merged = self.allocator.realloc(last.text, new_len) catch return null;
        std.mem.copyForwards(u8, merged[last.text.len..new_len], data);
        last.text = merged;
        return true;
    }

    fn tryMergeUndoDelete(self: *Rope, pos: usize, deleted: []const u8) ?bool {
        if (self.undo_stack.items.len == 0) return null;
        const last_index = self.undo_stack.items.len - 1;
        const last = &self.undo_stack.items[last_index];
        if (last.kind != .delete) return null;
        if (last.text.len + deleted.len > max_undo_bytes) return null;
        if (pos == last.pos) {
            const new_len = last.text.len + deleted.len;
            var merged = self.allocator.realloc(last.text, new_len) catch return null;
            std.mem.copyForwards(u8, merged[last.text.len..new_len], deleted);
            last.text = merged;
            return true;
        }
        if (pos + deleted.len == last.pos) {
            const new_len = last.text.len + deleted.len;
            var merged = self.allocator.alloc(u8, new_len) catch return null;
            std.mem.copyForwards(u8, merged[0..deleted.len], deleted);
            std.mem.copyForwards(u8, merged[deleted.len..new_len], last.text);
            self.allocator.free(last.text);
            last.text = merged;
            last.pos = pos;
            return true;
        }
        return null;
    }

    fn markGroupDirty(self: *Rope) void {
        if (self.group_depth > 0) {
            self.group_dirty = true;
        }
    }
};

const UndoKind = enum(u8) {
    insert,
    delete,
    boundary,
};

const UndoOp = struct {
    kind: UndoKind,
    pos: usize,
    text: []u8,
    before_state: ?u64 = null,
    after_state: ?u64 = null,
};

fn undoCursorPos(op: UndoOp) usize {
    return switch (op.kind) {
        .insert => op.pos,
        .delete => op.pos + op.text.len,
        .boundary => op.pos,
    };
}

fn redoCursorPos(op: UndoOp) usize {
    return switch (op.kind) {
        .insert => op.pos + op.text.len,
        .delete => op.pos,
        .boundary => op.pos,
    };
}

fn createUndoOp(self: *Rope, kind: UndoKind, pos: usize, data: []const u8) !UndoOp {
    const copy = try self.allocator.alloc(u8, data.len);
    if (data.len > 0) {
        std.mem.copyForwards(u8, copy, data);
    }
    return UndoOp{ .kind = kind, .pos = pos, .text = copy };
}

fn freeUndoOp(self: *Rope, op: UndoOp) void {
    self.allocator.free(op.text);
}

fn freeUndoStack(self: *Rope, stack: *std.ArrayList(UndoOp)) void {
    for (stack.items) |op| {
        freeUndoOp(self, op);
    }
    stack.clearAndFree(self.allocator);
}

fn clearRedoStack(self: *Rope) !void {
    if (self.redo_stack.items.len == 0) return;
    freeUndoStack(self, &self.redo_stack);
}

fn trimUndoStack(self: *Rope) void {
    while (self.undo_stack.items.len > Rope.max_undo_ops) {
        const op = self.undo_stack.orderedRemove(0);
        freeUndoOp(self, op);
    }
}

fn clearHistory(self: *Rope) void {
    if (self.undo_stack.items.len > 0) {
        freeUndoStack(self, &self.undo_stack);
    }
    if (self.redo_stack.items.len > 0) {
        freeUndoStack(self, &self.redo_stack);
    }
}

fn boundaryOp(self: *Rope) !UndoOp {
    const empty = try self.allocator.alloc(u8, 0);
    return UndoOp{ .kind = .boundary, .pos = 0, .text = empty };
}

test "rope insert/read/delete and line starts" {
    const allocator = std.testing.allocator;
    var rope = try Rope.init(allocator, "hello\nworld");
    defer rope.deinit();

    try std.testing.expectEqual(@as(usize, 11), rope.totalLen());
    try std.testing.expectEqual(@as(usize, 2), rope.lineCount());
    try std.testing.expectEqual(@as(usize, 6), rope.lineStart(1));
    try std.testing.expectEqual(@as(usize, 0), rope.lineIndexForOffset(0));
    try std.testing.expectEqual(@as(usize, 0), rope.lineIndexForOffset(5));
    try std.testing.expectEqual(@as(usize, 1), rope.lineIndexForOffset(6));

    var out = try allocator.alloc(u8, rope.totalLen());
    defer allocator.free(out);
    const read_len = rope.readRange(0, out);
    try std.testing.expectEqual(@as(usize, 11), read_len);
    try std.testing.expectEqualStrings("hello\nworld", out);

    try rope.insert(6, "big ");
    try std.testing.expectEqual(@as(usize, 15), rope.totalLen());
    try std.testing.expectEqual(@as(usize, 2), rope.lineCount());
    out = try allocator.realloc(out, rope.totalLen());
    const read_len2 = rope.readRange(0, out);
    try std.testing.expectEqual(@as(usize, 15), read_len2);
    try std.testing.expectEqualStrings("hello\nbig world", out);

    try rope.deleteRange(5, 1); // remove newline
    try std.testing.expectEqual(@as(usize, 14), rope.totalLen());
    try std.testing.expectEqual(@as(usize, 1), rope.lineCount());
    out = try allocator.realloc(out, rope.totalLen());
    const read_len3 = rope.readRange(0, out);
    try std.testing.expectEqual(@as(usize, 14), read_len3);
    try std.testing.expectEqualStrings("hellobig world", out);

    try std.testing.expect((try rope.undo()).changed);
    const undo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(undo_text);
    try std.testing.expectEqualStrings("hello\nbig world", undo_text);
    try std.testing.expect((try rope.redo()).changed);
    const redo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(redo_text);
    try std.testing.expectEqualStrings("hellobig world", redo_text);
}

test "rope undo merges adjacent inserts" {
    const allocator = std.testing.allocator;
    var rope = try Rope.init(allocator, "abc");
    defer rope.deinit();

    try rope.insert(3, "d");
    try rope.insert(4, "e");
    const merged_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(merged_text);
    try std.testing.expectEqualStrings("abcde", merged_text);

    try std.testing.expect((try rope.undo()).changed);
    const undo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(undo_text);
    try std.testing.expectEqualStrings("abc", undo_text);
}

test "rope undo merges adjacent deletes (same position)" {
    const allocator = std.testing.allocator;
    var rope = try Rope.init(allocator, "abcdef");
    defer rope.deinit();

    try rope.deleteRange(3, 1); // delete 'd'
    try rope.deleteRange(3, 1); // delete 'e' (same pos)
    const after_delete = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(after_delete);
    try std.testing.expectEqualStrings("abcf", after_delete);

    try std.testing.expect((try rope.undo()).changed);
    const undo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(undo_text);
    try std.testing.expectEqualStrings("abcdef", undo_text);
}

test "rope undo merges adjacent deletes (backspace-style)" {
    const allocator = std.testing.allocator;
    var rope = try Rope.init(allocator, "abcdef");
    defer rope.deinit();

    try rope.deleteRange(2, 1); // delete 'c'
    try rope.deleteRange(1, 1); // delete 'b' (just before last delete)
    const after_delete = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(after_delete);
    try std.testing.expectEqualStrings("adef", after_delete);

    try std.testing.expect((try rope.undo()).changed);
    const undo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(undo_text);
    try std.testing.expectEqualStrings("abcdef", undo_text);
}

test "rope undo groups multiple edits" {
    const allocator = std.testing.allocator;
    var rope = try Rope.init(allocator, "hi");
    defer rope.deinit();

    rope.beginUndoGroup();
    try rope.insert(2, "!");
    try rope.insert(3, "!");
    try rope.endUndoGroup();

    const after_group = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(after_group);
    try std.testing.expectEqualStrings("hi!!", after_group);

    try std.testing.expect((try rope.undo()).changed);
    const undo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(undo_text);
    try std.testing.expectEqualStrings("hi", undo_text);

    try std.testing.expect((try rope.redo()).changed);
    const redo_text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(redo_text);
    try std.testing.expectEqualStrings("hi!!", redo_text);
}

test "rope owned original init avoids duplicate copy" {
    const allocator = std.testing.allocator;
    const original = try allocator.dupe(u8, "owned");
    var rope = try Rope.initOwnedOriginal(allocator, original);
    defer rope.deinit();

    try std.testing.expectEqual(@intFromPtr(original.ptr), @intFromPtr(rope.original.ptr));
    const text = try rope.readRangeAlloc(0, rope.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("owned", text);
}
