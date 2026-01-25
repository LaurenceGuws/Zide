const std = @import("std");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");

pub fn buildInputBatch(allocator: std.mem.Allocator, shell: *app_shell.Shell) shared_types.input.InputBatch {
    var batch = shared_types.input.InputBatch.init(allocator);
    const r = shell.rendererPtr();

    const pos = r.getMousePos();
    batch.mouse_pos = .{ .x = pos.x, .y = pos.y };
    const pos_raw = r.getMousePosRaw();
    batch.mouse_pos_raw = .{ .x = pos_raw.x, .y = pos_raw.y };
    batch.scroll = .{ .x = 0, .y = r.getMouseWheelMove() };

    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonDown(app_shell.MOUSE_LEFT);
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonDown(app_shell.MOUSE_MIDDLE);
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonDown(app_shell.MOUSE_RIGHT);

    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonPressed(app_shell.MOUSE_LEFT);
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonPressed(app_shell.MOUSE_MIDDLE);
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonPressed(app_shell.MOUSE_RIGHT);

    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonReleased(app_shell.MOUSE_LEFT);
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonReleased(app_shell.MOUSE_MIDDLE);
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonReleased(app_shell.MOUSE_RIGHT);

    batch.mods = .{
        .shift = r.isKeyDown(app_shell.KEY_LEFT_SHIFT) or r.isKeyDown(app_shell.KEY_RIGHT_SHIFT),
        .alt = r.isKeyDown(app_shell.KEY_LEFT_ALT) or r.isKeyDown(app_shell.KEY_RIGHT_ALT),
        .ctrl = r.isKeyDown(app_shell.KEY_LEFT_CONTROL) or r.isKeyDown(app_shell.KEY_RIGHT_CONTROL),
        .super = r.isKeyDown(app_shell.KEY_LEFT_SUPER) or r.isKeyDown(app_shell.KEY_RIGHT_SUPER),
    };

    const key_map = [_]struct { key: shared_types.input.Key, raylib: i32 }{
        .{ .key = .enter, .raylib = app_shell.KEY_ENTER },
        .{ .key = .backspace, .raylib = app_shell.KEY_BACKSPACE },
        .{ .key = .tab, .raylib = app_shell.KEY_TAB },
        .{ .key = .escape, .raylib = app_shell.KEY_ESCAPE },
        .{ .key = .up, .raylib = app_shell.KEY_UP },
        .{ .key = .down, .raylib = app_shell.KEY_DOWN },
        .{ .key = .left, .raylib = app_shell.KEY_LEFT },
        .{ .key = .right, .raylib = app_shell.KEY_RIGHT },
        .{ .key = .home, .raylib = app_shell.KEY_HOME },
        .{ .key = .end, .raylib = app_shell.KEY_END },
        .{ .key = .page_up, .raylib = app_shell.KEY_PAGE_UP },
        .{ .key = .page_down, .raylib = app_shell.KEY_PAGE_DOWN },
        .{ .key = .insert, .raylib = app_shell.KEY_INSERT },
        .{ .key = .delete, .raylib = app_shell.KEY_DELETE },
        .{ .key = .a, .raylib = app_shell.KEY_A },
        .{ .key = .b, .raylib = app_shell.KEY_B },
        .{ .key = .c, .raylib = app_shell.KEY_C },
        .{ .key = .d, .raylib = app_shell.KEY_D },
        .{ .key = .e, .raylib = app_shell.KEY_E },
        .{ .key = .f, .raylib = app_shell.KEY_F },
        .{ .key = .g, .raylib = app_shell.KEY_G },
        .{ .key = .h, .raylib = app_shell.KEY_H },
        .{ .key = .i, .raylib = app_shell.KEY_I },
        .{ .key = .j, .raylib = app_shell.KEY_J },
        .{ .key = .k, .raylib = app_shell.KEY_K },
        .{ .key = .l, .raylib = app_shell.KEY_L },
        .{ .key = .m, .raylib = app_shell.KEY_M },
        .{ .key = .n, .raylib = app_shell.KEY_N },
        .{ .key = .o, .raylib = app_shell.KEY_O },
        .{ .key = .p, .raylib = app_shell.KEY_P },
        .{ .key = .q, .raylib = app_shell.KEY_Q },
        .{ .key = .r, .raylib = app_shell.KEY_R },
        .{ .key = .s, .raylib = app_shell.KEY_S },
        .{ .key = .t, .raylib = app_shell.KEY_T },
        .{ .key = .u, .raylib = app_shell.KEY_U },
        .{ .key = .v, .raylib = app_shell.KEY_V },
        .{ .key = .w, .raylib = app_shell.KEY_W },
        .{ .key = .x, .raylib = app_shell.KEY_X },
        .{ .key = .y, .raylib = app_shell.KEY_Y },
        .{ .key = .z, .raylib = app_shell.KEY_Z },
        .{ .key = .zero, .raylib = app_shell.KEY_ZERO },
        .{ .key = .one, .raylib = app_shell.KEY_ONE },
        .{ .key = .two, .raylib = app_shell.KEY_TWO },
        .{ .key = .three, .raylib = app_shell.KEY_THREE },
        .{ .key = .four, .raylib = app_shell.KEY_FOUR },
        .{ .key = .five, .raylib = app_shell.KEY_FIVE },
        .{ .key = .six, .raylib = app_shell.KEY_SIX },
        .{ .key = .seven, .raylib = app_shell.KEY_SEVEN },
        .{ .key = .eight, .raylib = app_shell.KEY_EIGHT },
        .{ .key = .nine, .raylib = app_shell.KEY_NINE },
        .{ .key = .space, .raylib = app_shell.KEY_SPACE },
        .{ .key = .minus, .raylib = app_shell.KEY_MINUS },
        .{ .key = .equal, .raylib = app_shell.KEY_EQUAL },
        .{ .key = .left_bracket, .raylib = app_shell.KEY_LEFT_BRACKET },
        .{ .key = .right_bracket, .raylib = app_shell.KEY_RIGHT_BRACKET },
        .{ .key = .backslash, .raylib = app_shell.KEY_BACKSLASH },
        .{ .key = .semicolon, .raylib = app_shell.KEY_SEMICOLON },
        .{ .key = .apostrophe, .raylib = app_shell.KEY_APOSTROPHE },
        .{ .key = .comma, .raylib = app_shell.KEY_COMMA },
        .{ .key = .period, .raylib = app_shell.KEY_PERIOD },
        .{ .key = .slash, .raylib = app_shell.KEY_SLASH },
        .{ .key = .grave, .raylib = app_shell.KEY_GRAVE },
        .{ .key = .kp_0, .raylib = app_shell.KEY_KP_0 },
        .{ .key = .kp_1, .raylib = app_shell.KEY_KP_1 },
        .{ .key = .kp_2, .raylib = app_shell.KEY_KP_2 },
        .{ .key = .kp_3, .raylib = app_shell.KEY_KP_3 },
        .{ .key = .kp_4, .raylib = app_shell.KEY_KP_4 },
        .{ .key = .kp_5, .raylib = app_shell.KEY_KP_5 },
        .{ .key = .kp_6, .raylib = app_shell.KEY_KP_6 },
        .{ .key = .kp_7, .raylib = app_shell.KEY_KP_7 },
        .{ .key = .kp_8, .raylib = app_shell.KEY_KP_8 },
        .{ .key = .kp_9, .raylib = app_shell.KEY_KP_9 },
        .{ .key = .kp_decimal, .raylib = app_shell.KEY_KP_DECIMAL },
        .{ .key = .kp_divide, .raylib = app_shell.KEY_KP_DIVIDE },
        .{ .key = .kp_multiply, .raylib = app_shell.KEY_KP_MULTIPLY },
        .{ .key = .kp_subtract, .raylib = app_shell.KEY_KP_SUBTRACT },
        .{ .key = .kp_add, .raylib = app_shell.KEY_KP_ADD },
        .{ .key = .kp_enter, .raylib = app_shell.KEY_KP_ENTER },
        .{ .key = .kp_equal, .raylib = app_shell.KEY_KP_EQUAL },
    };

    for (key_map) |entry| {
        batch.key_down[@intFromEnum(entry.key)] = r.isKeyDown(entry.raylib);
        batch.key_pressed[@intFromEnum(entry.key)] = r.isKeyPressed(entry.raylib);
        batch.key_repeated[@intFromEnum(entry.key)] = r.isKeyRepeated(entry.raylib);
    }

    while (r.getKeyPressed()) |raw_key| {
        if (inputKeyFromRaylib(raw_key)) |key| {
            batch.append(.{
                .key = .{
                    .key = key,
                    .mods = batch.mods,
                    .repeated = false,
                    .pressed = true,
                },
            }) catch {};
        }
    }

    while (r.getCharPressed()) |char| {
        batch.append(.{ .text = .{ .codepoint = char } }) catch {};
    }

    return batch;
}

fn inputKeyFromRaylib(key: i32) ?shared_types.input.Key {
    return switch (key) {
        app_shell.KEY_ENTER => .enter,
        app_shell.KEY_BACKSPACE => .backspace,
        app_shell.KEY_TAB => .tab,
        app_shell.KEY_ESCAPE => .escape,
        app_shell.KEY_UP => .up,
        app_shell.KEY_DOWN => .down,
        app_shell.KEY_LEFT => .left,
        app_shell.KEY_RIGHT => .right,
        app_shell.KEY_HOME => .home,
        app_shell.KEY_END => .end,
        app_shell.KEY_PAGE_UP => .page_up,
        app_shell.KEY_PAGE_DOWN => .page_down,
        app_shell.KEY_INSERT => .insert,
        app_shell.KEY_DELETE => .delete,
        app_shell.KEY_A => .a,
        app_shell.KEY_B => .b,
        app_shell.KEY_C => .c,
        app_shell.KEY_D => .d,
        app_shell.KEY_E => .e,
        app_shell.KEY_F => .f,
        app_shell.KEY_G => .g,
        app_shell.KEY_H => .h,
        app_shell.KEY_I => .i,
        app_shell.KEY_J => .j,
        app_shell.KEY_K => .k,
        app_shell.KEY_L => .l,
        app_shell.KEY_M => .m,
        app_shell.KEY_N => .n,
        app_shell.KEY_O => .o,
        app_shell.KEY_P => .p,
        app_shell.KEY_Q => .q,
        app_shell.KEY_R => .r,
        app_shell.KEY_S => .s,
        app_shell.KEY_T => .t,
        app_shell.KEY_U => .u,
        app_shell.KEY_V => .v,
        app_shell.KEY_W => .w,
        app_shell.KEY_X => .x,
        app_shell.KEY_Y => .y,
        app_shell.KEY_Z => .z,
        app_shell.KEY_ZERO => .zero,
        app_shell.KEY_ONE => .one,
        app_shell.KEY_TWO => .two,
        app_shell.KEY_THREE => .three,
        app_shell.KEY_FOUR => .four,
        app_shell.KEY_FIVE => .five,
        app_shell.KEY_SIX => .six,
        app_shell.KEY_SEVEN => .seven,
        app_shell.KEY_EIGHT => .eight,
        app_shell.KEY_NINE => .nine,
        app_shell.KEY_SPACE => .space,
        app_shell.KEY_MINUS => .minus,
        app_shell.KEY_EQUAL => .equal,
        app_shell.KEY_LEFT_BRACKET => .left_bracket,
        app_shell.KEY_RIGHT_BRACKET => .right_bracket,
        app_shell.KEY_BACKSLASH => .backslash,
        app_shell.KEY_SEMICOLON => .semicolon,
        app_shell.KEY_APOSTROPHE => .apostrophe,
        app_shell.KEY_COMMA => .comma,
        app_shell.KEY_PERIOD => .period,
        app_shell.KEY_SLASH => .slash,
        app_shell.KEY_GRAVE => .grave,
        app_shell.KEY_KP_0 => .kp_0,
        app_shell.KEY_KP_1 => .kp_1,
        app_shell.KEY_KP_2 => .kp_2,
        app_shell.KEY_KP_3 => .kp_3,
        app_shell.KEY_KP_4 => .kp_4,
        app_shell.KEY_KP_5 => .kp_5,
        app_shell.KEY_KP_6 => .kp_6,
        app_shell.KEY_KP_7 => .kp_7,
        app_shell.KEY_KP_8 => .kp_8,
        app_shell.KEY_KP_9 => .kp_9,
        app_shell.KEY_KP_DECIMAL => .kp_decimal,
        app_shell.KEY_KP_DIVIDE => .kp_divide,
        app_shell.KEY_KP_MULTIPLY => .kp_multiply,
        app_shell.KEY_KP_SUBTRACT => .kp_subtract,
        app_shell.KEY_KP_ADD => .kp_add,
        app_shell.KEY_KP_ENTER => .kp_enter,
        app_shell.KEY_KP_EQUAL => .kp_equal,
        else => null,
    };
}
