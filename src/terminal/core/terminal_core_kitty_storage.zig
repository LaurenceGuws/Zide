const std = @import("std");
const kitty_mod = @import("../kitty/graphics.zig");

const TerminalCore = @import("terminal_core.zig").TerminalCore;
const KittyState = kitty_mod.KittyState;

pub fn activeKittyState(self: *TerminalCore) *KittyState {
    return if (self.active == .alt) &self.kitty_alt else &self.kitty_primary;
}

pub fn clearActive(self: *TerminalCore) void {
    clearState(self, activeKittyState(self));
}

pub fn clearAll(self: *TerminalCore) void {
    clearState(self, &self.kitty_primary);
    clearState(self, &self.kitty_alt);
}

pub fn deinitState(self: *TerminalCore, state: *KittyState) void {
    for (state.images.items) |image| {
        self.allocator.free(image.data);
    }
    state.images.deinit(self.allocator);
    state.placements.deinit(self.allocator);
    var partial_it = state.partials.iterator();
    while (partial_it.next()) |entry| {
        entry.value_ptr.data.deinit(self.allocator);
    }
    state.partials.deinit();
}

fn clearState(self: *TerminalCore, state: *KittyState) void {
    for (state.images.items) |image| {
        self.allocator.free(image.data);
    }
    state.images.clearRetainingCapacity();
    state.placements.clearRetainingCapacity();
    var partial_it = state.partials.iterator();
    while (partial_it.next()) |entry| {
        entry.value_ptr.data.deinit(self.allocator);
    }
    state.partials.clearRetainingCapacity();
    state.total_bytes = 0;
    state.generation += 1;
}
