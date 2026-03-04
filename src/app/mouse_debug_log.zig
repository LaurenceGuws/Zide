const std = @import("std");
const app_shell = @import("../app_shell.zig");

pub fn log(shell: *app_shell.Shell, enabled: bool) void {
    if (!enabled) return;
    const r = shell.rendererPtr();
    const raw = r.getMousePosRaw();
    const scaled = r.getMousePos();
    const dpi = r.getDpiScale();
    const screen = r.getScreenSize();
    const render = r.getRenderSize();
    const monitor = r.getMonitorSize();
    const scale_screen = if (render.x > 0) screen.x / render.x else 1.0;
    const scale_render = if (screen.x > 0) render.x / screen.x else 1.0;
    const via_screen = r.getMousePosScaled(scale_screen);
    const via_render = r.getMousePosScaled(scale_render);

    std.debug.print(
        "mouse click raw({d:.1},{d:.1}) scaled({d:.1},{d:.1}) dpi({d:.2},{d:.2}) scr({d:.0}x{d:.0}) ren({d:.0}x{d:.0}) mon({d:.0}x{d:.0}) via_screen({d:.1},{d:.1}) via_render({d:.1},{d:.1}) scale({d:.2})\n",
        .{
            raw.x,
            raw.y,
            scaled.x,
            scaled.y,
            dpi.x,
            dpi.y,
            screen.x,
            screen.y,
            render.x,
            render.y,
            monitor.x,
            monitor.y,
            via_screen.x,
            via_screen.y,
            via_render.x,
            via_render.y,
            shell.mouseScale().x,
        },
    );
}
