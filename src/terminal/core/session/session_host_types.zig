const semantic_prompt_mod = @import("../semantic_prompt.zig");

pub const ProgressState = enum(u8) {
    none,
    set,
    @"error",
    indeterminate,
    pause,
};

pub const ProgressMetadata = struct {
    state: ProgressState = .none,
    value: ?u8 = null,

    pub fn active(self: ProgressMetadata) bool {
        return self.state != .none;
    }

    pub fn determinate(self: ProgressMetadata) bool {
        return switch (self.state) {
            .set, .@"error", .pause => self.value != null,
            else => false,
        };
    }
};

pub const ActivityMetadata = struct {
    running: bool,
    foreground_process_present: bool,
    foreground_process_label: []const u8,
    foreground_process_command: []const u8 = "",
    semantic_prompt_active: bool,
    semantic_input_active: bool,
    semantic_output_active: bool,
    semantic_prompt_kind: semantic_prompt_mod.SemanticPromptKind,
    semantic_prompt_exit_code: ?u8,
    progress: ProgressMetadata = .{},
};

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
