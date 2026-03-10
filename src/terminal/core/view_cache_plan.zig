pub const PublicationPlan = struct {
    visible_history_changed: bool,
    viewport_shift_rows: i32,
    shift_abs: usize,
    scroll_offset_changed: bool,
    can_publish_scroll_shift: bool,
    requires_full_damage_for_scroll_offset_change: bool,
    needs_full_damage: bool,
};

pub fn buildPublicationPlan(
    visible_history_generation: u64,
    active_visible_history_generation: u64,
    clamped_offset: usize,
    active_scroll_offset: usize,
    history_len: usize,
    active_history_len: usize,
    total_lines: usize,
    active_total_lines: usize,
    rows: usize,
    active_rows: usize,
    cols: usize,
    active_cols: usize,
    selection_active: bool,
    active_selection_active: bool,
    view_dirty: anytype,
    view_dirty_none: bool,
    presented_generation: u64,
    active_generation: u64,
    active_is_alt: bool,
    cache_alt_active: bool,
) PublicationPlan {
    const visible_history_changed = visible_history_generation != active_visible_history_generation or
        (clamped_offset > 0 and (history_len != active_history_len or total_lines != active_total_lines)) or
        (clamped_offset == 0 and active_scroll_offset == 0 and
            (history_len != active_history_len or total_lines != active_total_lines));

    const start_line = if (total_lines > rows + clamped_offset)
        total_lines - rows - clamped_offset
    else
        0;

    var viewport_shift_rows: i32 = 0;
    if (active_rows == rows) {
        const prev_end_line = if (active_total_lines > active_scroll_offset)
            active_total_lines - active_scroll_offset
        else
            0;
        const prev_start_line = if (prev_end_line > rows) prev_end_line - rows else 0;
        viewport_shift_rows = @as(i32, @intCast(start_line)) - @as(i32, @intCast(prev_start_line));
    }

    const shift_abs: usize = @intCast(if (viewport_shift_rows < 0) -viewport_shift_rows else viewport_shift_rows);
    const scroll_offset_changed = clamped_offset != active_scroll_offset;
    const can_publish_offset_scroll_shift = scroll_offset_changed and
        !selection_active and
        !active_selection_active and
        !visible_history_changed and
        view_dirty_none and
        active_rows == rows and
        active_cols == cols and
        active_generation == presented_generation and
        shift_abs > 0 and
        shift_abs < rows;
    const history_delta = total_lines -| active_total_lines;
    const can_publish_live_scroll_shift = !scroll_offset_changed and
        clamped_offset == 0 and
        active_scroll_offset == 0 and
        !selection_active and
        !active_selection_active and
        visible_history_changed and
        view_dirty != .full and
        active_rows == rows and
        active_cols == cols and
        active_generation == presented_generation and
        shift_abs > 0 and
        shift_abs < rows and
        history_delta == shift_abs;
    const can_publish_scroll_shift = can_publish_offset_scroll_shift or can_publish_live_scroll_shift;
    const requires_full_damage_for_scroll_offset_change = scroll_offset_changed and !can_publish_scroll_shift;
    const needs_full_damage = rows != active_rows or
        cols != active_cols or
        requires_full_damage_for_scroll_offset_change or
        active_is_alt != cache_alt_active or
        view_dirty == .full;

    return .{
        .visible_history_changed = visible_history_changed,
        .viewport_shift_rows = viewport_shift_rows,
        .shift_abs = shift_abs,
        .scroll_offset_changed = scroll_offset_changed,
        .can_publish_scroll_shift = can_publish_scroll_shift,
        .requires_full_damage_for_scroll_offset_change = requires_full_damage_for_scroll_offset_change,
        .needs_full_damage = needs_full_damage,
    };
}
