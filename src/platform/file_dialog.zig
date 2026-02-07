const std = @import("std");
const builtin = @import("builtin");

pub const OpenOptions = struct {
    title: ?[]const u8 = null,
    // If null, uses current working directory.
    initial_dir: ?[]const u8 = null,
};

pub const SaveOptions = struct {
    title: ?[]const u8 = null,
    initial_dir: ?[]const u8 = null,
    default_name: ?[]const u8 = null,
};

pub fn openFileDialog(allocator: std.mem.Allocator, options: OpenOptions) !?[]u8 {
    if (builtin.os.tag != .windows) {
        return null;
    }
    return windowsOpenFileDialog(allocator, options);
}

pub fn saveFileDialog(allocator: std.mem.Allocator, options: SaveOptions) !?[]u8 {
    if (builtin.os.tag != .windows) {
        return null;
    }
    return windowsSaveFileDialog(allocator, options);
}

const win32 = if (builtin.os.tag == .windows) struct {
    const BOOL = i32;
    const TRUE: BOOL = 1;
    const FALSE: BOOL = 0;

    const DWORD = u32;
    const WORD = u16;
    const HWND = ?*anyopaque;
    const LPCWSTR = [*:0]const u16;
    const LPWSTR = [*:0]u16;

    const OPENFILENAMEW = extern struct {
        lStructSize: DWORD,
        hwndOwner: HWND,
        hInstance: ?*anyopaque,
        lpstrFilter: ?LPCWSTR,
        lpstrCustomFilter: ?LPWSTR,
        nMaxCustFilter: DWORD,
        nFilterIndex: DWORD,
        lpstrFile: ?LPWSTR,
        nMaxFile: DWORD,
        lpstrFileTitle: ?LPWSTR,
        nMaxFileTitle: DWORD,
        lpstrInitialDir: ?LPCWSTR,
        lpstrTitle: ?LPCWSTR,
        Flags: DWORD,
        nFileOffset: WORD,
        nFileExtension: WORD,
        lpstrDefExt: ?LPCWSTR,
        lCustData: usize,
        lpfnHook: ?*anyopaque,
        lpTemplateName: ?LPCWSTR,
        pvReserved: ?*anyopaque,
        dwReserved: DWORD,
        FlagsEx: DWORD,
    };

    const OFN_EXPLORER: DWORD = 0x00080000;
    const OFN_FILEMUSTEXIST: DWORD = 0x00001000;
    const OFN_PATHMUSTEXIST: DWORD = 0x00000800;
    const OFN_NOCHANGEDIR: DWORD = 0x00000008;
    const OFN_OVERWRITEPROMPT: DWORD = 0x00000002;

    extern "comdlg32" fn GetOpenFileNameW(ofn: *OPENFILENAMEW) callconv(.winapi) BOOL;
    extern "comdlg32" fn GetSaveFileNameW(ofn: *OPENFILENAMEW) callconv(.winapi) BOOL;
    extern "comdlg32" fn CommDlgExtendedError() callconv(.winapi) DWORD;
} else struct {};

fn utf8ToUtf16LeZAlloc(allocator: std.mem.Allocator, s: []const u8) ![:0]u16 {
    const tmp = try std.unicode.utf8ToUtf16LeAlloc(allocator, s);
    defer allocator.free(tmp);
    var buf = try allocator.alloc(u16, tmp.len + 1);
    std.mem.copyForwards(u16, buf[0..tmp.len], tmp);
    buf[tmp.len] = 0;
    return buf[0..tmp.len :0];
}

fn utf16LeZToUtf8Alloc(allocator: std.mem.Allocator, s: [:0]const u16) ![]u8 {
    const slice = std.mem.sliceTo(s, 0);
    return std.unicode.utf16LeToUtf8Alloc(allocator, slice);
}

fn windowsOpenFileDialog(allocator: std.mem.Allocator, options: OpenOptions) !?[]u8 {
    // Use a fixed-size buffer for simplicity; Windows common dialogs fill it.
    var file_buf: [4096]u16 = undefined;
    @memset(&file_buf, 0);

    var title_w: ?[:0]u16 = null;
    defer if (title_w) |buf| allocator.free(buf);
    if (options.title) |t| title_w = try utf8ToUtf16LeZAlloc(allocator, t);

    var dir_w: ?[:0]u16 = null;
    defer if (dir_w) |buf| allocator.free(buf);
    if (options.initial_dir) |d| dir_w = try utf8ToUtf16LeZAlloc(allocator, d);

    // Filter string: pairs of null-terminated strings, terminated by an extra null.
    // Here: "All Files\0*.*\0\0".
    const filter = [_:0]u16{ 'A', 'l', 'l', ' ', 'F', 'i', 'l', 'e', 's', 0, '*', '.', '*', 0, 0 };

    var ofn: win32.OPENFILENAMEW = .{
        .lStructSize = @sizeOf(win32.OPENFILENAMEW),
        .hwndOwner = null,
        .hInstance = null,
        .lpstrFilter = @ptrCast(&filter),
        .lpstrCustomFilter = null,
        .nMaxCustFilter = 0,
        .nFilterIndex = 1,
        .lpstrFile = @ptrCast(&file_buf),
        .nMaxFile = @intCast(file_buf.len),
        .lpstrFileTitle = null,
        .nMaxFileTitle = 0,
        .lpstrInitialDir = if (dir_w) |buf| @ptrCast(buf.ptr) else null,
        .lpstrTitle = if (title_w) |buf| @ptrCast(buf.ptr) else null,
        .Flags = win32.OFN_EXPLORER | win32.OFN_FILEMUSTEXIST | win32.OFN_PATHMUSTEXIST | win32.OFN_NOCHANGEDIR,
        .nFileOffset = 0,
        .nFileExtension = 0,
        .lpstrDefExt = null,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
        .pvReserved = null,
        .dwReserved = 0,
        .FlagsEx = 0,
    };

    if (win32.GetOpenFileNameW(&ofn) == win32.FALSE) {
        const ext = win32.CommDlgExtendedError();
        if (ext == 0) return null; // user canceled
        return error.FileDialogFailed;
    }

    const selected: [:0]const u16 = std.mem.sliceTo(@as([*:0]const u16, @ptrCast(&file_buf)), 0);
    return utf16LeZToUtf8Alloc(allocator, selected);
}

fn windowsSaveFileDialog(allocator: std.mem.Allocator, options: SaveOptions) !?[]u8 {
    var file_buf: [4096]u16 = undefined;
    @memset(&file_buf, 0);

    if (options.default_name) |name| {
        const tmp = try std.unicode.utf8ToUtf16LeAlloc(allocator, name);
        defer allocator.free(tmp);
        const n = @min(tmp.len, file_buf.len - 1);
        std.mem.copyForwards(u16, file_buf[0..n], tmp[0..n]);
        file_buf[n] = 0;
    }

    var title_w: ?[:0]u16 = null;
    defer if (title_w) |buf| allocator.free(buf);
    if (options.title) |t| title_w = try utf8ToUtf16LeZAlloc(allocator, t);

    var dir_w: ?[:0]u16 = null;
    defer if (dir_w) |buf| allocator.free(buf);
    if (options.initial_dir) |d| dir_w = try utf8ToUtf16LeZAlloc(allocator, d);

    const filter = [_:0]u16{ 'A', 'l', 'l', 'F', 'i', 'l', 'e', 's', 0, '*', '.', '*', 0, 0 };

    var ofn: win32.OPENFILENAMEW = .{
        .lStructSize = @sizeOf(win32.OPENFILENAMEW),
        .hwndOwner = null,
        .hInstance = null,
        .lpstrFilter = @ptrCast(&filter),
        .lpstrCustomFilter = null,
        .nMaxCustFilter = 0,
        .nFilterIndex = 1,
        .lpstrFile = @ptrCast(&file_buf),
        .nMaxFile = @intCast(file_buf.len),
        .lpstrFileTitle = null,
        .nMaxFileTitle = 0,
        .lpstrInitialDir = if (dir_w) |buf| @ptrCast(buf.ptr) else null,
        .lpstrTitle = if (title_w) |buf| @ptrCast(buf.ptr) else null,
        .Flags = win32.OFN_EXPLORER | win32.OFN_PATHMUSTEXIST | win32.OFN_NOCHANGEDIR | win32.OFN_OVERWRITEPROMPT,
        .nFileOffset = 0,
        .nFileExtension = 0,
        .lpstrDefExt = null,
        .lCustData = 0,
        .lpfnHook = null,
        .lpTemplateName = null,
        .pvReserved = null,
        .dwReserved = 0,
        .FlagsEx = 0,
    };

    if (win32.GetSaveFileNameW(&ofn) == win32.FALSE) {
        const ext = win32.CommDlgExtendedError();
        if (ext == 0) return null; // user canceled
        return error.FileDialogFailed;
    }

    const selected: [:0]const u16 = std.mem.sliceTo(@as([*:0]const u16, @ptrCast(&file_buf)), 0);
    return utf16LeZToUtf8Alloc(allocator, selected);
}
