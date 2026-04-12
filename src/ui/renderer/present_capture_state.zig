pub const PresentCaptureState = struct {
    path: ?[]const u8 = null,
    armed: bool = false,
    frame_seq: u64 = 0,
};
