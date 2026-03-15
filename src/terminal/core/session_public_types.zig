const input_mod = @import("../input/input.zig");
const snapshot_mod = @import("snapshot.zig");
const render_cache_mod = @import("render_cache.zig");
const session_content = @import("session_content.zig");
const session_host_types = @import("session_host_types.zig");
const session_input_snapshot = @import("session_input_snapshot.zig");
const session_presentation_feedback = @import("session_presentation_feedback.zig");
const session_rendering = @import("session_rendering.zig");
const session_selection = @import("session_selection.zig");
const terminal_transport = @import("terminal_transport.zig");

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const RenderCache = render_cache_mod.RenderCache;

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;
pub const ScrollbackInfo = session_content.ScrollbackInfo;
pub const ScrollbackRange = session_content.ScrollbackRange;
pub const SelectionGesture = session_selection.SelectionGesture;
pub const ClickSelectionResult = session_selection.ClickSelectionResult;
pub const SessionMetadata = session_host_types.SessionMetadata;
pub const PresentedRenderCache = session_rendering.PresentedRenderCache;
pub const PresentationCapture = session_rendering.PresentationCapture;
pub const AltExitPresentationInfo = session_presentation_feedback.AltExitPresentationInfo;
pub const PresentationFeedback = session_presentation_feedback.PresentationFeedback;

pub const PtyWriteGuard = terminal_transport.Writer;
pub const InputSnapshot = session_input_snapshot.InputSnapshot;
pub const InputState = input_mod.InputState;
