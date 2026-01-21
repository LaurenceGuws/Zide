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
    add: std.ArrayList(u8),
    const target_leaf_bytes: usize = 2048;

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*Rope {
        var rope = try allocator.create(Rope);
        rope.* = .{
            .allocator = allocator,
            .root = null,
            .original = try allocator.dupe(u8, initial),
            .add = .{},
        };
        if (initial.len > 0) {
            rope.root = try rope.createLeafNode(.original, 0, initial.len);
        }
        return rope;
    }

    pub fn deinit(self: *Rope) void {
        if (self.original.len > 0) {
            self.allocator.free(self.original);
        }
        self.add.deinit(self.allocator);
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

    pub fn deleteRange(self: *Rope, start: usize, len: usize) !void {
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
        _ = self;
        if (node.leaf != null) {
            node.left = null;
            node.right = null;
            node.byte_len = node.leaf.?.len;
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
};

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
}
