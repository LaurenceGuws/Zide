const std = @import("std");
const editor_mod = @import("editor/editor.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const syntax_mod = @import("editor/syntax.zig");
const cache_mod = @import("editor/render/cache.zig");
const frame_view_mod = @import("editor/view/frame.zig");
const runtime_mod = @import("editor/view/runtime.zig");
const draw_mod = @import("ui/widgets/editor_widget_draw.zig");
const renderer_mod = @import("ui/renderer.zig");
const presentable_targets_runtime = @import("ui/renderer/presentable_targets_runtime.zig");
const shared_types = @import("types/mod.zig");

const Editor = editor_mod.Editor;
const EditorRenderCache = cache_mod.EditorRenderCache;
const InputSnapshot = shared_types.input.InputSnapshot;
const EditorTextStyleFlags = renderer_mod.EditorTextStyleFlags;
const PresentableSurface = presentable_targets_runtime.PresentableSurface;
const PresentableDraw = presentable_targets_runtime.PresentableDraw;
const TokenKind = syntax_mod.TokenKind;

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
    retained_surface_update_count: usize,
    retained_surface_blit_count: usize,
    composition_clip_count: usize,
    composition_full_pane_clear: bool,
};

const RunSummary = struct {
    scenario: []const u8,
    fixture_path: []const u8,
    visible_start: usize,
    visible_end: usize,
    frames: []FrameSummary,
};

const FakeColor = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const FakeTheme = struct {
    background: FakeColor = .{ .r = 40, .g = 42, .b = 54 },
    foreground: FakeColor = .{ .r = 248, .g = 248, .b = 242 },
    selection: FakeColor = .{ .r = 68, .g = 71, .b = 90 },
    cursor: FakeColor = .{ .r = 248, .g = 248, .b = 242 },
    link: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    line_number: FakeColor = .{ .r = 98, .g = 114, .b = 164 },
    line_number_bg: FakeColor = .{ .r = 33, .g = 34, .b = 44 },
    current_line: FakeColor = .{ .r = 50, .g = 52, .b = 66 },
    comment_color: FakeColor = .{ .r = 98, .g = 114, .b = 164 },
    string: FakeColor = .{ .r = 241, .g = 250, .b = 140 },
    keyword: FakeColor = .{ .r = 255, .g = 121, .b = 198 },
    number: FakeColor = .{ .r = 189, .g = 147, .b = 249 },
    function: FakeColor = .{ .r = 80, .g = 250, .b = 123 },
    variable: FakeColor = .{ .r = 248, .g = 248, .b = 242 },
    type_name: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    operator: FakeColor = .{ .r = 255, .g = 121, .b = 198 },
    builtin_color: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    punctuation: FakeColor = .{ .r = 248, .g = 248, .b = 242 },
    constant: FakeColor = .{ .r = 189, .g = 147, .b = 249 },
    attribute: FakeColor = .{ .r = 80, .g = 250, .b = 123 },
    namespace: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    label: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    error_token: FakeColor = .{ .r = 255, .g = 85, .b = 85 },
    preproc: FakeColor = .{ .r = 143, .g = 188, .b = 187 },
    macro: FakeColor = .{ .r = 180, .g = 142, .b = 173 },
    escape: FakeColor = .{ .r = 136, .g = 192, .b = 208 },
    keyword_control: FakeColor = .{ .r = 255, .g = 121, .b = 198 },
    function_method: FakeColor = .{ .r = 80, .g = 250, .b = 123 },
    type_builtin: FakeColor = .{ .r = 139, .g = 233, .b = 253 },
    syntax_style_flags: [token_kind_count]EditorTextStyleFlags = [_]EditorTextStyleFlags{.{}} ** token_kind_count,
    syntax_special_colors: [token_kind_count]?FakeColor = [_]?FakeColor{null} ** token_kind_count,
};

const SelectionOverlayStyle = struct {
    smooth_enabled: bool = true,
    corner_px: ?f32 = null,
    pad_px: ?f32 = null,
};

const CompositionCapture = struct {
    retained_surface_update_count: usize = 0,
    retained_surface_blit_count: usize = 0,
    composition_clip_count: usize = 0,
    composition_full_pane_clear: bool = false,
};

const token_kind_count: usize = switch (@typeInfo(TokenKind)) {
    .@"enum" => |info| info.fields.len,
    else => 0,
};

const FakeRenderer = struct {
    width: i32,
    height: i32,
    editor_char_width: f32,
    editor_char_height: f32,
    editor_disable_ligatures: @import("ui/renderer.zig").TerminalDisableLigaturesStrategy = .never,
    theme: FakeTheme = .{},
    editor_selection_overlay_style: SelectionOverlayStyle = .{},
    terminal_selection_overlay_style: SelectionOverlayStyle = .{},
    retained_surface_created: bool = false,
    in_retained_surface: bool = false,
    capture: CompositionCapture = .{},

    fn init(width: i32, height: i32, char_width: f32, char_height: f32) FakeRenderer {
        return .{
            .width = width,
            .height = height,
            .editor_char_width = char_width,
            .editor_char_height = char_height,
        };
    }

    pub fn rendererPtr(self: *FakeRenderer) *FakeRenderer {
        return self;
    }

    pub fn uiScaleFactor(self: *FakeRenderer) f32 {
        _ = self;
        return 1.0;
    }

    pub fn editorSelectionOverlayStyle(self: *FakeRenderer) SelectionOverlayStyle {
        return self.editor_selection_overlay_style;
    }

    pub fn terminalSelectionOverlayStyle(self: *FakeRenderer) SelectionOverlayStyle {
        return self.terminal_selection_overlay_style;
    }

    pub fn ensurePresentable(self: *FakeRenderer, surface: PresentableSurface, width: i32, height: i32) bool {
        std.debug.assert(surface == .editor);
        _ = width;
        _ = height;
        if (!self.retained_surface_created) {
            self.retained_surface_created = true;
            return true;
        }
        return false;
    }

    pub fn beginPresentable(self: *FakeRenderer, surface: PresentableSurface) bool {
        std.debug.assert(surface == .editor);
        self.in_retained_surface = true;
        self.capture.retained_surface_update_count += 1;
        return true;
    }

    pub fn endPresentable(self: *FakeRenderer, surface: PresentableSurface) void {
        std.debug.assert(surface == .editor);
        self.in_retained_surface = false;
    }

    pub fn beginClip(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32) void {
        _ = x;
        _ = y;
        _ = w;
        _ = h;
        self.capture.composition_clip_count += 1;
    }

    pub fn endClip(self: *FakeRenderer) void {
        _ = self;
    }

    pub fn drawPresentable(self: *FakeRenderer, surface: PresentableSurface, draw: PresentableDraw) void {
        std.debug.assert(surface == .editor);
        _ = draw;
        self.capture.retained_surface_blit_count += 1;
    }

    pub fn drawRect(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32, color: FakeColor) void {
        _ = color;
        if (self.in_retained_surface and x == 0 and y == 0 and w == self.width and h == self.height) {
            self.capture.composition_full_pane_clear = true;
        }
    }

    pub fn drawText(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor) void {
        _ = self;
        _ = text;
        _ = x;
        _ = y;
        _ = color;
    }

    pub fn drawTextMonospace(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor) void {
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospacePolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor, disable_programming_ligatures: bool) void {
        _ = disable_programming_ligatures;
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospaceOnBg(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor, bg: FakeColor) void {
        _ = bg;
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospaceOnBgPolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor, bg: FakeColor, disable_programming_ligatures: bool) void {
        _ = bg;
        _ = disable_programming_ligatures;
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospaceOnBgStyledPolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor, bg: FakeColor, disable_programming_ligatures: bool, italic: bool) void {
        _ = italic;
        self.drawTextMonospaceOnBgPolicy(text, x, y, color, bg, disable_programming_ligatures);
    }

    pub fn drawTextMonospaceStyledPolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: FakeColor, disable_programming_ligatures: bool, italic: bool) void {
        _ = italic;
        self.drawTextMonospacePolicy(text, x, y, color, disable_programming_ligatures);
    }

    pub fn drawCursor(self: *FakeRenderer, x: f32, y: f32, mode: enum { block, line, underline }) void {
        _ = self;
        _ = x;
        _ = y;
        _ = mode;
    }

    fn clearCapture(self: *FakeRenderer) void {
        self.capture = .{};
    }
};

const FakeWidget = struct {
    editor: *Editor,
    gutter_width: f32 = 0,
    wrap_enabled: bool = false,

    const CursorLineCtx = struct {
        widget: *FakeWidget,
    };

    fn cursorLineText(ctx: *anyopaque, line_idx: usize, scratch: *runtime_mod.LineScratch) runtime_mod.LineSlice {
        const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
        const editor = payload.widget.editor;
        const line_len = editor.lineLen(line_idx);
        if (line_len <= scratch.buf.len) {
            const len = editor.getLine(line_idx, scratch.buf);
            return .{ .text = scratch.buf[0..len], .owned = null };
        }
        const owned = editor.getLineAlloc(line_idx) catch {
            return .{ .text = &[_]u8{}, .owned = null };
        };
        return .{ .text = owned, .owned = owned };
    }

    fn cursorClusters(ctx: *anyopaque, line_idx: usize, line_text: []const u8) runtime_mod.ClusterSlice {
        _ = ctx;
        _ = line_idx;
        _ = line_text;
        return .{ .clusters = null, .owned = false };
    }

    fn cursorFreeLineText(ctx: *anyopaque, owned: []u8) void {
        const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
        payload.widget.editor.allocator.free(owned);
    }

    fn cursorFreeClusters(ctx: *anyopaque, owned: []const u32) void {
        const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
        payload.widget.editor.allocator.free(owned);
    }

    pub fn frameView(self: *FakeWidget) frame_view_mod.EditorFrameView {
        return frame_view_mod.EditorFrameView.init(self.editor, self.wrap_enabled);
    }

    pub fn viewportColumns(self: *FakeWidget, renderer: *FakeRenderer) usize {
        const editor_width = @max(0, renderer.width - @as(i32, @intFromFloat(self.gutter_width)));
        if (renderer.editor_char_width <= 0) return 0;
        return @as(usize, @intFromFloat(@as(f32, @floatFromInt(editor_width)) / renderer.editor_char_width));
    }

    pub fn clusterOffsets(
        self: *FakeWidget,
        renderer: *FakeRenderer,
        line_idx: usize,
        line_text: []const u8,
        out_slice: *?[]const u32,
        out_owned: *bool,
    ) void {
        _ = self;
        _ = renderer;
        _ = line_idx;
        _ = line_text;
        out_slice.* = null;
        out_owned.* = false;
    }

    fn initViewRuntime(self: *FakeWidget, ctx: *CursorLineCtx) runtime_mod.EditorViewRuntime {
        return .{
            .editor = self.editor,
            .wrap_enabled = self.wrap_enabled,
            .ctx = ctx,
            .getLineText = cursorLineText,
            .getClusters = cursorClusters,
            .freeLineText = cursorFreeLineText,
            .freeClusters = cursorFreeClusters,
        };
    }

    pub fn lineData(self: *FakeWidget, shell: *FakeRenderer, line_idx: usize, scratch: *runtime_mod.LineScratch) runtime_mod.LineData {
        _ = shell;
        var ctx = CursorLineCtx{ .widget = self };
        const runtime = self.initViewRuntime(&ctx);
        return runtime.lineData(line_idx, scratch);
    }

    pub fn releaseLineData(self: *FakeWidget, data: *runtime_mod.LineData) void {
        if (data.owned_text) |owned| self.editor.allocator.free(owned);
        if (data.owned_clusters) {
            if (data.clusters) |clusters| self.editor.allocator.free(clusters);
        }
    }
};

const Harness = struct {
    allocator: std.mem.Allocator,
    grammar_manager: *grammar_manager_mod.GrammarManager,
    editor: *Editor,
    cache: EditorRenderCache,
    renderer: FakeRenderer,

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
            .renderer = FakeRenderer.init(1200, 800, 8, 16),
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
    renderer: *FakeRenderer,
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
    var widget = FakeWidget{ .editor = editor };
    const view = widget.frameView();
    const cols = widget.viewportColumns(renderer);
    const full_redraw = cache.wouldBeginFrameFullRedraw(
        cols,
        widget.wrap_enabled,
        renderer.width,
        renderer.height,
        epoch,
        view.scroll_line,
        view.scroll_row_offset,
        view.scroll_col,
        view.selectionStateHash(),
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

    const input = InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    renderer.clearCapture();
    draw_mod.drawCached(&widget, renderer, cache, 0, 0, 1200, 800, frame, input);

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
        .retained_surface_update_count = renderer.capture.retained_surface_update_count,
        .retained_surface_blit_count = renderer.capture.retained_surface_blit_count,
        .composition_clip_count = renderer.capture.composition_clip_count,
        .composition_full_pane_clear = renderer.capture.composition_full_pane_clear,
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
        &harness.renderer,
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
        &harness.renderer,
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
            &harness.renderer,
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
            "frame={d} action={s} invalidation_full={any} invalidation_ranges={d} full_redraw={any} request={any} apply={any} apply_lines={d} request_pending={any} result_pending={any} compute_in_flight={any} authority={s} retained_updates={d} retained_blits={d} clip_count={d} full_pane_clear={any}\n",
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
                frame.retained_surface_update_count,
                frame.retained_surface_blit_count,
                frame.composition_clip_count,
                frame.composition_full_pane_clear,
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
