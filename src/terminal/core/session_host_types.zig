pub const SessionMetadata = struct {
    title: []const u8,
    cwd: []const u8,
    scrollback_count: usize,
    scrollback_offset: usize,
    alive: bool,
    exit_code: ?i32,
};

pub const CloseConfirmSignals = struct {
    foreground_process: bool = false,
    semantic_command: bool = false,
    alt_screen: bool = false,
    mouse_reporting: bool = false,

    pub fn any(self: CloseConfirmSignals) bool {
        return self.foreground_process or self.semantic_command or self.alt_screen or self.mouse_reporting;
    }
};
