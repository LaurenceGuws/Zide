const std = @import("std");

const Layer = enum {
    editor_widget,
    terminal_widget,
    app_main,
    shell_renderer,
    editor_core,
    terminal_core,
    shared_types,
    input_support,
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
    const types_root = try std.fs.path.join(allocator, &.{ root_path, "src", "types" });
    const input_root = try std.fs.path.join(allocator, &.{ root_path, "src", "input" });
    const ui_root = try std.fs.path.join(allocator, &.{ root_path, "src", "ui" });
    const ui_renderer_path = try std.fs.path.join(allocator, &.{ root_path, "src", "ui", "renderer.zig" });
    const editor_root_sep = try std.mem.concat(allocator, u8, &.{ editor_root, std.fs.path.sep_str });
    const terminal_root_sep = try std.mem.concat(allocator, u8, &.{ terminal_root, std.fs.path.sep_str });
    const types_root_sep = try std.mem.concat(allocator, u8, &.{ types_root, std.fs.path.sep_str });
    const input_root_sep = try std.mem.concat(allocator, u8, &.{ input_root, std.fs.path.sep_str });
    const ui_root_sep = try std.mem.concat(allocator, u8, &.{ ui_root, std.fs.path.sep_str });

    var had_error = false;
    const stderr_file = std.fs.File.stderr();

    try checkWidgetImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        types_root_sep,
        input_root_sep,
        ui_root_sep,
        ui_renderer_path,
        &had_error,
        stderr_file,
    );

    try checkInputImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        types_root_sep,
        input_root_sep,
        ui_root_sep,
        ui_renderer_path,
        &had_error,
        stderr_file,
    );

    try checkUiImports(
        allocator,
        cwd,
        root_path,
        editor_root_sep,
        terminal_root_sep,
        types_root_sep,
        input_root_sep,
        ui_root_sep,
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
        types_root_sep,
        input_root_sep,
        ui_root_sep,
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
        types_root_sep,
        input_root_sep,
        ui_root_sep,
        ui_renderer_path,
        "src/ui/renderer.zig",
        .shell_renderer,
        &had_error,
        stderr_file,
    );

    if (had_error) return error.ForbiddenImport;
}

fn checkInputImports(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    root_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    types_root_sep: []const u8,
    input_root_sep: []const u8,
    ui_root_sep: []const u8,
    ui_renderer_path: []const u8,
    had_error: *bool,
    stderr_file: std.fs.File,
) !void {
    var input_dir = try cwd.openDir("src/input", .{ .iterate = true });
    defer input_dir.close();
    var walker = try input_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const rel_path = try std.fs.path.join(allocator, &.{ "src/input", entry.path });
        const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
        try checkImportsInFile(
            allocator,
            cwd,
            rel_path,
            abs_path,
            editor_root_sep,
            terminal_root_sep,
            types_root_sep,
            input_root_sep,
            ui_root_sep,
            ui_renderer_path,
            .input_support,
            had_error,
            stderr_file,
        );
    }
}

fn checkWidgetImports(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    root_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    types_root_sep: []const u8,
    input_root_sep: []const u8,
    ui_root_sep: []const u8,
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
            types_root_sep,
            input_root_sep,
            ui_root_sep,
            ui_renderer_path,
            from_layer,
            had_error,
            stderr_file,
        );
    }
}

fn checkUiImports(
    allocator: std.mem.Allocator,
    cwd: std.fs.Dir,
    root_path: []const u8,
    editor_root_sep: []const u8,
    terminal_root_sep: []const u8,
    types_root_sep: []const u8,
    input_root_sep: []const u8,
    ui_root_sep: []const u8,
    ui_renderer_path: []const u8,
    had_error: *bool,
    stderr_file: std.fs.File,
) !void {
    var ui_dir = try cwd.openDir("src/ui", .{ .iterate = true });
    defer ui_dir.close();
    var walker = try ui_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        if (std.mem.eql(u8, entry.basename, "renderer.zig")) continue;
        if (std.mem.startsWith(u8, entry.path, "widgets")) continue;

        const rel_path = try std.fs.path.join(allocator, &.{ "src/ui", entry.path });
        const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
        try checkImportsInFile(
            allocator,
            cwd,
            rel_path,
            abs_path,
            editor_root_sep,
            terminal_root_sep,
            types_root_sep,
            input_root_sep,
            ui_root_sep,
            ui_renderer_path,
            .shell_renderer,
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
    types_root_sep: []const u8,
    input_root_sep: []const u8,
    ui_root_sep: []const u8,
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
        types_root_sep,
        input_root_sep,
        ui_root_sep,
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
    types_root_sep: []const u8,
    input_root_sep: []const u8,
    ui_root_sep: []const u8,
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

        const to_layer = layerForResolvedPath(resolved, editor_root_sep, terminal_root_sep, types_root_sep, input_root_sep);
        if (!isAllowed(from_layer, to_layer, resolved, editor_root_sep, terminal_root_sep, types_root_sep, ui_root_sep, ui_renderer_path)) {
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

fn layerForResolvedPath(
    path: []const u8,
    editor_root: []const u8,
    terminal_root: []const u8,
    types_root: []const u8,
    input_root: []const u8,
) Layer {
    if (std.mem.startsWith(u8, path, editor_root)) return .editor_core;
    if (std.mem.startsWith(u8, path, terminal_root)) return .terminal_core;
    if (std.mem.startsWith(u8, path, types_root)) return .shared_types;
    if (std.mem.startsWith(u8, path, input_root)) return .input_support;
    return .other;
}

fn isAllowed(
    from: Layer,
    to: Layer,
    resolved: []const u8,
    editor_root: []const u8,
    terminal_root: []const u8,
    types_root: []const u8,
    ui_root: []const u8,
    ui_renderer_path: []const u8,
) bool {
    if (from == .app_main and std.mem.eql(u8, resolved, ui_renderer_path)) return false;
    if (from == .shared_types and (to == .editor_core or to == .terminal_core)) return false;
    if (from == .shared_types and std.mem.startsWith(u8, resolved, ui_root)) return false;
    if (from == .input_support and std.mem.startsWith(u8, resolved, ui_root)) return false;
    if (to == .input_support and (from == .editor_widget or from == .terminal_widget or from == .shell_renderer or from == .shared_types)) return false;
    if (from == .other or to == .other) return true;
    if (from == to) return true;
    return switch (from) {
        .editor_widget => to != .terminal_core,
        .terminal_widget => to != .editor_core,
        .app_main => isAllowedAppMain(to, resolved, editor_root, terminal_root, types_root),
        .shell_renderer => isAllowedShellRenderer(to, resolved, editor_root, types_root),
        .shared_types => to == .shared_types or to == .other,
        .input_support => to == .input_support or to == .shared_types or to == .other,
        .editor_core, .terminal_core, .other => true,
    };
}

fn isAllowedAppMain(
    to: Layer,
    resolved: []const u8,
    editor_root: []const u8,
    terminal_root: []const u8,
    types_root: []const u8,
) bool {
    _ = editor_root;
    if (to == .shared_types and std.mem.startsWith(u8, resolved, types_root)) return true;
    if (to != .terminal_core) return true;
    const rel = resolved[terminal_root.len..];
    const sep_index = std.mem.indexOfScalar(u8, rel, std.fs.path.sep) orelse return true;
    const first = rel[0..sep_index];
    return std.mem.eql(u8, first, "core") or std.mem.eql(u8, first, "model");
}

fn isAllowedShellRenderer(to: Layer, resolved: []const u8, editor_root: []const u8, types_root: []const u8) bool {
    if (to == .terminal_core) return false;
    if (to == .shared_types and std.mem.startsWith(u8, resolved, types_root)) return true;
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
        .shared_types => "shared_types",
        .input_support => "input_support",
        .other => "other",
    };
}
