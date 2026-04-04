const std = @import("std");
const app_shell = @import("../app_shell.zig");

pub fn log(shell: *app_shell.Shell, enabled: bool) void {
    if (!enabled) return;
    const r = shell.rendererPtr();
    const diagnostics = shell.windowGeometryDiagnostics();
    const raw = r.getMousePosRaw();
    const scaled = r.getMousePos();
    const scale_screen = if (diagnostics.render.x > 0) diagnostics.screen.x / diagnostics.render.x else 1.0;
    const scale_render = if (diagnostics.screen.x > 0) diagnostics.render.x / diagnostics.screen.x else 1.0;
    const via_screen: app_shell.MousePos = .{ .x = raw.x * scale_screen, .y = raw.y * scale_screen };
    const via_render: app_shell.MousePos = .{ .x = raw.x * scale_render, .y = raw.y * scale_render };

    std.debug.print(
        "mouse click raw({d:.1},{d:.1}) logical({d:.1},{d:.1}) dpi({d:.2},{d:.2}) display_scale({d:.2}) pixel_density({d:.2}) render_scale({d:.2}) scr({d:.0}x{d:.0}) ren({d:.0}x{d:.0}) mon({d:.0}x{d:.0}) via_screen({d:.1},{d:.1}) via_render({d:.1},{d:.1})\n",
        .{
            raw.x,
            raw.y,
            scaled.x,
            scaled.y,
            diagnostics.dpi.x,
            diagnostics.dpi.y,
            diagnostics.display_scale,
            diagnostics.pixel_density,
            diagnostics.render_scale,
            diagnostics.screen.x,
            diagnostics.screen.y,
            diagnostics.render.x,
            diagnostics.render.y,
            diagnostics.monitor.x,
            diagnostics.monitor.y,
            via_screen.x,
            via_screen.y,
            via_render.x,
            via_render.y,
        },
    );
}
