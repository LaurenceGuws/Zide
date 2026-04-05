const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const native_host = @import("../../platform/native_host.zig");
const platform_input_events = @import("../../platform/input_events.zig");
const input_state = @import("input_state.zig");
const text_input = @import("text_input.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn pollInputEvents(
    domain: input_state.InputDomain,
    mouse_wheel_delta: *f32,
) void {
    const window_log = app_logger.logger("sdl.window");
    compactInputQueue(@TypeOf(domain.key_queue.items[0]), domain.key_queue, domain.key_queue_head);
    compactInputQueue(@TypeOf(domain.char_queue.items[0]), domain.char_queue, domain.char_queue_head);
    compactInputQueue(bool, domain.focus_queue, domain.focus_queue_head);

    const state = input_state.InputState{
        .key_down = domain.key_down,
        .key_pressed = domain.key_pressed,
        .key_repeated = domain.key_repeated,
        .key_released = domain.key_released,
        .mouse_down = domain.mouse_down,
        .mouse_pressed = domain.mouse_pressed,
        .mouse_released = domain.mouse_released,
        .mouse_clicks = domain.mouse_clicks,
        .key_queue = domain.key_queue,
        .char_queue = domain.char_queue,
        .composing_text = domain.composing_text,
        .composing_cursor = domain.composing_cursor,
        .composing_selection_len = domain.composing_selection_len,
        .composing_active = domain.composing_active,
        .mouse_wheel_delta = mouse_wheel_delta,
        .window_changes = domain.window_changes,
    };
    input_state.resetForFrame(state);
    @memset(domain.mouse_press_pos_valid, false);
    input_state.resetMouseWheel(mouse_wheel_delta);

    if (domain.pending_wait_event_valid.*) {
        handleEvent(domain, domain.pending_wait_event, window_log, state);
        domain.pending_wait_event_valid.* = false;
    }

    var event: sdl_api.c.SDL_Event = undefined;
    while (sdl_api.pollEvent(&event)) {
        handleEvent(domain, &event, window_log, state);
    }
}

fn handleEvent(
    domain: input_state.InputDomain,
    event: *const sdl_api.c.SDL_Event,
    window_log: app_logger.Logger,
    state: input_state.InputState,
) void {
    const main_window_id = sdl_api.getWindowId(domain.window);
    switch (event.type) {
        sdl_api.EVENT_QUIT => {
            domain.should_close_flag.* = true;
            domain.app_host.noteTerminationRequested();
        },
        sdl_api.EVENT_DROP_FILE => {
            if (sdl_api.dropEventWindowId(event) != main_window_id) return;
            const path = sdl_api.dropEventData(event) orelse return;
            _ = domain.app_host.noteOpenFileRequested(path);
        },
        sdl_api.EVENT_WINDOW => {
            if (sdl_api.windowEventId(event) != main_window_id) return;
            handleWindowEvent(event.type, domain.app_host, domain.should_close_flag, domain.window_changes);
            if (sdl_api.isFocusGainedEvent(event.type)) {
                sdl_api.startTextInput(domain.window);
                text_input.reapplyRect(domain.text_input_state, domain.window);
                domain.window_focused.* = true;
                domain.app_host.noteResumed();
                domain.focus_queue.append(domain.allocator, true) catch |err| {
                    window_log.logf(.warning, "focus queue append failed focused=1 err={s}", .{@errorName(err)});
                };
            }
            if (sdl_api.isFocusLostEvent(event.type)) {
                domain.window_focused.* = false;
                domain.app_host.notePaused();
                domain.focus_queue.append(domain.allocator, false) catch |err| {
                    window_log.logf(.warning, "focus queue append failed focused=0 err={s}", .{@errorName(err)});
                };
            }
        },
        sdl_api.EVENT_KEY_DOWN => {
            _ = platform_input_events.handleKeyDown(
                event,
                domain.key_down,
                domain.key_pressed,
                domain.key_repeated,
                domain.key_queue,
                domain.allocator,
            );
        },
        sdl_api.EVENT_KEY_UP => {
            _ = platform_input_events.handleKeyUp(event, domain.key_down, domain.key_released);
        },
        sdl_api.EVENT_TEXT_INPUT => {
            const text_was_composed = state.composing_active.*;
            _ = platform_input_events.handleTextInput(event, domain.char_queue, domain.allocator, text_was_composed);
            input_state.applyTextInputReset(state);
        },
        sdl_api.EVENT_TEXT_EDITING => {
            _ = platform_input_events.handleTextEditing(event, domain.composing_text, domain.composing_cursor, domain.composing_selection_len, domain.composing_active, domain.allocator);
        },
        sdl_api.EVENT_MOUSE_BUTTON_DOWN => {
            platform_input_events.handleMouseButtonDown(event, domain.mouse_down, domain.mouse_pressed, domain.mouse_clicks);
            const btn = @as(i32, @intCast(event.button.button));
            if (btn >= 0) {
                const idx: usize = @intCast(btn);
                if (idx < domain.mouse_press_pos.len) {
                    const raw_x = sdl_api.mouseButtonX(event);
                    const raw_y = sdl_api.mouseButtonY(event);
                    domain.mouse_press_pos[idx] = .{ .x = raw_x, .y = raw_y };
                    domain.mouse_press_pos_valid[idx] = true;
                }
            }
        },
        sdl_api.EVENT_MOUSE_BUTTON_UP => {
            platform_input_events.handleMouseButtonUp(event, domain.mouse_down, domain.mouse_released);
        },
        sdl_api.EVENT_MOUSE_WHEEL => input_state.addMouseWheel(state.mouse_wheel_delta, platform_input_events.wheelDelta(event)),
        else => {
            if (sdl_api.isRuntimeWakeEvent(event.type)) return;
            if (sdl_api.isWindowEventType(event.type)) {
                if (sdl_api.windowEventId(event) != main_window_id) return;
                handleWindowEvent(event.type, domain.app_host, domain.should_close_flag, domain.window_changes);
                if (sdl_api.isFocusGainedEvent(event.type)) {
                    sdl_api.startTextInput(domain.window);
                    text_input.reapplyRect(domain.text_input_state, domain.window);
                    domain.window_focused.* = true;
                    domain.app_host.noteResumed();
                    domain.focus_queue.append(domain.allocator, true) catch |err| {
                        window_log.logf(.warning, "focus queue append failed focused=1 err={s}", .{@errorName(err)});
                    };
                }
                if (sdl_api.isFocusLostEvent(event.type)) {
                    domain.window_focused.* = false;
                    domain.app_host.notePaused();
                    domain.focus_queue.append(domain.allocator, false) catch |err| {
                        window_log.logf(.warning, "focus queue append failed focused=0 err={s}", .{@errorName(err)});
                    };
                }
            }
        },
    }
}

fn handleWindowEvent(
    event_type: c_uint,
    app_host: *native_host.PlatformAppHost,
    should_close: *bool,
    window_changes: *sdl_api.WindowChangeMask,
) void {
    const change = sdl_api.classifyWindowChange(event_type);
    if (change.any()) {
        window_changes.merge(change);
    }
    if (sdl_api.isCloseEvent(event_type)) {
        should_close.* = true;
        app_host.noteTerminationRequested();
    }
}

fn compactInputQueue(comptime T: type, queue: *std.ArrayList(T), head: *usize) void {
    if (head.* == 0) return;
    if (head.* >= queue.items.len) {
        queue.clearRetainingCapacity();
        head.* = 0;
        return;
    }
    const remaining = queue.items.len - head.*;
    std.mem.copyForwards(T, queue.items[0..remaining], queue.items[head.*..queue.items.len]);
    queue.items.len = remaining;
    head.* = 0;
}
