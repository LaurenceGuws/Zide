const std = @import("std");
const builtin = @import("builtin");

const terminal_mod = @import("../../terminal/core/terminal.zig");
const hover_mod = @import("terminal_widget_hover.zig");

const TerminalSession = terminal_mod.TerminalSession;
const Cell = terminal_mod.Cell;

pub const PendingOpen = struct {
    path: []u8,
    line: ?usize = null, // 1-based
    col: ?usize = null, // 1-based
};

pub fn ctrlClickOpenMaybe(
    allocator: std.mem.Allocator,
    session: *TerminalSession,
    pending_open: *?PendingOpen,
    snapshot: terminal_mod.TerminalSnapshot,
    history_len: usize,
    start_line: usize,
    rows: usize,
    cols: usize,
    x: f32,
    y: f32,
    mouse_x: f32,
    mouse_y: f32,
    cell_width: f32,
    cell_height: f32,
) bool {
    if (rows == 0 or cols == 0) return false;
    if (cell_width <= 0 or cell_height <= 0) return false;

    const col = @as(usize, @intFromFloat((mouse_x - x) / cell_width));
    const row = @as(usize, @intFromFloat((mouse_y - y) / cell_height));
    if (row >= rows or col >= cols) return false;

    // Try hyperlink first.
    var opened = false;
    const link_id = hover_mod.linkIdAtCell(session, snapshot, history_len, start_line, rows, cols, row, col);
    if (link_id != 0) {
        if (session.hyperlinkUri(link_id)) |link| {
            if (resolveLinkPath(allocator, session, link)) |path| {
                setPendingOpen(allocator, pending_open, .{ .path = path });
                opened = true;
            }
        }
    }

    if (opened) return true;

    // Fallback: extract a token under the mouse.
    if (rowCellsAtVisibleRow(session, snapshot, history_len, start_line, rows, cols, row)) |row_cells| {
        if (extractTokenAtCol(allocator, row_cells, col)) |token| {
            defer allocator.free(token);
            if (parsePathAndLocation(token)) |parsed| {
                // Resolve to an absolute path when possible.
                var resolved: ?[]u8 = null;
                if (builtin.os.tag == .windows and isWindowsAbsPath(parsed.path)) {
                    resolved = allocator.dupe(u8, parsed.path) catch null;
                } else if (std.mem.startsWith(u8, parsed.path, "file://") or (parsed.path.len > 0 and parsed.path[0] == '/')) {
                    resolved = resolveLinkPath(allocator, session, parsed.path);
                } else {
                    const cwd = session.currentCwd();
                    if (cwd.len > 0) {
                        resolved = std.fs.path.join(allocator, &.{ cwd, parsed.path }) catch null;
                    } else {
                        resolved = allocator.dupe(u8, parsed.path) catch null;
                    }
                }

                if (resolved) |path| {
                    setPendingOpen(allocator, pending_open, .{ .path = path, .line = parsed.line, .col = parsed.col });
                    return true;
                }
            }
        }
    }

    return false;
}

fn setPendingOpen(allocator: std.mem.Allocator, pending_open: *?PendingOpen, req: PendingOpen) void {
    if (pending_open.*) |old| {
        allocator.free(old.path);
    }
    pending_open.* = req;
}

fn decodePercent(allocator: std.mem.Allocator, text: []const u8) ?[]u8 {
    if (text.len == 0) return allocator.dupe(u8, "") catch null;
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const b = text[i];
        if (b == '%' and i + 2 < text.len) {
            const hi = std.fmt.charToDigit(text[i + 1], 16) catch return null;
            const lo = std.fmt.charToDigit(text[i + 2], 16) catch return null;
            _ = out.append(allocator, @as(u8, (hi << 4) | lo)) catch return null;
            i += 2;
            continue;
        }
        _ = out.append(allocator, b) catch return null;
    }
    return out.toOwnedSlice(allocator) catch null;
}

fn resolveLinkPath(allocator: std.mem.Allocator, session: *TerminalSession, uri: []const u8) ?[]u8 {
    if (uri.len == 0) return null;
    if (builtin.os.tag == .windows) {
        if (isWindowsAbsPath(uri)) {
            return allocator.dupe(u8, uri) catch null;
        }
    }
    if (std.mem.startsWith(u8, uri, "file://")) {
        var rest = uri["file://".len..];
        if (rest.len == 0) return null;
        if (rest[0] != '/') {
            if (std.mem.indexOfScalar(u8, rest, '/')) |slash| {
                const host = rest[0..slash];
                if (!(host.len == 0 or std.mem.eql(u8, host, "localhost"))) return null;
                rest = rest[slash..];
            } else {
                return null;
            }
        }
        const decoded = decodePercent(allocator, rest) orelse return null;
        if (builtin.os.tag == .windows) {
            const normalized = normalizeWindowsFileUriPath(allocator, decoded) orelse decoded;
            if (normalized.ptr != decoded.ptr) allocator.free(decoded);
            return normalized;
        }
        return decoded;
    }
    if (uri[0] == '/') {
        return allocator.dupe(u8, uri) catch null;
    }
    const cwd = session.currentCwd();
    if (cwd.len == 0) return null;
    return std.fs.path.join(allocator, &.{ cwd, uri }) catch null;
}

fn isWindowsAbsPath(text: []const u8) bool {
    if (text.len >= 3 and std.ascii.isAlphabetic(text[0]) and text[1] == ':' and (text[2] == '\\' or text[2] == '/')) return true;
    if (text.len >= 2 and text[0] == '\\' and text[1] == '\\') return true; // UNC
    return false;
}

fn normalizeWindowsFileUriPath(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    // Common patterns produced by file:// URIs:
    // - /C:/foo/bar  -> C:/foo/bar
    // - /c:/foo/bar  -> c:/foo/bar
    if (path.len >= 4 and path[0] == '/' and std.ascii.isAlphabetic(path[1]) and path[2] == ':' and path[3] == '/') {
        return allocator.dupe(u8, path[1..]) catch null;
    }
    return null;
}

fn rowCellsAtVisibleRow(
    session: *TerminalSession,
    snapshot: terminal_mod.TerminalSnapshot,
    history_len: usize,
    start_line: usize,
    rows: usize,
    cols: usize,
    row: usize,
) ?[]const Cell {
    if (rows == 0 or cols == 0) return null;
    if (row >= rows) return null;
    const global_row = start_line + row;
    if (global_row < history_len) {
        if (session.scrollbackRow(global_row)) |history_row| return history_row;
        return null;
    }
    const grid_row = global_row - history_len;
    if (grid_row < rows and snapshot.cells.len >= rows * cols) {
        return snapshot.cells[grid_row * cols .. grid_row * cols + cols];
    }
    return null;
}

fn isTokenChar(cp: u32) bool {
    if (cp < 128) {
        const ch: u8 = @intCast(cp);
        if (std.ascii.isAlphanumeric(ch)) return true;
        return switch (ch) {
            '/', '\\', '.', '_', '-', '+', ':', '@', '~', '%', '=', '#', '$' => true,
            else => false,
        };
    }
    return false;
}

fn extractTokenAtCol(allocator: std.mem.Allocator, row_cells: []const Cell, col: usize) ?[]u8 {
    if (col >= row_cells.len) return null;
    if (row_cells[col].codepoint == 0) return null;
    if (!isTokenChar(row_cells[col].codepoint)) return null;

    var start: usize = col;
    while (start > 0) {
        const prev = row_cells[start - 1];
        if (prev.codepoint == 0 or !isTokenChar(prev.codepoint)) break;
        start -= 1;
    }
    var end: usize = col;
    while (end + 1 < row_cells.len) {
        const next = row_cells[end + 1];
        if (next.codepoint == 0 or !isTokenChar(next.codepoint)) break;
        end += 1;
    }

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var i: usize = start;
    while (i <= end and i < row_cells.len) : (i += 1) {
        const cell = row_cells[i];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0) continue;
        var buf: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
        if (n > 0) {
            out.appendSlice(allocator, buf[0..n]) catch return null;
        }
    }
    var token = out.toOwnedSlice(allocator) catch return null;

    // Trim common punctuation around terminal paths.
    while (token.len > 0) {
        const c0 = token[0];
        if (c0 == '(' or c0 == '[' or c0 == '{' or c0 == '<' or c0 == '"' or c0 == '\'' or c0 == '`') {
            token = token[1..];
            continue;
        }
        break;
    }
    while (token.len > 0) {
        const c1 = token[token.len - 1];
        if (c1 == ')' or c1 == ']' or c1 == '}' or c1 == '>' or c1 == ',' or c1 == ';' or c1 == '"' or c1 == '\'' or c1 == '`') {
            token = token[0 .. token.len - 1];
            continue;
        }
        break;
    }
    if (token.len == 0) return null;
    return allocator.dupe(u8, token) catch null;
}

const ParsedPath = struct {
    path: []const u8,
    line: ?usize,
    col: ?usize,
};

fn parsePathAndLocation(token: []const u8) ?ParsedPath {
    if (token.len == 0) return null;
    if (std.mem.indexOf(u8, token, "://") != null and !std.mem.startsWith(u8, token, "file://")) return null;

    var base = token;
    var line: ?usize = null;
    var col: ?usize = null;

    // Parse trailing :<num>[:<num>] without confusing drive letters.
    var tmp = base;
    if (std.mem.lastIndexOfScalar(u8, tmp, ':')) |idx2| {
        const tail2 = tmp[idx2 + 1 ..];
        if (tail2.len > 0 and allDigits(tail2)) {
            const n2 = std.fmt.parseInt(usize, tail2, 10) catch null;
            if (n2 != null) {
                tmp = tmp[0..idx2];
                if (std.mem.lastIndexOfScalar(u8, tmp, ':')) |idx1| {
                    const tail1 = tmp[idx1 + 1 ..];
                    if (tail1.len > 0 and allDigits(tail1)) {
                        const n1 = std.fmt.parseInt(usize, tail1, 10) catch null;
                        if (n1 != null) {
                            base = tmp[0..idx1];
                            line = n1.?;
                            col = n2.?;
                            return .{ .path = base, .line = line, .col = col };
                        }
                    }
                }
                base = tmp;
                line = n2.?;
                col = null;
            }
        }
    }

    return .{ .path = base, .line = line, .col = col };
}

fn allDigits(text: []const u8) bool {
    for (text) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return text.len > 0;
}
