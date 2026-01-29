const std = @import("std");

pub const Modifiers = packed struct(u8) {
    shift: bool = false,
    alt: bool = false,
    ctrl: bool = false,
    super: bool = false,
    _pad: u4 = 0,

    pub fn isEmpty(self: Modifiers) bool {
        return !self.shift and !self.alt and !self.ctrl and !self.super;
    }
};

pub const MouseButton = enum(u8) {
    left,
    middle,
    right,
    back,
    forward,
    other,
};

pub const MouseEventKind = enum(u8) {
    move,
    down,
    up,
    drag,
};

pub const Key = enum(u16) {
    unknown = 0,
    enter,
    backspace,
    tab,
    escape,
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    insert,
    delete,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    space,
    minus,
    equal,
    left_bracket,
    right_bracket,
    backslash,
    semicolon,
    apostrophe,
    comma,
    period,
    slash,
    grave,
    kp_0,
    kp_1,
    kp_2,
    kp_3,
    kp_4,
    kp_5,
    kp_6,
    kp_7,
    kp_8,
    kp_9,
    kp_decimal,
    kp_divide,
    kp_multiply,
    kp_subtract,
    kp_add,
    kp_enter,
    kp_equal,
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,
    left_super,
    right_super,
};

pub const MousePos = struct {
    x: f32,
    y: f32,
};

pub const ScrollDelta = struct {
    x: f32,
    y: f32,
};

pub const KeyEvent = struct {
    key: Key,
    mods: Modifiers,
    repeated: bool,
    pressed: bool,
};

pub const TextEvent = struct {
    codepoint: u32,
};

pub const MouseEvent = struct {
    kind: MouseEventKind,
    button: ?MouseButton,
    pos: MousePos,
    mods: Modifiers,
};

pub const ScrollEvent = struct {
    delta: ScrollDelta,
    pos: MousePos,
    mods: Modifiers,
};

pub const ResizeEvent = struct {
    width: u32,
    height: u32,
};

pub const InputEvent = union(enum) {
    key: KeyEvent,
    text: TextEvent,
    mouse: MouseEvent,
    scroll: ScrollEvent,
    resize: ResizeEvent,
    focus: bool,
};

pub const InputSnapshot = struct {
    mouse_pos: MousePos,
    mods: Modifiers,
    mouse_down: [MOUSE_BUTTON_COUNT]bool,
    composing_text: []const u8,
    composing_cursor: i32,
    composing_selection_len: i32,
    composing_active: bool,

    pub fn init(mouse_pos: MousePos, mods: Modifiers) InputSnapshot {
        return .{
            .mouse_pos = mouse_pos,
            .mods = mods,
            .mouse_down = [_]bool{false} ** MOUSE_BUTTON_COUNT,
            .composing_text = &[_]u8{},
            .composing_cursor = 0,
            .composing_selection_len = 0,
            .composing_active = false,
        };
    }
};

pub const KEY_COUNT: usize = switch (@typeInfo(Key)) {
    .@"enum" => |info| info.fields.len,
    else => 0,
};
pub const MOUSE_BUTTON_COUNT: usize = switch (@typeInfo(MouseButton)) {
    .@"enum" => |info| info.fields.len,
    else => 0,
};

pub const InputBatch = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(InputEvent),
    composing_buffer: std.ArrayList(u8),
    composing_text: []const u8,
    composing_cursor: i32,
    composing_selection_len: i32,
    composing_active: bool,
    key_down: [KEY_COUNT]bool,
    key_pressed: [KEY_COUNT]bool,
    key_repeated: [KEY_COUNT]bool,
    key_released: [KEY_COUNT]bool,
    mouse_down: [MOUSE_BUTTON_COUNT]bool,
    mouse_pressed: [MOUSE_BUTTON_COUNT]bool,
    mouse_released: [MOUSE_BUTTON_COUNT]bool,
    mouse_pos: MousePos,
    mouse_pos_raw: MousePos,
    scroll: ScrollDelta,
    mods: Modifiers,

    pub fn init(allocator: std.mem.Allocator) InputBatch {
        return .{
            .allocator = allocator,
            .events = .empty,
            .composing_buffer = .empty,
            .composing_text = &[_]u8{},
            .composing_cursor = 0,
            .composing_selection_len = 0,
            .composing_active = false,
            .key_down = [_]bool{false} ** KEY_COUNT,
            .key_pressed = [_]bool{false} ** KEY_COUNT,
            .key_repeated = [_]bool{false} ** KEY_COUNT,
            .key_released = [_]bool{false} ** KEY_COUNT,
            .mouse_down = [_]bool{false} ** MOUSE_BUTTON_COUNT,
            .mouse_pressed = [_]bool{false} ** MOUSE_BUTTON_COUNT,
            .mouse_released = [_]bool{false} ** MOUSE_BUTTON_COUNT,
            .mouse_pos = .{ .x = 0, .y = 0 },
            .mouse_pos_raw = .{ .x = 0, .y = 0 },
            .scroll = .{ .x = 0, .y = 0 },
            .mods = .{},
        };
    }

    pub fn deinit(self: *InputBatch) void {
        self.events.deinit(self.allocator);
        self.composing_buffer.deinit(self.allocator);
    }

    pub fn clear(self: *InputBatch) void {
        self.events.clearRetainingCapacity();
        self.composing_buffer.clearRetainingCapacity();
        self.composing_text = &[_]u8{};
        self.composing_cursor = 0;
        self.composing_selection_len = 0;
        self.composing_active = false;
        self.key_down = [_]bool{false} ** KEY_COUNT;
        self.key_pressed = [_]bool{false} ** KEY_COUNT;
        self.key_repeated = [_]bool{false} ** KEY_COUNT;
        self.key_released = [_]bool{false} ** KEY_COUNT;
        self.mouse_down = [_]bool{false} ** MOUSE_BUTTON_COUNT;
        self.mouse_pressed = [_]bool{false} ** MOUSE_BUTTON_COUNT;
        self.mouse_released = [_]bool{false} ** MOUSE_BUTTON_COUNT;
        self.mouse_pos = .{ .x = 0, .y = 0 };
        self.mouse_pos_raw = .{ .x = 0, .y = 0 };
        self.scroll = .{ .x = 0, .y = 0 };
        self.mods = .{};
    }

    pub fn append(self: *InputBatch, event: InputEvent) !void {
        try self.events.append(self.allocator, event);
    }

    pub fn keyDown(self: *const InputBatch, key: Key) bool {
        return self.key_down[@intFromEnum(key)];
    }

    pub fn keyPressed(self: *const InputBatch, key: Key) bool {
        return self.key_pressed[@intFromEnum(key)];
    }

    pub fn keyRepeated(self: *const InputBatch, key: Key) bool {
        return self.key_repeated[@intFromEnum(key)];
    }

    pub fn keyReleased(self: *const InputBatch, key: Key) bool {
        return self.key_released[@intFromEnum(key)];
    }

    pub fn mouseDown(self: *const InputBatch, button: MouseButton) bool {
        return self.mouse_down[@intFromEnum(button)];
    }

    pub fn mousePressed(self: *const InputBatch, button: MouseButton) bool {
        return self.mouse_pressed[@intFromEnum(button)];
    }

    pub fn mouseReleased(self: *const InputBatch, button: MouseButton) bool {
        return self.mouse_released[@intFromEnum(button)];
    }

    pub fn snapshot(self: *const InputBatch) InputSnapshot {
        return .{
            .mouse_pos = self.mouse_pos,
            .mods = self.mods,
            .mouse_down = self.mouse_down,
            .composing_text = self.composing_text,
            .composing_cursor = self.composing_cursor,
            .composing_selection_len = self.composing_selection_len,
            .composing_active = self.composing_active,
        };
    }
};
