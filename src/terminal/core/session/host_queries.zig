const std = @import("std");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const session_host_types = @import("host_types.zig");
const session_lifecycle = @import("lifecycle.zig");

pub const SessionMetadata = session_host_types.SessionMetadata;
pub const ActivityMetadata = session_host_types.ActivityMetadata;
pub const ProgressMetadata = session_host_types.ProgressMetadata;

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

    const metadata_state = self.core.metadataState();
    const alive = if (terminal_transport.Transport.fromSession(self)) |transport| transport.isAlive() else false;
    const exit_code = session_lifecycle.childExitCode(self);

    return .{
        .title = try copyTextInto(allocator, title_out, metadata_state.title),
        .cwd = try copyTextInto(allocator, cwd_out, metadata_state.cwd),
        .scrollback_count = metadata_state.scrollback_count,
        .scrollback_offset = metadata_state.scrollback_offset,
        .alive = alive,
        .exit_code = exit_code,
    };
}

pub fn copyCwdText(
    self: anytype,
    allocator: std.mem.Allocator,
    cwd_out: *std.ArrayList(u8),
) ![]const u8 {
    self.lock();
    defer self.unlock();

    return try copyTextInto(allocator, cwd_out, self.core.cwdText());
}

pub fn copyHyperlinkUri(
    self: anytype,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    link_id: u32,
) !?[]const u8 {
    self.lock();
    defer self.unlock();

    const uri = self.core.hyperlinkUri(link_id) orelse {
        out.clearRetainingCapacity();
        return null;
    };
    return try copyTextInto(allocator, out, uri);
}

pub fn currentProgress(self: anytype) ProgressMetadata {
    self.lock();
    defer self.unlock();

    return self.core.activityState().progress;
}

pub fn displayTitleText(self: anytype) []const u8 {
    return if (terminal_transport.Transport.fromSession(self)) |transport|
        (transport.foregroundProcessLabel() orelse self.core.titleText())
    else
        self.core.titleText();
}

pub fn currentActivityMetadata(self: anytype) ActivityMetadata {
    const activity_state = self.core.activityState();
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
    return .{
        .running = alive,
        .foreground_process_present = foreground_process_present,
        .foreground_process_label = foreground_process_label,
        .foreground_process_command = foreground_process_command,
        .semantic_prompt_active = activity_state.semantic_prompt_active,
        .semantic_input_active = activity_state.semantic_input_active,
        .semantic_output_active = activity_state.semantic_output_active,
        .semantic_prompt_kind = activity_state.semantic_prompt_kind,
        .semantic_prompt_exit_code = activity_state.semantic_prompt_exit_code,
        .progress = activity_state.progress,
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
