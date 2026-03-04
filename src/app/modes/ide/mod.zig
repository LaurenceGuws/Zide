const host = @import("host.zig");

pub const IdeHost = host.IdeHost;
pub const ActiveMode = host.ActiveMode;
pub const initialActiveMode = host.initialActiveMode;
pub const initialTerminalVisibility = host.initialTerminalVisibility;
pub const isTerminalOnly = host.isTerminalOnly;
pub const isEditorOnly = host.isEditorOnly;
pub const supportsEditorSurface = host.supportsEditorSurface;
pub const supportsTerminalSurface = host.supportsTerminalSurface;
pub const routedActiveMode = host.routedActiveMode;
