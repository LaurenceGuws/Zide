const std = @import("std");
const pty_mod = @import("../../io/pty.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const runtime_fields = @import("runtime_fields.zig");
const interaction_fields = @import("interaction_fields.zig");
const publication_fields = @import("publication_fields.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const view_cache = @import("../publication/view_cache.zig");
const render_cache_mod = @import("../publication/render_cache.zig");
const terminal_core_feed = @import("../protocol/terminal_core_feed.zig");

const TerminalCore = terminal_core_mod.TerminalCore;
const RenderCache = render_cache_mod.RenderCache;
const Pty = pty_mod.Pty;
const FeedResult = terminal_core_feed.FeedResult;

pub const SessionFaces = struct {
    protocol_modes: *interaction_fields.ProtocolModeState,
    derived_snapshot: *interaction_fields.DerivedSnapshotState,
    publication: *publication_fields.Fields,
};

pub const ReportingContractFace = struct {
    report_color_scheme_2031: *bool,
    inband_resize_notifications_2048: *bool,
    kitty_paste_events_5522: *bool,
};

pub const ColorSchemeStateFace = struct {
    color_scheme_dark: *bool,
};

pub const RuntimeWriteFace = struct {
    pty: *?Pty,
    external_transport: *?terminal_transport.ExternalTransport,
    pty_write_mutex: *std.Thread.Mutex,
    io_wait_cond: *std.Thread.Condition,
};

pub const ProtocolExecution = struct {
    pub const ViewRefreshRequest = struct {
        generation: u64,
        scroll_offset: usize,
    };

    pub const PendingRefreshDecision = union(enum) {
        none,
        request: ViewRefreshRequest,
    };

    allocator: std.mem.Allocator,
    core: *TerminalCore,
    session: SessionFaces,
    reporting_contract: ReportingContractFace,
    color_scheme_state: ColorSchemeStateFace,
    runtime: RuntimeWriteFace,
    state_mutex: *std.Thread.Mutex,

    pub fn init(owner: anytype, core: *TerminalCore) ProtocolExecution {
        return .{
            .allocator = owner.allocator,
            .core = core,
            .session = .{
                .protocol_modes = &owner.session.interaction.protocol_modes,
                .derived_snapshot = &owner.session.interaction.derived_snapshot,
                .publication = &owner.session.publication,
            },
            .reporting_contract = .{
                .report_color_scheme_2031 = &owner.session.interaction.host_contract.report_color_scheme_2031,
                .inband_resize_notifications_2048 = &owner.session.interaction.host_contract.inband_resize_notifications_2048,
                .kitty_paste_events_5522 = &owner.session.interaction.host_contract.kitty_paste_events_5522,
            },
            .color_scheme_state = .{
                .color_scheme_dark = &owner.session.interaction.host_contract.color_scheme_dark,
            },
            .runtime = .{
                .pty = &owner.session.runtime.pty,
                .external_transport = &owner.session.runtime.external_transport,
                .pty_write_mutex = &owner.session.runtime.pty_write_mutex,
                .io_wait_cond = &owner.session.runtime.io_wait_cond,
            },
            .state_mutex = &owner.session.control.state_mutex,
        };
    }

    pub fn lock(self: *ProtocolExecution) void {
        self.state_mutex.lock();
    }

    pub fn unlock(self: *ProtocolExecution) void {
        self.state_mutex.unlock();
    }

    pub fn writePtyBytes(self: *ProtocolExecution, bytes: []const u8) !void {
        self.runtime.pty_write_mutex.lock();
        defer self.runtime.pty_write_mutex.unlock();
        if (self.runtime.pty.*) |*pty| {
            _ = try pty.write(bytes);
            return;
        }
        if (self.runtime.external_transport.*) |*transport| {
            _ = try transport.write(bytes);
        }
    }

    pub fn signalIoWait(self: *ProtocolExecution) void {
        self.runtime.io_wait_cond.signal();
    }

    pub fn currentRenderCache(self: *ProtocolExecution) *const RenderCache {
        const idx = self.session.publication.render_cache_index.load(.acquire);
        return &self.session.publication.render_caches[idx];
    }

    pub fn presentedGeneration(self: *ProtocolExecution) u64 {
        return self.session.publication.presented_generation.load(.acquire);
    }

    pub fn bumpPublicationGeneration(self: *ProtocolExecution) u64 {
        return self.session.publication.pending_generation.fetchAdd(1, .acq_rel) + 1;
    }

    pub fn pendingPublicationGeneration(self: *ProtocolExecution) u64 {
        return self.session.publication.pending_generation.load(.acquire);
    }

    pub fn updateViewCacheForProtocol(self: *ProtocolExecution, generation: u64, scroll_offset: usize, source: []const u8) void {
        view_cache.updateViewCacheNoLockTagged(self, generation, scroll_offset, source);
    }

    pub fn syncUpdateNeedsPublication(self: *ProtocolExecution) bool {
        const cache = self.currentRenderCache();
        const presented_generation = self.presentedGeneration();
        return !(cache.generation == presented_generation and cache.dirty == .none);
    }

    pub fn publishSyncUpdate(self: *ProtocolExecution, scroll_offset: usize) void {
        _ = self.bumpPublicationGeneration();
        self.updateViewCacheForProtocol(self.pendingPublicationGeneration(), scroll_offset, "set_sync_updates");
    }

    pub fn noteParsedOutputPending(self: *ProtocolExecution) void {
        _ = self.bumpPublicationGeneration();
        self.markOutputPending();
    }

    pub fn publishParsedOutput(self: *ProtocolExecution, result: FeedResult, source: []const u8) void {
        if (!result.parsed) return;
        _ = self.bumpPublicationGeneration();
        self.updateViewCacheForProtocol(self.pendingPublicationGeneration(), result.scroll_offset, source);
        self.markOutputPending();
    }

    pub fn publishBufferedParsedOutput(self: *ProtocolExecution, scroll_offset: usize, source: []const u8) void {
        self.updateViewCacheForProtocol(self.pendingPublicationGeneration(), scroll_offset, source);
        self.markOutputPending();
    }

    pub fn markOutputPending(self: *ProtocolExecution) void {
        self.session.publication.output_pending.store(true, .release);
    }

    pub fn viewRefreshPending(self: *ProtocolExecution) bool {
        return self.session.publication.view_cache_pending.load(.acquire);
    }

    pub fn takePendingRefreshDecision(self: *ProtocolExecution) PendingRefreshDecision {
        const request = self.takePendingViewRefreshRequest() orelse return .none;
        return .{ .request = request };
    }

    pub fn publishPendingRefreshDecision(self: *ProtocolExecution, decision: PendingRefreshDecision, source: []const u8) bool {
        switch (decision) {
            .none => return false,
            .request => |request| {
                self.publishViewRefreshRequest(request, source);
                return true;
            },
        }
    }

    pub fn takePendingViewRefreshRequest(self: *ProtocolExecution) ?ViewRefreshRequest {
        if (!self.session.publication.view_cache_pending.swap(false, .acq_rel)) return null;
        return .{
            .generation = self.pendingPublicationGeneration(),
            .scroll_offset = @intCast(self.session.publication.view_cache_request_offset.load(.acquire)),
        };
    }

    pub fn publishViewRefreshRequest(self: *ProtocolExecution, request: ViewRefreshRequest, source: []const u8) void {
        self.updateViewCacheForProtocol(request.generation, request.scroll_offset, source);
    }

    pub fn shouldPublishPollUpdate(self: *ProtocolExecution, had_data: bool) bool {
        return had_data or self.viewRefreshPending();
    }

    pub fn publishPollUpdate(self: *ProtocolExecution, had_data: bool, publish_source: []const u8, refresh_source: []const u8) bool {
        if (had_data) {
            self.updateViewCacheForProtocol(self.pendingPublicationGeneration(), self.core.scrollbackOffset(), publish_source);
        }
        const decision = self.takePendingRefreshDecision();
        return self.publishPendingRefreshDecision(decision, refresh_source);
    }
};
