const std = @import("std");
const terminal_core_mod = @import("../terminal_core.zig");
const init_options = @import("init_options.zig");
const session_fields = @import("session_fields.zig");
const runtime = @import("runtime.zig");
const control = @import("control.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");
const content = @import("content.zig");
const host_selection = @import("selection.zig");

const TerminalCoreType = terminal_core_mod.TerminalCore;

pub const TerminalSession = struct {
    pub const InitOptions = init_options.InitOptions;
    pub const selectionPlainTextAlloc = content.selectionPlainTextAlloc;
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
    core: TerminalCoreType,
    session: session_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        return initWithOptions(allocator, rows, cols, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*TerminalSession {
        return try runtime.init(TerminalSession, allocator, rows, cols, options);
    }

    pub const deinit = runtime.deinit;

    pub const lock = control.lock;
    pub const tryLock = control.tryLock;
    pub const unlock = control.unlock;

    pub const lockPtyWriter = runtime.lockPtyWriter;
    pub const writePtyBytes = runtime.writePtyBytes;

    pub const snapshot = terminal_publication.snapshot;
};
