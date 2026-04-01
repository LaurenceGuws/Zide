const std = @import("std");
const scrollback_view = @import("../scrollback_view.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const session_host_types = @import("host_types.zig");
const session_lifecycle = @import("lifecycle.zig");

pub const SessionMetadata = session_host_types.SessionMetadata;
pub const ActivityMetadata = session_host_types.ActivityMetadata;

fn copyTextInto(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) ![]const u8 {
    out.clearRetainingCapacity();
    try out.appendSlice(allocator, text);
    return out.items;
}

pub fn copyMetadata(
    self: anytype,
    allocator: std.mem.Allocator,
    title_out: *std.ArrayList(u8),
    cwd_out: *std.ArrayList(u8),
) !SessionMetadata {
    self.lock();
    defer self.unlock();

    const title = self.core.titleText();
    const cwd = self.core.cwdText();
    const scrollback = scrollback_view.scrollbackInfo(self);
    const scroll_offset = self.core.scrollbackOffset();
    const alive = if (terminal_transport.Transport.fromSession(self)) |transport| transport.isAlive() else false;
    const exit_code = session_lifecycle.childExitCode(self);

    return .{
        .title = try copyTextInto(allocator, title_out, title),
        .cwd = try copyTextInto(allocator, cwd_out, cwd),
        .scrollback_count = scrollback.total_rows,
        .scrollback_offset = scroll_offset,
        .alive = alive,
        .exit_code = exit_code,
    };
}

pub fn titleText(self: anytype) []const u8 {
    return self.core.titleText();
}

pub fn cwdText(self: anytype) []const u8 {
    return self.core.cwdText();
}

pub fn displayTitleText(self: anytype) []const u8 {
    return if (terminal_transport.Transport.fromSession(self)) |transport|
        (transport.foregroundProcessLabel() orelse self.core.titleText())
    else
        self.core.titleText();
}

pub fn altScreenActive(self: anytype) bool {
    return self.core.isAltActive();
}

pub fn currentActivityMetadata(self: anytype) ActivityMetadata {
    const alive = if (terminal_transport.Transport.fromSession(self)) |transport| transport.isAlive() else false;
    const foreground_process_present = if (terminal_transport.Transport.fromSession(self)) |transport|
        transport.hasForegroundProcessOutsideShell()
    else
        false;
    const foreground_process_label = if (terminal_transport.Transport.fromSession(self)) |transport|
        transport.foregroundProcessLabel() orelse ""
    else
        "";
    const foreground_process_command = if (terminal_transport.Transport.fromSession(self)) |transport|
        transport.foregroundProcessCommandLabel() orelse foreground_process_label
    else
        "";
    const semantic_prompt = self.core.semantic_prompt;
    return .{
        .running = alive,
        .foreground_process_present = foreground_process_present,
        .foreground_process_label = foreground_process_label,
        .foreground_process_command = foreground_process_command,
        .semantic_prompt_active = semantic_prompt.prompt_active or semantic_prompt.input_active or semantic_prompt.output_active,
        .semantic_input_active = semantic_prompt.input_active,
        .semantic_output_active = semantic_prompt.output_active,
        .semantic_prompt_kind = semantic_prompt.kind,
        .semantic_prompt_exit_code = semantic_prompt.exit_code,
        .progress = .{
            .state = self.core.progress_state,
            .value = self.core.progress_value,
        },
    };
}

pub fn copyActivityMetadata(
    self: anytype,
    allocator: std.mem.Allocator,
    foreground_process_label_out: *std.ArrayList(u8),
    foreground_process_command_out: *std.ArrayList(u8),
) !ActivityMetadata {
    self.lock();
    defer self.unlock();

    const current = currentActivityMetadata(self);
    const foreground_process_label = try copyTextInto(allocator, foreground_process_label_out, current.foreground_process_label);
    const foreground_process_command = try copyTextInto(allocator, foreground_process_command_out, current.foreground_process_command);
    return .{
        .running = current.running,
        .foreground_process_present = current.foreground_process_present,
        .foreground_process_label = foreground_process_label,
        .foreground_process_command = foreground_process_command,
        .semantic_prompt_active = current.semantic_prompt_active,
        .semantic_input_active = current.semantic_input_active,
        .semantic_output_active = current.semantic_output_active,
        .semantic_prompt_kind = current.semantic_prompt_kind,
        .semantic_prompt_exit_code = current.semantic_prompt_exit_code,
        .progress = current.progress,
    };
}

pub fn isAlive(self: anytype) bool {
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        return transport.isAlive();
    }
    return false;
}
