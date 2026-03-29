const std = @import("std");
const editor_mod = @import("editor/editor.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const cache_mod = @import("editor/render/cache.zig");

const Editor = editor_mod.Editor;
const EditorRenderCache = cache_mod.EditorRenderCache;

const Scenario = enum {
    single_insert,
    burst_typing,
    edit_pending_refresh,
};

const RangeSummary = struct {
    start_line: usize,
    end_line: usize,
};

const FrameSummary = struct {
    frame: u64,
    action: []const u8,
    invalidation_full_document: bool,
    invalidation_ranges: []RangeSummary,
    full_redraw: bool,
    request_range: ?RangeSummary,
    apply_range: ?RangeSummary,
    apply_line_count: usize,
    request_pending: bool,
    result_pending: bool,
    compute_in_flight: bool,
    styling_authority: []const u8,
};

const RunSummary = struct {
    scenario: []const u8,
    fixture_path: []const u8,
    visible_start: usize,
    visible_end: usize,
    frames: []FrameSummary,
};

const Harness = struct {
    allocator: std.mem.Allocator,
    grammar_manager: *grammar_manager_mod.GrammarManager,
    editor: *Editor,
    cache: EditorRenderCache,

    fn init(allocator: std.mem.Allocator) !Harness {
        const grammar_manager = try allocator.create(grammar_manager_mod.GrammarManager);
        errdefer allocator.destroy(grammar_manager);
        grammar_manager.* = try grammar_manager_mod.GrammarManager.init(allocator);
        errdefer grammar_manager.deinit();
        const editor = try Editor.init(allocator, grammar_manager);
        errdefer editor.deinit();
        return .{
            .allocator = allocator,
            .grammar_manager = grammar_manager,
            .editor = editor,
            .cache = EditorRenderCache.init(allocator, 256),
        };
    }

    fn deinit(self: *Harness) void {
        self.cache.deinit();
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

fn consumeInvalidationBatch(
    allocator: std.mem.Allocator,
    editor: *Editor,
    cache: *EditorRenderCache,
) !struct {
    full_document: bool,
    ranges: []RangeSummary,
} {
    if (editor.takeHighlightInvalidationBatch()) |batch| {
        defer allocator.free(batch.ranges);
        if (batch.full_document) {
            cache.clearHighlightEntries();
        } else {
            const total_lines = editor.lineCount();
            for (batch.ranges) |range| {
                cache.invalidateHighlightRange(range.start_line, @min(range.end_line, total_lines));
            }
        }
        var ranges = std.ArrayList(RangeSummary).empty;
        defer ranges.deinit(allocator);
        for (batch.ranges) |range| {
            try ranges.append(allocator, .{
                .start_line = range.start_line,
                .end_line = range.end_line,
            });
        }
        return .{
            .full_document = batch.full_document,
            .ranges = try ranges.toOwnedSlice(allocator),
        };
    }
    return .{
        .full_document = false,
        .ranges = try allocator.alloc(RangeSummary, 0),
    };
}

fn stageFrame(
    allocator: std.mem.Allocator,
    editor: *Editor,
    cache: *EditorRenderCache,
    frame: u64,
    action: []const u8,
    visible_start: usize,
    visible_end: usize,
    budget_lines: usize,
    skip_execute: bool,
) !FrameSummary {
    const invalidation = try consumeInvalidationBatch(allocator, editor, cache);
    errdefer allocator.free(invalidation.ranges);

    const doc = editor.documentCore();
    const epoch = doc.highlightEpoch();
    const change_tick = doc.changeTick();
    const full_redraw = cache.beginFrame(
        frame,
        120,
        false,
        1200,
        800,
        change_tick,
        epoch,
        0,
        0,
        0,
        0,
    );

    editor.beginVisibleHighlightWork(visible_start, visible_end, epoch, change_tick);
    const batch = editor.takeVisibleHighlightWorkBatch(budget_lines);
    var request_range: ?RangeSummary = null;
    var apply_range: ?RangeSummary = null;
    var apply_line_count: usize = 0;
    if (batch) |b| {
        request_range = .{ .start_line = b.start_line, .end_line = b.end_line };
        editor.replaceVisibleHighlightRequest(.{
            .start_line = b.start_line,
            .end_line = b.end_line,
            .epoch = epoch,
            .change_tick = change_tick,
        });
        if (!skip_execute and editor.executePendingVisibleHighlightRequest()) {
            if (editor.takeVisibleHighlightResult()) |result_owned| {
                const result = result_owned;
                apply_line_count = result.lines.len;
                apply_range = .{
                    .start_line = result.request.start_line,
                    .end_line = result.request.end_line,
                };
                editor.replaceVisibleHighlightResult(result);
                _ = editor.applyPendingVisibleHighlightResult(cache);
            }
        }
    }
    if (!skip_execute and editor.hasPendingVisibleHighlightRequest() and editor.executePendingVisibleHighlightRequest()) {
        if (editor.takeVisibleHighlightResult()) |result_owned| {
            const result = result_owned;
            apply_line_count = result.lines.len;
            apply_range = .{
                .start_line = result.request.start_line,
                .end_line = result.request.end_line,
            };
            editor.replaceVisibleHighlightResult(result);
            _ = editor.applyPendingVisibleHighlightResult(cache);
        }
    }

    const line_text = try editor.getLineAlloc(visible_start);
    defer allocator.free(line_text);
    const authority = if (cache.tryHighlightTokens(visible_start, editor.lineStart(visible_start), hashLine(line_text), epoch).len > 0)
        "highlight_tokens"
    else
        "plain_fallback";

    return .{
        .frame = frame,
        .action = action,
        .invalidation_full_document = invalidation.full_document,
        .invalidation_ranges = invalidation.ranges,
        .full_redraw = full_redraw,
        .request_range = request_range,
        .apply_range = apply_range,
        .apply_line_count = apply_line_count,
        .request_pending = editor.hasPendingVisibleHighlightRequest(),
        .result_pending = editor.hasPendingVisibleHighlightResult(),
        .compute_in_flight = editor.visibleHighlightComputeInFlight(),
        .styling_authority = authority,
    };
}

fn runScenario(allocator: std.mem.Allocator, fixture_path: []const u8, scenario: Scenario) !RunSummary {
    var harness = try Harness.init(allocator);
    defer harness.deinit();

    try harness.editor.openFile(fixture_path);
    try harness.editor.tryInitHighlighter(fixture_path);
    const initial = try consumeInvalidationBatch(allocator, harness.editor, &harness.cache);
    allocator.free(initial.ranges);

    const visible_start: usize = 0;
    const visible_end: usize = @min(harness.editor.lineCount(), 3);
    var frames = std.ArrayList(FrameSummary).empty;
    errdefer {
        for (frames.items) |item| allocator.free(item.invalidation_ranges);
        frames.deinit(allocator);
    }

    try frames.append(allocator, try stageFrame(
        allocator,
        harness.editor,
        &harness.cache,
        1,
        "stabilize",
        visible_start,
        visible_end,
        1,
        false,
    ));

    harness.editor.setCursor(0, 7);
    switch (scenario) {
        .single_insert => try harness.editor.insertText("x"),
        .burst_typing => {
            try harness.editor.insertText("x");
            try harness.editor.insertText("y");
            try harness.editor.insertText("z");
        },
        .edit_pending_refresh => try harness.editor.insertText("x"),
    }

    try frames.append(allocator, try stageFrame(
        allocator,
        harness.editor,
        &harness.cache,
        2,
        "edit",
        visible_start,
        visible_end,
        1,
        scenario == .edit_pending_refresh,
    ));

    if (scenario == .edit_pending_refresh) {
        try frames.append(allocator, try stageFrame(
            allocator,
            harness.editor,
            &harness.cache,
            3,
            "refresh_complete",
            visible_start,
            visible_end,
            1,
            false,
        ));
    }

    return .{
        .scenario = @tagName(scenario),
        .fixture_path = fixture_path,
        .visible_start = visible_start,
        .visible_end = visible_end,
        .frames = try frames.toOwnedSlice(allocator),
    };
}

fn printHumanSummary(summary: RunSummary) void {
    std.debug.print("scenario={s} fixture={s} visible={d}..{d}\n", .{
        summary.scenario,
        summary.fixture_path,
        summary.visible_start,
        summary.visible_end,
    });
    for (summary.frames) |frame| {
        std.debug.print(
            "frame={d} action={s} invalidation_full={any} invalidation_ranges={d} full_redraw={any} request={any} apply={any} apply_lines={d} request_pending={any} result_pending={any} compute_in_flight={any} authority={s}\n",
            .{
                frame.frame,
                frame.action,
                frame.invalidation_full_document,
                frame.invalidation_ranges.len,
                frame.full_redraw,
                frame.request_range,
                frame.apply_range,
                frame.apply_line_count,
                frame.request_pending,
                frame.result_pending,
                frame.compute_in_flight,
                frame.styling_authority,
            },
        );
    }
}

fn deinitSummary(allocator: std.mem.Allocator, summary: *RunSummary) void {
    for (summary.frames) |frame| allocator.free(frame.invalidation_ranges);
    allocator.free(summary.frames);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    const fixture_path = args.next() orelse return error.MissingFixturePath;
    const scenario_name = args.next() orelse return error.MissingScenario;
    const scenario = std.meta.stringToEnum(Scenario, scenario_name) orelse return error.InvalidScenario;

    var summary = try runScenario(allocator, fixture_path, scenario);
    defer deinitSummary(allocator, &summary);

    printHumanSummary(summary);
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("{f}\n", .{std.json.fmt(summary, .{ .whitespace = .indent_2 })});
}
