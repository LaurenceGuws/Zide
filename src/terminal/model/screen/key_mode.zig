pub const KeyModeStack = struct {
    len: usize,
    items: [key_mode_stack_max]u32,

    pub fn init() KeyModeStack {
        return .{
            .len = 1,
            .items = [_]u32{0} ** key_mode_stack_max,
        };
    }

    pub fn current(self: *const KeyModeStack) u32 {
        return self.items[self.len - 1];
    }

    pub fn push(self: *KeyModeStack, flags: u32) void {
        if (self.len >= key_mode_stack_max) {
            var idx: usize = 1;
            while (idx < key_mode_stack_max) : (idx += 1) {
                self.items[idx - 1] = self.items[idx];
            }
            self.len = key_mode_stack_max - 1;
        }
        self.items[self.len] = flags;
        self.len += 1;
    }

    pub fn pop(self: *KeyModeStack, count: usize) void {
        if (self.len <= 1) return;
        const max_pop = self.len - 1;
        const actual = @min(count, max_pop);
        self.len -= actual;
    }

    pub fn setCurrent(self: *KeyModeStack, flags: u32) void {
        self.items[self.len - 1] = flags;
    }
};

const key_mode_stack_max: usize = 32;
