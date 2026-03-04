const editor_mod = @import("../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn seedDefaultWelcomeBuffer(editor: *Editor) !void {
    try editor.insertText(
        \\// Welcome to Zide - A Zig IDE
        \\//
        \\// Keyboard shortcuts:
        \\//   Ctrl+N  - New file
        \\//   Ctrl+O  - Open file
        \\//   Ctrl+S  - Save file
        \\//   Ctrl+Z  - Undo
        \\//   Ctrl+Y  - Redo
        \\//   Ctrl+`  - Toggle terminal
        \\//   Ctrl+Q  - Quit
        \\//
        \\// Start typing to begin editing...
        \\
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    std.debug.print("Hello, Zide!\n", .{});
        \\}
        \\
    );
    editor.cursor = .{ .line = 0, .col = 0, .offset = 0 };
    editor.modified = false;
}
