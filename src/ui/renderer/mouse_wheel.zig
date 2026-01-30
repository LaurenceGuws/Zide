pub fn reset(delta: *f32) void {
    delta.* = 0.0;
}

pub fn add(delta: *f32, value: f32) void {
    delta.* += value;
}

pub fn get(delta: *const f32) f32 {
    return delta.*;
}
