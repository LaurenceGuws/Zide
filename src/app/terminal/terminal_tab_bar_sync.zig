const std = @import("std");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const widgets = @import("../../ui/widgets.zig");

fn terminalTabLabel(title: []const u8, cwd: []const u8) []const u8 {
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

fn hasTabId(entries: []const terminal_mod.TerminalTabSyncEntry, tab_id: u64) bool {
    for (entries) |entry| {
        if (entry.id == tab_id) return true;
    }
    return false;
}

pub fn syncFromWorkspace(
    tab_bar: *widgets.TabBar,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
) !void {
    if (terminal_workspace.*) |*workspace| {
        var entry_buf = std.ArrayList(terminal_mod.TerminalTabSyncEntry).empty;
        defer entry_buf.deinit(tab_bar.allocator);
        var string_buf = std.ArrayList(u8).empty;
        defer string_buf.deinit(tab_bar.allocator);
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
            const title = terminalTabLabel(entry.title(sync_state.strings), entry.cwd(sync_state.strings));
            const tab_id = entry.id;
            if (tab_bar.indexOfTerminalTabId(tab_id)) |bar_idx| {
                try tab_bar.setTabTitle(bar_idx, title);
            } else {
                try tab_bar.addTerminalTab(title, tab_id);
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
