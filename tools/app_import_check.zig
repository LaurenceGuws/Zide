const std = @import("std");

const Layer = enum {
    editor_widget,
    terminal_widget,
    app_main,
    shell_renderer,
    editor_core,
    terminal_core,
    other,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = std.fs.cwd();
    const root_path = try cwd.realpathAlloc(allocator, ".");
    const editor_root = try std.fs.path.join(allocator, &.{ root_path, "src", "editor" });
    const terminal_root = try std.fs.path.join(allocator, &.{ root_path, "src", "terminal" });
    const ui_renderer_path = try std.fs.path.join(allocator, &.{ root_path, "src", "ui", "renderer.zig" });
    const editor_root_sep = try std.mem.concat(allocator, u8, &.{ editor_root, std.fs.path.sep_str });
    const terminal_root_sep = try std.mem.concat(allocator, u8, &.{ terminal_root, std.fs.path.sep_str });

    var had_error = false;
    const stderr_file = std.fs.File.stderr();

    try checkWidgetImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        ui_renderer_path,
        &had_error,
        stderr_file,
    );

    try checkFileImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        ui_renderer_path,
        "src/main.zig",
        .app_main,
        &had_error,
        stderr_file,
    );

    try checkFileImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        ui_renderer_path,
        "src/ui/renderer.zig",
        .shell_renderer,
        &had_error,
        stderr_file,
    );

    if (had_error) return error.ForbiddenImport;
}

fn checkWidgetImports(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    root_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    ui_renderer_path: []const u8,
    had_error: *bool,
    stderr_file: std.fs.File,
) !void {
    var widgets_dir = try cwd.openDir("src/ui/widgets", .{ .iterate = true });
    defer widgets_dir.close();
    var walker = try widgets_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const rel_path = try std.fs.path.join(allocator, &.{ "src/ui/widgets", entry.path });
        const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
        const from_layer = layerForWidgetPath(entry.basename);
        if (from_layer == .other) continue;

        try checkImportsInFile(
            allocator,
            cwd,
            rel_path,
            abs_path,
            editor_root_sep,
            terminal_root_sep,
            ui_renderer_path,
            from_layer,
            had_error,
            stderr_file,
        );
    }
}

fn checkFileImports(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    root_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    ui_renderer_path: []const u8,
    rel_path: []const u8,
    from_layer: Layer,
    had_error: *bool,
    stderr_file: std.fs.File,
) !void {
    const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
    try checkImportsInFile(
        allocator,
        cwd,
        rel_path,
        abs_path,
        editor_root_sep,
        terminal_root_sep,
        ui_renderer_path,
        from_layer,
        had_error,
        stderr_file,
    );
}

fn checkImportsInFile(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    rel_path: []const u8,
    abs_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    ui_renderer_path: []const u8,
    from_layer: Layer,
    had_error: *bool,
    stderr_file: std.fs.File,
) !void {
    const data = try cwd.readFileAlloc(allocator, rel_path, 1024 * 1024);
    var i: usize = 0;
    while (true) {
        const start = std.mem.indexOfPos(u8, data, i, "@import(\"") orelse break;
        const import_start = start + "@import(\"".len;
        const end = std.mem.indexOfPos(u8, data, import_start, "\")") orelse break;
        const import_path = data[import_start..end];
        i = end + 2;

        if (!std.mem.endsWith(u8, import_path, ".zig")) continue;

        const dir = std.fs.path.dirname(abs_path) orelse continue;
        const resolved = std.fs.path.resolve(allocator, &.{ dir, import_path }) catch continue;

        const to_layer = layerForResolvedPath(resolved, editor_root_sep, terminal_root_sep);
        if (!isAllowed(from_layer, to_layer, resolved, editor_root_sep, terminal_root_sep, ui_renderer_path)) {
            had_error.* = true;
            var line_buf: [2048]u8 = undefined;
            const msg = try std.fmt.bufPrint(
                &line_buf,
                "app import check: {s} imports {s} ({s}) which is not allowed ({s} -> {s})\n",
                .{ rel_path, import_path, resolved, layerName(from_layer), layerName(to_layer) },
            );
            try stderr_file.writeAll(msg);
        }
    }
}

fn layerForWidgetPath(basename: []const u8) Layer {
    if (std.mem.startsWith(u8, basename, "editor_widget")) return .editor_widget;
    if (std.mem.eql(u8, basename, "terminal_widget.zig")) return .terminal_widget;
    return .other;
}

fn layerForResolvedPath(path: []const u8, editor_root: []const u8, terminal_root: []const u8) Layer {
    if (std.mem.startsWith(u8, path, editor_root)) return .editor_core;
    if (std.mem.startsWith(u8, path, terminal_root)) return .terminal_core;
    return .other;
}

fn isAllowed(
    from: Layer,
    to: Layer,
    resolved: []const u8,
    editor_root: []const u8,
    terminal_root: []const u8,
    ui_renderer_path: []const u8,
) bool {
    if (from == .app_main and std.mem.eql(u8, resolved, ui_renderer_path)) return false;
    if (from == .other or to == .other) return true;
    if (from == to) return true;
    return switch (from) {
        .editor_widget => to != .terminal_core,
        .terminal_widget => to != .editor_core,
        .app_main => isAllowedAppMain(to, resolved, editor_root, terminal_root),
        .shell_renderer => isAllowedShellRenderer(to, resolved, editor_root),
        .editor_core, .terminal_core, .other => true,
    };
}

fn isAllowedAppMain(to: Layer, resolved: []const u8, editor_root: []const u8, terminal_root: []const u8) bool {
    _ = editor_root;
    if (to != .terminal_core) return true;
    const rel = resolved[terminal_root.len..];
    const sep_index = std.mem.indexOfScalar(u8, rel, std.fs.path.sep) orelse return true;
    const first = rel[0..sep_index];
    return std.mem.eql(u8, first, "core") or std.mem.eql(u8, first, "model");
}

fn isAllowedShellRenderer(to: Layer, resolved: []const u8, editor_root: []const u8) bool {
    if (to == .terminal_core) return false;
    if (to != .editor_core) return true;
    const rel = resolved[editor_root.len..];
    if (std.mem.eql(u8, rel, "types.zig")) return true;
    const sep_index = std.mem.indexOfScalar(u8, rel, std.fs.path.sep) orelse return false;
    const first = rel[0..sep_index];
    return std.mem.eql(u8, first, "render");
}

fn layerName(layer: Layer) []const u8 {
    return switch (layer) {
        .editor_widget => "editor_widget",
        .terminal_widget => "terminal_widget",
        .app_main => "app_main",
        .shell_renderer => "shell_renderer",
        .editor_core => "editor_core",
        .terminal_core => "terminal_core",
        .other => "other",
    };
}
