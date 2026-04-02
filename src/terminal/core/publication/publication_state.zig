const publication_flow = @import("publication_flow.zig");

pub const GenerationState = struct {
    pending: u64,
    published: u64,
    presented: u64,
};

pub const FrameState = struct {
    has_data: bool = false,
    session_ptr: usize = 0,
    pending_generation: u64 = 0,
    published_generation: u64 = 0,
    presented_generation: u64 = 0,
    redraw_pending: bool = false,
    parse_backlog: bool = false,
    output_pressure: bool = false,
};

pub fn generationState(self: anytype) GenerationState {
    return .{
        .pending = publication_flow.pendingGeneration(self),
        .published = publishedGeneration(self),
        .presented = presentedGeneration(self),
    };
}

pub fn frameState(self: anytype, has_data: bool) FrameState {
    const generation_state = generationState(self);
    const parse_backlog = generation_state.pending != generation_state.published;
    const redraw_pending = generation_state.published != generation_state.presented;
    return .{
        .has_data = has_data,
        .session_ptr = @intFromPtr(self),
        .pending_generation = generation_state.pending,
        .published_generation = generation_state.published,
        .presented_generation = generation_state.presented,
        .redraw_pending = redraw_pending,
        .parse_backlog = parse_backlog,
        .output_pressure = has_data or parse_backlog,
    };
}

pub fn publishedGeneration(self: anytype) u64 {
    return renderCache(self).generation;
}

pub fn publishedGenerationChangedSince(self: anytype, baseline: u64) bool {
    return publishedGeneration(self) != baseline;
}

pub fn presentedGeneration(self: anytype) u64 {
    return self.publication.presented_generation.load(.acquire);
}

fn renderCache(self: anytype) *const @import("render_cache.zig").RenderCache {
    const idx = self.publication.render_cache_index.load(.acquire);
    return &self.publication.render_caches[idx];
}
