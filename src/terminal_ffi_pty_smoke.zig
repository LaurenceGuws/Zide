const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("app_logger.zig");
const c_api = @import("terminal/ffi/c_api.zig");
const terminal = @import("terminal/core/terminal.zig");

pub fn main() !void {
    if (builtin.os.tag == .windows) return;
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) return error.CreateFailed;
    defer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, 60, 12, 8, 16) != 0) return error.ResizeFailed;
    if (c_api.zide_terminal_start(handle, "/bin/sh") != 0) return error.StartFailed;

    const command =
        "printf '\\033]0;ffi-pty-title\\007\\033]7;file://localhost/tmp/ffi-pty\\007\\033[?1004h\\033[?2031h'; " ++
        "i=0; while [ \"$i\" -lt 16 ]; do printf 'hist-%02d\\n' \"$i\"; i=$((i+1)); done; " ++
        "printf 'ffi-pty\\n'; exit 7";
    if (c_api.zide_terminal_send_text(handle, command.ptr, command.len) != 0) return error.SendTextFailed;

    const enter_event = c_api.ZideTerminalKeyEvent{
        .key = terminal.VTERM_KEY_ENTER,
        .modifiers = terminal.VTERM_MOD_NONE,
    };
    if (c_api.zide_terminal_send_key(handle, &enter_event) != 0) return error.SendEnterFailed;

    const deadline = std.time.milliTimestamp() + 4000;
    var saw_marker = false;
    var saw_child_exit = false;
    var saw_metadata = false;
    var saw_redraw = false;
    var saw_close_confirm = false;
    var saw_focus_report = false;
    var saw_color_scheme_report = false;
    var saw_viewport = false;

    {
        var focus_reported: u8 = 99;
        if (c_api.zide_terminal_report_focus_changed(handle, 1, &focus_reported) != 0) return error.FocusReportFailed;
        if (focus_reported != 0) return error.FocusReportUnexpectedlyEnabled;

        var color_reported: u8 = 99;
        if (c_api.zide_terminal_report_color_scheme_changed(handle, 1, &color_reported) != 0) return error.ColorSchemeReportFailed;
        if (color_reported != 0) return error.ColorSchemeReportUnexpectedlyEnabled;
    }

    while (std.time.milliTimestamp() < deadline) {
        if (c_api.zide_terminal_poll(handle) != 0) return error.PollFailed;

        if (try consumeTerminalPublicationOnceIfPending(handle, "ffi-pty")) saw_marker = true;

        if (!saw_focus_report) {
            var focus_reported: u8 = 0;
            if (c_api.zide_terminal_report_focus_changed(handle, 1, &focus_reported) != 0) return error.FocusReportFailed;
            saw_focus_report = focus_reported == 1;
        }

        if (!saw_color_scheme_report) {
            var color_reported: u8 = 0;
            if (c_api.zide_terminal_report_color_scheme_changed(handle, 1, &color_reported) != 0) return error.ColorSchemeReportFailed;
            saw_color_scheme_report = color_reported == 1;
        }

        {
            var metadata: c_api.ZideTerminalMetadata = .{};
            var metadata_request = metadataRequest(c_api.ZIDE_TERMINAL_METADATA_INCLUDE_ALL_STRINGS);
            if (c_api.zide_terminal_metadata_acquire(handle, &metadata_request, &metadata) != 0) return error.MetadataAcquireFailed;
            defer c_api.zide_terminal_metadata_release(&metadata);
            saw_metadata =
                std.mem.eql(u8, ptrBytes(metadata.title_ptr, metadata.title_len), "ffi-pty-title") and
                std.mem.eql(u8, ptrBytes(metadata.cwd_ptr, metadata.cwd_len), "/tmp/ffi-pty");

            if (!saw_viewport and saw_marker and metadata.scrollback_count > 1) {
                const target_offset: u32 = @intCast(@min(@as(usize, metadata.scrollback_count), @as(usize, 3)));
                const live_snapshot_request = snapshotRequest(0);
                var live_snapshot: c_api.ZideTerminalSnapshot = .{};
                if (c_api.zide_terminal_snapshot_acquire(handle, &live_snapshot_request, &live_snapshot) != 0) return error.SnapshotAcquireFailed;
                defer c_api.zide_terminal_snapshot_release(&live_snapshot);
                var live_row0 = try snapshotRowText(&live_snapshot, 0);
                defer live_row0.deinit(std.heap.page_allocator);

                if (c_api.zide_terminal_set_scrollback_offset(handle, target_offset) != 0) return error.ViewportPinFailed;

                var pinned_metadata: c_api.ZideTerminalMetadata = .{};
                var pinned_request = metadataRequest(0);
                if (c_api.zide_terminal_metadata_acquire(handle, &pinned_request, &pinned_metadata) != 0) return error.MetadataAcquireFailed;
                defer c_api.zide_terminal_metadata_release(&pinned_metadata);
                if (pinned_metadata.scrollback_offset != target_offset) return error.ViewportPinOffsetMismatch;

                var pinned_redraw: c_api.ZideTerminalRedrawState = .{};
                if (c_api.zide_terminal_redraw_state(handle, &pinned_redraw) != 0) return error.RedrawStateFailed;
                if (pinned_redraw.needs_redraw != 1) return error.ViewportPinDidNotRedraw;

                var diff_request = snapshotDiffRequest(0);
                var diff: c_api.ZideTerminalSnapshotDiff = .{};
                if (c_api.zide_terminal_snapshot_diff_acquire(handle, &diff_request, &diff) != 0) return error.SnapshotDiffAcquireFailed;
                defer c_api.zide_terminal_snapshot_diff_release(&diff);
                if (diff.abi_version != c_api.ZIDE_TERMINAL_SNAPSHOT_DIFF_ABI_VERSION) return error.SnapshotDiffAbiMismatch;
                if (diff.struct_size != @sizeOf(c_api.ZideTerminalSnapshotDiff)) return error.SnapshotDiffStructSizeMismatch;
                if (diff.full_refresh_required != 1) return error.SnapshotDiffExpectedFullRefresh;
                if (diff.row_count != 0 or diff.span_count != 0) return error.SnapshotDiffUnexpectedGranularPayload;

                const pinned_snapshot_request = snapshotRequest(0);
                var pinned_snapshot: c_api.ZideTerminalSnapshot = .{};
                if (c_api.zide_terminal_snapshot_acquire(handle, &pinned_snapshot_request, &pinned_snapshot) != 0) return error.SnapshotAcquireFailed;
                defer c_api.zide_terminal_snapshot_release(&pinned_snapshot);
                var pinned_row0 = try snapshotRowText(&pinned_snapshot, 0);
                defer pinned_row0.deinit(std.heap.page_allocator);
                if (std.mem.eql(u8, pinned_row0.items, live_row0.items)) return error.ViewportPinnedSnapshotDidNotMove;

                if (c_api.zide_terminal_present_ack(handle, pinned_redraw.published_generation) != 0) return error.PresentAckFailed;

                if (c_api.zide_terminal_follow_live_bottom(handle) != 0) return error.ViewportFollowLiveBottomFailed;
                var live_metadata: c_api.ZideTerminalMetadata = .{};
                var live_request = metadataRequest(0);
                if (c_api.zide_terminal_metadata_acquire(handle, &live_request, &live_metadata) != 0) return error.MetadataAcquireFailed;
                defer c_api.zide_terminal_metadata_release(&live_metadata);
                if (live_metadata.scrollback_offset != 0) return error.ViewportLiveBottomOffsetMismatch;

                const restored_snapshot_request = snapshotRequest(0);
                var restored_snapshot: c_api.ZideTerminalSnapshot = .{};
                if (c_api.zide_terminal_snapshot_acquire(handle, &restored_snapshot_request, &restored_snapshot) != 0) return error.SnapshotAcquireFailed;
                defer c_api.zide_terminal_snapshot_release(&restored_snapshot);
                var restored_row0 = try snapshotRowText(&restored_snapshot, 0);
                defer restored_row0.deinit(std.heap.page_allocator);
                if (!std.mem.eql(u8, restored_row0.items, live_row0.items)) return error.ViewportLiveBottomDidNotRestore;
                saw_viewport = true;
            }
        }

        {
            var close_confirm: c_api.ZideTerminalCloseConfirmSignals = .{};
            if (c_api.zide_terminal_close_confirm_signals(handle, &close_confirm) != 0) {
                return error.CloseConfirmAcquireFailed;
            }
            if (close_confirm.abi_version != c_api.ZIDE_TERMINAL_CLOSE_CONFIRM_ABI_VERSION) {
                return error.CloseConfirmAbiMismatch;
            }
            if (close_confirm.struct_size != @sizeOf(c_api.ZideTerminalCloseConfirmSignals)) {
                return error.CloseConfirmStructSizeMismatch;
            }
            if (close_confirm.foreground_process != 0) return error.UnexpectedForegroundProcessCloseConfirm;
            if (close_confirm.semantic_command != 0) return error.UnexpectedSemanticCommandCloseConfirm;
            if (close_confirm.alt_screen != 0) return error.UnexpectedAltScreenCloseConfirm;
            if (close_confirm.mouse_reporting != 0) return error.UnexpectedMouseReportingCloseConfirm;
            if (close_confirm.any != 0) return error.UnexpectedAnyCloseConfirm;
            saw_close_confirm = true;
        }

        {
            var events: c_api.ZideTerminalEventBuffer = .{};
            if (c_api.zide_terminal_event_drain(handle, &events) != 0) return error.EventDrainFailed;
            defer c_api.zide_terminal_events_free(&events);

            if (events.events) |event_ptr| {
                for (event_ptr[0..events.count]) |event| {
                    if (event.kind == @intFromEnum(c_api.ZideTerminalEventKind.redraw_ready)) {
                        saw_redraw = true;
                    }
                    if (event.kind == @intFromEnum(c_api.ZideTerminalEventKind.child_exit)) {
                        if (event.int0 != 7 or event.int1 != 1) return error.UnexpectedChildExitEvent;
                        saw_child_exit = true;
                    }
                }
            }
        }

        if (saw_marker and saw_child_exit and saw_metadata and saw_redraw and saw_close_confirm and saw_focus_report and saw_color_scheme_report and saw_viewport) {
            var code: i32 = -1;
            var has_status: u8 = 0;
            if (c_api.zide_terminal_child_exit_status(handle, &code, &has_status) != 0) return error.ChildExitStatusFailed;
            if (has_status != 1 or code != 7) return error.UnexpectedChildExitStatus;
            try validatePtyStartupSnapshotDiffFallback();
            try validatePtySettledSnapshotDiffGranular();
            return;
        }

        std.Thread.sleep(20 * std.time.ns_per_ms);
    }

    if (!saw_marker) return error.MissingMarker;
    if (!saw_redraw) return error.MissingRedrawReady;
    if (!saw_child_exit) return error.MissingChildExit;
    if (!saw_metadata) return error.MissingMetadata;
    if (!saw_close_confirm) return error.MissingCloseConfirm;
    if (!saw_focus_report) return error.MissingFocusReport;
    if (!saw_color_scheme_report) return error.MissingColorSchemeReport;
    if (!saw_viewport) return error.MissingViewportValidation;
}

fn validatePtyStartupSnapshotDiffFallback() !void {
    const script_path = "/tmp/zide-terminal-ffi-pty-diff-startup.sh";
    const script_contents =
        "#!/bin/sh\n" ++
        "sleep 0.2\n" ++
        "printf 'ABCDEFGH'\n" ++
        "sleep 0.5\n" ++
        "printf '\\rWXYZ'\n" ++
        "sleep 0.5\n";
    {
        const file = try std.fs.createFileAbsolute(script_path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(script_contents);
    }
    {
        const result = try std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &.{ "chmod", "+x", script_path },
        });
        defer std.heap.page_allocator.free(result.stdout);
        defer std.heap.page_allocator.free(result.stderr);
        if (result.term.Exited != 0) return error.ChmodFailed;
    }

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) return error.CreateFailed;
    defer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, 9, 1, 8, 16) != 0) return error.ResizeFailed;
    if (c_api.zide_terminal_start(handle, script_path) != 0) return error.StartFailed;

    const deadline = std.time.milliTimestamp() + 4000;
    var base_generation: ?u64 = null;

    while (std.time.milliTimestamp() < deadline) {
        if (c_api.zide_terminal_poll(handle) != 0) return error.PollFailed;

        var redraw_state: c_api.ZideTerminalRedrawState = .{};
        if (c_api.zide_terminal_redraw_state(handle, &redraw_state) != 0) return error.RedrawStateFailed;
        if (redraw_state.needs_redraw != 1) {
            std.Thread.sleep(20 * std.time.ns_per_ms);
            continue;
        }

        const request = snapshotRequest(0);
        var snapshot: c_api.ZideTerminalSnapshot = .{};
        if (c_api.zide_terminal_snapshot_acquire(handle, &request, &snapshot) != 0) return error.SnapshotAcquireFailed;
        defer c_api.zide_terminal_snapshot_release(&snapshot);

        var row0 = try snapshotRowText(&snapshot, 0);
        defer row0.deinit(std.heap.page_allocator);

        if (base_generation == null and std.mem.startsWith(u8, row0.items, "ABCDEFGH")) {
            base_generation = snapshot.generation;
            continue;
        }

        if (base_generation != null and std.mem.startsWith(u8, row0.items, "WXYZEFGH")) {
            var diff_request = snapshotDiffRequest(base_generation.?);
            var diff: c_api.ZideTerminalSnapshotDiff = .{};
            if (c_api.zide_terminal_snapshot_diff_acquire(handle, &diff_request, &diff) != 0) {
                return error.SnapshotDiffAcquireFailed;
            }
            defer c_api.zide_terminal_snapshot_diff_release(&diff);

            if (diff.full_refresh_required != 1) return error.SnapshotDiffExpectedFullRefresh;
            if (diff.row_count != 0 or diff.span_count != 0) return error.SnapshotDiffUnexpectedGranularPayload;
            if (diff.cell_count != 9) return error.SnapshotDiffUnexpectedFullRefreshPayload;
            return;
        }

        if (base_generation != null) {
            std.Thread.sleep(20 * std.time.ns_per_ms);
            continue;
        }

        if (c_api.zide_terminal_present_ack(handle, redraw_state.published_generation) != 0) {
            return error.PresentAckFailed;
        }
    }

    return error.MissingSnapshotDiffStartupFallbackValidation;
}

fn validatePtySettledSnapshotDiffGranular() !void {
    const script_path = "/tmp/zide-terminal-ffi-pty-diff-settled.sh";
    const script_contents =
        "#!/bin/sh\n" ++
        "stty -echo\n" ++
        "IFS= read -r _\n" ++
        "printf '\\rABCDEFGH'\n" ++
        "IFS= read -r _\n" ++
        "printf '\\rWXYZ'\n" ++
        "sleep 0.2\n";
    {
        const file = try std.fs.createFileAbsolute(script_path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(script_contents);
    }
    {
        const result = try std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &.{ "chmod", "+x", script_path },
        });
        defer std.heap.page_allocator.free(result.stdout);
        defer std.heap.page_allocator.free(result.stderr);
        if (result.term.Exited != 0) return error.ChmodFailed;
    }

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) return error.CreateFailed;
    defer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, 9, 1, 8, 16) != 0) return error.ResizeFailed;
    if (c_api.zide_terminal_start(handle, script_path) != 0) return error.StartFailed;

    const enter_event = c_api.ZideTerminalKeyEvent{
        .key = terminal.VTERM_KEY_ENTER,
        .modifiers = terminal.VTERM_MOD_NONE,
    };
    if (c_api.zide_terminal_send_text(handle, "go".ptr, 2) != 0) return error.SendTextFailed;
    if (c_api.zide_terminal_send_key(handle, &enter_event) != 0) return error.SendEnterFailed;

    const deadline = std.time.milliTimestamp() + 4000;
    var base_generation: ?u64 = null;

    while (std.time.milliTimestamp() < deadline) {
        if (c_api.zide_terminal_poll(handle) != 0) return error.PollFailed;

        var redraw_state: c_api.ZideTerminalRedrawState = .{};
        if (c_api.zide_terminal_redraw_state(handle, &redraw_state) != 0) return error.RedrawStateFailed;
        if (redraw_state.needs_redraw != 1) {
            std.Thread.sleep(20 * std.time.ns_per_ms);
            continue;
        }

        const request = snapshotRequest(0);
        var snapshot: c_api.ZideTerminalSnapshot = .{};
        if (c_api.zide_terminal_snapshot_acquire(handle, &request, &snapshot) != 0) return error.SnapshotAcquireFailed;
        defer c_api.zide_terminal_snapshot_release(&snapshot);

        var row0 = try snapshotRowText(&snapshot, 0);
        defer row0.deinit(std.heap.page_allocator);

        if (base_generation == null and std.mem.startsWith(u8, row0.items, "ABCDEFGH")) {
            base_generation = snapshot.generation;
            if (c_api.zide_terminal_present_ack(handle, redraw_state.published_generation) != 0) {
                return error.PresentAckFailed;
            }
            if (c_api.zide_terminal_send_text(handle, "go".ptr, 2) != 0) return error.SendTextFailed;
            if (c_api.zide_terminal_send_key(handle, &enter_event) != 0) return error.SendEnterFailed;
            continue;
        }

        if (base_generation != null and std.mem.startsWith(u8, row0.items, "WXYZEFGH")) {
            var diff_request = snapshotDiffRequest(base_generation.?);
            var diff: c_api.ZideTerminalSnapshotDiff = .{};
            if (c_api.zide_terminal_snapshot_diff_acquire(handle, &diff_request, &diff) != 0) {
                return error.SnapshotDiffAcquireFailed;
            }
            defer c_api.zide_terminal_snapshot_diff_release(&diff);

            if (diff.full_refresh_required != 0) return error.SnapshotDiffExpectedGranularPayload;
            if (diff.row_count != 1 or diff.span_count != 1 or diff.cell_count != 4) {
                return error.SnapshotDiffUnexpectedGranularPayload;
            }
            if (diff.rows_ptr == null or diff.spans_ptr == null or diff.cells_ptr == null) {
                return error.SnapshotDiffMissingGranularPayload;
            }
            const row = diff.rows_ptr.?[0];
            const span = diff.spans_ptr.?[0];
            if (row.row != 0 or row.first_span_index != 0 or row.first_cell_index != 0 or row.cell_count != 4) {
                return error.SnapshotDiffUnexpectedGranularPayload;
            }
            if (span.start_col != 0 or span.end_col != 3) return error.SnapshotDiffUnexpectedGranularPayload;
            const diff_cells = diff.cells_ptr.?[0..diff.cell_count];
            if (diff_cells[0].codepoint != 'W' or diff_cells[1].codepoint != 'X' or diff_cells[2].codepoint != 'Y' or diff_cells[3].codepoint != 'Z') {
                return error.SnapshotDiffUnexpectedGranularPayload;
            }
            return;
        }

        if (c_api.zide_terminal_present_ack(handle, redraw_state.published_generation) != 0) {
            return error.PresentAckFailed;
        }
    }

    return error.MissingSnapshotDiffGranularValidation;
}

fn consumeTerminalPublicationOnceIfPending(handle: ?*c_api.ZideTerminalHandle, needle: []const u8) !bool {
    var redraw_state: c_api.ZideTerminalRedrawState = .{};
    if (c_api.zide_terminal_redraw_state(handle, &redraw_state) != 0) return error.RedrawStateFailed;
    if (redraw_state.needs_redraw != 1) return false;

    const snapshot_request = snapshotRequest(0);
    var snapshot: c_api.ZideTerminalSnapshot = .{};
    if (c_api.zide_terminal_snapshot_acquire(handle, &snapshot_request, &snapshot) != 0) return error.SnapshotAcquireFailed;
    defer c_api.zide_terminal_snapshot_release(&snapshot);
    const found_marker = snapshotContains(&snapshot, needle);

    if (c_api.zide_terminal_present_ack(handle, redraw_state.published_generation) != 0) {
        return error.PresentAckFailed;
    }
    if (c_api.zide_terminal_redraw_state(handle, &redraw_state) != 0) return error.RedrawStateFailed;
    if (redraw_state.acknowledged_generation != redraw_state.published_generation) {
        return error.AckDidNotAdvance;
    }
    if (redraw_state.needs_redraw != 0) return error.RedrawDidNotCoolOff;

    return found_marker;
}

fn snapshotContains(snapshot: *const c_api.ZideTerminalSnapshot, needle: []const u8) bool {
    if (snapshot.cells == null) return false;
    const cells = snapshot.cells.?[0..snapshot.cell_count];
    const cols = snapshot.cols;
    var row: u32 = 0;
    while (row < snapshot.rows) : (row += 1) {
        var line = std.ArrayList(u8).empty;
        defer line.deinit(std.heap.page_allocator);

        var col: u32 = 0;
        while (col < cols) : (col += 1) {
            const idx: usize = @intCast(row * cols + col);
            const cell = cells[idx];
            if (cell.width == 0) continue;
            const cp = cell.codepoint;
            if (cp == 0 or cp > 0x7f) {
                line.append(std.heap.page_allocator, ' ') catch return false;
                continue;
            }
            line.append(std.heap.page_allocator, @intCast(cp)) catch return false;
        }

        if (std.mem.indexOf(u8, line.items, needle) != null) return true;
    }
    return false;
}

fn snapshotRowText(snapshot: *const c_api.ZideTerminalSnapshot, row: usize) !std.ArrayList(u8) {
    var line = std.ArrayList(u8).empty;
    errdefer line.deinit(std.heap.page_allocator);
    if (snapshot.cells == null) return line;
    const cells = snapshot.cells.?[0..snapshot.cell_count];
    const cols: usize = @intCast(snapshot.cols);
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        const idx = row * cols + col;
        const cell = cells[idx];
        if (cell.width == 0) continue;
        const cp = cell.codepoint;
        try line.append(std.heap.page_allocator, if (cp == 0 or cp > 0x7f) ' ' else @intCast(cp));
    }
    return line;
}

fn ptrBytes(ptr: ?[*]const u8, len: usize) []const u8 {
    if (len == 0) return "";
    return (ptr orelse unreachable)[0..len];
}

fn metadataRequest(include_flags: u32) c_api.ZideTerminalMetadataRequest {
    return .{
        .abi_version = c_api.zide_terminal_metadata_abi_version(),
        .struct_size = @sizeOf(c_api.ZideTerminalMetadataRequest),
        .include_flags = include_flags,
        .reserved0 = 0,
    };
}

fn snapshotRequest(include_flags: u32) c_api.ZideTerminalSnapshotRequest {
    return .{
        .abi_version = c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION,
        .struct_size = @sizeOf(c_api.ZideTerminalSnapshotRequest),
        .include_flags = include_flags,
        .reserved0 = 0,
    };
}

fn snapshotDiffRequest(base_generation: u64) c_api.ZideTerminalSnapshotDiffRequest {
    return .{
        .abi_version = c_api.ZIDE_TERMINAL_SNAPSHOT_DIFF_ABI_VERSION,
        .struct_size = @sizeOf(c_api.ZideTerminalSnapshotDiffRequest),
        .base_generation = base_generation,
        .reserved0 = 0,
        .reserved1 = 0,
    };
}
