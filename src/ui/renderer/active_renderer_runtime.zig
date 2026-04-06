var active_renderer: ?*anyopaque = null;

pub fn set(renderer: *anyopaque) void {
    active_renderer = renderer;
}

pub fn clearIf(renderer: *anyopaque) void {
    if (active_renderer == renderer) active_renderer = null;
}

pub fn get(comptime T: type) ?*T {
    const ptr = active_renderer orelse return null;
    return @ptrCast(@alignCast(ptr));
}
