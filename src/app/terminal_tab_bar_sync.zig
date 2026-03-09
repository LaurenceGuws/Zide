const std = @import("std");
const terminal_mod = @import("../terminal/core/terminal.zig");
const widgets = @import("../ui/widgets.zig");

fn terminalTabLabel(metadata: terminal_mod.TerminalTabMetadata) []const u8 {
    const title = metadata.title;
    if (title.len > 0 and !std.mem.eql(u8, title, "Terminal")) return title;

    const cwd = metadata.cwd;
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

pub fn syncFromWorkspace(
    tab_bar: *widgets.TabBar,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
) !void {
    if (terminal_workspace.*) |*workspace| {
        const count = workspace.tabCount();
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
            var found = false;
            for (0..count) |widx| {
                if (workspace.tabIdAt(widx)) |wid| {
                    if (wid == tab_id) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found) tab_bar.removeTabAt(i);
        }

        // Add missing tabs and refresh titles while preserving current visual order.
        for (0..count) |widx| {
            const tab_id = workspace.tabIdAt(widx) orelse continue;
            const metadata = workspace.metadataAt(widx) orelse continue;
            const title = terminalTabLabel(metadata);
            if (tab_bar.indexOfTerminalTabId(tab_id)) |bar_idx| {
                try tab_bar.setTabTitle(bar_idx, title);
            } else {
                try tab_bar.addTerminalTab(title, tab_id);
            }
        }

        // Ensure active index mirrors workspace active tab.
        if (workspace.activeTabId()) |active_id| {
            tab_bar.active_index = tab_bar.indexOfTerminalTabId(active_id) orelse 0;
        } else {
            tab_bar.active_index = 0;
        }
    } else {
        tab_bar.clearTabs();
    }
}
