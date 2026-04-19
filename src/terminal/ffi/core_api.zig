//! VT core FFI: publication and query surface for hosts — snapshots, diffs,
//! redraw/generation, metadata, events, clipboard/selection strings, and handle
//! lifecycle. Session/transport entrypoints live in `../byo_pty_host.zig` (BYO-PTY
//! seam; terminal-owned, not under `ffi/`).
const std = @import("std");
const terminal_runtime = @import("../core/terminal_runtime.zig");
const publication_state = @import("../core/publication/publication_state.zig");
const terminal_publication = @import("../core/publication/terminal_publication.zig");
const terminal_core_feed = @import("../core/protocol/terminal_core_feed.zig");
const host_queries = @import("../core/session/host_queries.zig");
const session_interaction = @import("../core/session/interaction.zig");
const session_runtime = @import("../core/session/runtime.zig");
const types = @import("../model/types.zig");
const screen = @import("../model/screen.zig");
const app_logger = @import("../../app_logger.zig");
const shared = @import("shared.zig");
const renderer_metadata_mod = @import("renderer_metadata.zig");
const surface_contract = @import("../surface_contract.zig");

const Handle = shared.Handle;
const SnapshotOwner = shared.SnapshotOwner;
const SnapshotDiffOwner = shared.SnapshotDiffOwner;
const MetadataOwner = shared.MetadataOwner;
const ActivityOwner = shared.ActivityOwner;
const ScrollbackOwner = shared.ScrollbackOwner;
const EventOwner = shared.EventOwner;

fn currentCloseConfirmSignals(handle: *shared.Handle) shared.CloseConfirmSignals {
    const activity = host_queries.currentActivityMetadata(handle.shell);
    const foreground_process = @intFromBool(activity.foreground_process_present);
    const semantic_command = @intFromBool(activity.semantic_input_active or activity.semantic_output_active);
    const alt_screen = @intFromBool(handle.shell.core.isAltActive());
    const mouse_reporting = @intFromBool(session_interaction.mouseReportingEnabled(handle.shell));
    return .{
        .abi_version = shared.close_confirm_abi_version,
        .struct_size = @sizeOf(shared.CloseConfirmSignals),
        .foreground_process = foreground_process,
        .semantic_command = semantic_command,
        .alt_screen = alt_screen,
        .mouse_reporting = mouse_reporting,
        .any = @intFromBool(
            foreground_process != 0 or
                semantic_command != 0 or
                alt_screen != 0 or
                mouse_reporting != 0,
        ),
    };
}

fn currentPublishedGeneration(handle: *shared.Handle) u64 {
    return publication_state.publishedGeneration(handle.shell);
}

const SnapshotExportState = struct {
    rows: usize,
    cols: usize,
    generation: u64,
    cursor: terminal_publication.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    alt_active: bool,
    screen_reverse: bool,
    damage: screen.Damage,
};

const SnapshotExport = struct {
    cells: []shared.Cell,
};

const SnapshotDiffExportState = struct {
    generation: u64,
    base_generation: u64,
    rows: usize,
    cols: usize,
    cursor: terminal_publication.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    alt_active: bool,
    screen_reverse: bool,
    damage: screen.Damage,
    viewport_shift_rows: i32,
    viewport_shift_exposed_only: bool,
    full_refresh_required: bool,
};

fn copyPublishedSnapshotExport(
    handle: *shared.Handle,
    allocator: std.mem.Allocator,
    out_state: *SnapshotExportState,
) !SnapshotExport {
    handle.shell.lock();
    errdefer handle.shell.unlock();

    const cache = terminal_publication.renderCacheLocked(handle.shell, "ffi_snapshot");
    const cells = try allocator.alloc(shared.Cell, cache.cells.items.len);
    errdefer allocator.free(cells);
    for (cache.cells.items, 0..) |cell, i| {
        cells[i] = mapCell(cell);
    }

    out_state.* = .{
        .rows = cache.rows,
        .cols = cache.cols,
        .generation = cache.generation,
        .cursor = cache.cursor,
        .cursor_style = cache.cursor_style,
        .cursor_visible = cache.cursor_visible,
        .alt_active = cache.alt_active,
        .screen_reverse = cache.screen_reverse,
        .damage = cache.damage,
    };
    handle.shell.unlock();
    return .{
        .cells = cells,
    };
}

fn copyGranularSnapshotDiffExport(
    handle: *shared.Handle,
    allocator: std.mem.Allocator,
    base_generation: u64,
    out_state: *SnapshotDiffExportState,
) !?SnapshotDiffOwner {
    handle.shell.lock();
    defer handle.shell.unlock();

    const current = terminal_publication.renderCacheLocked(handle.shell, "ffi_snapshot_diff");
    const previous = terminal_publication.renderCacheForGenerationLocked(handle.shell, base_generation, "ffi_snapshot_diff") orelse {
        out_state.* = .{
            .generation = current.generation,
            .base_generation = base_generation,
            .rows = current.rows,
            .cols = current.cols,
            .cursor = current.cursor,
            .cursor_style = current.cursor_style,
            .cursor_visible = current.cursor_visible,
            .alt_active = current.alt_active,
            .screen_reverse = current.screen_reverse,
            .damage = current.damage,
            .viewport_shift_rows = current.viewport_shift_rows,
            .viewport_shift_exposed_only = current.viewport_shift_exposed_only,
            .full_refresh_required = true,
        };
        return null;
    };

    const granular_diff_ineligible =
        base_generation == 0 or
        base_generation != handle.last_acknowledged_generation or
        current.generation == base_generation or
        current.rows != previous.rows or
        current.cols != previous.cols or
        current.alt_active != previous.alt_active or
        current.visible_history_generation != previous.visible_history_generation or
        current.scroll_offset != previous.scroll_offset or
        current.viewport_shift_rows != 0 or
        current.dirty == .full;

    if (granular_diff_ineligible) {
        out_state.* = .{
            .generation = current.generation,
            .base_generation = base_generation,
            .rows = current.rows,
            .cols = current.cols,
            .cursor = current.cursor,
            .cursor_style = current.cursor_style,
            .cursor_visible = current.cursor_visible,
            .alt_active = current.alt_active,
            .screen_reverse = current.screen_reverse,
            .damage = current.damage,
            .viewport_shift_rows = current.viewport_shift_rows,
            .viewport_shift_exposed_only = current.viewport_shift_exposed_only,
            .full_refresh_required = true,
        };
        return null;
    }

    var row_count: usize = 0;
    var span_count: usize = 0;
    var cell_count: usize = 0;
    for (current.dirty_rows.items, 0..) |dirty, row_idx| {
        if (!dirty) continue;
        if (current.row_dirty_span_overflow.items[row_idx]) {
            out_state.* = .{
                .generation = current.generation,
                .base_generation = base_generation,
                .rows = current.rows,
                .cols = current.cols,
                .cursor = current.cursor,
                .cursor_style = current.cursor_style,
                .cursor_visible = current.cursor_visible,
                .alt_active = current.alt_active,
                .screen_reverse = current.screen_reverse,
                .damage = current.damage,
                .viewport_shift_rows = current.viewport_shift_rows,
                .viewport_shift_exposed_only = current.viewport_shift_exposed_only,
                .full_refresh_required = true,
            };
            return null;
        }
        row_count += 1;
        const row_span_count = current.row_dirty_span_counts.items[row_idx];
        span_count += row_span_count;
        var span_idx: usize = 0;
        while (span_idx < row_span_count) : (span_idx += 1) {
            const span = current.row_dirty_spans.items[row_idx][span_idx];
            cell_count += @as(usize, span.end - span.start) + 1;
        }
    }

    if (cell_count == 0) {
        const empty_rows = try allocator.alloc(shared.SnapshotDiffRow, 0);
        errdefer allocator.free(empty_rows);
        const empty_spans = try allocator.alloc(shared.SnapshotDiffSpan, 0);
        errdefer allocator.free(empty_spans);
        const empty_cells = try allocator.alloc(shared.Cell, 0);
        errdefer allocator.free(empty_cells);
        out_state.* = .{
            .generation = current.generation,
            .base_generation = base_generation,
            .rows = current.rows,
            .cols = current.cols,
            .cursor = current.cursor,
            .cursor_style = current.cursor_style,
            .cursor_visible = current.cursor_visible,
            .alt_active = current.alt_active,
            .screen_reverse = current.screen_reverse,
            .damage = current.damage,
            .viewport_shift_rows = 0,
            .viewport_shift_exposed_only = false,
            .full_refresh_required = false,
        };
        return .{
            .allocator = allocator,
            .rows = empty_rows,
            .spans = empty_spans,
            .cells = empty_cells,
        };
    }

    if (cell_count >= current.cells.items.len) {
        out_state.* = .{
            .generation = current.generation,
            .base_generation = base_generation,
            .rows = current.rows,
            .cols = current.cols,
            .cursor = current.cursor,
            .cursor_style = current.cursor_style,
            .cursor_visible = current.cursor_visible,
            .alt_active = current.alt_active,
            .screen_reverse = current.screen_reverse,
            .damage = current.damage,
            .viewport_shift_rows = current.viewport_shift_rows,
            .viewport_shift_exposed_only = current.viewport_shift_exposed_only,
            .full_refresh_required = true,
        };
        return null;
    }

    const rows = try allocator.alloc(shared.SnapshotDiffRow, row_count);
    errdefer allocator.free(rows);
    const spans = try allocator.alloc(shared.SnapshotDiffSpan, span_count);
    errdefer allocator.free(spans);
    const cells = try allocator.alloc(shared.Cell, cell_count);
    errdefer allocator.free(cells);

    var out_row_idx: usize = 0;
    var out_span_idx: usize = 0;
    var out_cell_idx: usize = 0;
    for (current.dirty_rows.items, 0..) |dirty, row_idx| {
        if (!dirty) continue;
        const row_span_count = current.row_dirty_span_counts.items[row_idx];
        const row_first_span = out_span_idx;
        const row_first_cell = out_cell_idx;
        var row_cell_count: usize = 0;
        var span_idx: usize = 0;
        while (span_idx < row_span_count) : (span_idx += 1) {
            const span = current.row_dirty_spans.items[row_idx][span_idx];
            spans[out_span_idx] = .{
                .start_col = span.start,
                .end_col = span.end,
            };
            out_span_idx += 1;
            var col: usize = span.start;
            while (col <= span.end) : (col += 1) {
                const idx = row_idx * current.cols + col;
                cells[out_cell_idx] = mapCell(current.cells.items[idx]);
                out_cell_idx += 1;
                row_cell_count += 1;
            }
        }
        rows[out_row_idx] = .{
            .row = @intCast(row_idx),
            .span_count = row_span_count,
            .span_overflow = 0,
            .reserved0 = 0,
            .first_span_index = @intCast(row_first_span),
            .first_cell_index = @intCast(row_first_cell),
            .cell_count = @intCast(row_cell_count),
        };
        out_row_idx += 1;
    }

    out_state.* = .{
        .generation = current.generation,
        .base_generation = base_generation,
        .rows = current.rows,
        .cols = current.cols,
        .cursor = current.cursor,
        .cursor_style = current.cursor_style,
        .cursor_visible = current.cursor_visible,
        .alt_active = current.alt_active,
        .screen_reverse = current.screen_reverse,
        .damage = current.damage,
        .viewport_shift_rows = 0,
        .viewport_shift_exposed_only = false,
        .full_refresh_required = false,
    };
    return .{
        .allocator = allocator,
        .rows = rows,
        .spans = spans,
        .cells = cells,
    };
}

/// Allocates a terminal handle and shell; wires external transport. Use
/// `byo_pty_host.start` / `poll` for the BYO-PTY session loop when applicable.
pub fn create(config: ?*const shared.CreateConfig, out_handle: *?*shared.ZideTerminalHandle) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    out_handle.* = null;
    const cfg = config orelse &shared.CreateConfig{};
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
    const shell = terminal_runtime.initWithOptions(allocator, cfg.rows, cfg.cols, .{
        .scrollback_rows = cfg.scrollback_rows,
        .cursor_style = cursor_style,
    }) catch |err| return shared.mapError(err);
    errdefer shell.deinit();

    handle.* = .{
        .allocator = allocator,
        .shell = shell,
        .destroying = std.atomic.Value(bool).init(false),
        .pending_events = .empty,
        .last_title = .empty,
        .last_cwd = .empty,
        .scratch_title = .empty,
        .scratch_cwd = .empty,
        .scratch_clipboard = .empty,
        .pending_clipboard_write = .empty,
        .clipboard_write_pending = false,
        .scratch_scrollback_cells = .empty,
        .last_generation = 0,
        .last_acknowledged_generation = 0,
        .last_alive = true,
        .exit_delivered = false,
    };
    session_runtime.attachExternalTransport(shell);
    handle.last_generation = publication_state.publishedGeneration(shell);
    _ = host_queries.copyTerminalMetadata(shell, allocator, &handle.last_title, &handle.last_cwd) catch |err| {
        log.logf(.warning, "create metadata copy failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    handle.last_alive = host_queries.currentRuntimeMetadata(shell).alive;

    out_handle.* = shared.toOpaque(handle);
    return .ok;
}

/// Records host presentation completion for `generation` (`surface_contract.ffiPresentAckGenerationAdmissible`).
pub fn presentAck(handle: ?*shared.ZideTerminalHandle, generation: u64) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const published_generation = currentPublishedGeneration(h);
    if (!surface_contract.ffiPresentAckGenerationAdmissible(generation, published_generation, h.last_acknowledged_generation)) {
        return .invalid_argument;
    }
    _ = terminal_publication.acknowledgePresentedGeneration(h.shell, generation);
    h.last_acknowledged_generation = generation;
    return .ok;
}

/// Last generation the host reported as presented (`presentAck`).
pub fn acknowledgedGeneration(handle: ?*shared.ZideTerminalHandle, out_generation: *u64) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    out_generation.* = h.last_acknowledged_generation;
    return .ok;
}

/// Current publication generation from the terminal core (VT core truth).
pub fn publishedGeneration(handle: ?*shared.ZideTerminalHandle, out_generation: *u64) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    out_generation.* = currentPublishedGeneration(h);
    return .ok;
}

/// Returns published vs acknowledged generations and whether a redraw is pending (`ffiRedrawStateFill`).
pub fn redrawState(handle: ?*shared.ZideTerminalHandle, out_state: *shared.RedrawState) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const published_generation = currentPublishedGeneration(h);
    const acknowledged_generation = h.last_acknowledged_generation;
    surface_contract.ffiRedrawStateFill(published_generation, acknowledged_generation, out_state);
    return .ok;
}

/// Shell/input close-confirm signals for the host (VT core publication).
pub fn closeConfirmSignals(handle: ?*shared.ZideTerminalHandle, out_signals: *shared.CloseConfirmSignals) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    out_signals.* = currentCloseConfirmSignals(h);
    return .ok;
}

/// Non-zero if published generation differs from last acknowledged (`ffiNeedsRedrawU8`).
pub fn needsRedraw(handle: ?*shared.ZideTerminalHandle) u8 {
    const h = shared.fromOpaqueActive(handle) orelse return 0;
    const published_generation = currentPublishedGeneration(h);
    return surface_contract.ffiNeedsRedrawU8(published_generation, h.last_acknowledged_generation);
}

/// Tears down the handle, shell, and pending FFI-owned buffers.
pub fn destroy(handle: ?*shared.ZideTerminalHandle) void {
    const h = shared.fromOpaque(handle) orelse return;
    h.destroying.store(true, .release);
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
    h.pending_clipboard_write.deinit(h.allocator);
    h.scratch_scrollback_cells.deinit(h.allocator);
    h.shell.deinit();
    h.allocator.destroy(h);
}

/// Feeds process output bytes into the engine (external transport or direct feed path).
pub fn feedOutput(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    if (session_runtime.enqueueExternalBytes(h.shell, slice) catch |err| return shared.mapError(err)) {
        session_runtime.poll(h.shell) catch |err| return shared.mapError(err);
    } else {
        terminal_core_feed.feedOutputBytes(h.shell, slice);
    }
    return shared.syncDerivedEvents(h);
}

/// Closes the external byte transport when the host is driving I/O (BYO path).
pub fn closeInput(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (!session_runtime.closeExternalTransport(h.shell)) return .invalid_argument;
    return shared.syncDerivedEvents(h);
}

/// Takes pending outgoing bytes from external transport into `out_buffer` (host must `pendingInputRelease`).
pub fn pendingInputAcquire(handle: ?*shared.ZideTerminalHandle, out_buffer: *shared.ByteBuffer) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const bytes = session_runtime.takeExternalOutgoingBytes(h.shell, h.allocator) catch |err| return shared.mapError(err);
    const slice = bytes orelse return .invalid_argument;
    return shared.byteBufferFromOwnedSlice(h.allocator, slice, out_buffer);
}

/// Frees a buffer from `pendingInputAcquire`.
pub fn pendingInputRelease(out_buffer: *shared.ByteBuffer) void {
    shared.byteBufferFree(out_buffer);
}

/// Copies the current published terminal grid into `out_snapshot` (VT core); host frees via `snapshotRelease`.
pub fn snapshotAcquire(handle: ?*shared.ZideTerminalHandle, request: ?*const shared.SnapshotRequest, out_snapshot: *shared.Snapshot) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const req = request orelse return .invalid_argument;
    if (req.abi_version != shared.snapshot_abi_version) return .invalid_argument;
    if (req.struct_size != @sizeOf(shared.SnapshotRequest)) return .invalid_argument;
    const allocator = h.allocator;

    const owner = allocator.create(SnapshotOwner) catch |err| {
        log.logf(.warning, "snapshot owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    var state: SnapshotExportState = undefined;
    const exported = copyPublishedSnapshotExport(h, allocator, &state) catch |err| {
        log.logf(.warning, "snapshot export failed err={s}", .{@errorName(err)});
        return shared.mapError(err);
    };
    errdefer allocator.free(exported.cells);
    const cell_count = exported.cells.len;

    owner.* = .{
        .allocator = allocator,
        .cells = exported.cells,
    };

    out_snapshot.* = .{
        .abi_version = shared.snapshot_abi_version,
        .struct_size = @sizeOf(shared.Snapshot),
        .rows = @intCast(state.rows),
        .cols = @intCast(state.cols),
        .generation = state.generation,
        .cell_count = cell_count,
        .cells = if (cell_count == 0) null else exported.cells.ptr,
        .cursor_row = @intCast(state.cursor.row),
        .cursor_col = @intCast(state.cursor.col),
        .cursor_visible = @intFromBool(state.cursor_visible),
        .cursor_shape = switch (state.cursor_style.shape) {
            .block => 0,
            .underline => 1,
            .bar => 2,
        },
        .cursor_blink = @intFromBool(state.cursor_style.blink),
        .alt_active = @intFromBool(state.alt_active),
        .screen_reverse = @intFromBool(state.screen_reverse),
        .has_damage = @intFromBool(state.damage.start_row <= state.damage.end_row and state.damage.start_col <= state.damage.end_col),
        .damage_start_row = @intCast(state.damage.start_row),
        .damage_end_row = @intCast(state.damage.end_row),
        .damage_start_col = @intCast(state.damage.start_col),
        .damage_end_col = @intCast(state.damage.end_col),
        ._ctx = owner,
    };
    return .ok;
}

/// Frees memory owned by a prior `snapshotAcquire`.
pub fn snapshotRelease(snapshot: *shared.Snapshot) void {
    const owner = shared.snapshotOwner(snapshot._ctx) orelse {
        snapshot.* = .{};
        return;
    };
    owner.allocator.free(owner.cells);
    owner.allocator.destroy(owner);
    snapshot.* = .{};
}

/// Exports an incremental or full cell diff vs `base_generation` (VT core); free with `snapshotDiffRelease`.
pub fn snapshotDiffAcquire(handle: ?*shared.ZideTerminalHandle, request: ?*const shared.SnapshotDiffRequest, out_diff: *shared.SnapshotDiff) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const req = request orelse return .invalid_argument;
    out_diff.* = .{};
    if (req.abi_version != shared.snapshot_diff_abi_version) return .invalid_argument;
    if (req.struct_size != @sizeOf(shared.SnapshotDiffRequest)) return .invalid_argument;

    const allocator = h.allocator;
    const owner = allocator.create(SnapshotDiffOwner) catch |err| {
        log.logf(.warning, "snapshot diff owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    var state: SnapshotDiffExportState = undefined;
    const granular = copyGranularSnapshotDiffExport(h, allocator, req.base_generation, &state) catch |err| {
        log.logf(.warning, "snapshot diff granular export failed err={s}", .{@errorName(err)});
        return shared.mapError(err);
    };

    if (granular) |exported| {
        owner.* = exported;
        out_diff.* = .{
            .abi_version = shared.snapshot_diff_abi_version,
            .struct_size = @sizeOf(shared.SnapshotDiff),
            .generation = state.generation,
            .base_generation = state.base_generation,
            .rows = @intCast(state.rows),
            .cols = @intCast(state.cols),
            .cursor_row = @intCast(state.cursor.row),
            .cursor_col = @intCast(state.cursor.col),
            .full_refresh_required = 0,
            .cursor_visible = @intFromBool(state.cursor_visible),
            .cursor_shape = switch (state.cursor_style.shape) {
                .underline => 1,
                .bar => 2,
                else => 0,
            },
            .cursor_blink = @intFromBool(state.cursor_style.blink),
            .alt_active = @intFromBool(state.alt_active),
            .screen_reverse = @intFromBool(state.screen_reverse),
            .has_damage = @intFromBool(state.damage.start_row <= state.damage.end_row and state.damage.start_col <= state.damage.end_col),
            .damage_start_row = @intCast(state.damage.start_row),
            .damage_end_row = @intCast(state.damage.end_row),
            .damage_start_col = @intCast(state.damage.start_col),
            .damage_end_col = @intCast(state.damage.end_col),
            .viewport_shift_rows = 0,
            .viewport_shift_exposed_only = 0,
            .rows_ptr = if (exported.rows.len == 0) null else exported.rows.ptr,
            .row_count = exported.rows.len,
            .spans_ptr = if (exported.spans.len == 0) null else exported.spans.ptr,
            .span_count = exported.spans.len,
            .cells_ptr = if (exported.cells.len == 0) null else exported.cells.ptr,
            .cell_count = exported.cells.len,
            ._ctx = owner,
        };
        return .ok;
    }

    var snapshot_state: SnapshotExportState = undefined;
    const full_published_cells = copyPublishedSnapshotExport(h, allocator, &snapshot_state) catch |err| {
        log.logf(.warning, "snapshot diff full published cells export failed err={s}", .{@errorName(err)});
        return shared.mapError(err);
    };
    errdefer allocator.free(full_published_cells.cells);
    const empty_rows = allocator.alloc(shared.SnapshotDiffRow, 0) catch |err| {
        log.logf(.warning, "snapshot diff empty rows alloc failed err={s}", .{@errorName(err)});
        allocator.free(full_published_cells.cells);
        return .out_of_memory;
    };
    errdefer allocator.free(empty_rows);
    const empty_spans = allocator.alloc(shared.SnapshotDiffSpan, 0) catch |err| {
        log.logf(.warning, "snapshot diff empty spans alloc failed err={s}", .{@errorName(err)});
        allocator.free(full_published_cells.cells);
        allocator.free(empty_rows);
        return .out_of_memory;
    };
    errdefer allocator.free(empty_spans);

    owner.* = .{
        .allocator = allocator,
        .rows = empty_rows,
        .spans = empty_spans,
        .cells = full_published_cells.cells,
    };
    out_diff.* = .{
        .abi_version = shared.snapshot_diff_abi_version,
        .struct_size = @sizeOf(shared.SnapshotDiff),
        .generation = snapshot_state.generation,
        .base_generation = req.base_generation,
        .rows = @intCast(snapshot_state.rows),
        .cols = @intCast(snapshot_state.cols),
        .cursor_row = @intCast(snapshot_state.cursor.row),
        .cursor_col = @intCast(snapshot_state.cursor.col),
        .full_refresh_required = 1,
        .cursor_visible = @intFromBool(snapshot_state.cursor_visible),
        .cursor_shape = switch (snapshot_state.cursor_style.shape) {
            .underline => 1,
            .bar => 2,
            else => 0,
        },
        .cursor_blink = @intFromBool(snapshot_state.cursor_style.blink),
        .alt_active = @intFromBool(snapshot_state.alt_active),
        .screen_reverse = @intFromBool(snapshot_state.screen_reverse),
        .has_damage = @intFromBool(snapshot_state.damage.start_row <= snapshot_state.damage.end_row and snapshot_state.damage.start_col <= snapshot_state.damage.end_col),
        .damage_start_row = @intCast(snapshot_state.damage.start_row),
        .damage_end_row = @intCast(snapshot_state.damage.end_row),
        .damage_start_col = @intCast(snapshot_state.damage.start_col),
        .damage_end_col = @intCast(snapshot_state.damage.end_col),
        .viewport_shift_rows = 0,
        .viewport_shift_exposed_only = 0,
        .rows_ptr = null,
        .row_count = 0,
        .spans_ptr = null,
        .span_count = 0,
        .cells_ptr = if (full_published_cells.cells.len == 0) null else full_published_cells.cells.ptr,
        .cell_count = full_published_cells.cells.len,
        ._ctx = owner,
    };
    return .ok;
}

/// Frees memory owned by a prior `snapshotDiffAcquire`.
pub fn snapshotDiffRelease(diff: *shared.SnapshotDiff) void {
    const owner = shared.snapshotDiffOwner(diff._ctx) orelse {
        diff.* = .{};
        return;
    };
    owner.allocator.free(owner.rows);
    owner.allocator.free(owner.spans);
    owner.allocator.free(owner.cells);
    owner.allocator.destroy(owner);
    diff.* = .{};
}

/// Copies a scrollback cell range into `out_buffer` (VT core); free with `scrollbackRelease`.
pub fn scrollbackAcquire(handle: ?*shared.ZideTerminalHandle, start_row: u32, max_rows: u32, out_buffer: *shared.ScrollbackBuffer) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    out_buffer.* = .{};
    const allocator = h.allocator;

    const range = h.shell.core.copyScrollbackRange(
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
    const cells = allocator.alloc(shared.Cell, cell_count) catch |err| {
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
        .abi_version = shared.scrollback_abi_version,
        .struct_size = @sizeOf(shared.ScrollbackBuffer),
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

/// Frees memory from a prior `scrollbackAcquire`.
pub fn scrollbackRelease(scrollback: *shared.ScrollbackBuffer) void {
    const owner = shared.scrollbackOwner(scrollback._ctx) orelse {
        scrollback.* = .{};
        return;
    };
    owner.allocator.free(owner.cells);
    owner.allocator.destroy(owner);
    scrollback.* = .{};
}

/// Copies title/cwd metadata per `request` (VT core); free with `metadataRelease`.
pub fn metadataAcquire(handle: ?*shared.ZideTerminalHandle, request: ?*const shared.MetadataRequest, out_metadata: *shared.Metadata) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const req = request orelse return .invalid_argument;
    out_metadata.* = .{};
    if (req.abi_version != shared.metadata_abi_version) return .invalid_argument;
    if (req.struct_size != @sizeOf(shared.MetadataRequest)) return .invalid_argument;

    const allocator = h.allocator;
    const owner = allocator.create(MetadataOwner) catch |err| {
        log.logf(.warning, "metadata owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const terminal_metadata = host_queries.copyTerminalMetadata(h.shell, allocator, &h.scratch_title, &h.scratch_cwd) catch |err| {
        log.logf(.warning, "terminal metadata copy failed err={s}", .{@errorName(err)});
        return shared.mapError(err);
    };
    const include_title = (req.include_flags & @intFromEnum(shared.MetadataIncludeFlags.title)) != 0;
    const include_cwd = (req.include_flags & @intFromEnum(shared.MetadataIncludeFlags.cwd)) != 0;
    const title = if (include_title)
        allocator.dupe(u8, terminal_metadata.title) catch |err| {
            log.logf(.warning, "metadata title dup failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        }
    else
        allocator.alloc(u8, 0) catch |err| {
            log.logf(.warning, "metadata empty title alloc failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        };
    errdefer allocator.free(title);
    const cwd = if (include_cwd)
        allocator.dupe(u8, terminal_metadata.cwd) catch |err| {
            log.logf(.warning, "metadata cwd dup failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        }
    else
        allocator.alloc(u8, 0) catch |err| {
            log.logf(.warning, "metadata empty cwd alloc failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        };
    errdefer allocator.free(cwd);

    owner.* = .{
        .allocator = allocator,
        .title = title,
        .cwd = cwd,
    };
    out_metadata.* = .{
        .abi_version = shared.metadata_abi_version,
        .struct_size = @sizeOf(shared.Metadata),
        .scrollback_count = std.math.cast(u32, terminal_metadata.scrollback_count) orelse std.math.maxInt(u32),
        .scrollback_offset = std.math.cast(u32, terminal_metadata.scrollback_offset) orelse std.math.maxInt(u32),
        .title_ptr = if (title.len == 0) null else title.ptr,
        .title_len = title.len,
        .cwd_ptr = if (cwd.len == 0) null else cwd.ptr,
        .cwd_len = cwd.len,
        ._ctx = owner,
    };
    return .ok;
}

/// Frees memory from a prior `metadataAcquire`.
pub fn metadataRelease(metadata: *shared.Metadata) void {
    const owner = shared.metadataOwner(metadata._ctx) orelse {
        metadata.* = .{};
        return;
    };
    owner.allocator.free(owner.title);
    owner.allocator.free(owner.cwd);
    owner.allocator.destroy(owner);
    metadata.* = .{};
}

/// Exports foreground/semantic activity fields per `request` (VT core); free with `activityRelease`.
pub fn activityAcquire(handle: ?*shared.ZideTerminalHandle, request: ?*const shared.ActivityRequest, out_activity: *shared.Activity) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const req = request orelse return .invalid_argument;
    out_activity.* = .{};
    if (req.abi_version != shared.activity_abi_version) return .invalid_argument;
    if (req.struct_size != @sizeOf(shared.ActivityRequest)) return .invalid_argument;

    const allocator = h.allocator;
    const owner = allocator.create(ActivityOwner) catch |err| {
        log.logf(.warning, "activity owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const activity = host_queries.currentActivityMetadata(h.shell);
    const include_foreground_process_label =
        (req.include_flags & @intFromEnum(shared.ActivityIncludeFlags.foreground_process_label)) != 0;
    const foreground_process_label = if (include_foreground_process_label)
        allocator.dupe(u8, activity.foreground_process_label) catch |err| {
            log.logf(.warning, "activity foreground-process-label dup failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        }
    else
        allocator.alloc(u8, 0) catch |err| {
            log.logf(.warning, "activity empty foreground-process-label alloc failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        };
    errdefer allocator.free(foreground_process_label);

    owner.* = .{
        .allocator = allocator,
        .foreground_process_label = foreground_process_label,
    };
    out_activity.* = .{
        .abi_version = shared.activity_abi_version,
        .struct_size = @sizeOf(shared.Activity),
        .foreground_process_present = @intFromBool(activity.foreground_process_present),
        .semantic_prompt_active = @intFromBool(activity.semantic_prompt_active),
        .semantic_input_active = @intFromBool(activity.semantic_input_active),
        .semantic_output_active = @intFromBool(activity.semantic_output_active),
        .semantic_prompt_kind = @intFromEnum(activity.semantic_prompt_kind),
        .semantic_prompt_exit_code_known = @intFromBool(activity.semantic_prompt_exit_code != null),
        .semantic_prompt_exit_code = activity.semantic_prompt_exit_code orelse 0,
        .foreground_process_label_ptr = if (foreground_process_label.len == 0) null else foreground_process_label.ptr,
        .foreground_process_label_len = foreground_process_label.len,
        ._ctx = owner,
    };
    return .ok;
}

/// Frees memory from a prior `activityAcquire`.
pub fn activityRelease(activity: *shared.Activity) void {
    const owner = shared.activityOwner(activity._ctx) orelse {
        activity.* = .{};
        return;
    };
    owner.allocator.free(owner.foreground_process_label);
    owner.allocator.destroy(owner);
    activity.* = .{};
}

/// Drains queued terminal events into `out_events` (VT core); free with `eventsFree`.
pub fn eventDrain(handle: ?*shared.ZideTerminalHandle, out_events: *shared.EventBuffer) shared.Status {
    const log = app_logger.logger("terminal.ffi");
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    out_events.* = .{};
    if (h.pending_events.items.len == 0) return .ok;

    const allocator = h.allocator;
    const owner = allocator.create(EventOwner) catch |err| {
        log.logf(.warning, "event owner alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(owner);

    const events = allocator.alloc(shared.Event, h.pending_events.items.len) catch |err| {
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
        .abi_version = shared.event_abi_version,
        .struct_size = @sizeOf(shared.EventBuffer),
        .events = events.ptr,
        .count = events.len,
        ._ctx = owner,
    };
    return .ok;
}

/// Frees memory from a prior `eventDrain`.
pub fn eventsFree(events: *shared.EventBuffer) void {
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

/// Allocates the current selection as a string (VT core); free with `stringFree`.
pub fn selectionText(handle: ?*shared.ZideTerminalHandle, out_string: *shared.StringBuffer) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const text = (h.shell.core.selectionPlainTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    }) orelse return shared.stringFromSlice(h.allocator, "", out_string);
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

/// If the engine requested a clipboard write, returns that payload (VT core); free with `stringFree`.
pub fn clipboardWrite(handle: ?*shared.ZideTerminalHandle, out_string: *shared.StringBuffer) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (!h.clipboard_write_pending) return shared.stringFromSlice(h.allocator, "", out_string);
    h.clipboard_write_pending = false;
    return shared.stringFromSlice(h.allocator, h.pending_clipboard_write.items, out_string);
}

/// Full scrollback as plain text (VT core); free with `stringFree`.
pub fn scrollbackPlainText(handle: ?*shared.ZideTerminalHandle, out_string: *shared.StringBuffer) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const text = h.shell.core.scrollbackPlainTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    };
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

/// Full scrollback as ANSI-colored text (VT core); free with `stringFree`.
pub fn scrollbackAnsiText(handle: ?*shared.ZideTerminalHandle, out_string: *shared.StringBuffer) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const text = h.shell.core.scrollbackAnsiTextAlloc(h.allocator) catch |err| {
        return shared.mapError(err);
    };
    return shared.stringFromOwnedSlice(h.allocator, text, out_string);
}

/// Frees FFI-owned string bytes from `selectionText`, scrollback exports, etc.
pub fn stringFree(string: *shared.StringBuffer) void {
    const owner = shared.stringOwner(string._ctx) orelse {
        string.* = .{};
        return;
    };
    owner.allocator.free(owner.bytes);
    owner.allocator.destroy(owner);
    string.* = .{};
}

pub fn snapshotAbiVersion() u32 {
    return shared.snapshot_abi_version;
}

pub fn snapshotDiffAbiVersion() u32 {
    return shared.snapshot_diff_abi_version;
}

pub fn eventAbiVersion() u32 {
    return shared.event_abi_version;
}

pub fn scrollbackAbiVersion() u32 {
    return shared.scrollback_abi_version;
}

pub fn rendererMetadataAbiVersion() u32 {
    return shared.renderer_metadata_abi_version;
}

pub fn redrawStateAbiVersion() u32 {
    return shared.redraw_state_abi_version;
}

pub fn activityAbiVersion() u32 {
    return shared.activity_abi_version;
}

pub fn closeConfirmAbiVersion() u32 {
    return shared.close_confirm_abi_version;
}

pub fn clipboardAbiVersion() u32 {
    return shared.clipboard_abi_version;
}

pub fn pendingInputAbiVersion() u32 {
    return shared.byte_buffer_abi_version;
}

pub fn stringAbiVersion() u32 {
    return shared.string_abi_version;
}

/// Glyph classification + damage-policy metadata for a codepoint (single fill path; VT core FFI).
pub fn rendererMetadata(codepoint: u32, out_metadata: *shared.RendererMetadata) shared.Status {
    renderer_metadata_mod.fillRendererMetadata(out_metadata, codepoint);
    return .ok;
}

fn mapCell(cell: types.Cell) shared.Cell {
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

fn mapColor(color: types.Color) shared.Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}
