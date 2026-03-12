const std = @import("std");
const builtin = @import("builtin");
const terminal = @import("core/terminal.zig");
const screen_mod = @import("model/screen.zig");
const pty_mod = @import("io/pty.zig");
const snapshot_mod = @import("core/snapshot.zig");
const input_mod = @import("input/input.zig");
const alt_probe = @import("input/alternate_probe.zig");
const types = @import("model/types.zig");
const shared_types = @import("../types/mod.zig");

pub const FixtureType = enum {
    vt,
    harness_api,
    encoder,
};

pub const LineEnding = enum {
    lf,
    crlf,
    cr,
};

pub const SelectionOp = enum {
    start,
    update,
    finish,
    select_range,
};

pub const SelectionAction = struct {
    op: SelectionOp,
    row: usize = 0,
    col: usize = 0,
    end_row: usize = 0,
    end_col: usize = 0,
    finished: bool = true,
};

pub const ScrollOffsetAction = struct {
    offset: usize,
};

pub const ScrollbackCellAction = struct {
    row: usize,
    col: usize,
    codepoint: u32,
};

pub const MouseAction = struct {
    kind: types.MouseEventKind,
    button: types.MouseButton,
    row: usize,
    col: usize,
    pixel_x: ?u32 = null,
    pixel_y: ?u32 = null,
    mod: types.Modifier = types.VTERM_MOD_NONE,
    buttons_down: u8 = 0,
};

pub const EncoderSpec = struct {
    key: ?u32 = null,
    char: ?u32 = null,
    mod: u8 = 0,
    flags: u32 = 0,
    action: input_mod.KeyAction = .press,
    alternate_meta: ?EncoderAlternateMetaSpec = null,
    alternate_probe_meta: ?EncoderAlternateProbeMetaSpec = null,
};

pub const EncoderAlternateMetaSpec = struct {
    physical_key: ?u32 = null,
    produced_text_utf8: ?[]const u8 = null,
    base_codepoint: ?u32 = null,
    shifted_codepoint: ?u32 = null,
    alternate_layout_codepoint: ?u32 = null,
    text_is_composed: bool = false,
};

pub const EncoderKeyModsSpec = struct {
    shift: bool = false,
    alt: bool = false,
    ctrl: bool = false,
    super: bool = false,
    altgr: bool = false,
};

pub const EncoderAlternateProbeMetaSpec = struct {
    key_mods: EncoderKeyModsSpec = .{},
    key_scancode: ?i32 = null,
    key_sym: ?i32 = null,
    key_enum: shared_types.input.Key = .unknown,
    text_utf8: ?[]const u8 = null,
    text_is_composed: bool = false,
    probe_base_codepoint: ?u32 = null,
    probe_shifted_codepoint: ?u32 = null,
    probe_event_sym_codepoint: ?u32 = null,
    probe_altgr_codepoint: ?u32 = null,
    probe_altgr_shift_codepoint: ?u32 = null,
    explicit_altgr: bool = false,
    explicit_non_altgr_alt: bool = false,
};

pub const FixtureMeta = struct {
    fixture_type: FixtureType,
    rows: u16,
    cols: u16,
    cursor: types.CursorPos = .{ .row = 0, .col = 0 },
    line_ending: LineEnding = .lf,
    baseline_input: ?[]const u8 = null,
    baseline_scrollback_rows: []const []const u8 = &.{},
    baseline_grid_rows: []const []const u8 = &.{},
    baseline_scroll_offsets: []const ScrollOffsetAction = &.{},
    assertions: []const []const u8 = &.{},
    reply_hex: ?[]const u8 = null,
    expected_dirty: ?DirtyExpectation = null,
    expected_damage: ?ExpectedDamage = null,
    expected_viewport_shift_rows: ?i32 = null,
    expected_viewport_shift_exposed_only: ?bool = null,
    expected_generation_advanced_from_baseline: ?bool = null,
    output_chunks: []const []const u8 = &.{},
    selection: []const SelectionAction = &.{},
    scroll_offsets: []const ScrollOffsetAction = &.{},
    scroll_full_up_count: usize = 0,
    scrollback_cells: []const ScrollbackCellAction = &.{},
    mouse: []const MouseAction = &.{},
    encoder: ?EncoderSpec = null,
    osc_5522_clipboard_text: ?[]const u8 = null,
    osc_5522_clipboard_html: ?[]const u8 = null,
    osc_5522_clipboard_uri_list: ?[]const u8 = null,
    osc_5522_clipboard_png_hex: ?[]const u8 = null,
};

pub const DirtyExpectation = enum {
    none,
    partial,
    full,
};

pub const ExpectedDamage = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub const ObservedFixtureState = struct {
    pub const RowSpan = struct {
        row: usize,
        start_col: usize,
        end_col: usize,
    };

    dirty: DirtyExpectation,
    damage: ExpectedDamage,
    viewport_shift_rows: ?i32,
    viewport_shift_exposed_only: ?bool,
    generation: u64,
    baseline_generation: ?u64,
    history_len: ?usize,
    total_lines: ?usize,
    scroll_offset: ?usize,
    row_spans: []const RowSpan,
};

pub const RunFixtureObserved = struct {
    output: []u8,
    observed: ObservedFixtureState,
};

const BaselinePublication = struct {
    generation: ?u64 = null,
};

pub const RunFixtureOptions = struct {
    validate_assertions: bool = true,
};

const ReplayPtyCapture = struct {
    read_fd: std.posix.fd_t,
    pty: pty_mod.Pty,

    fn init() !ReplayPtyCapture {
        if (builtin.os.tag != .linux and builtin.os.tag != .macos) return error.UnsupportedReplyCapture;
        const fds = try std.posix.pipe();
        return .{
            .read_fd = fds[0],
            .pty = .{
                .master_fd = fds[1],
                .child_pid = null,
                .cached_fg_pgrp = 0,
                .cached_fg_name_len = 0,
                .cached_fg_name = [_]u8{0} ** 128,
            },
        };
    }

    fn deinit(self: *ReplayPtyCapture) void {
        std.posix.close(self.read_fd);
        self.pty.deinit();
    }

    fn readAll(self: *ReplayPtyCapture, allocator: std.mem.Allocator) ![]u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        while (true) {
            var pollfds = [_]std.posix.pollfd{.{ .fd = self.read_fd, .events = std.posix.POLL.IN, .revents = 0 }};
            const timeout_ms: i32 = if (out.items.len == 0) 50 else 0;
            const ready = try std.posix.poll(&pollfds, timeout_ms);
            if (ready <= 0 or (pollfds[0].revents & std.posix.POLL.IN) == 0) break;

            var buf: [256]u8 = undefined;
            const n = try std.posix.read(self.read_fd, &buf);
            if (n == 0) break;
            try out.appendSlice(allocator, buf[0..n]);
        }
        return out.toOwnedSlice(allocator);
    }
};

pub const Fixture = struct {
    name: []const u8,
    meta: FixtureMeta,
    input: []const u8,
    golden: ?[]const u8,
    parsed: std.json.Parsed(FixtureMeta),
};

pub fn loadFixtures(allocator: std.mem.Allocator, dir_path: []const u8) ![]Fixture {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.ArrayList(Fixture).empty;
    errdefer {
        for (fixtures.items) |*fixture| {
            deinitFixture(allocator, fixture);
        }
        fixtures.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".vt")) continue;

        const stem_len = entry.name.len - 3;
        const stem = entry.name[0..stem_len];
        const name = try allocator.dupe(u8, stem);
        errdefer allocator.free(name);

        const file_bytes = try dir.readFileAlloc(allocator, entry.name, 1024 * 1024);
        errdefer allocator.free(file_bytes);

        const meta_name = try std.fmt.allocPrint(allocator, "{s}.json", .{stem});
        defer allocator.free(meta_name);
        const meta_bytes = try dir.readFileAlloc(allocator, meta_name, 1024 * 1024);
        defer allocator.free(meta_bytes);
        const parsed = try std.json.parseFromSlice(
            FixtureMeta,
            allocator,
            meta_bytes,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        errdefer parsed.deinit();

        var golden: ?[]const u8 = null;
        const golden_name = try std.fmt.allocPrint(allocator, "{s}.golden", .{stem});
        defer allocator.free(golden_name);
        if (dir.openFile(golden_name, .{})) |golden_file| {
            defer golden_file.close();
            golden = try golden_file.readToEndAlloc(allocator, 4 * 1024 * 1024);
        } else |_| {}

        try fixtures.append(allocator, .{
            .name = name,
            .meta = parsed.value,
            .input = file_bytes,
            .golden = golden,
            .parsed = parsed,
        });
    }

    return fixtures.toOwnedSlice(allocator);
}

pub fn loadEncoderFixtures(allocator: std.mem.Allocator, dir_path: []const u8) ![]Fixture {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.ArrayList(Fixture).empty;
    errdefer {
        for (fixtures.items) |*fixture| {
            deinitFixture(allocator, fixture);
        }
        fixtures.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const stem_len = entry.name.len - 5;
        const stem = entry.name[0..stem_len];
        const name = try allocator.dupe(u8, stem);
        errdefer allocator.free(name);

        const meta_bytes = try dir.readFileAlloc(allocator, entry.name, 64 * 1024);
        defer allocator.free(meta_bytes);
        const parsed = try std.json.parseFromSlice(
            FixtureMeta,
            allocator,
            meta_bytes,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        errdefer parsed.deinit();

        var golden: ?[]const u8 = null;
        const golden_name = try std.fmt.allocPrint(allocator, "{s}.golden", .{stem});
        defer allocator.free(golden_name);
        if (dir.openFile(golden_name, .{})) |golden_file| {
            defer golden_file.close();
            golden = try golden_file.readToEndAlloc(allocator, 64 * 1024);
        } else |_| {}

        try fixtures.append(allocator, .{
            .name = name,
            .meta = parsed.value,
            .input = &.{},
            .golden = golden,
            .parsed = parsed,
        });
    }

    return fixtures.toOwnedSlice(allocator);
}

pub fn deinitFixtures(allocator: std.mem.Allocator, fixtures: []Fixture) void {
    for (fixtures) |*fixture| {
        deinitFixture(allocator, fixture);
    }
    allocator.free(fixtures);
}

fn deinitFixture(allocator: std.mem.Allocator, fixture: *Fixture) void {
    allocator.free(fixture.name);
    allocator.free(fixture.input);
    if (fixture.golden) |golden| allocator.free(golden);
    fixture.parsed.deinit();
}

pub fn runFixture(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) ![]u8 {
    const observed = try runFixtureObserved(allocator, fixture);
    allocator.free(observed.observed.row_spans);
    return observed.output;
}

pub fn runFixtureObserved(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) !RunFixtureObserved {
    return runFixtureObservedWithOptions(allocator, fixture, .{});
}

pub fn runFixtureObservedWithOptions(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
    options: RunFixtureOptions,
) !RunFixtureObserved {
    if (fixture.meta.rows == 0 or fixture.meta.cols == 0) {
        return error.InvalidFixtureSize;
    }

    var session = try terminal.TerminalSession.init(allocator, fixture.meta.rows, fixture.meta.cols);
    defer session.deinit();
    var baseline_publication: BaselinePublication = .{};

    var reply_capture: ?ReplayPtyCapture = null;
    if (fixture.meta.reply_hex != null) {
        reply_capture = try ReplayPtyCapture.init();
        session.attachPtyTransport(reply_capture.?.pty);
    } else {
        session.attachExternalTransport();
    }
    defer {
        if (reply_capture != null) {
            session.detachPtyTransport();
            var capture = reply_capture.?;
            capture.deinit();
        }
    }

    terminal.debugSetCursor(session, fixture.meta.cursor.row, fixture.meta.cursor.col);
    try seedOsc5522Clipboard(session, fixture.meta);

    if (fixture.meta.baseline_input != null or
        fixture.meta.baseline_scrollback_rows.len > 0 or
        fixture.meta.baseline_grid_rows.len > 0 or
        fixture.meta.baseline_scroll_offsets.len > 0)
    {
        if (fixture.meta.baseline_input) |baseline_input| {
            const normalized_baseline = try normalizeLineEndings(allocator, baseline_input, fixture.meta.line_ending);
            defer allocator.free(normalized_baseline);
            try runFixtureInputPhase(session, normalized_baseline, reply_capture != null);
        }
        applyBaselineScrollbackRows(session, fixture.meta.baseline_scrollback_rows);
        applyBaselineGridRows(session, fixture.meta.baseline_grid_rows);
        applyScrollOffsetActions(session, fixture.meta.baseline_scroll_offsets);
        baseline_publication.generation = session.renderCache().generation;
        session.notePresentedGeneration(session.renderCache().generation);
        if (!session.acknowledgePresentedGeneration(session.renderCache().generation)) {
            return error.BaselinePublishAcknowledgeFailed;
        }
    }

    const normalized = try normalizeLineEndings(allocator, fixture.input, fixture.meta.line_ending);
    defer allocator.free(normalized);
    const has_meaningful_input = if (fixture.meta.fixture_type == .harness_api)
        std.mem.trim(u8, normalized, "\r\n\t ").len > 0
    else
        normalized.len > 0;
    if (has_meaningful_input) {
        try runFixtureInputPhase(session, normalized, reply_capture != null);
    }

    if (fixture.meta.fixture_type == .harness_api) {
        try applyOutputChunks(allocator, session, fixture.meta.output_chunks, fixture.meta.line_ending, reply_capture != null);
        applySelectionActions(session, fixture.meta.selection);
        applyScrollOffsetActions(session, fixture.meta.scroll_offsets);
        applyScrollFullUp(session, fixture.meta.scroll_full_up_count);
        applyScrollbackCellActions(session, fixture.name, fixture.meta.scrollback_cells);
    }
    try applyMouseActions(session, fixture.meta.mouse);

    const snapshot = session.snapshot();
    const debug = terminal.debugSnapshot(session);
    if (options.validate_assertions) {
        try validateAssertions(fixture, snapshot, debug, baseline_publication);
    }
    if (fixture.meta.reply_hex) |reply_hex| {
        var capture = reply_capture orelse return error.ReplyAssertionMissingCapture;
        const actual = try capture.readAll(allocator);
        defer allocator.free(actual);
        const expected = try decodeHex(allocator, reply_hex);
        defer allocator.free(expected);
        if (!std.mem.eql(u8, actual, expected)) return error.ReplyAssertionMismatch;
    }

    const output = try snapshot_mod.encodeSnapshot(allocator, session, snapshot, debug, terminal.debugScrollbackRow);
    return .{
        .output = output,
        .observed = try observedFixtureState(allocator, snapshot, debug, baseline_publication),
    };
}

fn runFixtureInputPhase(session: *terminal.TerminalSession, input: []const u8, uses_reply_capture: bool) !void {
    if (uses_reply_capture) {
        terminal.debugFeedBytes(session, input);
    } else {
        _ = try session.enqueueExternalBytes(input);
        try session.poll();
    }
}

fn seedOsc5522Clipboard(session: *terminal.TerminalSession, meta: FixtureMeta) !void {
    if (meta.osc_5522_clipboard_text) |text| {
        session.core.kitty_osc5522_clipboard_text.clearRetainingCapacity();
        try session.core.kitty_osc5522_clipboard_text.ensureTotalCapacity(session.allocator, text.len);
        try session.core.kitty_osc5522_clipboard_text.appendSlice(session.allocator, text);
    }
    if (meta.osc_5522_clipboard_html) |html| {
        session.core.kitty_osc5522_clipboard_html.clearRetainingCapacity();
        try session.core.kitty_osc5522_clipboard_html.ensureTotalCapacity(session.allocator, html.len);
        try session.core.kitty_osc5522_clipboard_html.appendSlice(session.allocator, html);
    }
    if (meta.osc_5522_clipboard_uri_list) |uri_list| {
        session.core.kitty_osc5522_clipboard_uri_list.clearRetainingCapacity();
        try session.core.kitty_osc5522_clipboard_uri_list.ensureTotalCapacity(session.allocator, uri_list.len);
        try session.core.kitty_osc5522_clipboard_uri_list.appendSlice(session.allocator, uri_list);
    }
    if (meta.osc_5522_clipboard_png_hex) |hex| {
        const bytes = try decodeHex(session.allocator, hex);
        defer session.allocator.free(bytes);
        session.core.kitty_osc5522_clipboard_png.clearRetainingCapacity();
        try session.core.kitty_osc5522_clipboard_png.ensureTotalCapacity(session.allocator, bytes.len);
        try session.core.kitty_osc5522_clipboard_png.appendSlice(session.allocator, bytes);
    }
}

pub fn runEncoderFixture(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) ![]u8 {
    const encoder = fixture.meta.encoder orelse return error.MissingEncoderSpec;
    if (encoder.key == null and encoder.char == null) return error.MissingEncoderValue;
    if (encoder.key != null and encoder.char != null) return error.InvalidEncoderSpec;
    try validateEncoderAssertions(fixture);

    if (encoder.key) |key| {
        return input_mod.encodeKeyActionBytesForTest(allocator, key, encoder.mod, encoder.flags, encoder.action);
    }
    if (encoder.alternate_meta != null and encoder.alternate_probe_meta != null) return error.InvalidEncoderSpec;
    if (encoder.alternate_probe_meta) |probe_spec| {
        var text_utf8_buf: [4]u8 = .{ 0, 0, 0, 0 };
        var text_event: shared_types.input.TextEvent = .{
            .codepoint = encoder.char.?,
            .text_is_composed = probe_spec.text_is_composed,
        };
        if (probe_spec.text_utf8) |provided| {
            const n = @min(provided.len, text_utf8_buf.len);
            @memcpy(text_utf8_buf[0..n], provided[0..n]);
            text_event.utf8_len = @intCast(n);
            text_event.utf8 = text_utf8_buf;
        }
        const key_event: shared_types.input.KeyEvent = .{
            .key = probe_spec.key_enum,
            .mods = .{
                .shift = probe_spec.key_mods.shift,
                .alt = probe_spec.key_mods.alt,
                .ctrl = probe_spec.key_mods.ctrl,
                .super = probe_spec.key_mods.super,
                .altgr = probe_spec.key_mods.altgr,
            },
            .repeated = false,
            .pressed = true,
            .scancode = probe_spec.key_scancode,
            .sym = probe_spec.key_sym,
            .sdl_mod_bits = null,
        };
        const meta = alt_probe.buildTextEventAlternateMetadata(key_event, text_event, encoder.char.?, .{
            .base = probe_spec.probe_base_codepoint,
            .shifted = probe_spec.probe_shifted_codepoint,
            .event_sym = probe_spec.probe_event_sym_codepoint,
            .altgr = probe_spec.probe_altgr_codepoint,
            .altgr_shift = probe_spec.probe_altgr_shift_codepoint,
            .explicit_altgr = probe_spec.explicit_altgr,
            .explicit_non_altgr_alt = probe_spec.explicit_non_altgr_alt,
        });
        return input_mod.encodeCharEventBytesForTest(allocator, .{
            .codepoint = encoder.char.?,
            .mod = encoder.mod,
            .key_mode_flags = encoder.flags,
            .action = encoder.action,
            .protocol = .{ .alternate = meta },
        });
    }
    if (encoder.alternate_meta) |alt| {
        return input_mod.encodeCharEventBytesForTest(allocator, .{
            .codepoint = encoder.char.?,
            .mod = encoder.mod,
            .key_mode_flags = encoder.flags,
            .action = encoder.action,
            .protocol = .{
                .alternate = .{
                    .physical_key = alt.physical_key,
                    .produced_text_utf8 = alt.produced_text_utf8,
                    .base_codepoint = alt.base_codepoint,
                    .shifted_codepoint = alt.shifted_codepoint,
                    .alternate_layout_codepoint = alt.alternate_layout_codepoint,
                    .text_is_composed = alt.text_is_composed,
                },
            },
        });
    }
    return input_mod.encodeCharBytesForTest(allocator, encoder.char.?, encoder.mod, encoder.flags);
}

fn validateEncoderAssertions(fixture: *const Fixture) !void {
    for (fixture.meta.assertions) |tag| {
        if (std.mem.eql(u8, tag, "encoder")) continue;
        return error.UnknownAssertionTag;
    }
}

fn validateAssertions(
    fixture: *const Fixture,
    snapshot: terminal.TerminalSnapshot,
    debug: terminal.DebugSnapshot,
    baseline_publication: BaselinePublication,
) !void {
    for (fixture.meta.assertions) |tag| {
        if (std.mem.eql(u8, tag, "grid")) {
            if (!snapshotHasNonDefaultGrid(snapshot)) return error.AssertionGridNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "cursor")) {
            if (snapshot.cursor.row == fixture.meta.cursor.row and snapshot.cursor.col == fixture.meta.cursor.col) {
                return error.AssertionCursorNotExercised;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "attrs")) {
            if (!snapshotHasNonDefaultAttrs(snapshot, debug.base_default_attrs)) return error.AssertionAttrsNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "clipboard")) {
            if (debug.osc_clipboard.len == 0) return error.AssertionClipboardNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "hyperlinks")) {
            if (debug.hyperlinks.len == 0) return error.AssertionHyperlinksNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "selection")) {
            if (debug.selection == null) return error.AssertionSelectionNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "scrollback")) {
            if (!fixtureExercisesScrollbackOrScrollSemantics(fixture, debug)) {
                return error.AssertionScrollbackNotExercised;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "reply")) {
            if (fixture.meta.reply_hex == null) return error.AssertionReplyNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "title")) {
            if (std.mem.eql(u8, debug.title, "Terminal")) return error.AssertionTitleNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "cwd")) {
            if (debug.cwd.len == 0) return error.AssertionCwdNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "kitty")) {
            if (snapshot.kitty_generation == 0) return error.AssertionKittyNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "alt-screen")) {
            const input = fixture.input;
            const has_alt = std.mem.indexOf(u8, input, "\x1b[?47h") != null or
                std.mem.indexOf(u8, input, "\x1b[?47l") != null or
                std.mem.indexOf(u8, input, "\x1b[?1047h") != null or
                std.mem.indexOf(u8, input, "\x1b[?1047l") != null or
                std.mem.indexOf(u8, input, "\x1b[?1049h") != null or
                std.mem.indexOf(u8, input, "\x1b[?1049l") != null;
            if (!has_alt) return error.AssertionAltScreenNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "damage")) {
            const cache = fixtureRenderCache(debug);
            const actual_dirty = if (cache) |c| c.dirty else snapshot.dirty;
            const actual_damage = if (cache) |c| c.damage else snapshot.damage;
            if (fixture.meta.expected_dirty) |expected_dirty| {
                const expected = switch (expected_dirty) {
                    .none => screen_mod.Dirty.none,
                    .partial => screen_mod.Dirty.partial,
                    .full => screen_mod.Dirty.full,
                };
                if (actual_dirty != expected) {
                    return error.AssertionDamageDirtyMismatch;
                }
            }
            if (fixture.meta.expected_damage) |expected_damage| {
                if (actual_damage.start_row != expected_damage.start_row or
                    actual_damage.end_row != expected_damage.end_row or
                    actual_damage.start_col != expected_damage.start_col or
                    actual_damage.end_col != expected_damage.end_col)
                {
                    return error.AssertionDamageBoundsMismatch;
                }
            }
            if (fixture.meta.expected_dirty == null and fixture.meta.expected_damage == null) {
                return error.AssertionDamageExpectationMissing;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "viewport-shift")) {
            const cache = fixtureRenderCache(debug) orelse return error.AssertionViewportShiftMissingCache;
            if (fixture.meta.expected_viewport_shift_rows) |expected_rows| {
                if (cache.viewport_shift_rows != expected_rows) {
                    return error.AssertionViewportShiftRowsMismatch;
                }
            }
            if (fixture.meta.expected_viewport_shift_exposed_only) |expected_exposed_only| {
                if (cache.viewport_shift_exposed_only != expected_exposed_only) return error.AssertionViewportShiftExposureMismatch;
            }
            if (fixture.meta.expected_viewport_shift_rows == null and fixture.meta.expected_viewport_shift_exposed_only == null) {
                return error.AssertionViewportShiftExpectationMissing;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "generation")) {
            if (fixture.meta.expected_generation_advanced_from_baseline) |expected_advanced| {
                const baseline_generation = baseline_publication.generation orelse return error.AssertionGenerationMissingBaseline;
                const actual_advanced = snapshot.generation != baseline_generation;
                if (actual_advanced != expected_advanced) return error.AssertionGenerationMismatch;
            }
            if (fixture.meta.expected_generation_advanced_from_baseline == null) {
                return error.AssertionGenerationExpectationMissing;
            }
            continue;
        }
        return error.UnknownAssertionTag;
    }
}

fn fixtureRenderCache(debug: terminal.DebugSnapshot) ?*const terminal.RenderCache {
    return debug.render_cache;
}

fn observedFixtureState(
    allocator: std.mem.Allocator,
    snapshot: terminal.TerminalSnapshot,
    debug: terminal.DebugSnapshot,
    baseline_publication: BaselinePublication,
) !ObservedFixtureState {
    const cache = fixtureRenderCache(debug);
    const actual_dirty = if (cache) |c| c.dirty else snapshot.dirty;
    const actual_damage = if (cache) |c| c.damage else snapshot.damage;
    var row_spans = std.ArrayList(ObservedFixtureState.RowSpan).empty;
    errdefer row_spans.deinit(allocator);

    if (cache) |c| {
        var row_idx: usize = 0;
        while (row_idx < c.rows) : (row_idx += 1) {
            if (!c.dirty_rows.items[row_idx]) continue;
            try row_spans.append(allocator, .{
                .row = row_idx,
                .start_col = c.dirty_cols_start.items[row_idx],
                .end_col = c.dirty_cols_end.items[row_idx],
            });
        }
    } else {
        var row_idx: usize = 0;
        while (row_idx < snapshot.rows) : (row_idx += 1) {
            if (!snapshot.dirty_rows[row_idx]) continue;
            try row_spans.append(allocator, .{
                .row = row_idx,
                .start_col = snapshot.dirty_cols_start[row_idx],
                .end_col = snapshot.dirty_cols_end[row_idx],
            });
        }
    }

    return .{
        .dirty = switch (actual_dirty) {
            .none => .none,
            .partial => .partial,
            .full => .full,
        },
        .damage = .{
            .start_row = actual_damage.start_row,
            .end_row = actual_damage.end_row,
            .start_col = actual_damage.start_col,
            .end_col = actual_damage.end_col,
        },
        .viewport_shift_rows = if (cache) |c| c.viewport_shift_rows else null,
        .viewport_shift_exposed_only = if (cache) |c| c.viewport_shift_exposed_only else null,
        .generation = snapshot.generation,
        .baseline_generation = baseline_publication.generation,
        .history_len = if (cache) |c| c.history_len else null,
        .total_lines = if (cache) |c| c.total_lines else null,
        .scroll_offset = if (cache) |c| c.scroll_offset else null,
        .row_spans = try row_spans.toOwnedSlice(allocator),
    };
}

fn decodeHex(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len % 2) != 0) return error.InvalidHexLength;
    var out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        const hi = try std.fmt.charToDigit(hex[i * 2], 16);
        const lo = try std.fmt.charToDigit(hex[i * 2 + 1], 16);
        out[i] = @as(u8, @intCast(hi * 16 + lo));
    }
    return out;
}

fn snapshotHasNonDefaultGrid(snapshot: terminal.TerminalSnapshot) bool {
    for (snapshot.cells) |cell| {
        if (cell.width == 0) return true;
        if (cell.codepoint != 0) return true;
        if (cell.combining_len > 0) return true;
    }
    return false;
}

fn snapshotHasNonDefaultAttrs(snapshot: terminal.TerminalSnapshot, base_default: terminal.CellAttrs) bool {
    for (snapshot.cells) |cell| {
        if (!attrsEqual(cell.attrs, base_default)) return true;
    }
    return false;
}

fn fixtureExercisesScrollbackOrScrollSemantics(fixture: *const Fixture, debug: terminal.DebugSnapshot) bool {
    if (debug.scrollback_count > 0 or debug.scrollback_offset > 0) return true;
    const input = fixture.input;
    if (inputHasCsiFinal(input, 'r') or // DECSTBM set/reset scroll region
        inputHasCsiFinal(input, 'S') or // SU
        inputHasCsiFinal(input, 'T'))
    {
        return true;
    }
    return inputLineBreakCount(input) >= fixture.meta.rows;
}

fn inputHasCsiFinal(input: []const u8, final: u8) bool {
    var i: usize = 0;
    while (i + 2 < input.len) : (i += 1) {
        if (input[i] != 0x1b or input[i + 1] != '[') continue;
        var j = i + 2;
        while (j < input.len) : (j += 1) {
            const b = input[j];
            if (b >= 0x40 and b <= 0x7e) {
                if (b == final) return true;
                break;
            }
        }
        i = j;
    }
    return false;
}

fn inputLineBreakCount(input: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') {
            count += 1;
            continue;
        }
        if (input[i] == '\r') {
            count += 1;
            if (i + 1 < input.len and input[i + 1] == '\n') i += 1;
        }
    }
    return count;
}

fn attrsEqual(a: terminal.CellAttrs, b: terminal.CellAttrs) bool {
    return a.fg.r == b.fg.r and a.fg.g == b.fg.g and a.fg.b == b.fg.b and a.fg.a == b.fg.a and
        a.bg.r == b.bg.r and a.bg.g == b.bg.g and a.bg.b == b.bg.b and a.bg.a == b.bg.a and
        a.bold == b.bold and a.blink == b.blink and a.blink_fast == b.blink_fast and
        a.reverse == b.reverse and a.underline == b.underline and
        a.underline_color.r == b.underline_color.r and
        a.underline_color.g == b.underline_color.g and
        a.underline_color.b == b.underline_color.b and
        a.underline_color.a == b.underline_color.a and
        a.link_id == b.link_id;
}

fn applySelectionActions(session: *terminal.TerminalSession, actions: []const SelectionAction) void {
    for (actions) |action| {
        switch (action.op) {
            .start => session.startSelection(action.row, action.col),
            .update => session.updateSelection(action.row, action.col),
            .finish => session.finishSelection(),
            .select_range => session.selectRange(
                .{ .row = action.row, .col = action.col },
                .{ .row = action.end_row, .col = action.end_col },
                action.finished,
            ),
        }
        session.updateViewCacheForScroll();
    }
}

fn applyOutputChunks(
    allocator: std.mem.Allocator,
    session: *terminal.TerminalSession,
    chunks: []const []const u8,
    line_ending: LineEnding,
    uses_reply_capture: bool,
) !void {
    for (chunks) |chunk| {
        const normalized = try normalizeLineEndings(allocator, chunk, line_ending);
        defer allocator.free(normalized);
        try runFixtureInputPhase(session, normalized, uses_reply_capture);
    }
}

fn applyScrollFullUp(session: *terminal.TerminalSession, count: usize) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        terminal.debugScrollUp(session);
    }
}

fn applyScrollOffsetActions(session: *terminal.TerminalSession, actions: []const ScrollOffsetAction) void {
    for (actions) |action| {
        terminal.debugSetScrollOffset(session, action.offset);
    }
}

fn applyScrollbackCellActions(session: *terminal.TerminalSession, fixture_name: []const u8, actions: []const ScrollbackCellAction) void {
    _ = fixture_name;
    for (actions) |action| {
        terminal.debugSetScrollbackCell(session, action.row, action.col, action.codepoint);
    }
}

fn applyBaselineScrollbackRows(session: *terminal.TerminalSession, rows: []const []const u8) void {
    for (rows) |row| {
        terminal.debugPushScrollbackRow(session, row);
    }
}

fn applyBaselineGridRows(session: *terminal.TerminalSession, rows: []const []const u8) void {
    for (rows, 0..) |row, idx| {
        terminal.debugSetGridRow(session, idx, row);
    }
}


fn applyMouseActions(session: *terminal.TerminalSession, actions: []const MouseAction) !void {
    for (actions) |action| {
        _ = try session.reportMouseEvent(.{
            .kind = action.kind,
            .button = action.button,
            .row = action.row,
            .col = action.col,
            .pixel_x = action.pixel_x,
            .pixel_y = action.pixel_y,
            .mod = action.mod,
            .buttons_down = action.buttons_down,
        });
    }
}

fn normalizeLineEndings(
    allocator: std.mem.Allocator,
    input_bytes: []const u8,
    mode: LineEnding,
) ![]u8 {
    if (input_bytes.len == 0) return allocator.alloc(u8, 0);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < input_bytes.len) {
        const b = input_bytes[i];
        if (b == '\r') {
            if (i + 1 < input_bytes.len and input_bytes[i + 1] == '\n') {
                i += 2;
            } else {
                i += 1;
            }
            switch (mode) {
                .lf => try out.append(allocator, '\n'),
                .crlf => try out.appendSlice(allocator, "\r\n"),
                .cr => try out.append(allocator, '\r'),
            }
            continue;
        }
        if (b == '\n') {
            i += 1;
            switch (mode) {
                .lf => try out.append(allocator, '\n'),
                .crlf => try out.appendSlice(allocator, "\r\n"),
                .cr => try out.append(allocator, '\r'),
            }
            continue;
        }
        try out.append(allocator, b);
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}
