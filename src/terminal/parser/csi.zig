pub const max_params: usize = 16;
pub const max_intermediates: usize = 4;

pub const CsiAction = struct {
    final: u8,
    params: [max_params]i32,
    count: u8,
    leader: u8,
    private: bool,
    intermediates: [max_intermediates]u8,
    intermediates_len: u8,
};

pub const CsiParser = struct {
    params: [max_params]i32 = [_]i32{0} ** max_params,
    count: u8 = 0,
    leader: u8 = 0,
    private: bool = false,
    intermediates: [max_intermediates]u8 = [_]u8{0} ** max_intermediates,
    intermediates_len: u8 = 0,
    in_param: bool = false,

    pub fn reset(self: *CsiParser) void {
        self.params = [_]i32{0} ** max_params;
        self.count = 0;
        self.leader = 0;
        self.private = false;
        self.intermediates = [_]u8{0} ** max_intermediates;
        self.intermediates_len = 0;
        self.in_param = false;
    }

    pub fn feed(self: *CsiParser, byte: u8) ?CsiAction {
        // Final byte in 0x40..0x7E
        if (byte >= 0x40 and byte <= 0x7E) {
            const action = CsiAction{
                .final = byte,
                .params = self.params,
                .count = self.count,
                .leader = self.leader,
                .private = self.private,
                .intermediates = self.intermediates,
                .intermediates_len = self.intermediates_len,
            };
            self.reset();
            return action;
        }

        if (byte == '<' or byte == '>' or byte == '=' or byte == '?') {
            if (self.leader == 0) {
                self.leader = byte;
            }
            if (byte == '?') {
                self.private = true;
            }
            return null;
        }

        if (byte == ';' or byte == ':') {
            if (self.count < self.params.len) self.count += 1;
            self.in_param = false;
            return null;
        }

        if (byte >= '0' and byte <= '9') {
            const digit: i32 = @intCast(byte - '0');
            if (self.count >= self.params.len) return null;
            if (!self.in_param) {
                self.params[self.count] = digit;
                self.in_param = true;
            } else {
                self.params[self.count] = self.params[self.count] * 10 + digit;
            }
            return null;
        }

        // Intermediate bytes in 0x20..0x2F (e.g. '$', '!').
        if (byte >= 0x20 and byte <= 0x2F) {
            if (self.intermediates_len < self.intermediates.len) {
                self.intermediates[self.intermediates_len] = byte;
                self.intermediates_len += 1;
            }
            return null;
        }

        // Ignore other bytes in CSI sequence.
        return null;
    }
};

const std = @import("std");

fn feedCsiBytes(bytes: []const u8) !CsiAction {
    var parser = CsiParser{};
    for (bytes) |b| {
        if (parser.feed(b)) |action| return action;
    }
    return error.NoAction;
}

test "CSI parser captures ansi DECRQM intermediate $" {
    const action = try feedCsiBytes("20$p");
    try std.testing.expectEqual(@as(u8, 'p'), action.final);
    try std.testing.expectEqual(@as(u8, 0), action.leader);
    try std.testing.expect(!action.private);
    try std.testing.expectEqual(@as(u8, 1), action.intermediates_len);
    try std.testing.expectEqual(@as(u8, '$'), action.intermediates[0]);
    try std.testing.expectEqual(@as(i32, 20), action.params[0]);
}

test "CSI parser captures dec private DECRQM intermediate $" {
    const action = try feedCsiBytes("?1004$p");
    try std.testing.expectEqual(@as(u8, 'p'), action.final);
    try std.testing.expectEqual(@as(u8, '?'), action.leader);
    try std.testing.expect(action.private);
    try std.testing.expectEqual(@as(u8, 1), action.intermediates_len);
    try std.testing.expectEqual(@as(u8, '$'), action.intermediates[0]);
    try std.testing.expectEqual(@as(i32, 1004), action.params[0]);
}

test "CSI parser captures DECSTR intermediate !" {
    const action = try feedCsiBytes("!p");
    try std.testing.expectEqual(@as(u8, 'p'), action.final);
    try std.testing.expectEqual(@as(u8, 0), action.leader);
    try std.testing.expect(!action.private);
    try std.testing.expectEqual(@as(u8, 1), action.intermediates_len);
    try std.testing.expectEqual(@as(u8, '!'), action.intermediates[0]);
}

test "CSI parser preserves multiple intermediate bytes in order" {
    const action = try feedCsiBytes("#!p");
    try std.testing.expectEqual(@as(u8, 'p'), action.final);
    try std.testing.expectEqual(@as(u8, 2), action.intermediates_len);
    try std.testing.expectEqual(@as(u8, '#'), action.intermediates[0]);
    try std.testing.expectEqual(@as(u8, '!'), action.intermediates[1]);
}
