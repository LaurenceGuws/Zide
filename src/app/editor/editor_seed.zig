const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn seedDefaultWelcomeBuffer(editor: *Editor) !void {
    try editor.insertText(
        \\// Welcome to Zide Editor
        \\//
        \\// Text-only editor shortcuts:
        \\//   Ctrl+N  - New file
        \\//   Ctrl+O  - Open file
        \\//   Ctrl+S  - Save file
        \\//   Ctrl+F  - Find
        \\//   Ctrl+Z  - Undo
        \\//   Ctrl+Y  - Redo
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
    editor.markSaved();
}
