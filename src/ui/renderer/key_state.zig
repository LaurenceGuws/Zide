pub fn isKeyDown(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}

pub fn isKeyPressed(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}

pub fn isKeyRepeated(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}

pub fn isKeyReleased(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}
