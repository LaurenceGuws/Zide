pub const NoticeState = struct {
    until: f64,
    success: bool,
};

pub fn arm(now: f64, success: bool) NoticeState {
    return .{
        .until = now + 2.0,
        .success = success,
    };
}

pub fn isVisible(until: f64, now: f64) bool {
    if (until <= 0) return false;
    return now < until;
}

pub fn clearIfExpired(until: *f64, now: f64) bool {
    if (until.* <= 0) return false;
    if (now < until.*) return false;
    until.* = 0;
    return true;
}
