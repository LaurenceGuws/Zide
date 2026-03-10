const std = @import("std");
const terminal = @import("../core/terminal.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");

pub const Status = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    backend_error = 3,
};

pub const snapshot_abi_version: u32 = 1;
pub const event_abi_version: u32 = 3;
pub const scrollback_abi_version: u32 = 1;
pub const renderer_metadata_abi_version: u32 = 1;
pub const metadata_abi_version: u32 = 1;

pub const EventKind = enum(c_int) {
    none = 0,
    title_changed = 1,
    cwd_changed = 2,
    clipboard_write = 3,
    child_exit = 4,
    alive_changed = 5,
    redraw_ready = 6,
};

pub const GlyphClassFlags = enum(u32) {
    box = 1 << 0,
    box_rounded = 1 << 1,
    graph = 1 << 2,
    braille = 1 << 3,
    powerline = 1 << 4,
    powerline_rounded = 1 << 5,
};

pub const DamagePolicyFlags = enum(u32) {
    advisory_bounds = 1 << 0,
    full_redraw_safe_default = 1 << 1,
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

pub const ScrollbackBuffer = extern struct {
    abi_version: u32 = 0,
    struct_size: u32 = 0,
    total_rows: u32 = 0,
    start_row: u32 = 0,
    row_count: u32 = 0,
    cols: u32 = 0,
    cell_count: usize = 0,
    cells: ?[*]const Cell = null,
    _ctx: ?*anyopaque = null,
};

pub const Metadata = extern struct {
    abi_version: u32 = 0,
    struct_size: u32 = 0,
    scrollback_count: u32 = 0,
    scrollback_offset: u32 = 0,
    alive: u8 = 0,
    has_exit_code: u8 = 0,
    _padding0: [2]u8 = .{ 0, 0 },
    exit_code: i32 = 0,
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

pub const RendererMetadata = extern struct {
    abi_version: u32 = 0,
    struct_size: u32 = 0,
    codepoint: u32 = 0,
    glyph_class_flags: u32 = 0,
    damage_policy_flags: u32 = 0,
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

pub const PendingEvent = struct {
    kind: EventKind,
    data: []u8,
    int0: i32,
    int1: i32,
};

pub const Handle = struct {
    allocator: std.mem.Allocator,
    session: *terminal.TerminalSession,
    pending_events: std.ArrayList(PendingEvent),
    last_title: std.ArrayList(u8),
    last_cwd: std.ArrayList(u8),
    scratch_title: std.ArrayList(u8),
    scratch_cwd: std.ArrayList(u8),
    scratch_clipboard: std.ArrayList(u8),
    scratch_scrollback_cells: std.ArrayList(types.Cell),
    last_generation: u64,
    last_alive: bool,
    exit_delivered: bool,
};

pub const SnapshotOwner = struct {
    allocator: std.mem.Allocator,
    cells: []Cell,
    title: []u8,
    cwd: []u8,
};

pub const MetadataOwner = struct {
    allocator: std.mem.Allocator,
    title: []u8,
    cwd: []u8,
};

pub const ScrollbackOwner = struct {
    allocator: std.mem.Allocator,
    cells: []Cell,
};

pub const EventOwner = struct {
    allocator: std.mem.Allocator,
    events: []Event,
    payloads: [][]u8,
};

pub const StringOwner = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
};

pub fn ptrLen(ptr: ?[*]const u8, len: usize) ?[]const u8 {
    if (len == 0) return &[_]u8{};
    const base = ptr orelse return null;
    return base[0..len];
}

pub fn fromOpaque(handle: ?*ZideTerminalHandle) ?*Handle {
    const value = handle orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn toOpaque(handle: *Handle) *ZideTerminalHandle {
    return @ptrCast(handle);
}

pub fn snapshotOwner(ctx: ?*anyopaque) ?*SnapshotOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn metadataOwner(ctx: ?*anyopaque) ?*MetadataOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn eventOwner(ctx: ?*anyopaque) ?*EventOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn scrollbackOwner(ctx: ?*anyopaque) ?*ScrollbackOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn stringOwner(ctx: ?*anyopaque) ?*StringOwner {
    const value = ctx orelse return null;
    return @ptrCast(@alignCast(value));
}

pub fn mapError(err: anyerror) Status {
    const log = app_logger.logger("terminal.ffi");
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        else => blk: {
            log.logf(.warning, "backend error mapped status=backend_error err={s}", .{@errorName(err)});
            break :blk .backend_error;
        },
    };
}

pub fn stringFromSlice(allocator: std.mem.Allocator, value: []const u8, out_string: *StringBuffer) Status {
    const log = app_logger.logger("terminal.ffi");
    out_string.* = .{};
    const owner = allocator.create(StringOwner) catch |err| {
        log.logf(.warning, "string owner alloc failed len={d} err={s}", .{ value.len, @errorName(err) });
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const bytes = allocator.dupe(u8, value) catch |err| {
        log.logf(.warning, "string dup failed len={d} err={s}", .{ value.len, @errorName(err) });
        return .out_of_memory;
    };
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

pub fn stringFromOwnedSlice(allocator: std.mem.Allocator, value: []u8, out_string: *StringBuffer) Status {
    const log = app_logger.logger("terminal.ffi");
    out_string.* = .{};
    const owner = allocator.create(StringOwner) catch |err| {
        log.logf(.warning, "string owner alloc failed len={d} err={s}", .{ value.len, @errorName(err) });
        allocator.free(value);
        return .out_of_memory;
    };

    owner.* = .{
        .allocator = allocator,
        .bytes = value,
    };
    out_string.* = .{
        .ptr = if (value.len == 0) null else value.ptr,
        .len = value.len,
        ._ctx = owner,
    };
    return .ok;
}

pub fn queueEvent(handle: *Handle, kind: EventKind, data: []const u8, int0: i32, int1: i32) !void {
    const owned = try handle.allocator.dupe(u8, data);
    errdefer handle.allocator.free(owned);
    try handle.pending_events.append(handle.allocator, .{
        .kind = kind,
        .data = owned,
        .int0 = int0,
        .int1 = int1,
    });
}

pub fn syncStringEvent(handle: *Handle, kind: EventKind, last: *std.ArrayList(u8), current: []const u8) !void {
    if (std.mem.eql(u8, last.items, current)) return;
    try queueEvent(handle, kind, current, 0, 0);
    last.clearRetainingCapacity();
    try last.appendSlice(handle.allocator, current);
}

pub fn syncDerivedEvents(handle: *Handle) Status {
    const generation = handle.session.snapshot().generation;
    if (handle.last_generation != generation) {
        queueEvent(handle, .redraw_ready, &[_]u8{}, 0, 0) catch |err| return mapError(err);
        handle.last_generation = generation;
    }
    const metadata = handle.session.copyMetadata(handle.allocator, &handle.scratch_title, &handle.scratch_cwd) catch |err| return mapError(err);
    syncStringEvent(handle, .title_changed, &handle.last_title, metadata.title) catch |err| return mapError(err);
    syncStringEvent(handle, .cwd_changed, &handle.last_cwd, metadata.cwd) catch |err| return mapError(err);

    if (handle.session.takeOscClipboardCopy(handle.allocator, &handle.scratch_clipboard) catch |err| return mapError(err)) {
        const clip = handle.scratch_clipboard.items;
        const payload = if (clip.len > 0 and clip[clip.len - 1] == 0) clip[0 .. clip.len - 1] else clip;
        queueEvent(handle, .clipboard_write, payload, 0, 0) catch |err| return mapError(err);
    }
    if (handle.last_alive != metadata.alive) {
        queueEvent(handle, .alive_changed, &[_]u8{}, @intFromBool(metadata.alive), 0) catch |err| return mapError(err);
        handle.last_alive = metadata.alive;
    }
    if (!handle.exit_delivered) {
        if (metadata.exit_code) |code| {
            queueEvent(handle, .child_exit, &[_]u8{}, code, 1) catch |err| return mapError(err);
            handle.exit_delivered = true;
        }
    }
    return .ok;
}

pub fn classifyGlyphClassFlags(codepoint: u32) u32 {
    var flags: u32 = 0;
    if (isBoxGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.box);
    if (isRoundedBoxGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.box_rounded);
    if (isGraphGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.graph);
    if (isBrailleGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.braille);
    if (isPowerlineGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.powerline);
    if (isRoundedPowerlineGlyph(codepoint)) flags |= @intFromEnum(GlyphClassFlags.powerline_rounded);
    return flags;
}

fn isBoxGlyph(codepoint: u32) bool {
    return codepoint >= 0x2500 and codepoint <= 0x259F;
}

fn isRoundedBoxGlyph(codepoint: u32) bool {
    return switch (codepoint) {
        0x256D, 0x256E, 0x256F, 0x2570 => true,
        else => false,
    };
}

fn isGraphGlyph(codepoint: u32) bool {
    return (codepoint >= 0x2580 and codepoint <= 0x259F) or
        (codepoint >= 0x2800 and codepoint <= 0x28FF) or
        (codepoint >= 0x1FB00 and codepoint <= 0x1FBAF) or
        codepoint == 0x1FBE6 or
        codepoint == 0x1FBE7;
}

fn isBrailleGlyph(codepoint: u32) bool {
    return codepoint >= 0x2800 and codepoint <= 0x28FF;
}

fn isPowerlineGlyph(codepoint: u32) bool {
    return (codepoint >= 0xE0B0 and codepoint <= 0xE0BF) or
        codepoint == 0xE0D6 or
        codepoint == 0xE0D7;
}

fn isRoundedPowerlineGlyph(codepoint: u32) bool {
    return switch (codepoint) {
        0xE0B4, 0xE0B5, 0xE0B6, 0xE0B7 => true,
        else => false,
    };
}
