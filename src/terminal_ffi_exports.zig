const c_api = @import("terminal/ffi/c_api.zig");

pub export fn zide_terminal_create(config: ?*const c_api.ZideTerminalCreateConfig, out_handle: *?*c_api.ZideTerminalHandle) c_int {
    return c_api.zide_terminal_create(config, out_handle);
}

pub export fn zide_terminal_destroy(handle: ?*c_api.ZideTerminalHandle) void {
    c_api.zide_terminal_destroy(handle);
}

pub export fn zide_terminal_start(handle: ?*c_api.ZideTerminalHandle, shell: ?[*:0]const u8) c_int {
    return c_api.zide_terminal_start(handle, shell);
}

pub export fn zide_terminal_poll(handle: ?*c_api.ZideTerminalHandle) c_int {
    return c_api.zide_terminal_poll(handle);
}

pub export fn zide_terminal_resize(handle: ?*c_api.ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) c_int {
    return c_api.zide_terminal_resize(handle, cols, rows, cell_width, cell_height);
}

pub export fn zide_terminal_send_bytes(handle: ?*c_api.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) c_int {
    return c_api.zide_terminal_send_bytes(handle, bytes, len);
}

pub export fn zide_terminal_send_text(handle: ?*c_api.ZideTerminalHandle, text: ?[*]const u8, len: usize) c_int {
    return c_api.zide_terminal_send_text(handle, text, len);
}

pub export fn zide_terminal_feed_output(handle: ?*c_api.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) c_int {
    return c_api.zide_terminal_feed_output(handle, bytes, len);
}

pub export fn zide_terminal_close_input(handle: ?*c_api.ZideTerminalHandle) c_int {
    return c_api.zide_terminal_close_input(handle);
}

pub export fn zide_terminal_send_key(handle: ?*c_api.ZideTerminalHandle, event: ?*const c_api.ZideTerminalKeyEvent) c_int {
    return c_api.zide_terminal_send_key(handle, event);
}

pub export fn zide_terminal_send_mouse(handle: ?*c_api.ZideTerminalHandle, event: ?*const c_api.ZideTerminalMouseEvent) c_int {
    return c_api.zide_terminal_send_mouse(handle, event);
}

pub export fn zide_terminal_snapshot_acquire(handle: ?*c_api.ZideTerminalHandle, out_snapshot: *c_api.ZideTerminalSnapshot) c_int {
    return c_api.zide_terminal_snapshot_acquire(handle, out_snapshot);
}

pub export fn zide_terminal_snapshot_release(snapshot: *c_api.ZideTerminalSnapshot) void {
    c_api.zide_terminal_snapshot_release(snapshot);
}

pub export fn zide_terminal_scrollback_acquire(handle: ?*c_api.ZideTerminalHandle, start_row: u32, max_rows: u32, out_buffer: *c_api.ZideTerminalScrollbackBuffer) c_int {
    return c_api.zide_terminal_scrollback_acquire(handle, start_row, max_rows, out_buffer);
}

pub export fn zide_terminal_scrollback_release(scrollback: *c_api.ZideTerminalScrollbackBuffer) void {
    c_api.zide_terminal_scrollback_release(scrollback);
}

pub export fn zide_terminal_metadata_acquire(handle: ?*c_api.ZideTerminalHandle, out_metadata: *c_api.ZideTerminalMetadata) c_int {
    return c_api.zide_terminal_metadata_acquire(handle, out_metadata);
}

pub export fn zide_terminal_metadata_release(metadata: *c_api.ZideTerminalMetadata) void {
    c_api.zide_terminal_metadata_release(metadata);
}

pub export fn zide_terminal_event_drain(handle: ?*c_api.ZideTerminalHandle, out_events: *c_api.ZideTerminalEventBuffer) c_int {
    return c_api.zide_terminal_event_drain(handle, out_events);
}

pub export fn zide_terminal_events_free(events: *c_api.ZideTerminalEventBuffer) void {
    c_api.zide_terminal_events_free(events);
}

pub export fn zide_terminal_is_alive(handle: ?*c_api.ZideTerminalHandle) u8 {
    return c_api.zide_terminal_is_alive(handle);
}

pub export fn zide_terminal_string_free(string: *c_api.ZideTerminalStringBuffer) void {
    c_api.zide_terminal_string_free(string);
}

pub export fn zide_terminal_child_exit_status(handle: ?*c_api.ZideTerminalHandle, out_code: *i32, out_has_status: *u8) c_int {
    return c_api.zide_terminal_child_exit_status(handle, out_code, out_has_status);
}

pub export fn zide_terminal_snapshot_abi_version() u32 {
    return c_api.zide_terminal_snapshot_abi_version();
}

pub export fn zide_terminal_event_abi_version() u32 {
    return c_api.zide_terminal_event_abi_version();
}

pub export fn zide_terminal_scrollback_abi_version() u32 {
    return c_api.zide_terminal_scrollback_abi_version();
}

pub export fn zide_terminal_metadata_abi_version() u32 {
    return c_api.zide_terminal_metadata_abi_version();
}

pub export fn zide_terminal_renderer_metadata_abi_version() u32 {
    return c_api.zide_terminal_renderer_metadata_abi_version();
}

pub export fn zide_terminal_renderer_metadata(codepoint: u32, out_metadata: *c_api.ZideTerminalRendererMetadata) c_int {
    return c_api.zide_terminal_renderer_metadata(codepoint, out_metadata);
}

pub export fn zide_terminal_status_string(status: c_int) [*:0]const u8 {
    return c_api.zide_terminal_status_string(status);
}
