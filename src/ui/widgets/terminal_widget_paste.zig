const std = @import("std");

const app_logger = @import("../../app_logger.zig");
const session_content = @import("../../terminal/core/session/content.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const session_interaction = @import("../../terminal/core/session/interaction.zig");

pub fn pasteSystemClipboard(
    widget: anytype,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) bool {
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    if (widget.draw_cache.scroll_offset > 0) {
        session_content.setScrollOffset(widget.session, 0);
    }

    return pasteClipboardWithPolicy(widget, clip_opt, html, uri_list, png, .system) catch false;
}

pub fn pasteSelectionClipboard(
    widget: anytype,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) bool {
    return pasteClipboardWithPolicy(widget, clip_opt, html, uri_list, png, .selection) catch false;
}

const PasteSource = enum {
    system,
    selection,
};

fn pasteClipboardWithPolicy(
    widget: anytype,
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

    if (try session_interaction.sendKittyPasteEvent5522WithMimeRich(widget.session, clip, html, uri_list, png)) {
        return true;
    }

    const clip_text = clip_opt orelse return false;
    if (session_interaction.bracketedPasteEnabled(widget.session)) {
        const payload = switch (source) {
            .system => filterBracketedPaste(widget.session.allocator, clip_text) catch |err| {
                log.logf(.warning, "paste filter failed source={s} err={s}", .{ @tagName(source), @errorName(err) });
                return false;
            },
            .selection => clip_text,
        };
        defer if (source == .system and payload.ptr != clip_text.ptr) widget.session.allocator.free(payload);

        session_input.sendText(widget.session, "\x1b[200~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed prefix source={s} err={s}", .{ @tagName(source), @errorName(err) });
            return false;
        };
        if (payload.len > 0) {
            session_input.sendText(widget.session, payload) catch |err| {
                log.logf(.warning, "paste failed sending payload source={s} err={s}", .{ @tagName(source), @errorName(err) });
                return false;
            };
        }
        session_input.sendText(widget.session, "\x1b[201~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed suffix source={s} err={s}", .{ @tagName(source), @errorName(err) });
            return false;
        };
        return true;
    }

    session_input.sendText(widget.session, clip_text) catch |err| {
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
