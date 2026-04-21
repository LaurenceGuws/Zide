const std = @import("std");

const app_logger = @import("../../app_logger.zig");
const input_adapter_mod = @import("terminal_widget_input_bridge.zig");

pub fn pasteSystemClipboard(
    widget: anytype,
    input_adapter: *const input_adapter_mod.TerminalInputAdapter,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) bool {
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    if (widget.publication.model().viewport.scroll_offset > 0) {
        input_adapter.setScrollOffset(0);
    }

    return pasteClipboardWithPolicy(input_adapter, clip_opt, html, uri_list, png, .system) catch false;
}

pub fn pasteSelectionClipboard(
    input_adapter: *const input_adapter_mod.TerminalInputAdapter,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) bool {
    return pasteClipboardWithPolicy(input_adapter, clip_opt, html, uri_list, png, .selection) catch false;
}

const PasteSource = enum {
    system,
    selection,
};

fn pasteClipboardWithPolicy(
    input_adapter: *const input_adapter_mod.TerminalInputAdapter,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
    source: PasteSource,
) !bool {
    const log = app_logger.logger("terminal.widget");
    const clip = clip_opt orelse "";
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    if (try input_adapter.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png)) {
        return true;
    }

    const clip_text = clip_opt orelse return false;
    if (input_adapter.bracketedPasteEnabled()) {
        const payload = switch (source) {
            .system => filterBracketedPaste(input_adapter.allocator(), clip_text) catch |err| {
                log.logf(.warning, "paste filter failed source={s} err={s}", .{ @tagName(source), @errorName(err) });
                return false;
            },
            .selection => clip_text,
        };
        defer if (source == .system and payload.ptr != clip_text.ptr) input_adapter.allocator().free(payload);

        input_adapter.sendText("\x1b[200~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed prefix source={s} err={s}", .{ @tagName(source), @errorName(err) });
            return false;
        };
        if (payload.len > 0) {
            input_adapter.sendText(payload) catch |err| {
                log.logf(.warning, "paste failed sending payload source={s} err={s}", .{ @tagName(source), @errorName(err) });
                return false;
            };
        }
        input_adapter.sendText("\x1b[201~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed suffix source={s} err={s}", .{ @tagName(source), @errorName(err) });
            return false;
        };
        return true;
    }

    input_adapter.sendText(clip_text) catch |err| {
        log.logf(.warning, "paste failed sending clipboard source={s} err={s}", .{ @tagName(source), @errorName(err) });
        return false;
    };
    return true;
}

fn filterBracketedPaste(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var filtered = std.ArrayList(u8).empty;
    defer filtered.deinit(allocator);
    for (text) |b| {
        if (b == 0x1b or b == 0x03) continue;
        try filtered.append(allocator, b);
    }
    return try allocator.dupe(u8, filtered.items);
}
