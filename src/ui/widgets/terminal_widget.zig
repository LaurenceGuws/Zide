//! Terminal UI widget: publication capture feeds draw. `terminal.generation_handoff` logs pair
//! publication generation state with the terminal presentable **pipeline** leg (`terminalPresentablePipelineReady`);
//! they are not full attachment logs — host target and conjunction vocabulary live on
//! `TerminalWidgetSurfaceState` and `PresentationPresentState.shared_surface_attachment_ready` (`CZH-B24`, alias lock `CZH-B25`).
//! Present aggregation (`TerminalPresentResult`) keeps host-target vs full-attachment fields
//! distinct (`CZH-B26`). **Reporting carrier (`CZH-S23`):** widget shell defers conjunction in
//! `renderer.terminal_present` to runtime’s `PresentationPresentState` snapshot, not draw.
//! **Shell vs runtime (`CZH-S24`):** widget shell orchestrates draw/input/publication; presentation
//! runtime computes present outcomes and **aggregates** host-facing present results — the shell does
//! not substitute reporting carriers for `TerminalPresentResult` fields.
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const session_interaction = @import("../../terminal/core/session/interaction.zig");
const shared_types = @import("../../types/mod.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const paste_mod = @import("terminal_widget_paste.zig");
const input_bridge_mod = @import("terminal_widget_input_bridge.zig");
const draw_mod = @import("terminal_widget_draw.zig");
const input_mod = @import("terminal_widget_input.zig");
const controller_state_mod = @import("terminal_widget_controller_state.zig");
const publication_state_mod = @import("terminal_widget_publication_state.zig");
const surface_state_mod = @import("terminal_widget_surface_state.zig");
const debug_geometry_mod = @import("terminal_widget_debug_geometry.zig");
const debug_capture_mod = @import("terminal_widget_debug_capture.zig");

const Shell = app_shell.Shell;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
const TerminalWidgetPublicationState = publication_state_mod.TerminalWidgetPublicationState;
const TerminalWidgetSurfaceState = surface_state_mod.TerminalWidgetSurfaceState;
const DrawOutcome = draw_mod.DrawOutcome;
const DrawPreparation = draw_mod.DrawPreparation;
const DebugCaptureState = debug_geometry_mod.DebugCaptureState;
const TerminalWidgetControllerState = controller_state_mod.TerminalWidgetControllerState;

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    pub const BlinkStyle = enum {
        kitty,
        off,
    };

    pub const PendingOpen = controller_state_mod.PendingOpen;
    pub const FocusReportSource = enum {
        window,
        pane,
    };
    session: *TerminalRuntimeShell,
    blink_style: BlinkStyle = .kitty,
    controller: TerminalWidgetControllerState = .{},
    publication: TerminalWidgetPublicationState,
    surface: TerminalWidgetSurfaceState,
    debug: DebugCaptureState = .{},

    pub const ScrollbarModel = struct {
        allowed: bool,
        visible: bool,
        rows: usize,
        total_lines: usize,
        scroll_offset: usize,
    };

    pub fn init(session: *TerminalRuntimeShell, blink_style: BlinkStyle) TerminalWidget {
        return .{
            .session = session,
            .blink_style = blink_style,
            .controller = .{},
            .publication = TerminalWidgetPublicationState.init(),
            .surface = TerminalWidgetSurfaceState.init(session.allocator),
            .debug = .{},
        };
    }

    pub fn setFocusReportSources(self: *TerminalWidget, window: bool, pane: bool) void {
        self.controller.focus.setSources(window, pane);
    }

    pub fn reportFocusChangedFrom(self: *TerminalWidget, source: FocusReportSource, focused: bool) !bool {
        return self.controller.focus.reportChanged(self.session, &self.controller.hover, source, focused);
    }

    pub fn setUiFocused(self: *TerminalWidget, focused: bool) void {
        self.controller.focus.setUiFocused(&self.controller.hover, focused);
    }

    pub fn updateBlink(self: *TerminalWidget, now: f64) bool {
        return self.controller.blink.update(self.publication.cacheConst(), self.blink_style, now);
    }

    pub fn noteInput(self: *TerminalWidget, now: f64) void {
        self.controller.blink.noteInput(now);
    }

    pub fn deinit(self: *TerminalWidget) void {
        self.controller.pending.deinit(self.session.allocator);
        self.publication.deinit(self.session.allocator);
        self.surface.deinit(self.session.allocator);
    }

    pub fn takePendingOpenRequest(self: *TerminalWidget) ?PendingOpen {
        return self.controller.pending.takeOpenRequest();
    }

    pub fn stagePresentationFeedback(self: *TerminalWidget, feedback: DrawOutcome) void {
        self.controller.pending.stagePresentationFeedback(feedback);
    }

    pub fn completePendingPresentationFeedback(self: *TerminalWidget, submission: anytype) void {
        self.controller.pending.completePendingPresentationFeedback(self.session, submission);
    }

    pub fn invalidatePresentationCache(self: *TerminalWidget) void {
        self.surface.invalidatePresentationContent();
    }

    pub fn invalidatePresentationContent(self: *TerminalWidget) void {
        self.surface.invalidatePresentationContent();
    }

    pub fn invalidatePresentationGeometry(self: *TerminalWidget) void {
        self.surface.invalidatePresentationGeometry();
    }

    pub fn invalidatePresentationOverlay(self: *TerminalWidget) void {
        self.surface.invalidatePresentationOverlay();
    }

    pub fn dumpVisibleAsciiView(self: *TerminalWidget, shell: *Shell, log: anytype) !void {
        try debug_capture_mod.dumpVisibleAsciiView(self, shell, log);
    }

    pub fn pasteClipboardFromSystem(self: *TerminalWidget, shell: *Shell) bool {
        const clip_opt = shell.getClipboardText();
        const html = shell.getClipboardMimeData(self.session.allocator, "text/html");
        const uri_list = shell.getClipboardMimeData(self.session.allocator, "text/uri-list");
        const png = shell.getClipboardMimeData(self.session.allocator, "image/png");
        defer if (html) |buf| self.session.allocator.free(buf);
        defer if (uri_list) |buf| self.session.allocator.free(buf);
        defer if (png) |buf| self.session.allocator.free(buf);
        const input_adapter = input_bridge_mod.TerminalInputAdapter.init(self.session);
        return paste_mod.pasteSystemClipboard(self, &input_adapter, clip_opt, html, uri_list, png);
    }

    pub fn scrollbarModel(self: *const TerminalWidget) ScrollbarModel {
        const terminal_view = self.viewModel();
        const scrollbar = terminal_view.scrollbarInfo(session_interaction.mouseReportingEnabled(self.session));
        return .{
            .allowed = scrollbar.allowed,
            .visible = scrollbar.allowed,
            .rows = scrollbar.rows,
            .total_lines = scrollbar.total_lines,
            .scroll_offset = scrollbar.scroll_offset,
        };
    }

    pub fn viewModel(self: *const TerminalWidget) @import("terminal_widget_view_state.zig").TerminalViewModel {
        return self.publication.model();
    }

    pub fn draw(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        input: shared_types.input.InputSnapshot,
    ) DrawOutcome {
        const draw_start = app_shell.getTime();
        const handoff_log = app_logger.logger("terminal.generation_handoff");
        const latest_capture = self.publication.prepareLatestPresentation(self.session) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "draw snapshot copy failed err={s}", .{@errorName(err)});
            return .{};
        };
        const capture = latest_capture.capture;
        if (handoff_log.enabled_file or handoff_log.enabled_console) {
            const generation_state = latest_capture.generation_state;
            handoff_log.logf(
                .info,
                "stage=widget_prepare sid={x} last_surface_render_generation={d} capture_presented_generation={d} publication_pending_generation={d} publication_published_generation={d} publication_presented_generation={d} terminal_presentable_pipeline_ready={d} cache_dirty={s}",
                .{
                    @intFromPtr(self.session),
                    self.surface.lastRenderGeneration(),
                    capture.presented.generation,
                    generation_state.pending,
                    generation_state.published,
                    generation_state.presented,
                    @intFromBool(self.surface.terminalPresentablePipelineReady()),
                    @tagName(capture.presented.dirty),
                },
            );
            if (latest_capture.refreshed) {
                handoff_log.logf(
                    .info,
                    "stage=widget_prepare_latest sid={x} last_surface_render_generation={d} capture_presented_generation={d} publication_pending_generation={d} publication_published_generation={d} publication_presented_generation={d} terminal_presentable_pipeline_ready={d} cache_dirty={s}",
                    .{
                        @intFromPtr(self.session),
                        self.surface.lastRenderGeneration(),
                        capture.presented.generation,
                        generation_state.pending,
                        generation_state.published,
                        generation_state.presented,
                        @intFromBool(self.surface.terminalPresentablePipelineReady()),
                        @tagName(capture.presented.dirty),
                    },
                );
            }
        }
        return draw_mod.drawPrepared(self, shell, x, y, width, height, input, DrawPreparation.fromCapture(draw_start, capture));
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        allow_input: bool,
        suppress_shortcuts: bool,
        input_batch: *shared_types.input.InputBatch,
    ) !bool {
        return input_mod.handleInput(
            self,
            shell,
            x,
            y,
            width,
            height,
            allow_input,
            suppress_shortcuts,
            input_batch,
        );
    }
};
