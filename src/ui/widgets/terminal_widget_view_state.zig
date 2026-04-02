const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const types = @import("../../terminal/model/types.zig");

const RenderCache = render_cache_mod.RenderCache;
const KittyImage = terminal_publication.KittyImage;
const KittyPlacement = terminal_publication.KittyPlacement;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const Color = terminal_publication.Color;

pub const ViewportInfo = struct {
    history_len: usize,
    total_lines: usize,
    scroll_offset: usize,
    start_line: usize,
};

pub const ScrollbarInfo = struct {
    allowed: bool,
    rows: usize,
    total_lines: usize,
    scroll_offset: usize,
};

pub const AltTransition = struct {
    changed: bool,
    exited: bool,
};

pub const LifecycleTransitionInfo = struct {
    changed: bool,
    exited: bool,
    current_alt_active: bool,

    pub fn reason(self: LifecycleTransitionInfo) ?[]const u8 {
        if (!self.changed) return null;
        return if (self.current_alt_active) "alt_enter" else "alt_exit";
    }
};

pub const PartialCaptureInfo = struct {
    use_viewport_shift: bool,
    active_viewport_shift_rows: i32,
    shift_exposed_only: bool,
    reason: []const u8,
};

pub const RenderStateInfo = struct {
    screen_reverse: bool,
    draw_cursor_visible: bool,
    cursor_style: types.CursorStyle,
    has_blinking_cells: bool,
};

pub const BackgroundRunInfo = struct {
    cursor_here: bool,
    cursor_col: ?usize,
    screen_reverse: bool,
};

pub const DirtySummary = struct {
    is_clean: bool,
    dirty_tag: []const u8,
    current_reason: []const u8,
    dirty_rows_count: usize,
    damage_row_span: usize,
    damage_col_span: usize,
    damage_start_row: usize,
    damage_end_row: usize,
    damage_start_col: usize,
    damage_end_col: usize,
};

pub const DrawStateInfo = struct {
    generation: u64,
    clear_generation: u64,
    rows: usize,
    cols: usize,
    viewport: ViewportInfo,
    render: RenderStateInfo,
    sync_updates_active: bool,
    kitty_generation: u64,
    cursor: CursorPos,
    cells: []const Cell,
    kitty_images: []const KittyImage,
    kitty_placements: []const KittyPlacement,
};

pub const BaseColorInfo = struct {
    background: Color,
    resolved_background: Color,
};

pub const VisibleViewDumpInfo = struct {
    rows: usize,
    cols: usize,
    generation: u64,
    scroll_offset: usize,
    alt_active: bool,
    cursor: CursorPos,
    draw_cursor_visible: bool,
    screen_reverse: bool,
};

pub fn viewportInfo(cache: *const RenderCache) ViewportInfo {
    const total_lines = cache.totalLines();
    const end_line = total_lines - cache.scroll_offset;
    return .{
        .history_len = cache.history_len,
        .total_lines = total_lines,
        .scroll_offset = cache.scroll_offset,
        .start_line = if (end_line > cache.rows) end_line - cache.rows else 0,
    };
}

pub fn scrollbarAllowed(cache: *const RenderCache, mouse_reporting_enabled: bool) bool {
    return !cache.alt_active and !mouse_reporting_enabled and cache.rows > 0 and cache.totalLines() > cache.rows;
}

pub fn scrollbarInfo(cache: *const RenderCache, mouse_reporting_enabled: bool) ScrollbarInfo {
    const viewport = viewportInfo(cache);
    return .{
        .allowed = scrollbarAllowed(cache, mouse_reporting_enabled),
        .rows = cache.rows,
        .total_lines = viewport.total_lines,
        .scroll_offset = viewport.scroll_offset,
    };
}

pub fn drawCursorVisible(cache: *const RenderCache) bool {
    return cache.scroll_offset == 0 and cache.cursor_visible;
}

pub fn altTransition(previous_alt_active: bool, cache: *const RenderCache) AltTransition {
    return .{
        .changed = previous_alt_active != cache.alt_active,
        .exited = previous_alt_active and !cache.alt_active,
    };
}

pub fn lifecycleTransitionInfo(previous_alt_active: bool, cache: *const RenderCache) LifecycleTransitionInfo {
    const transition = altTransition(previous_alt_active, cache);
    return .{
        .changed = transition.changed,
        .exited = transition.exited,
        .current_alt_active = cache.alt_active,
    };
}

pub fn partialCaptureInfo(cache: *const RenderCache) PartialCaptureInfo {
    const use_viewport_shift = cache.dirty == .partial and cache.viewport_shift_rows != 0;
    const active_viewport_shift_rows = if (use_viewport_shift) cache.viewport_shift_rows else 0;
    const shift_exposed_only = use_viewport_shift and cache.viewport_shift_exposed_only;
    return .{
        .use_viewport_shift = use_viewport_shift,
        .active_viewport_shift_rows = active_viewport_shift_rows,
        .shift_exposed_only = shift_exposed_only,
        .reason = switch (cache.dirty) {
            .full => @tagName(cache.full_dirty_reason),
            .partial => if (cache.viewport_shift_rows != 0)
                (if (cache.viewport_shift_exposed_only) "viewport_shift_exposed" else "viewport_shift")
            else
                "partial",
            .none => "clean",
        },
    };
}

pub fn renderStateInfo(cache: *const RenderCache) RenderStateInfo {
    return .{
        .screen_reverse = cache.screen_reverse,
        .draw_cursor_visible = drawCursorVisible(cache),
        .cursor_style = cache.cursor_style,
        .has_blinking_cells = cache.has_blink,
    };
}

pub fn backgroundRunInfo(cache: *const RenderCache, row: usize) BackgroundRunInfo {
    const cursor_here = cache.cursor_visible and cache.cursor.row == row and cache.cursor.col < cache.cols;
    return .{
        .cursor_here = cursor_here,
        .cursor_col = if (cursor_here) cache.cursor.col else null,
        .screen_reverse = cache.screen_reverse,
    };
}

pub fn visibleViewDumpInfo(cache: *const RenderCache) VisibleViewDumpInfo {
    const viewport = viewportInfo(cache);
    const render_state = renderStateInfo(cache);
    return .{
        .rows = cache.rows,
        .cols = cache.cols,
        .generation = cache.generation,
        .scroll_offset = viewport.scroll_offset,
        .alt_active = cache.alt_active,
        .cursor = cache.cursor,
        .draw_cursor_visible = render_state.draw_cursor_visible,
        .screen_reverse = render_state.screen_reverse,
    };
}

pub fn dirtySummary(cache: *const RenderCache) DirtySummary {
    var dirty_rows_count: usize = 0;
    var damage_row_span: usize = 0;
    var damage_col_span: usize = 0;

    if (cache.dirty != .none) {
        for (cache.dirty_rows.items) |row_dirty| {
            if (row_dirty) dirty_rows_count += 1;
        }
        if (cache.damage.end_row >= cache.damage.start_row) {
            damage_row_span = cache.damage.end_row - cache.damage.start_row + 1;
        }
        if (cache.damage.end_col >= cache.damage.start_col) {
            damage_col_span = cache.damage.end_col - cache.damage.start_col + 1;
        }
    }

    return .{
        .is_clean = cache.dirty == .none,
        .dirty_tag = @tagName(cache.dirty),
        .current_reason = partialCaptureInfo(cache).reason,
        .dirty_rows_count = dirty_rows_count,
        .damage_row_span = damage_row_span,
        .damage_col_span = damage_col_span,
        .damage_start_row = cache.damage.start_row,
        .damage_end_row = cache.damage.end_row,
        .damage_start_col = cache.damage.start_col,
        .damage_end_col = cache.damage.end_col,
    };
}

pub fn drawStateInfo(cache: *const RenderCache) DrawStateInfo {
    return .{
        .generation = cache.generation,
        .clear_generation = cache.clear_generation,
        .rows = cache.rows,
        .cols = cache.cols,
        .viewport = viewportInfo(cache),
        .render = renderStateInfo(cache),
        .sync_updates_active = cache.sync_updates_active,
        .kitty_generation = cache.kitty_generation,
        .cursor = cache.cursor,
        .cells = cache.cells.items,
        .kitty_images = cache.kitty_images.items,
        .kitty_placements = cache.kitty_placements.items,
    };
}

pub fn baseColorInfo(cache: *const RenderCache) BaseColorInfo {
    const render_state = renderStateInfo(cache);
    if (cache.cells.items.len == 0) {
        return .{
            .background = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
            .resolved_background = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
        };
    }
    const cell = cache.cells.items[0];
    const reversed = cell.attrs.reverse != render_state.screen_reverse;
    return .{
        .background = cell.attrs.bg,
        .resolved_background = if (reversed) cell.attrs.fg else cell.attrs.bg,
    };
}
