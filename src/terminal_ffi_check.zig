const c_api = @import("terminal/ffi/c_api.zig");
const app_logger = @import("app_logger.zig");

pub fn main() !void {
    try app_logger.setConsoleFilterString("none");
    try app_logger.setFileFilterString("none");

    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) return error.CreateFailed;
    defer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, 80, 24, 8, 16) != 0) return error.ResizeFailed;

    const vt = "\x1b]0;ffi-title\x07\x1b]52;c;ZmZpLWNsaXA=\x07";
    if (c_api.zide_terminal_feed_output(handle, vt.ptr, vt.len) != 0) return error.FeedFailed;

    const snapshot_request = c_api.ZideTerminalSnapshotRequest{
        .abi_version = c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION,
        .struct_size = @sizeOf(c_api.ZideTerminalSnapshotRequest),
        .reserved0 = 0,
        .reserved1 = 0,
    };
    var snapshot: c_api.ZideTerminalSnapshot = .{};
    if (c_api.zide_terminal_snapshot_acquire(handle, &snapshot_request, &snapshot) != 0) return error.SnapshotAcquireFailed;
    defer c_api.zide_terminal_snapshot_release(&snapshot);

    if (snapshot.abi_version != c_api.ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION) return error.UnexpectedAbiVersion;
    if (snapshot.struct_size != @sizeOf(c_api.ZideTerminalSnapshot)) return error.UnexpectedStructSize;
    if (snapshot.rows != 24) return error.UnexpectedRows;
    if (snapshot.cols != 80) return error.UnexpectedCols;
    if (snapshot.cell_count != 24 * 80) return error.UnexpectedCellCount;
    if (snapshot.cells == null) return error.MissingCells;

    const metadata_request = c_api.ZideTerminalMetadataRequest{
        .abi_version = c_api.ZIDE_TERMINAL_METADATA_ABI_VERSION,
        .struct_size = @sizeOf(c_api.ZideTerminalMetadataRequest),
        .include_flags = c_api.ZIDE_TERMINAL_METADATA_INCLUDE_TITLE,
        .reserved0 = 0,
    };
    var metadata: c_api.ZideTerminalMetadata = .{};
    if (c_api.zide_terminal_metadata_acquire(handle, &metadata_request, &metadata) != 0) return error.MetadataAcquireFailed;
    defer c_api.zide_terminal_metadata_release(&metadata);
    if (metadata.title_ptr == null or metadata.title_len == 0) return error.MissingTitle;

    var events: c_api.ZideTerminalEventBuffer = .{};
    if (c_api.zide_terminal_event_drain(handle, &events) != 0) return error.EventDrainFailed;
    defer c_api.zide_terminal_events_free(&events);
    if (events.count < 2) return error.UnexpectedEvents;
}
