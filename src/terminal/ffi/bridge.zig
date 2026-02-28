const std = @import("std");
const terminal = @import("../core/terminal.zig");
const types = @import("../model/types.zig");

pub const Status = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    backend_error = 3,
};

pub const snapshot_abi_version: u32 = 1;
pub const event_abi_version: u32 = 1;

pub const EventKind = enum(c_int) {
    none = 0,
    title_changed = 1,
    cwd_changed = 2,
    clipboard_write = 3,
    child_exit = 4,
};

pub const ZideTerminalHandle = opaque {};

pub const CreateConfig = extern struct {
    rows: u16 = 24,
    cols: u16 = 80,
    scrollback_rows: u32 = 4000,
    cursor_shape: u8 = 0,
    cursor_blink: u8 = 1,
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Cell = extern struct {
    codepoint: u32,
    combining_len: u8,
    width: u8,
    height: u8,
    x: u8,
    y: u8,
    combining_0: u32,
    combining_1: u32,
    fg: Color,
    bg: Color,
    underline_color: Color,
    bold: u8,
    blink: u8,
    blink_fast: u8,
    reverse: u8,
    underline: u8,
    _padding0: [3]u8 = .{ 0, 0, 0 },
    link_id: u32,
};

pub const Snapshot = extern struct {
    abi_version: u32 = 0,
    struct_size: u32 = 0,
    rows: u32 = 0,
    cols: u32 = 0,
    generation: u64 = 0,
    cell_count: usize = 0,
    cells: ?[*]const Cell = null,
    cursor_row: u32 = 0,
    cursor_col: u32 = 0,
    cursor_visible: u8 = 0,
    cursor_shape: u8 = 0,
    cursor_blink: u8 = 0,
    alt_active: u8 = 0,
    screen_reverse: u8 = 0,
    has_damage: u8 = 0,
    damage_start_row: u32 = 0,
    damage_end_row: u32 = 0,
    damage_start_col: u32 = 0,
    damage_end_col: u32 = 0,
    title_ptr: ?[*]const u8 = null,
    title_len: usize = 0,
    cwd_ptr: ?[*]const u8 = null,
    cwd_len: usize = 0,
    _ctx: ?*anyopaque = null,
};

pub const KeyEvent = extern struct {
    key: u32,
    modifiers: u8,
};

pub const MouseEvent = extern struct {
    kind: u8,
    button: u8,
    row: u32,
    col: u32,
    pixel_x: u32,
    pixel_y: u32,
    has_pixel: u8,
    modifiers: u8,
    buttons_down: u8,
};

pub const Event = extern struct {
    kind: c_int,
    data_ptr: ?[*]const u8,
    data_len: usize,
    int0: i32,
    int1: i32,
};

pub const EventBuffer = extern struct {
    events: ?[*]const Event = null,
    count: usize = 0,
    _ctx: ?*anyopaque = null,
};

pub const StringBuffer = extern struct {
    ptr: ?[*]const u8 = null,
    len: usize = 0,
    _ctx: ?*anyopaque = null,
};

const PendingEvent = struct {
    kind: EventKind,
    data: []u8,
    int0: i32,
    int1: i32,
};

const Handle = struct {
    allocator: std.mem.Allocator,
    session: *terminal.TerminalSession,
    pending_events: std.ArrayList(PendingEvent),
    last_title: std.ArrayList(u8),
    last_cwd: std.ArrayList(u8),
    exit_delivered: bool,
};

const SnapshotOwner = struct {
    allocator: std.mem.Allocator,
    cells: []Cell,
    title: []u8,
    cwd: []u8,
};

const EventOwner = struct {
    allocator: std.mem.Allocator,
    events: []Event,
    payloads: [][]u8,
};

const StringOwner = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
};

pub fn create(config: ?*const CreateConfig, out_handle: *?*ZideTerminalHandle) Status {
    out_handle.* = null;
    const cfg = config orelse &CreateConfig{};
    if (cfg.rows == 0 or cfg.cols == 0) return .invalid_argument;

    const allocator = std.heap.c_allocator;
    const handle = allocator.create(Handle) catch return .out_of_memory;
    errdefer allocator.destroy(handle);

    const cursor_style = types.CursorStyle{
        .shape = switch (cfg.cursor_shape) {
            1 => .underline,
            2 => .bar,
            else => .block,
        },
        .blink = cfg.cursor_blink != 0,
    };
    const session = terminal.TerminalSession.initWithOptions(allocator, cfg.rows, cfg.cols, .{
        .scrollback_rows = cfg.scrollback_rows,
        .cursor_style = cursor_style,
    }) catch |err| return mapError(err);
    errdefer session.deinit();

    handle.* = .{
        .allocator = allocator,
        .session = session,
        .pending_events = .empty,
        .last_title = .empty,
        .last_cwd = .empty,
        .exit_delivered = false,
    };
    handle.last_title.appendSlice(allocator, session.currentTitle()) catch return .out_of_memory;
    handle.last_cwd.appendSlice(allocator, session.currentCwd()) catch return .out_of_memory;

    out_handle.* = toOpaque(handle);
    return .ok;
}

pub fn destroy(handle: ?*ZideTerminalHandle) void {
    const h = fromOpaque(handle) orelse return;
    var i: usize = 0;
    while (i < h.pending_events.items.len) : (i += 1) {
        h.allocator.free(h.pending_events.items[i].data);
    }
    h.pending_events.deinit(h.allocator);
    h.last_title.deinit(h.allocator);
    h.last_cwd.deinit(h.allocator);
    h.session.deinit();
    h.allocator.destroy(h);
}

pub fn start(handle: ?*ZideTerminalHandle, shell: ?[*:0]const u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const shell_slice: ?[:0]const u8 = if (shell) |value| std.mem.span(value) else null;
    h.session.startNoThreads(shell_slice) catch |err| return mapError(err);
    return .ok;
}

pub fn poll(handle: ?*ZideTerminalHandle) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    h.session.poll() catch |err| return mapError(err);
    return syncDerivedEvents(h);
}

pub fn resize(handle: ?*ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    if (rows == 0 or cols == 0) return .invalid_argument;
    h.session.resize(rows, cols) catch |err| return mapError(err);
    h.session.setCellSize(cell_width, cell_height);
    return .ok;
}

pub fn sendBytes(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const slice = ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.sendBytes(slice) catch |err| return mapError(err);
    return .ok;
}

pub fn sendText(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const slice = ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.sendText(slice) catch |err| return mapError(err);
    return .ok;
}

pub fn feedOutput(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const slice = ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.feedOutputBytes(slice);
    return syncDerivedEvents(h);
}

pub fn sendKey(handle: ?*ZideTerminalHandle, event: ?*const KeyEvent) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const key_event = event orelse return .invalid_argument;
    h.session.sendKey(key_event.key, key_event.modifiers) catch |err| return mapError(err);
    return .ok;
}

pub fn sendMouse(handle: ?*ZideTerminalHandle, event: ?*const MouseEvent) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const mouse_event = event orelse return .invalid_argument;
    const mapped = types.MouseEvent{
        .kind = switch (mouse_event.kind) {
            0 => .press,
            1 => .release,
            2 => .move,
            3 => .wheel,
            else => return .invalid_argument,
        },
        .button = switch (mouse_event.button) {
            0 => .none,
            1 => .left,
            2 => .middle,
            3 => .right,
            4 => .wheel_up,
            5 => .wheel_down,
            else => return .invalid_argument,
        },
        .row = mouse_event.row,
        .col = mouse_event.col,
        .pixel_x = if (mouse_event.has_pixel != 0) mouse_event.pixel_x else null,
        .pixel_y = if (mouse_event.has_pixel != 0) mouse_event.pixel_y else null,
        .mod = mouse_event.modifiers,
        .buttons_down = mouse_event.buttons_down,
    };
    _ = h.session.reportMouseEvent(mapped) catch |err| return mapError(err);
    return .ok;
}

pub fn snapshotAcquire(handle: ?*ZideTerminalHandle, out_snapshot: *Snapshot) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const snapshot = h.session.snapshot();
    const allocator = h.allocator;

    const owner = allocator.create(SnapshotOwner) catch return .out_of_memory;
    errdefer allocator.destroy(owner);

    const cell_count = snapshot.cells.len;
    const cells = allocator.alloc(Cell, cell_count) catch return .out_of_memory;
    errdefer allocator.free(cells);
    for (snapshot.cells, 0..) |cell, i| {
        cells[i] = mapCell(cell);
    }

    const title = allocator.dupe(u8, h.session.currentTitle()) catch return .out_of_memory;
    errdefer allocator.free(title);
    const cwd = allocator.dupe(u8, h.session.currentCwd()) catch return .out_of_memory;
    errdefer allocator.free(cwd);

    owner.* = .{
        .allocator = allocator,
        .cells = cells,
        .title = title,
        .cwd = cwd,
    };

    out_snapshot.* = .{
        .abi_version = snapshot_abi_version,
        .struct_size = @sizeOf(Snapshot),
        .rows = @intCast(snapshot.rows),
        .cols = @intCast(snapshot.cols),
        .generation = snapshot.generation,
        .cell_count = cell_count,
        .cells = if (cell_count == 0) null else cells.ptr,
        .cursor_row = @intCast(snapshot.cursor.row),
        .cursor_col = @intCast(snapshot.cursor.col),
        .cursor_visible = @intFromBool(snapshot.cursor_visible),
        .cursor_shape = switch (snapshot.cursor_style.shape) {
            .block => 0,
            .underline => 1,
            .bar => 2,
        },
        .cursor_blink = @intFromBool(snapshot.cursor_style.blink),
        .alt_active = @intFromBool(snapshot.alt_active),
        .screen_reverse = @intFromBool(snapshot.screen_reverse),
        .has_damage = @intFromBool(snapshot.damage.start_row <= snapshot.damage.end_row and snapshot.damage.start_col <= snapshot.damage.end_col),
        .damage_start_row = @intCast(snapshot.damage.start_row),
        .damage_end_row = @intCast(snapshot.damage.end_row),
        .damage_start_col = @intCast(snapshot.damage.start_col),
        .damage_end_col = @intCast(snapshot.damage.end_col),
        .title_ptr = if (title.len == 0) null else title.ptr,
        .title_len = title.len,
        .cwd_ptr = if (cwd.len == 0) null else cwd.ptr,
        .cwd_len = cwd.len,
        ._ctx = owner,
    };
    return .ok;
}

pub fn snapshotRelease(snapshot: *Snapshot) void {
    const owner = snapshotOwner(snapshot._ctx) orelse {
        snapshot.* = .{};
        return;
    };
    owner.allocator.free(owner.cells);
    owner.allocator.free(owner.title);
    owner.allocator.free(owner.cwd);
    owner.allocator.destroy(owner);
    snapshot.* = .{};
}

pub fn eventDrain(handle: ?*ZideTerminalHandle, out_events: *EventBuffer) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_events.* = .{};
    if (h.pending_events.items.len == 0) return .ok;

    const allocator = h.allocator;
    const owner = allocator.create(EventOwner) catch return .out_of_memory;
    errdefer allocator.destroy(owner);

    const events = allocator.alloc(Event, h.pending_events.items.len) catch return .out_of_memory;
    errdefer allocator.free(events);
    const payloads = allocator.alloc([]u8, h.pending_events.items.len) catch return .out_of_memory;
    errdefer allocator.free(payloads);

    for (h.pending_events.items, 0..) |pending, i| {
        payloads[i] = pending.data;
        events[i] = .{
            .kind = @intFromEnum(pending.kind),
            .data_ptr = if (pending.data.len == 0) null else pending.data.ptr,
            .data_len = pending.data.len,
            .int0 = pending.int0,
            .int1 = pending.int1,
        };
    }

    owner.* = .{
        .allocator = allocator,
        .events = events,
        .payloads = payloads,
    };
    h.pending_events.clearRetainingCapacity();

    out_events.* = .{
        .events = events.ptr,
        .count = events.len,
        ._ctx = owner,
    };
    return .ok;
}

pub fn eventsFree(events: *EventBuffer) void {
    const owner = eventOwner(events._ctx) orelse {
        events.* = .{};
        return;
    };
    for (owner.payloads) |payload| {
        owner.allocator.free(payload);
    }
    owner.allocator.free(owner.payloads);
    owner.allocator.free(owner.events);
    owner.allocator.destroy(owner);
    events.* = .{};
}

pub fn isAlive(handle: ?*ZideTerminalHandle) u8 {
    const h = fromOpaque(handle) orelse return 0;
    return @intFromBool(h.session.isAlive());
}

pub fn currentTitle(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    return stringFromSlice(h.allocator, h.session.currentTitle(), out_string);
}

pub fn currentCwd(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    return stringFromSlice(h.allocator, h.session.currentCwd(), out_string);
}

pub fn stringFree(string: *StringBuffer) void {
    const owner = stringOwner(string._ctx) orelse {
        string.* = .{};
        return;
    };
    owner.allocator.free(owner.bytes);
    owner.allocator.destroy(owner);
    string.* = .{};
}

pub fn childExitStatus(handle: ?*ZideTerminalHandle, out_code: *i32, out_has_status: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    if (h.session.childExitCode()) |code| {
        out_code.* = code;
        out_has_status.* = 1;
    } else {
        out_code.* = 0;
        out_has_status.* = 0;
    }
    return .ok;
}

pub fn snapshotAbiVersion() u32 {
    return snapshot_abi_version;
}

pub fn eventAbiVersion() u32 {
    return event_abi_version;
}

fn syncDerivedEvents(handle: *Handle) Status {
    syncStringEvent(handle, .title_changed, &handle.last_title, handle.session.currentTitle()) catch |err| return mapError(err);
    syncStringEvent(handle, .cwd_changed, &handle.last_cwd, handle.session.currentCwd()) catch |err| return mapError(err);
    if (handle.session.takeOscClipboard()) |clip| {
        const payload = if (clip.len > 0 and clip[clip.len - 1] == 0) clip[0 .. clip.len - 1] else clip;
        queueEvent(handle, .clipboard_write, payload, 0, 0) catch |err| return mapError(err);
    }
    if (!handle.exit_delivered) {
        if (handle.session.childExitCode()) |code| {
            queueEvent(handle, .child_exit, &[_]u8{}, code, 1) catch |err| return mapError(err);
            handle.exit_delivered = true;
        }
    }
    return .ok;
}

fn syncStringEvent(handle: *Handle, kind: EventKind, last: *std.ArrayList(u8), current: []const u8) !void {
    if (std.mem.eql(u8, last.items, current)) return;
    try queueEvent(handle, kind, current, 0, 0);
    last.clearRetainingCapacity();
    try last.appendSlice(handle.allocator, current);
}

fn queueEvent(handle: *Handle, kind: EventKind, data: []const u8, int0: i32, int1: i32) !void {
    const owned = try handle.allocator.dupe(u8, data);
    errdefer handle.allocator.free(owned);
    try handle.pending_events.append(handle.allocator, .{
        .kind = kind,
        .data = owned,
        .int0 = int0,
        .int1 = int1,
    });
}

fn mapCell(cell: types.Cell) Cell {
    return .{
        .codepoint = cell.codepoint,
        .combining_len = cell.combining_len,
        .width = cell.width,
        .height = cell.height,
        .x = cell.x,
        .y = cell.y,
        .combining_0 = cell.combining[0],
        .combining_1 = cell.combining[1],
        .fg = mapColor(cell.attrs.fg),
        .bg = mapColor(cell.attrs.bg),
        .underline_color = mapColor(cell.attrs.underline_color),
        .bold = @intFromBool(cell.attrs.bold),
        .blink = @intFromBool(cell.attrs.blink),
        .blink_fast = @intFromBool(cell.attrs.blink_fast),
        .reverse = @intFromBool(cell.attrs.reverse),
        .underline = @intFromBool(cell.attrs.underline),
        .link_id = cell.attrs.link_id,
    };
}

fn mapColor(color: types.Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn ptrLen(ptr: ?[*]const u8, len: usize) ?[]const u8 {
    if (len == 0) return &[_]u8{};
    const base = ptr orelse return null;
    return base[0..len];
}

fn fromOpaque(handle: ?*ZideTerminalHandle) ?*Handle {
    const value = handle orelse return null;
    return @ptrCast(@alignCast(value));
}

fn toOpaque(handle: *Handle) *ZideTerminalHandle {
    return @ptrCast(handle);
}

fn snapshotOwner(ctx: ?*anyopaque) ?*SnapshotOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

fn eventOwner(ctx: ?*anyopaque) ?*EventOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

fn mapError(err: anyerror) Status {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        else => .backend_error,
    };
}

fn stringFromSlice(allocator: std.mem.Allocator, value: []const u8, out_string: *StringBuffer) Status {
    out_string.* = .{};
    const owner = allocator.create(StringOwner) catch return .out_of_memory;
    errdefer allocator.destroy(owner);

    const bytes = allocator.dupe(u8, value) catch return .out_of_memory;
    errdefer allocator.free(bytes);

    owner.* = .{
        .allocator = allocator,
        .bytes = bytes,
    };
    out_string.* = .{
        .ptr = if (bytes.len == 0) null else bytes.ptr,
        .len = bytes.len,
        ._ctx = owner,
    };
    return .ok;
}

fn stringOwner(ctx: ?*anyopaque) ?*StringOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}
