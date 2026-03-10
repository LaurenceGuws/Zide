const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn pasteSystemClipboard(
    self: anytype,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !bool {
    const log = app_logger.logger("terminal.widget");
    const clip = clip_opt orelse "";
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    if (self.renderCache().scroll_offset > 0) {
        self.setScrollOffset(0);
    }

    if (try self.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png)) {
        return true;
    }

    if (clip_opt == null) return false;

    if (self.bracketedPasteEnabled()) {
        self.sendText("\x1b[200~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed prefix err={s}", .{@errorName(err)});
            return false;
        };

        var filtered = std.ArrayList(u8).empty;
        defer filtered.deinit(self.allocator);
        for (clip_opt.?) |b| {
            if (b == 0x1b or b == 0x03) continue;
            filtered.append(self.allocator, b) catch {
                log.logf(.warning, "paste failed appending filtered clipboard byte", .{});
                return false;
            };
        }
        if (filtered.items.len > 0) {
            self.sendText(filtered.items) catch |err| {
                log.logf(.warning, "paste failed sending filtered clipboard err={s}", .{@errorName(err)});
                return false;
            };
        }
        self.sendText("\x1b[201~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed suffix err={s}", .{@errorName(err)});
            return false;
        };
        return true;
    }

    self.sendText(clip_opt.?) catch |err| {
        log.logf(.warning, "paste failed sending clipboard err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}
