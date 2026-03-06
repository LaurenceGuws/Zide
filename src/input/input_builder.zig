const std = @import("std");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const app_logger = @import("../app_logger.zig");

fn sdlModHasAltGr(mod_bits: u32) bool {
    const sdl_ralt_mask: u32 = 0x0200;
    const sdl_mode_mask: u32 = 0x4000;
    return (mod_bits & (sdl_ralt_mask | sdl_mode_mask)) != 0;
}

pub fn buildInputBatch(allocator: std.mem.Allocator, shell: *app_shell.Shell) shared_types.input.InputBatch {
    var batch = shared_types.input.InputBatch.init(allocator);
    const log = app_logger.logger("input.batch");
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
        // SDL MODE (AltGr) is event-scoped; batch-level state uses right-alt as a best-effort proxy.
        .altgr = r.isKeyDown(app_shell.KEY_RIGHT_ALT),
    };

    const key_map = [_]struct { key: shared_types.input.Key, code: i32 }{
        .{ .key = .enter, .code = app_shell.KEY_ENTER },
        .{ .key = .backspace, .code = app_shell.KEY_BACKSPACE },
        .{ .key = .tab, .code = app_shell.KEY_TAB },
        .{ .key = .escape, .code = app_shell.KEY_ESCAPE },
        .{ .key = .up, .code = app_shell.KEY_UP },
        .{ .key = .down, .code = app_shell.KEY_DOWN },
        .{ .key = .left, .code = app_shell.KEY_LEFT },
        .{ .key = .right, .code = app_shell.KEY_RIGHT },
        .{ .key = .home, .code = app_shell.KEY_HOME },
        .{ .key = .end, .code = app_shell.KEY_END },
        .{ .key = .page_up, .code = app_shell.KEY_PAGE_UP },
        .{ .key = .page_down, .code = app_shell.KEY_PAGE_DOWN },
        .{ .key = .insert, .code = app_shell.KEY_INSERT },
        .{ .key = .delete, .code = app_shell.KEY_DELETE },
        .{ .key = .f1, .code = app_shell.KEY_F1 },
        .{ .key = .f2, .code = app_shell.KEY_F2 },
        .{ .key = .f3, .code = app_shell.KEY_F3 },
        .{ .key = .f4, .code = app_shell.KEY_F4 },
        .{ .key = .f5, .code = app_shell.KEY_F5 },
        .{ .key = .f6, .code = app_shell.KEY_F6 },
        .{ .key = .f7, .code = app_shell.KEY_F7 },
        .{ .key = .f8, .code = app_shell.KEY_F8 },
        .{ .key = .f9, .code = app_shell.KEY_F9 },
        .{ .key = .f10, .code = app_shell.KEY_F10 },
        .{ .key = .f11, .code = app_shell.KEY_F11 },
        .{ .key = .f12, .code = app_shell.KEY_F12 },
        .{ .key = .a, .code = app_shell.KEY_A },
        .{ .key = .b, .code = app_shell.KEY_B },
        .{ .key = .c, .code = app_shell.KEY_C },
        .{ .key = .d, .code = app_shell.KEY_D },
        .{ .key = .e, .code = app_shell.KEY_E },
        .{ .key = .f, .code = app_shell.KEY_F },
        .{ .key = .g, .code = app_shell.KEY_G },
        .{ .key = .h, .code = app_shell.KEY_H },
        .{ .key = .i, .code = app_shell.KEY_I },
        .{ .key = .j, .code = app_shell.KEY_J },
        .{ .key = .k, .code = app_shell.KEY_K },
        .{ .key = .l, .code = app_shell.KEY_L },
        .{ .key = .m, .code = app_shell.KEY_M },
        .{ .key = .n, .code = app_shell.KEY_N },
        .{ .key = .o, .code = app_shell.KEY_O },
        .{ .key = .p, .code = app_shell.KEY_P },
        .{ .key = .q, .code = app_shell.KEY_Q },
        .{ .key = .r, .code = app_shell.KEY_R },
        .{ .key = .s, .code = app_shell.KEY_S },
        .{ .key = .t, .code = app_shell.KEY_T },
        .{ .key = .u, .code = app_shell.KEY_U },
        .{ .key = .v, .code = app_shell.KEY_V },
        .{ .key = .w, .code = app_shell.KEY_W },
        .{ .key = .x, .code = app_shell.KEY_X },
        .{ .key = .y, .code = app_shell.KEY_Y },
        .{ .key = .z, .code = app_shell.KEY_Z },
        .{ .key = .zero, .code = app_shell.KEY_ZERO },
        .{ .key = .one, .code = app_shell.KEY_ONE },
        .{ .key = .two, .code = app_shell.KEY_TWO },
        .{ .key = .three, .code = app_shell.KEY_THREE },
        .{ .key = .four, .code = app_shell.KEY_FOUR },
        .{ .key = .five, .code = app_shell.KEY_FIVE },
        .{ .key = .six, .code = app_shell.KEY_SIX },
        .{ .key = .seven, .code = app_shell.KEY_SEVEN },
        .{ .key = .eight, .code = app_shell.KEY_EIGHT },
        .{ .key = .nine, .code = app_shell.KEY_NINE },
        .{ .key = .space, .code = app_shell.KEY_SPACE },
        .{ .key = .minus, .code = app_shell.KEY_MINUS },
        .{ .key = .equal, .code = app_shell.KEY_EQUAL },
        .{ .key = .left_bracket, .code = app_shell.KEY_LEFT_BRACKET },
        .{ .key = .right_bracket, .code = app_shell.KEY_RIGHT_BRACKET },
        .{ .key = .backslash, .code = app_shell.KEY_BACKSLASH },
        .{ .key = .semicolon, .code = app_shell.KEY_SEMICOLON },
        .{ .key = .apostrophe, .code = app_shell.KEY_APOSTROPHE },
        .{ .key = .comma, .code = app_shell.KEY_COMMA },
        .{ .key = .period, .code = app_shell.KEY_PERIOD },
        .{ .key = .slash, .code = app_shell.KEY_SLASH },
        .{ .key = .grave, .code = app_shell.KEY_GRAVE },
        .{ .key = .kp_0, .code = app_shell.KEY_KP_0 },
        .{ .key = .kp_1, .code = app_shell.KEY_KP_1 },
        .{ .key = .kp_2, .code = app_shell.KEY_KP_2 },
        .{ .key = .kp_3, .code = app_shell.KEY_KP_3 },
        .{ .key = .kp_4, .code = app_shell.KEY_KP_4 },
        .{ .key = .kp_5, .code = app_shell.KEY_KP_5 },
        .{ .key = .kp_6, .code = app_shell.KEY_KP_6 },
        .{ .key = .kp_7, .code = app_shell.KEY_KP_7 },
        .{ .key = .kp_8, .code = app_shell.KEY_KP_8 },
        .{ .key = .kp_9, .code = app_shell.KEY_KP_9 },
        .{ .key = .kp_decimal, .code = app_shell.KEY_KP_DECIMAL },
        .{ .key = .kp_divide, .code = app_shell.KEY_KP_DIVIDE },
        .{ .key = .kp_multiply, .code = app_shell.KEY_KP_MULTIPLY },
        .{ .key = .kp_subtract, .code = app_shell.KEY_KP_SUBTRACT },
        .{ .key = .kp_add, .code = app_shell.KEY_KP_ADD },
        .{ .key = .kp_enter, .code = app_shell.KEY_KP_ENTER },
        .{ .key = .kp_equal, .code = app_shell.KEY_KP_EQUAL },
        .{ .key = .left_shift, .code = app_shell.KEY_LEFT_SHIFT },
        .{ .key = .right_shift, .code = app_shell.KEY_RIGHT_SHIFT },
        .{ .key = .left_ctrl, .code = app_shell.KEY_LEFT_CONTROL },
        .{ .key = .right_ctrl, .code = app_shell.KEY_RIGHT_CONTROL },
        .{ .key = .left_alt, .code = app_shell.KEY_LEFT_ALT },
        .{ .key = .right_alt, .code = app_shell.KEY_RIGHT_ALT },
        .{ .key = .left_super, .code = app_shell.KEY_LEFT_SUPER },
        .{ .key = .right_super, .code = app_shell.KEY_RIGHT_SUPER },
    };

    for (key_map) |entry| {
        batch.key_down[@intFromEnum(entry.key)] = r.isKeyDown(entry.code);
        batch.key_pressed[@intFromEnum(entry.key)] = r.isKeyPressed(entry.code);
        batch.key_repeated[@intFromEnum(entry.key)] = r.isKeyRepeated(entry.code);
        batch.key_released[@intFromEnum(entry.key)] = r.isKeyReleased(entry.code);
    }

    while (r.getKeyPressed()) |press| {
        if (inputKeyFromShell(press.scancode)) |key| {
            var key_mods = batch.mods;
            key_mods.altgr = sdlModHasAltGr(press.mod_bits);
            batch.append(.{
                .key = .{
                    .key = key,
                    .mods = key_mods,
                    .repeated = press.repeated,
                    .pressed = true,
                    .scancode = press.scancode,
                    .sym = press.sym,
                .sdl_mod_bits = press.mod_bits,
                },
            }) catch |err| {
                if (log.enabled_file or log.enabled_console) {
                    log.logf(.warning, "batch append key failed key={s} err={s}", .{ @tagName(key), @errorName(err) });
                }
            };
        }
    }

    for (key_map) |entry| {
        if (!r.isKeyReleased(entry.code)) continue;
        batch.append(.{
            .key = .{
                .key = entry.key,
                .mods = batch.mods,
                .repeated = false,
                .pressed = false,
                .scancode = entry.code,
                .sym = null,
                .sdl_mod_bits = null,
                },
        }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "batch append key release failed key={s} err={s}", .{ @tagName(entry.key), @errorName(err) });
            }
        };
    }

    while (r.getTextPressed()) |text_press| {
        batch.append(.{ .text = .{
            .codepoint = text_press.codepoint,
            .utf8_len = text_press.utf8_len,
            .utf8 = text_press.utf8,
            .text_is_composed = text_press.text_is_composed,
        } }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "batch append text failed cp={d} err={s}", .{ text_press.codepoint, @errorName(err) });
            }
        };
    }

    while (r.getFocusEvent()) |focused| {
        batch.append(.{ .focus = focused }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "batch append focus failed focused={d} err={s}", .{ @intFromBool(focused), @errorName(err) });
            }
        };
    }

    const composition = r.getTextComposition();
    if (composition.active and composition.text.len > 0) {
        batch.composing_buffer.clearRetainingCapacity();
        _ = batch.composing_buffer.appendSlice(allocator, composition.text) catch |err| blk: {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "batch composing append failed bytes={d} err={s}", .{ composition.text.len, @errorName(err) });
            }
            break :blk 0;
        };
        batch.composing_text = batch.composing_buffer.items;
        batch.composing_cursor = composition.cursor;
        batch.composing_selection_len = composition.selection_len;
        batch.composing_active = true;
    }

    return batch;
}

fn inputKeyFromShell(key: i32) ?shared_types.input.Key {
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
        app_shell.KEY_F1 => .f1,
        app_shell.KEY_F2 => .f2,
        app_shell.KEY_F3 => .f3,
        app_shell.KEY_F4 => .f4,
        app_shell.KEY_F5 => .f5,
        app_shell.KEY_F6 => .f6,
        app_shell.KEY_F7 => .f7,
        app_shell.KEY_F8 => .f8,
        app_shell.KEY_F9 => .f9,
        app_shell.KEY_F10 => .f10,
        app_shell.KEY_F11 => .f11,
        app_shell.KEY_F12 => .f12,
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
        app_shell.KEY_LEFT_SHIFT => .left_shift,
        app_shell.KEY_RIGHT_SHIFT => .right_shift,
        app_shell.KEY_LEFT_CONTROL => .left_ctrl,
        app_shell.KEY_RIGHT_CONTROL => .right_ctrl,
        app_shell.KEY_LEFT_ALT => .left_alt,
        app_shell.KEY_RIGHT_ALT => .right_alt,
        app_shell.KEY_LEFT_SUPER => .left_super,
        app_shell.KEY_RIGHT_SUPER => .right_super,
        else => null,
    };
}
