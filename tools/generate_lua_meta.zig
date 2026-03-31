const std = @import("std");
const meta = @import("zide_meta_root").config_meta;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const meta_path = if (args.len >= 2) args[1] else "lua/zide-meta.lua";
    const snippets_path = if (args.len >= 3) args[2] else "snippets/lua.json";
    const luarc_path = if (args.len >= 4) args[3] else ".luarc.json";

    const meta_lua = try renderMetaLua(allocator);
    defer allocator.free(meta_lua);
    const snippets = try renderSnippets(allocator);
    defer allocator.free(snippets);

    try writeFileEnsuringParent(meta_path, meta_lua);
    try writeFileEnsuringParent(snippets_path, snippets);
    try writeFileEnsuringParent(luarc_path, luarc_json);
}

fn writeFileEnsuringParent(path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir_path| {
        try std.fs.cwd().makePath(dir_path);
    }
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
}

fn renderMetaLua(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    try w.writeAll(
        \\---@meta
        \\
        \\---@alias ZideColor string|{ r: integer, g: integer, b: integer, a?: integer }
        \\
    );

    try renderEnumAlias(w, "ZideLogLevel", meta.LogLevel);
    try renderEnumAlias(w, "ZideOutputMode", meta.OutputMode);
    try renderEnumAlias(w, "ZideFontHinting", meta.FontHinting);
    try renderEnumAlias(w, "ZideGlyphOverflowPolicy", meta.GlyphOverflowPolicy);
    try renderEnumAlias(w, "ZideTerminalBlinkStyle", meta.TerminalBlinkStyle);
    try renderEnumAlias(w, "ZideLigatureStrategy", meta.LigatureStrategy);
    try renderEnumAlias(w, "ZideTerminalNewTabStartLocationMode", meta.TerminalNewTabStartLocationMode);
    try renderEnumAlias(w, "ZideTerminalWindowChromeMode", meta.TerminalWindowChromeMode);
    try renderEnumAlias(w, "ZideTabBarWidthMode", meta.TabBarWidthMode);
    try renderEnumAlias(w, "ZideEditorManualHighlightMode", meta.EditorManualHighlightMode);
    try renderEnumAlias(w, "ZideBindScope", meta.BindScope);
    try renderEnumAlias(w, "ZideActionKind", meta.ActionKind);
    try renderEnumAlias(w, "ZideKey", meta.Key);
    try renderStringAlias(w, "ZideModFlag", &meta.mod_flags);
    try renderEnumAlias(w, "ZideTerminalCursorShape", meta.TerminalCursorShape);
    try renderStringAlias(w, "ZideSdlLogLevel", &meta.sdl_log_levels);

    try w.writeAll("\n");
    for (meta.sections) |section| {
        try w.print("---@class {s}\n", .{section.class_name});
        if (section.doc.len > 0) {
            try w.print("--- {s}\n", .{section.doc});
        }
        for (section.fields) |field| {
            try w.print("---@field {s}? {s}", .{ field.name, field.type_expr });
            if (field.doc.len > 0) {
                try w.print(" {s}", .{field.doc});
            }
            try w.writeAll("\n");
        }
        try w.writeAll("\n");
    }

    try w.writeAll("---@class ZideConfig\n");
    for (meta.root_sections) |field| {
        try w.print("---@field {s}? {s}", .{ field.name, field.type_expr });
        if (field.doc.len > 0) {
            try w.print(" {s}", .{field.doc});
        }
        try w.writeAll("\n");
    }

    try w.writeAll(
        \\
        \\---@class ZideModule
        \\---@field config fun(opts: ZideConfig): ZideConfig
        \\
        \\---@type ZideModule
        \\local zide = {
        \\  config = function(opts)
        \\    return opts
        \\  end,
        \\}
        \\
        \\return zide
        \\
    );

    return out.toOwnedSlice(allocator);
}

fn renderEnumAlias(writer: anytype, alias_name: []const u8, comptime T: type) !void {
    try writer.print("---@alias {s} ", .{alias_name});
    const info = @typeInfo(T).@"enum";
    inline for (info.fields, 0..) |field, i| {
        if (i != 0) try writer.writeAll(" | ");
        try writer.print("\"{s}\"", .{field.name});
    }
    try writer.writeAll("\n");
}

fn renderStringAlias(writer: anytype, alias_name: []const u8, values: []const []const u8) !void {
    try writer.print("---@alias {s} ", .{alias_name});
    for (values, 0..) |value, i| {
        if (i != 0) try writer.writeAll(" | ");
        try writer.print("\"{s}\"", .{value});
    }
    try writer.writeAll("\n");
}

fn renderSnippets(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    try w.writeAll(
        \\{
        \\  "zide config": {
        \\    "prefix": "zide-config",
        \\    "body": [
        \\      "---@diagnostic disable: undefined-global",
        \\      "local mod",
        \\      "do",
        \\      "  local ok, loaded = pcall(require, \"zide-meta\")",
        \\      "  if ok and type(loaded) == \"table\" then",
        \\      "    mod = loaded",
        \\      "  end",
        \\      "end",
        \\      "---@type ZideModule",
        \\      "local zide",
        \\      "if mod then",
        \\      "  zide = mod",
        \\      "else",
        \\      "  zide = { config = function(opts) return opts end }",
        \\      "end",
        \\      "",
        \\      "---@type ZideConfig",
        \\      "return zide.config({",
        \\      "  log = {",
        \\      "    enable = { \"${1:app.core}\", \"${2:terminal.core}\" },",
        \\      "  },",
        \\      "  logs = {",
        \\      "    file_level = \"${3:info}\",",
        \\      "    console_level = \"${4:info}\",",
        \\      "  },",
        \\      "  sdl = {",
        \\      "    log_level = \"${5:info}\",",
        \\      "  },",
        \\      "  app = {",
        \\      "    font = {",
        \\      "      path = \"${6:assets/fonts/JetBrainsMonoNerdFont-Regular.ttf}\",",
        \\      "      size = ${7:16},",
        \\      "    },",
        \\      "  },",
        \\      "  editor = {",
        \\      "    wrap = ${8:false},",
        \\      "    imported_theme = \"${9:tokyonight-night}\",",
        \\      "    font = {",
        \\      "      path = \"${10:assets/fonts/JetBrainsMonoNerdFont-Regular.ttf}\",",
        \\      "      size = ${11:16},",
        \\      "    },",
        \\      "    theme = {",
        \\      "      syntax = {",
        \\      "        comment = \"${12:#636da6}\",",
        \\      "      },",
        \\      "    },",
        \\      "    tab_bar = {",
        \\      "      width_mode = \"${13:dynamic}\",",
        \\      "    },",
        \\      "  },",
        \\      "  terminal = {",
        \\      "    blink = \"${14:kitty}\",",
        \\      "    shell = {",
        \\      "      path = \"${15:/bin/bash}\",",
        \\      "      new_tab_start_location = \"${16:current}\",",
        \\      "    },",
        \\      "    tab_bar = {",
        \\      "      show_single_tab = ${17:false},",
        \\      "      width_mode = \"${18:dynamic}\",",
        \\      "      show_shell_icon = ${19:true},",
        \\      "    },",
        \\      "  },",
        \\      "  keybinds = {",
        \\      "    no_defaults = ${20:false},",
        \\      "    bindings = {",
        \\      "      { scope = \"global\", key = \"r\", mods = { \"ctrl\" }, action = \"reload_config\" },",
        \\      "    },",
        \\      "  },",
        \\      "})",
        \\      ""
        \\    ],
        \\    "description": "Full zide Lua config scaffold"
        \\  }
        \\}
        \\
    );

    return out.toOwnedSlice(allocator);
}

const luarc_json =
    \\{
    \\  "$schema": "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
    \\  "runtime.version": "Lua 5.4",
    \\  "workspace.library": [
    \\    "lua"
    \\  ],
    \\  "workspace.checkThirdParty": false,
    \\  "hint.enable": true,
    \\  "format.enable": true
    \\}
    \\
;
