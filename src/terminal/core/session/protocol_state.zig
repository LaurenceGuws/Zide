const terminal_core_csi_input_modes = @import("../protocol/terminal_core_csi_input_modes.zig");
const interaction_fields = @import("interaction_fields.zig");

pub fn protocolModes(self: anytype) *interaction_fields.ProtocolModeState {
    const receiver = switch (@typeInfo(@TypeOf(self))) {
        .pointer => |ptr| switch (@typeInfo(ptr.child)) {
            .pointer => self.*,
            else => self,
        },
        else => @compileError("protocol_state expects a pointer receiver"),
    };
    if (@hasField(@TypeOf(receiver.session), "protocol_modes")) {
        return receiver.session.protocol_modes;
    }
    return &receiver.session.interaction.protocol_modes;
}

pub fn derivedSnapshot(self: anytype) *interaction_fields.DerivedSnapshotState {
    const receiver = switch (@typeInfo(@TypeOf(self))) {
        .pointer => |ptr| switch (@typeInfo(ptr.child)) {
            .pointer => self.*,
            else => self,
        },
        else => @compileError("protocol_state expects a pointer receiver"),
    };
    if (@hasField(@TypeOf(receiver.session), "derived_snapshot")) {
        return receiver.session.derived_snapshot;
    }
    return &receiver.session.interaction.derived_snapshot;
}

pub fn setGraphemeClusterShaping2027(self: anytype, enabled: bool) void {
    protocolModes(self).grapheme_cluster_shaping_2027 = enabled;
    self.core.setGraphemeClusterShaping2027(enabled);
}

pub fn inputModeSnapshot(self: anytype) terminal_core_csi_input_modes.InputModeSnapshot {
    const protocol_modes = protocolModes(self);
    const input_snapshot = &derivedSnapshot(self).input;
    return .{
        .app_cursor_keys = input_snapshot.app_cursor_keys.load(.acquire),
        .auto_repeat = input_snapshot.auto_repeat.load(.acquire),
        .mouse_mode_x10 = input_snapshot.mouse_mode_x10.load(.acquire),
        .app_keypad = input_snapshot.app_keypad.load(.acquire),
        .mouse_mode_button = input_snapshot.mouse_mode_button.load(.acquire),
        .mouse_mode_any = input_snapshot.mouse_mode_any.load(.acquire),
        .focus_reporting = input_snapshot.focus_reporting.load(.acquire),
        .mouse_mode_sgr = input_snapshot.mouse_mode_sgr.load(.acquire),
        .mouse_alternate_scroll = input_snapshot.mouse_alternate_scroll.load(.acquire),
        .mouse_mode_sgr_pixels = input_snapshot.mouse_mode_sgr_pixels_1016.load(.acquire),
        .bracketed_paste = input_snapshot.bracketed_paste.load(.acquire),
        .sync_updates_active = self.core.sync_updates_active,
        .grapheme_cluster_shaping_2027 = protocol_modes.grapheme_cluster_shaping_2027,
    };
}
