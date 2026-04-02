const std = @import("std");
const editor_mod = @import("../src/editor/editor.zig");
const grammar_manager_mod = @import("../src/editor/grammar_manager.zig");
const cache_mod = @import("../src/editor/render/cache.zig");
const editor_display_prepare_mod = @import("../src/app/editor/editor_display_prepare.zig");
const syntax_mod = @import("../src/editor/syntax.zig");
comptime {
    _ = @import("../src/ui/widgets/editor_widget_draw.zig");
}

const Editor = editor_mod.Editor;

const EditorFixture = struct {
    allocator: std.mem.Allocator,
    grammar_manager: *grammar_manager_mod.GrammarManager,
    editor: *Editor,

    pub fn init(allocator: std.mem.Allocator) !EditorFixture {
        const grammar_manager = try allocator.create(grammar_manager_mod.GrammarManager);
        errdefer allocator.destroy(grammar_manager);
        grammar_manager.* = try grammar_manager_mod.GrammarManager.init(allocator);
        errdefer grammar_manager.deinit();
        const editor = try Editor.init(allocator, grammar_manager);
        return .{
            .allocator = allocator,
            .grammar_manager = grammar_manager,
            .editor = editor,
        };
    }

    pub fn deinit(self: *EditorFixture) void {
        self.editor.deinit();
        self.grammar_manager.deinit();
        self.allocator.destroy(self.grammar_manager);
    }
};

fn hashLine(text: []const u8) u64 {
    var h: u64 = 1469598103934665603;
    for (text) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

test "editor visible highlight invalidation after edit requires reschedule" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{
        .sub_path = "fixture.zig",
        .data = "const foo = bar;\n",
    });
    const path = try tmp.dir.realpathAlloc(allocator, "fixture.zig");
    defer allocator.free(path);

    try editor.openFile(path);
    try editor.tryInitHighlighter(path);
    if (editor.takeHighlightInvalidationBatch()) |initial_batch| {
        allocator.free(initial_batch.ranges);
    }

    const doc_before = editor.documentCore();
    const epoch_before = doc_before.highlightEpoch();
    const change_tick_before = doc_before.changeTick();
    const visible_start: usize = 0;
    const visible_end: usize = @min(1, editor.lineCount());

    editor.beginVisibleHighlightWork(visible_start, visible_end, epoch_before, change_tick_before);
    const batch = editor.takeVisibleHighlightWorkBatch(visible_end - visible_start) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(visible_start, batch.start_line);
    try std.testing.expectEqual(visible_end, batch.end_line);

    editor.replaceVisibleHighlightRequest(.{
        .start_line = batch.start_line,
        .end_line = batch.end_line,
        .epoch = epoch_before,
        .change_tick = change_tick_before,
    });

    var cache = cache_mod.EditorRenderCache.init(allocator, 64);
    defer cache.deinit();

    try std.testing.expect(editor.executePendingVisibleHighlightRequest());
    try std.testing.expect(editor.applyPendingVisibleHighlightResult(&cache));
    try std.testing.expect(!editor.shouldThrottleVisibleHighlightRange(
        visible_start,
        visible_end,
        epoch_before,
        change_tick_before,
    ));

    const line_before = try editor.getLineAlloc(0);
    defer allocator.free(line_before);
    const line_start_before = editor.lineStart(0);
    const hash_before = hashLine(line_before);
    try std.testing.expect(cache.tryHighlightTokens(0, line_start_before, hash_before, epoch_before).len > 0);

    editor.setCursor(0, 7);
    try editor.insertText("x");
    editor_display_prepare_mod.prepare(editor, &cache, 1);

    const doc_after = editor.documentCore();
    const epoch_after = doc_after.highlightEpoch();
    const change_tick_after = doc_after.changeTick();
    try std.testing.expect(change_tick_after != change_tick_before);
    try std.testing.expectEqual(epoch_before, epoch_after);

    const line_after = try editor.getLineAlloc(0);
    defer allocator.free(line_after);
    const line_start_after = editor.lineStart(0);
    const hash_after = hashLine(line_after);
    try std.testing.expect(cache.tryHighlightTokens(0, line_start_after, hash_after, epoch_after).len > 0);

    try std.testing.expect(editor.shouldThrottleVisibleHighlightRange(
        visible_start,
        visible_end,
        epoch_before,
        change_tick_before,
    ));

    const syntax = syntax_mod.resolvePath(path);
    try editor.tryInitHighlighter(path);
    try std.testing.expect(editor.currentSyntax() == syntax);
}
