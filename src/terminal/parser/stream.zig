const utf8 = @import("utf8.zig");

pub const StreamEvent = union(enum) {
    codepoint: u21,
    control: u8,
    invalid,
};

pub const Stream = struct {
    decoder: utf8.Utf8Decoder = .{},

    pub fn reset(self: *Stream) void {
        self.decoder.reset();
    }

    pub fn feed(self: *Stream, byte: u8) ?StreamEvent {
        // C0 controls + DEL are emitted as control events when not in a UTF-8 sequence.
        if (self.decoder.needed == 0 and (byte < 0x20 or byte == 0x7f)) {
            return .{ .control = byte };
        }

        const res = self.decoder.feed(byte);
        return switch (res) {
            .codepoint => |cp| .{ .codepoint = cp },
            .invalid => .invalid,
            .incomplete => null,
        };
    }
};
