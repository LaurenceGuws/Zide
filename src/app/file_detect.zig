const std = @import("std");

/// Cheap, no-I/O gate for ctrl+click open requests.
/// This intentionally avoids open/stat/read in UI input handling.
pub fn isProbablyTextFile(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    if (ext.len == 0) return true;
    const lower_ext = ext[1..];
    return !isKnownBinaryExtension(lower_ext);
}

fn isKnownBinaryExtension(ext: []const u8) bool {
    return std.ascii.eqlIgnoreCase(ext, "png") or
        std.ascii.eqlIgnoreCase(ext, "jpg") or
        std.ascii.eqlIgnoreCase(ext, "jpeg") or
        std.ascii.eqlIgnoreCase(ext, "gif") or
        std.ascii.eqlIgnoreCase(ext, "bmp") or
        std.ascii.eqlIgnoreCase(ext, "webp") or
        std.ascii.eqlIgnoreCase(ext, "ico") or
        std.ascii.eqlIgnoreCase(ext, "svgz") or
        std.ascii.eqlIgnoreCase(ext, "pdf") or
        std.ascii.eqlIgnoreCase(ext, "zip") or
        std.ascii.eqlIgnoreCase(ext, "gz") or
        std.ascii.eqlIgnoreCase(ext, "xz") or
        std.ascii.eqlIgnoreCase(ext, "bz2") or
        std.ascii.eqlIgnoreCase(ext, "7z") or
        std.ascii.eqlIgnoreCase(ext, "tar") or
        std.ascii.eqlIgnoreCase(ext, "jar") or
        std.ascii.eqlIgnoreCase(ext, "war") or
        std.ascii.eqlIgnoreCase(ext, "class") or
        std.ascii.eqlIgnoreCase(ext, "so") or
        std.ascii.eqlIgnoreCase(ext, "dll") or
        std.ascii.eqlIgnoreCase(ext, "dylib") or
        std.ascii.eqlIgnoreCase(ext, "o") or
        std.ascii.eqlIgnoreCase(ext, "a") or
        std.ascii.eqlIgnoreCase(ext, "exe") or
        std.ascii.eqlIgnoreCase(ext, "bin") or
        std.ascii.eqlIgnoreCase(ext, "wasm") or
        std.ascii.eqlIgnoreCase(ext, "ttf") or
        std.ascii.eqlIgnoreCase(ext, "otf") or
        std.ascii.eqlIgnoreCase(ext, "woff") or
        std.ascii.eqlIgnoreCase(ext, "woff2") or
        std.ascii.eqlIgnoreCase(ext, "mp3") or
        std.ascii.eqlIgnoreCase(ext, "wav") or
        std.ascii.eqlIgnoreCase(ext, "ogg") or
        std.ascii.eqlIgnoreCase(ext, "flac") or
        std.ascii.eqlIgnoreCase(ext, "mp4") or
        std.ascii.eqlIgnoreCase(ext, "mov") or
        std.ascii.eqlIgnoreCase(ext, "avi") or
        std.ascii.eqlIgnoreCase(ext, "mkv");
}
