const std = @import("std");
const input_mod = @import("../input/input.zig");
const pty_io = @import("runtime/pty_io.zig");
const view_cache = @import("publication/view_cache.zig");
const resize_reflow = @import("resize_reflow.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const terminal_core_mod = @import("terminal_core.zig");
const host_queries = @import("session/host_queries.zig");
const queries = @import("session/queries.zig");
const content = @import("session/content.zig");
const host_types = @import("session/host_types.zig");
const host_selection = @import("session/selection.zig");
const interaction = @import("session/interaction.zig");
const session_input = @import("session/input.zig");
const init_options = @import("session/init_options.zig");
const input_snapshot = @import("session/input_snapshot.zig");
const control = @import("session/control.zig");
const terminal_publication = @import("publication/terminal_publication.zig");
const runtime = @import("session/runtime.zig");
const session_debug = @import("session/debug_ops.zig");
const publication_fields = @import("session/publication_fields.zig");
const runtime_fields = @import("session/runtime_fields.zig");
const interaction_fields = @import("session/interaction_fields.zig");
const control_fields = @import("session/control_fields.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
const terminal_transport = @import("runtime/terminal_transport.zig");
const TerminalCoreType = terminal_core_mod.TerminalCore;

pub const PtyTerminalRuntime = struct {
    const Self = @This();

    pub const InitOptions = init_options.InitOptions;
    pub const scrollbackInfo = content.scrollbackInfo;
    pub const copyScrollbackRange = content.copyScrollbackRange;
    pub const selectionPlainTextAlloc = content.selectionPlainTextAlloc;
    pub const scrollbackPlainTextAlloc = content.scrollbackPlainTextAlloc;
    pub const scrollbackAnsiTextAlloc = content.scrollbackAnsiTextAlloc;
    pub const setScrollOffset = content.setScrollOffset;
    pub const setScrollOffsetLocked = content.setScrollOffsetLocked;
    pub const resetToLiveBottomLocked = content.resetToLiveBottomLocked;
    pub const resetToLiveBottomForInputLocked = content.resetToLiveBottomForInputLocked;
    pub const setScrollOffsetFromNormalizedTrackLocked = content.setScrollOffsetFromNormalizedTrackLocked;
    pub const scrollSelectionDragLocked = content.scrollSelectionDragLocked;
    pub const scrollBy = content.scrollBy;
    pub const scrollByLocked = content.scrollByLocked;
    pub const scrollWheelLocked = content.scrollWheelLocked;
    pub const clearSelection = host_selection.clearSelection;
    pub const clearSelectionLocked = host_selection.clearSelectionLocked;
    pub const clearSelectionIfActiveLocked = host_selection.clearSelectionIfActiveLocked;
    pub const startSelection = host_selection.startSelection;
    pub const startSelectionLocked = host_selection.startSelectionLocked;
    pub const updateSelection = host_selection.updateSelection;
    pub const updateSelectionLocked = host_selection.updateSelectionLocked;
    pub const finishSelection = host_selection.finishSelection;
    pub const finishSelectionLocked = host_selection.finishSelectionLocked;
    pub const finishSelectionIfActiveLocked = host_selection.finishSelectionIfActiveLocked;
    pub const selectRange = host_selection.selectRange;
    pub const selectRangeLocked = host_selection.selectRangeLocked;
    pub const selectCellLocked = host_selection.selectCellLocked;
    pub const selectOrUpdateCellLocked = host_selection.selectOrUpdateCellLocked;
    pub const selectOrderedRangeLocked = host_selection.selectOrderedRangeLocked;
    pub const beginClickSelectionLocked = host_selection.beginClickSelectionLocked;
    pub const extendGestureSelectionLocked = host_selection.extendGestureSelectionLocked;
    pub const selectOrUpdateCellInRowLocked = host_selection.selectOrUpdateCellInRowLocked;
    allocator: std.mem.Allocator,
    runtime: runtime_fields.Fields,
    core: TerminalCoreType,
    interaction: interaction_fields.Fields,
    publication: publication_fields.Fields,
    control: control_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*PtyTerminalRuntime {
        return initWithOptions(allocator, rows, cols, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*PtyTerminalRuntime {
        return try runtime.init(PtyTerminalRuntime, allocator, rows, cols, options);
    }

    pub const deinit = runtime.deinit;

    pub const lock = control.lock;
    pub const tryLock = control.tryLock;
    pub const unlock = control.unlock;

    pub const lockPtyWriter = runtime.lockPtyWriter;
    pub const writePtyBytes = runtime.writePtyBytes;

    pub const resize = runtime.resize;

    pub const snapshot = terminal_publication.snapshot;
};
