var mouse_wheel_delta: f32 = 0.0;

pub fn get() f32 {
    return mouse_wheel_delta;
}

pub fn deltaPtr() *f32 {
    return &mouse_wheel_delta;
}
