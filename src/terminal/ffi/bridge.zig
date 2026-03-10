const std = @import("std");
const terminal = @import("../core/terminal.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");
const shared = @import("shared.zig");
const host_api = @import("host_api.zig");

pub const Status = shared.Status;
pub const snapshot_abi_version = shared.snapshot_abi_version;
pub const event_abi_version = shared.event_abi_version;
pub const scrollback_abi_version = shared.scrollback_abi_version;
pub const renderer_metadata_abi_version = shared.renderer_metadata_abi_version;
pub const metadata_abi_version = shared.metadata_abi_version;
pub const EventKind = shared.EventKind;
pub const GlyphClassFlags = shared.GlyphClassFlags;
pub const DamagePolicyFlags = shared.DamagePolicyFlags;
pub const ZideTerminalHandle = shared.ZideTerminalHandle;
pub const CreateConfig = shared.CreateConfig;
pub const Color = shared.Color;
pub const Cell = shared.Cell;
pub const Snapshot = shared.Snapshot;
pub const ScrollbackBuffer = shared.ScrollbackBuffer;
pub const Metadata = shared.Metadata;
pub const KeyEvent = shared.KeyEvent;
pub const MouseEvent = shared.MouseEvent;
pub const Event = shared.Event;
pub const RendererMetadata = shared.RendererMetadata;
pub const EventBuffer = shared.EventBuffer;
pub const StringBuffer = shared.StringBuffer;

const Handle = shared.Handle;
const SnapshotOwner = shared.SnapshotOwner;
const MetadataOwner = shared.MetadataOwner;
const ScrollbackOwner = shared.ScrollbackOwner;
const EventOwner = shared.EventOwner;

pub fn create(config: ?*const CreateConfig, out_handle: *?*ZideTerminalHandle) Status {
    const log = app_logger.logger("terminal.ffi");
    out_handle.* = null;
    const cfg = config orelse &CreateConfig{};
    if (cfg.rows == 0 or cfg.cols == 0) return .invalid_argument;

    const allocator = std.heap.c_allocator;
    const handle = allocator.create(Handle) catch |err| {
        log.logf(.warning, "create handle alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
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
    }) catch |err| return shared.mapError(err);
    errdefer session.deinit();

    handle.* = .{
        .allocator = allocator,
        .session = session,
        .pending_events = .empty,
        .last_title = .empty,
        .last_cwd = .empty,
        .scratch_title = .empty,
        .scratch_cwd = .empty,
        .scratch_clipboard = .empty,
        .scratch_scrollback_cells = .empty,
        .exit_delivered = false,
    };
    _ = session.copyMetadata(allocator, &handle.last_title, &handle.last_cwd) catch |err| {
        log.logf(.warning, "create metadata copy failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };

    out_handle.* = shared.toOpaque(handle);
    return .ok;
}

pub fn destroy(handle: ?*ZideTerminalHandle) void {
    const h = shared.fromOpaque(handle) orelse return;
    var i: usize = 0;
    while (i < h.pending_events.items.len) : (i += 1) {
        h.allocator.free(h.pending_events.items[i].data);
    }
    h.pending_events.deinit(h.allocator);
    h.last_title.deinit(h.allocator);
    h.last_cwd.deinit(h.allocator);
    h.scratch_title.deinit(h.allocator);
    h.scratch_cwd.deinit(h.allocator);
    h.scratch_clipboard.deinit(h.allocator);
    h.scratch_scrollback_cells.deinit(h.allocator);
    h.session.deinit();
    h.allocator.destroy(h);
}

pub fn start(handle: ?*ZideTerminalHandle, shell: ?[*:0]const u8) Status {
    return host_api.start(handle, shell);
}

pub fn poll(handle: ?*ZideTerminalHandle) Status {
    return host_api.poll(handle);
}

pub fn resize(handle: ?*ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) Status {
    return host_api.resize(handle, cols, rows, cell_width, cell_height);
}

pub fn sendBytes(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    return host_api.sendBytes(handle, bytes, len);
}

pub fn sendText(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    return host_api.sendText(handle, bytes, len);
}

pub fn feedOutput(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.feedOutputBytes(slice);
    return shared.syncDerivedEvents(h);
}

pub fn sendKey(handle: ?*ZideTerminalHandle, event: ?*const KeyEvent) Status {
    return host_api.sendKey(handle, event);
}

pub fn sendMouse(handle: ?*ZideTerminalHandle, event: ?*const MouseEvent) Status {
    return host_api.sendMouse(handle, event);
}

pub fn snapshotAcquire(handle: ?*ZideTerminalHandle, out_snapshot: *Snapshot) Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const snapshot = h.session.snapshot();
    const allocator = h.allocator;

    const owner = allocator.create(SnapshotOwner) catch |err| {
        log.logf(.warning, "snapshot owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const cell_count = snapshot.cells.len;
    const cells = allocator.alloc(Cell, cell_count) catch |err| {
        log.logf(.warning, "snapshot cells alloc failed count={d} err={s}", .{ cell_count, @errorName(err) });
        return .out_of_memory;
    };
    errdefer allocator.free(cells);
    for (snapshot.cells, 0..) |cell, i| {
        cells[i] = mapCell(cell);
    }

    const metadata = h.session.copyMetadata(allocator, &h.scratch_title, &h.scratch_cwd) catch |err| {
        log.logf(.warning, "snapshot metadata copy failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    const title = allocator.dupe(u8, metadata.title) catch |err| {
        log.logf(.warning, "snapshot title dup failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.free(title);
    const cwd = allocator.dupe(u8, metadata.cwd) catch |err| {
        log.logf(.warning, "snapshot cwd dup failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
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
    const owner = shared.snapshotOwner(snapshot._ctx) orelse {
        snapshot.* = .{};
        return;
    };
    owner.allocator.free(owner.cells);
    owner.allocator.free(owner.title);
    owner.allocator.free(owner.cwd);
    owner.allocator.destroy(owner);
    snapshot.* = .{};
}

pub fn scrollbackAcquire(handle: ?*ZideTerminalHandle, start_row: u32, max_rows: u32, out_buffer: *ScrollbackBuffer) Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    out_buffer.* = .{};
    const allocator = h.allocator;

    const range = h.session.copyScrollbackRange(
        allocator,
        @intCast(start_row),
        @intCast(max_rows),
        &h.scratch_scrollback_cells,
    ) catch |err| switch (err) {
        error.InvalidArgument => return .invalid_argument,
        else => {
            log.logf(.warning, "scrollback range export failed start={d} max={d} err={s}", .{ start_row, max_rows, @errorName(err) });
            return shared.mapError(err);
        },
    };

    const cell_count = range.row_count * range.cols;

    const owner = allocator.create(ScrollbackOwner) catch |err| {
        log.logf(.warning, "scrollback owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);
    const cells = allocator.alloc(Cell, cell_count) catch |err| {
        log.logf(.warning, "scrollback cells alloc failed count={d} err={s}", .{ cell_count, @errorName(err) });
        return .out_of_memory;
    };
    errdefer allocator.free(cells);

    for (h.scratch_scrollback_cells.items, 0..) |cell, idx| {
        cells[idx] = mapCell(cell);
    }

    owner.* = .{
        .allocator = allocator,
        .cells = cells,
    };

    out_buffer.* = .{
        .abi_version = scrollback_abi_version,
        .struct_size = @sizeOf(ScrollbackBuffer),
        .total_rows = std.math.cast(u32, range.total_rows) orelse std.math.maxInt(u32),
        .start_row = start_row,
        .row_count = std.math.cast(u32, range.row_count) orelse std.math.maxInt(u32),
        .cols = std.math.cast(u32, range.cols) orelse std.math.maxInt(u32),
        .cell_count = cell_count,
        .cells = if (cell_count == 0) null else cells.ptr,
        ._ctx = owner,
    };
    return .ok;
}

pub fn scrollbackRelease(scrollback: *ScrollbackBuffer) void {
    const owner = shared.scrollbackOwner(scrollback._ctx) orelse {
        scrollback.* = .{};
        return;
    };
    owner.allocator.free(owner.cells);
    owner.allocator.destroy(owner);
    scrollback.* = .{};
}

pub fn metadataAcquire(handle: ?*ZideTerminalHandle, out_metadata: *Metadata) Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    out_metadata.* = .{};

    const allocator = h.allocator;
    const owner = allocator.create(MetadataOwner) catch |err| {
        log.logf(.warning, "metadata owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const metadata = h.session.copyMetadata(allocator, &h.scratch_title, &h.scratch_cwd) catch |err| {
        log.logf(.warning, "metadata copy failed err={s}", .{@errorName(err)});
        return shared.mapError(err);
    };
    const title = allocator.dupe(u8, metadata.title) catch |err| {
        log.logf(.warning, "metadata title dup failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.free(title);
    const cwd = allocator.dupe(u8, metadata.cwd) catch |err| {
        log.logf(.warning, "metadata cwd dup failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.free(cwd);

    owner.* = .{
        .allocator = allocator,
        .title = title,
        .cwd = cwd,
    };
    out_metadata.* = .{
        .abi_version = metadata_abi_version,
        .struct_size = @sizeOf(Metadata),
        .scrollback_count = std.math.cast(u32, metadata.scrollback_count) orelse std.math.maxInt(u32),
        .scrollback_offset = std.math.cast(u32, metadata.scrollback_offset) orelse std.math.maxInt(u32),
        .alive = @intFromBool(metadata.alive),
        .has_exit_code = @intFromBool(metadata.exit_code != null),
        .exit_code = metadata.exit_code orelse 0,
        .title_ptr = if (title.len == 0) null else title.ptr,
        .title_len = title.len,
        .cwd_ptr = if (cwd.len == 0) null else cwd.ptr,
        .cwd_len = cwd.len,
        ._ctx = owner,
    };
    return .ok;
}

pub fn metadataRelease(metadata: *Metadata) void {
    const owner = shared.metadataOwner(metadata._ctx) orelse {
        metadata.* = .{};
        return;
    };
    owner.allocator.free(owner.title);
    owner.allocator.free(owner.cwd);
    owner.allocator.destroy(owner);
    metadata.* = .{};
}

pub fn eventDrain(handle: ?*ZideTerminalHandle, out_events: *EventBuffer) Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    out_events.* = .{};
    if (h.pending_events.items.len == 0) return .ok;

    const allocator = h.allocator;
    const owner = allocator.create(EventOwner) catch |err| {
        log.logf(.warning, "event owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const events = allocator.alloc(Event, h.pending_events.items.len) catch |err| {
        log.logf(.warning, "event array alloc failed count={d} err={s}", .{ h.pending_events.items.len, @errorName(err) });
        return .out_of_memory;
    };
    errdefer allocator.free(events);
    const payloads = allocator.alloc([]u8, h.pending_events.items.len) catch |err| {
        log.logf(.warning, "event payload array alloc failed count={d} err={s}", .{ h.pending_events.items.len, @errorName(err) });
        return .out_of_memory;
    };
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
    const owner = shared.eventOwner(events._ctx) orelse {
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
    return host_api.isAlive(handle);
}

pub fn selectionText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const text = (h.session.selectionPlainTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    }) orelse return shared.stringFromSlice(h.allocator, "", out_string);
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

pub fn scrollbackPlainText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const text = h.session.scrollbackPlainTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    };
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

pub fn scrollbackAnsiText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const text = h.session.scrollbackAnsiTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    };
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

pub fn stringFree(string: *StringBuffer) void {
    const owner = shared.stringOwner(string._ctx) orelse {
        string.* = .{};
        return;
    };
    owner.allocator.free(owner.bytes);
    owner.allocator.destroy(owner);
    string.* = .{};
}

pub fn childExitStatus(handle: ?*ZideTerminalHandle, out_code: *i32, out_has_status: *u8) Status {
    return host_api.childExitStatus(handle, out_code, out_has_status);
}

pub fn snapshotAbiVersion() u32 {
    return snapshot_abi_version;
}

pub fn eventAbiVersion() u32 {
    return event_abi_version;
}

pub fn scrollbackAbiVersion() u32 {
    return scrollback_abi_version;
}

pub fn rendererMetadataAbiVersion() u32 {
    return renderer_metadata_abi_version;
}

pub fn rendererMetadata(codepoint: u32, out_metadata: *RendererMetadata) Status {
    out_metadata.* = .{
        .abi_version = renderer_metadata_abi_version,
        .struct_size = @sizeOf(RendererMetadata),
        .codepoint = codepoint,
        .glyph_class_flags = shared.classifyGlyphClassFlags(codepoint),
        .damage_policy_flags = @intFromEnum(DamagePolicyFlags.advisory_bounds) |
            @intFromEnum(DamagePolicyFlags.full_redraw_safe_default),
    };
    return .ok;
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
