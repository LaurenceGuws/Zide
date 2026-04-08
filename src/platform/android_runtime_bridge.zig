const LifecycleState = enum(u8) {
    created,
    started,
    resumed,
    paused,
    stopped,
};

const BridgeState = struct {
    seq: u64 = 0,
    lifecycle: LifecycleState = .created,
    window_focused: bool = false,
    surface_available: bool = false,
    surface_width: i32 = 0,
    surface_height: i32 = 0,
};

var bridge_state = BridgeState{};

fn nextSequence() u64 {
    bridge_state.seq += 1;
    return bridge_state.seq;
}

pub fn noteCreate() u64 {
    bridge_state = .{};
    return nextSequence();
}

pub fn noteStart() u64 {
    bridge_state.lifecycle = .started;
    return nextSequence();
}

pub fn noteResume() u64 {
    bridge_state.lifecycle = .resumed;
    return nextSequence();
}

pub fn notePause() u64 {
    bridge_state.lifecycle = .paused;
    bridge_state.window_focused = false;
    return nextSequence();
}

pub fn noteStop() u64 {
    bridge_state.lifecycle = .stopped;
    bridge_state.window_focused = false;
    return nextSequence();
}

pub fn noteWindowFocusChanged(focused: bool) u64 {
    bridge_state.window_focused = focused;
    return nextSequence();
}

pub fn noteSurfaceAvailable(width: i32, height: i32) u64 {
    bridge_state.surface_available = true;
    bridge_state.surface_width = width;
    bridge_state.surface_height = height;
    return nextSequence();
}

pub fn noteSurfaceDestroyed() u64 {
    bridge_state.surface_available = false;
    bridge_state.surface_width = 0;
    bridge_state.surface_height = 0;
    return nextSequence();
}
