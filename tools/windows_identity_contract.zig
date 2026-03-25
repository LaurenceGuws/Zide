const std = @import("std");

pub const PackageIdentity = struct {
    name: []const u8,
    publisher: []const u8,
    publisher_display_name: []const u8,
    display_name: []const u8,
    min_version: []const u8,
    max_version_tested: []const u8,
};

pub const ShellExtensionIdentity = struct {
    clsid: []const u8,
    verb_id: []const u8,
    title: []const u8,
    item_types: []const []const u8,
};

pub const ArtifactIdentity = struct {
    display_name: []const u8,
    app_id: []const u8,
    internal_name: []const u8,
    original_filename: []const u8,
    file_description: []const u8,
    product_name: []const u8 = "Zide",
    icon_png_path: []const u8,
    package_application_id: []const u8,
    package_description: []const u8,
};

pub const package_identity: PackageIdentity = .{
    .name = "LaurenceGuws.Zide",
    .publisher = "CN=Laurence",
    .publisher_display_name = "Laurence",
    .display_name = "Zide",
    .min_version = "10.0.19041.0",
    .max_version_tested = "10.0.26100.0",
};

pub const shell_extension_dll_name = "zide-shell-ext.dll";

pub const shell_extensions = [_]ShellExtensionIdentity{
    .{
        .clsid = "7A4A9F94-7A56-4B72-9D3A-0E4F1A0E6E11",
        .verb_id = "ZideFileMenu",
        .title = "Zide",
        .item_types = &.{"*"},
    },
    .{
        .clsid = "7D8E995A-2D37-48D8-AB12-4F03C6362D85",
        .verb_id = "ZideFolderMenu",
        .title = "Zide",
        .item_types = &.{"Directory"},
    },
    .{
        .clsid = "4C5D89A5-4E56-48E0-AE5A-8F4A5C6D1972",
        .verb_id = "ZideBackgroundTerminal",
        .title = "Open Zide Terminal here",
        .item_types = &.{"Directory\\Background"},
    },
};

pub fn identityForArtifact(name: []const u8) ArtifactIdentity {
    if (std.mem.eql(u8, name, "zide-terminal")) {
        return .{
            .display_name = "Zide Terminal",
            .app_id = "LaurenceGuws.Zide.Terminal",
            .internal_name = "zide-terminal",
            .original_filename = "zide-terminal.exe",
            .file_description = "Zide Terminal",
            .icon_png_path = "assets\\icon\\zide_terminal_taskbar.png",
            .package_application_id = "ZideTerminal",
            .package_description = "Zide Terminal",
        };
    }
    if (std.mem.eql(u8, name, "zide-editor")) {
        return .{
            .display_name = "Zide Editor",
            .app_id = "LaurenceGuws.Zide.Editor",
            .internal_name = "zide-editor",
            .original_filename = "zide-editor.exe",
            .file_description = "Zide Editor",
            .icon_png_path = "assets\\icon\\color_icon.png",
            .package_application_id = "ZideEditor",
            .package_description = "Zide Editor",
        };
    }
    if (std.mem.eql(u8, name, "zide-ide")) {
        return .{
            .display_name = "Zide",
            .app_id = "LaurenceGuws.Zide",
            .internal_name = "zide-ide",
            .original_filename = "zide-ide.exe",
            .file_description = "Zide IDE",
            .icon_png_path = "assets\\icon\\color_icon.png",
            .package_application_id = "ZideIde",
            .package_description = "Zide IDE",
        };
    }
    return .{
        .display_name = "Zide",
        .app_id = "LaurenceGuws.Zide",
        .internal_name = "zide",
        .original_filename = "zide.exe",
        .file_description = "Zide",
        .icon_png_path = "assets\\icon\\color_icon.png",
        .package_application_id = "Zide",
        .package_description = "Zide",
    };
}
