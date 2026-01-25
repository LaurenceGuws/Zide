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

pub const InputBatch = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(InputEvent),

    pub fn init(allocator: std.mem.Allocator) InputBatch {
        return .{ .allocator = allocator, .events = .empty };
    }

    pub fn deinit(self: *InputBatch) void {
        self.events.deinit(self.allocator);
    }

    pub fn clear(self: *InputBatch) void {
        self.events.clearRetainingCapacity();
    }

    pub fn append(self: *InputBatch, event: InputEvent) !void {
        try self.events.append(self.allocator, event);
    }
};
