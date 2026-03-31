const std = @import("std");
const config_mod = @import("../../config/lua_config.zig");
const app_terminal_shell_icon_runtime = @import("terminal_shell_icon_runtime.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const widgets = @import("../../ui/widgets.zig");

const TerminalTabLabelModel = struct {
    raw_title: []const u8,
    foreground_process_command: []const u8,
    foreground_process_label: []const u8,
    cwd: []const u8,
    shell_path: []const u8,
    progress_state: terminal_runtime.ProgressState,
    progress_value: ?u8,
};

fn terminalTabBaseLabel(title: []const u8, cwd: []const u8) []const u8 {
    if (title.len > 0 and !std.mem.eql(u8, title, "Terminal")) return title;

    if (cwd.len > 0) {
        if (std.mem.eql(u8, cwd, "/")) return "/";
        const trimmed = std.mem.trimRight(u8, cwd, "/");
        if (trimmed.len > 0) {
            if (std.mem.lastIndexOfScalar(u8, trimmed, '/')) |slash| {
                if (slash + 1 < trimmed.len) return trimmed[slash + 1 ..];
            } else {
                return trimmed;
            }
        }
    }
    if (title.len > 0) return title;
    return "Terminal";
}

fn compactCwdLabel(cwd: []const u8) []const u8 {
    if (cwd.len == 0) return "";
    if (std.mem.eql(u8, cwd, "/")) return "/";
    const trimmed = std.mem.trimRight(u8, cwd, "/");
    if (trimmed.len == 0) return "";
    if (std.mem.lastIndexOfScalar(u8, trimmed, '/')) |slash| {
        if (slash + 1 < trimmed.len) return trimmed[slash + 1 ..];
    }
    return trimmed;
}

fn appendProgressPrefix(
    allocator: std.mem.Allocator,
    scratch: *std.ArrayList(u8),
    model: TerminalTabLabelModel,
) !void {
    switch (model.progress_state) {
        .set => if (model.progress_value) |value| try scratch.writer(allocator).print("{d}% ", .{value}),
        .@"error" => if (model.progress_value) |value| try scratch.writer(allocator).print("!{d}% ", .{value}) else try scratch.appendSlice(allocator, "! "),
        .pause => if (model.progress_value) |value| try scratch.writer(allocator).print("||{d}% ", .{value}) else try scratch.appendSlice(allocator, "|| "),
        .indeterminate => try scratch.appendSlice(allocator, "... "),
        .none => {},
    }
}

fn terminalTabLabelModel(entry: terminal_runtime.TerminalTabSyncEntry, strings: []const u8) TerminalTabLabelModel {
    return .{
        .raw_title = entry.title(strings),
        .foreground_process_command = entry.foregroundProcessCommand(strings),
        .foreground_process_label = entry.foregroundProcessLabel(strings),
        .cwd = entry.cwd(strings),
        .shell_path = entry.shellPath(strings),
        .progress_state = entry.progress_state,
        .progress_value = entry.progress_value,
    };
}

fn terminalTabLabel(
    allocator: std.mem.Allocator,
    scratch: *std.ArrayList(u8),
    model: TerminalTabLabelModel,
) ![]const u8 {
    const title = if (model.foreground_process_command.len > 0)
        model.foreground_process_command
    else if (model.foreground_process_label.len > 0)
        model.foreground_process_label
    else
        model.raw_title;
    const base = terminalTabBaseLabel(title, model.cwd);
    const cwd_label = compactCwdLabel(model.cwd);
    scratch.clearRetainingCapacity();
    try appendProgressPrefix(allocator, scratch, model);
    try scratch.appendSlice(allocator, base);
    if (cwd_label.len > 0 and !std.mem.eql(u8, cwd_label, base) and std.mem.indexOf(u8, base, cwd_label) == null) {
        try scratch.appendSlice(allocator, " · ");
        try scratch.appendSlice(allocator, cwd_label);
    }
    return scratch.items;
}

fn hasTabId(entries: []const terminal_runtime.TerminalTabSyncEntry, tab_id: u64) bool {
    for (entries) |entry| {
        if (entry.id == tab_id) return true;
    }
    return false;
}

pub fn syncFromWorkspace(
    tab_bar: *widgets.TabBar,
    terminal_workspace: *?terminal_runtime.TerminalWorkspace,
    show_shell_icon: bool,
    shell_icons: ?[]const config_mod.TerminalShellIconMapping,
) !void {
    if (terminal_workspace.*) |*workspace| {
        var entry_buf = std.ArrayList(terminal_runtime.TerminalTabSyncEntry).empty;
        defer entry_buf.deinit(tab_bar.allocator);
        var string_buf = std.ArrayList(u8).empty;
        defer string_buf.deinit(tab_bar.allocator);
        var label_buf = std.ArrayList(u8).empty;
        defer label_buf.deinit(tab_bar.allocator);
        const sync_state = try workspace.copyTabSyncState(tab_bar.allocator, &entry_buf, &string_buf);

        var has_non_terminal = false;
        for (tab_bar.tabs.items) |tab| {
            if (tab.kind != .terminal) {
                has_non_terminal = true;
                break;
            }
        }
        if (has_non_terminal) {
            tab_bar.clearTabs();
        }

        // Remove tabs that no longer exist in workspace.
        var i: usize = tab_bar.tabs.items.len;
        while (i > 0) {
            i -= 1;
            const tab = tab_bar.tabs.items[i];
            if (tab.kind != .terminal) {
                tab_bar.removeTabAt(i);
                continue;
            }
            const tab_id = tab.terminal_tab_id orelse {
                tab_bar.removeTabAt(i);
                continue;
            };
            if (!hasTabId(sync_state.tabs, tab_id)) tab_bar.removeTabAt(i);
        }

        // Add missing tabs and refresh titles while preserving current visual order.
        for (sync_state.tabs) |entry| {
            const label_model = terminalTabLabelModel(entry, sync_state.strings);
            const title = try terminalTabLabel(
                tab_bar.allocator,
                &label_buf,
                label_model,
            );
            const icon_path = app_terminal_shell_icon_runtime.resolveIconPath(
                show_shell_icon,
                shell_icons,
                label_model.shell_path,
            );
            const tab_id = entry.id;
            if (tab_bar.indexOfTerminalTabId(tab_id)) |bar_idx| {
                try tab_bar.setTabTitle(bar_idx, title);
                try tab_bar.setTabIconPath(bar_idx, icon_path);
            } else {
                try tab_bar.addTerminalTab(title, tab_id);
                try tab_bar.setTabIconPath(tab_bar.tabs.items.len - 1, icon_path);
            }
        }

        // Ensure active index mirrors workspace active tab.
        if (sync_state.active_tab_id) |active_id| {
            tab_bar.active_index = tab_bar.indexOfTerminalTabId(active_id) orelse 0;
        } else {
            tab_bar.active_index = 0;
        }
    } else {
        tab_bar.clearTabs();
    }
}

test "terminal tab label prefixes determinate progress" {
    var scratch = std.ArrayList(u8).empty;
    defer scratch.deinit(std.testing.allocator);

    const label = try terminalTabLabel(
        std.testing.allocator,
        &scratch,
        .{
            .raw_title = "zig build",
            .foreground_process_command = "",
            .foreground_process_label = "",
            .cwd = "/tmp/work",
            .progress_state = .set,
            .progress_value = 42,
        },
    );

    try std.testing.expectEqualStrings("42% zig build", label);
}

test "terminal tab label prefers rich command summary and cwd context" {
    var scratch = std.ArrayList(u8).empty;
    defer scratch.deinit(std.testing.allocator);

    const label = try terminalTabLabel(
        std.testing.allocator,
        &scratch,
        .{
            .raw_title = "Terminal",
            .foreground_process_command = "codex resume --search ...",
            .foreground_process_label = "codex",
            .cwd = "/workspace/zide",
            .progress_state = .none,
            .progress_value = null,
        },
    );

    try std.testing.expectEqualStrings("codex resume --search ... · zide", label);
}
