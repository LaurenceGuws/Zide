const std = @import("std");

const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const presentation_feedback = @import("../../terminal/core/publication/presentation_feedback.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const terminal_selection = @import("../../terminal/core/selection.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const open_mod = @import("terminal_widget_command/open.zig");

const RenderCache = render_cache_mod.RenderCache;
pub const PendingOpen = open_mod.PendingOpen;

pub const PendingActionState = struct {
    open: ?PendingOpen = null,
    presentation_feedback: ?presentation_feedback.PresentationFeedback = null,

    pub fn pendingOpenPtr(self: *PendingActionState) *?PendingOpen {
        return &self.open;
    }

    pub fn deinit(self: *PendingActionState, allocator: std.mem.Allocator) void {
        if (self.open) |req| {
            allocator.free(req.path);
            self.open = null;
        }
    }

    pub fn takeOpenRequest(self: *PendingActionState) ?PendingOpen {
        const value = self.open;
        self.open = null;
        return value;
    }

    pub fn stagePresentationFeedback(self: *PendingActionState, feedback: presentation_feedback.PresentationFeedback) void {
        self.presentation_feedback = feedback;
    }

    pub fn completePendingPresentationFeedback(
        self: *PendingActionState,
        session: anytype,
        submission: anytype,
    ) void {
        const pending = self.presentation_feedback orelse return;
        defer self.presentation_feedback = null;
        presentation_feedback.completeSubmittedPresentationFeedback(session, pending, submission);
    }
};

pub const BlinkUiState = struct {
    last_slow_on: bool = true,
    last_fast_on: bool = true,
    last_active: bool = false,
    phase_changed_pending: bool = false,
    cursor_blink_pause_until: f64 = 0,
    last_terminal_input_time: f64 = 0,

    pub fn update(self: *BlinkUiState, cache: *const RenderCache, blink_style: anytype, now: f64) bool {
        if (blink_style == .off) {
            self.last_active = false;
            self.phase_changed_pending = false;
            return false;
        }
        var has_slow = false;
        var has_fast = false;
        for (cache.cells.items) |cell| {
            if (!cell.attrs.blink) continue;
            if (cell.attrs.blink_fast) {
                has_fast = true;
            } else {
                has_slow = true;
            }
            if (has_slow and has_fast) break;
        }
        if (!has_slow and !has_fast) {
            self.last_active = false;
            self.phase_changed_pending = false;
            return false;
        }
        const slow_on = @mod(now, 2.0) < 1.0;
        const fast_on = @mod(now, 1.0) < 0.5;
        var changed = false;
        if (has_slow) {
            if (!self.last_active or slow_on != self.last_slow_on) {
                changed = true;
            }
            self.last_slow_on = slow_on;
        }
        if (has_fast) {
            if (!self.last_active or fast_on != self.last_fast_on) {
                changed = true;
            }
            self.last_fast_on = fast_on;
        }
        self.last_active = true;
        self.phase_changed_pending = changed;
        return changed;
    }

    pub fn noteInput(self: *BlinkUiState, now: f64) void {
        self.cursor_blink_pause_until = now + 0.4;
        self.last_terminal_input_time = now;
    }

    pub fn takePhaseChangedPending(self: *BlinkUiState) bool {
        const pending = self.phase_changed_pending;
        self.phase_changed_pending = false;
        return pending;
    }

    pub fn cursorBlinkPauseUntil(self: *const BlinkUiState) f64 {
        return self.cursor_blink_pause_until;
    }

    pub fn recentInputWindowActive(self: *const BlinkUiState, at: f64, window_seconds: f64) bool {
        return self.last_terminal_input_time > 0 and
            at >= self.last_terminal_input_time and
            (at - self.last_terminal_input_time) <= window_seconds;
    }
};

pub const FocusUiState = struct {
    report_window_events: bool = true,
    report_pane_events: bool = false,
    last_reported: ?bool = null,
    ui_focused: bool = false,
    ui_window_focused: bool = false,

    pub fn setSources(self: *FocusUiState, window: bool, pane: bool) void {
        self.report_window_events = window;
        self.report_pane_events = pane;
    }

    pub fn reportChanged(
        self: *FocusUiState,
        session: anytype,
        hover: *hover_mod.HoverState,
        source: anytype,
        focused: bool,
    ) !bool {
        var ui_changed = false;
        if (source == .window) {
            ui_changed = self.ui_window_focused != focused;
            self.ui_window_focused = focused;
            self.setUiFocused(hover, self.ui_window_focused);
        }

        const source_enabled = switch (source) {
            .window => self.report_window_events,
            .pane => self.report_pane_events,
        };
        if (!source_enabled) return ui_changed;
        if (self.last_reported) |last| {
            if (last == focused) return ui_changed;
        }
        if (try session_input.reportFocusChanged(session, focused)) {
            self.last_reported = focused;
            return true;
        }
        return ui_changed;
    }

    pub fn setUiFocused(self: *FocusUiState, hover: *hover_mod.HoverState, focused: bool) void {
        if (self.ui_focused == focused) return;
        self.ui_focused = focused;
        if (!focused) {
            hover.* = .{};
        }
        const log = app_logger.logger("terminal.cursor");
        log.logf(.info, "ui_focus changed focused={d}", .{@intFromBool(focused)});
    }

    pub fn isUiFocused(self: *const FocusUiState) bool {
        return self.ui_focused;
    }
};

pub const SelectionGestureState = struct {
    gesture: terminal_selection.SelectionGesture = .{},
    press_origin: ?shared_types.input.MousePos = null,
    drag_active: bool = false,

    pub fn beginPress(self: *SelectionGestureState, press_mouse: shared_types.input.MousePos) void {
        self.press_origin = press_mouse;
        self.drag_active = false;
    }

    pub fn setGesture(self: *SelectionGestureState, gesture: terminal_selection.SelectionGesture) void {
        self.gesture = gesture;
    }

    pub fn reset(self: *SelectionGestureState) void {
        self.gesture = .{};
        self.press_origin = null;
        self.drag_active = false;
    }

    pub fn dragIsActive(self: *const SelectionGestureState) bool {
        return self.drag_active;
    }

    pub fn pressOrigin(self: *const SelectionGestureState) ?shared_types.input.MousePos {
        return self.press_origin;
    }

    pub fn activateDrag(self: *SelectionGestureState) void {
        self.drag_active = true;
    }
};

pub const TerminalWidgetControllerState = struct {
    hover: hover_mod.HoverState = .{},
    pending: PendingActionState = .{},
    blink: BlinkUiState = .{},
    focus: FocusUiState = .{},
    selection: SelectionGestureState = .{},
};
