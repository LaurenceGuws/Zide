const std = @import("std");

pub const Fields = struct {
    state_mutex: std.Thread.Mutex,
    input_pressure: std.atomic.Value(bool),
    last_parse_log_ms: i64,
    parse_publishes_since_log: usize,
    parse_bytes_since_log: usize,
    last_parse_publish_ms: i64,
    parse_bytes_since_publish: usize,
};
