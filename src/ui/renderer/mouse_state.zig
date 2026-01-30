pub fn isMouseButtonPressed(buttons: []const bool, button: i32) bool {
    if (button < 0) return false;
    const idx: usize = @intCast(button);
    if (idx >= buttons.len) return false;
    return buttons[idx];
}

pub fn isMouseButtonDown(buttons: []const bool, button: i32) bool {
    if (button < 0) return false;
    const idx: usize = @intCast(button);
    if (idx >= buttons.len) return false;
    return buttons[idx];
}

pub fn isMouseButtonReleased(buttons: []const bool, button: i32) bool {
    if (button < 0) return false;
    const idx: usize = @intCast(button);
    if (idx >= buttons.len) return false;
    return buttons[idx];
}
