const std = @import("std");

pub const AppIdentity = struct {
    display_name: []const u8,
    app_id: []const u8,
    internal_name: []const u8,
    original_filename: []const u8,
    file_description: []const u8,
    product_name: []const u8 = "Zide",
    icon_png_path: []const u8,
};

const VersionInfo = struct {
    text: []const u8,
    major: u32,
    minor: u32,
    patch: u32,
    build: u32,
};

pub fn configureExecutableResources(
    b: *std.Build,
    step: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    artifact_name: []const u8,
) void {
    if (target.result.os.tag != .windows) return;

    const identity = identityForArtifact(artifact_name);
    const version = readVersionInfo(b);
    const icon_png = std.fs.cwd().readFileAlloc(
        b.allocator,
        identity.icon_png_path,
        16 * 1024 * 1024,
    ) catch @panic("failed to read Windows icon PNG");
    const icon_ico = buildIcoFromPng(b.allocator, icon_png) catch @panic("failed to build Windows ICO");

    const write_files = b.addWriteFiles();
    _ = write_files.add("app.ico", icon_ico);
    const rc_source = b.fmt(
        \\1 VERSIONINFO
        \\FILEVERSION {d},{d},{d},{d}
        \\PRODUCTVERSION {d},{d},{d},{d}
        \\FILEFLAGSMASK 0x3fL
        \\FILEFLAGS 0x0L
        \\FILEOS 0x40004L
        \\FILETYPE 0x1L
        \\FILESUBTYPE 0x0L
        \\BEGIN
        \\  BLOCK "StringFileInfo"
        \\  BEGIN
        \\    BLOCK "040904b0"
        \\    BEGIN
        \\      VALUE "CompanyName", "Laurence\0"
        \\      VALUE "FileDescription", "{s}\0"
        \\      VALUE "FileVersion", "{s}\0"
        \\      VALUE "InternalName", "{s}\0"
        \\      VALUE "OriginalFilename", "{s}\0"
        \\      VALUE "ProductName", "{s}\0"
        \\      VALUE "ProductVersion", "{s}\0"
        \\    END
        \\  END
        \\  BLOCK "VarFileInfo"
        \\  BEGIN
        \\    VALUE "Translation", 0x0409, 1200
        \\  END
        \\END
        \\
        \\APP_ICON ICON "app.ico"
        \\
    , .{
        version.major,
        version.minor,
        version.patch,
        version.build,
        version.major,
        version.minor,
        version.patch,
        version.build,
        identity.file_description,
        version.text,
        identity.internal_name,
        identity.original_filename,
        identity.product_name,
        version.text,
    });
    const rc_file = write_files.add("app.rc", rc_source);
    step.root_module.addWin32ResourceFile(.{ .file = rc_file });
}

pub fn identityForArtifact(name: []const u8) AppIdentity {
    if (std.mem.eql(u8, name, "zide-terminal")) {
        return .{
            .display_name = "Zide Terminal",
            .app_id = "LaurenceGuws.Zide.Terminal",
            .internal_name = "zide-terminal",
            .original_filename = "zide-terminal.exe",
            .file_description = "Zide Terminal",
            .icon_png_path = "assets/icon/zide_terminal_taskbar.png",
        };
    }
    if (std.mem.eql(u8, name, "zide-editor")) {
        return .{
            .display_name = "Zide Editor",
            .app_id = "LaurenceGuws.Zide.Editor",
            .internal_name = "zide-editor",
            .original_filename = "zide-editor.exe",
            .file_description = "Zide Editor",
            .icon_png_path = "assets/icon/color_icon.png",
        };
    }
    if (std.mem.eql(u8, name, "zide-ide")) {
        return .{
            .display_name = "Zide",
            .app_id = "LaurenceGuws.Zide",
            .internal_name = "zide-ide",
            .original_filename = "zide-ide.exe",
            .file_description = "Zide IDE",
            .icon_png_path = "assets/icon/color_icon.png",
        };
    }
    return .{
        .display_name = "Zide",
        .app_id = "LaurenceGuws.Zide",
        .internal_name = "zide",
        .original_filename = "zide.exe",
        .file_description = "Zide",
        .icon_png_path = "assets/icon/color_icon.png",
    };
}

fn readVersionInfo(b: *std.Build) VersionInfo {
    const zon = std.fs.cwd().readFileAlloc(b.allocator, "build.zig.zon", 1024 * 1024) catch
        @panic("failed to read build.zig.zon");
    const needle = ".version = \"";
    const start = std.mem.indexOf(u8, zon, needle) orelse
        @panic("missing version in build.zig.zon");
    const version_start = start + needle.len;
    const version_end_rel = std.mem.indexOfScalarPos(u8, zon, version_start, '"') orelse
        @panic("unterminated version in build.zig.zon");
    const version_text = zon[version_start..version_end_rel];

    const core_end = std.mem.indexOfScalar(u8, version_text, '-') orelse version_text.len;
    var core_it = std.mem.splitScalar(u8, version_text[0..core_end], '.');
    const major = std.fmt.parseUnsigned(u32, core_it.next() orelse @panic("missing major version"), 10) catch
        @panic("invalid major version");
    const minor = std.fmt.parseUnsigned(u32, core_it.next() orelse @panic("missing minor version"), 10) catch
        @panic("invalid minor version");
    const patch = std.fmt.parseUnsigned(u32, core_it.next() orelse @panic("missing patch version"), 10) catch
        @panic("invalid patch version");

    var build: u32 = 0;
    if (core_end < version_text.len) {
        var suffix_it = std.mem.splitScalar(u8, version_text[core_end + 1 ..], '.');
        while (suffix_it.next()) |token| {
            if (token.len == 0) continue;
            build = std.fmt.parseUnsigned(u32, token, 10) catch build;
        }
    }

    return .{
        .text = b.dupe(version_text),
        .major = major,
        .minor = minor,
        .patch = patch,
        .build = build,
    };
}

fn buildIcoFromPng(allocator: std.mem.Allocator, png_bytes: []const u8) ![]const u8 {
    const total_len = 22 + png_bytes.len;
    const ico = try allocator.alloc(u8, total_len);
    @memset(ico, 0);

    writeLe16(ico[0..2], 0);
    writeLe16(ico[2..4], 1);
    writeLe16(ico[4..6], 1);
    ico[6] = 0;
    ico[7] = 0;
    ico[8] = 0;
    ico[9] = 0;
    writeLe16(ico[10..12], 1);
    writeLe16(ico[12..14], 32);
    writeLe32(ico[14..18], @intCast(png_bytes.len));
    writeLe32(ico[18..22], 22);
    @memcpy(ico[22..], png_bytes);
    return ico;
}

fn writeLe16(dest: []u8, value: u16) void {
    dest[0] = @intCast(value & 0xff);
    dest[1] = @intCast((value >> 8) & 0xff);
}

fn writeLe32(dest: []u8, value: u32) void {
    dest[0] = @intCast(value & 0xff);
    dest[1] = @intCast((value >> 8) & 0xff);
    dest[2] = @intCast((value >> 16) & 0xff);
    dest[3] = @intCast((value >> 24) & 0xff);
}
