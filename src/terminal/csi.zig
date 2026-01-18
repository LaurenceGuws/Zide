pub const CsiAction = struct {
    final: u8,
    params: [8]i32,
    count: u8,
    leader: u8,
    private: bool,
};

pub const CsiParser = struct {
    params: [8]i32 = [_]i32{0} ** 8,
    count: u8 = 0,
    leader: u8 = 0,
    private: bool = false,
    in_param: bool = false,

    pub fn reset(self: *CsiParser) void {
        self.params = [_]i32{0} ** 8;
        self.count = 0;
        self.leader = 0;
        self.private = false;
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

        if (byte == ';') {
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

        // Ignore other bytes in CSI sequence.
        return null;
    }
};
