const std = @import("std");
const pty_mod = @import("../../io/pty.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const runtime_fields = @import("runtime_fields.zig");
const interaction_fields = @import("interaction_fields.zig");
const publication_fields = @import("publication_fields.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const view_cache = @import("../publication/view_cache.zig");
const render_cache_mod = @import("../publication/render_cache.zig");

const TerminalCore = terminal_core_mod.TerminalCore;
const RenderCache = render_cache_mod.RenderCache;
const Pty = pty_mod.Pty;

pub const SessionFaces = struct {
    runtime: *runtime_fields.Fields,
    interaction: *interaction_fields.Fields,
    publication: *publication_fields.Fields,
};

pub const RuntimeWriteFace = struct {
    pty: *?Pty,
    external_transport: *?terminal_transport.ExternalTransport,
    pty_write_mutex: *std.Thread.Mutex,
    io_wait_cond: *std.Thread.Condition,
};

pub const ProtocolExecution = struct {
    allocator: std.mem.Allocator,
    core: *TerminalCore,
    session: SessionFaces,
    runtime: RuntimeWriteFace,
    state_mutex: *std.Thread.Mutex,

    pub fn init(owner: anytype, core: *TerminalCore) ProtocolExecution {
        return .{
            .allocator = owner.allocator,
            .core = core,
            .session = .{
                .runtime = &owner.session.runtime,
                .interaction = &owner.session.interaction,
                .publication = &owner.session.publication,
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
};
