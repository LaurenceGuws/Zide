const publication_capture = @import("../../terminal/core/publication/publication_capture.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const view_state = @import("terminal_widget_view_state.zig");

const RenderCache = render_cache_mod.RenderCache;

pub const TerminalWidgetPublicationState = struct {
    cache: RenderCache,

    pub fn init() TerminalWidgetPublicationState {
        return .{
            .cache = RenderCache.init(),
        };
    }

    pub fn deinit(self: *TerminalWidgetPublicationState, allocator: anytype) void {
        self.cache.deinit(allocator);
    }

    pub fn model(self: *const TerminalWidgetPublicationState) view_state.TerminalViewModel {
        return view_state.model(&self.cache);
    }

    pub fn prepareLatestPresentation(
        self: *TerminalWidgetPublicationState,
        session: anytype,
    ) !publication_capture.LatestPresentationPreparation {
        return publication_capture.prepareLatestPresentation(session, &self.cache);
    }

    pub fn cacheConst(self: *const TerminalWidgetPublicationState) *const RenderCache {
        return &self.cache;
    }

    pub fn cacheMut(self: *TerminalWidgetPublicationState) *RenderCache {
        return &self.cache;
    }
};
